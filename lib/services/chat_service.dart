import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tuchat/models/chat.dart';
import 'package:tuchat/models/encrypted_message_payload.dart';
import 'package:tuchat/models/message.dart';
import 'package:tuchat/models/user.dart';
import 'package:tuchat/services/base_service.dart';
import 'package:tuchat/services/encryption_service.dart';
import 'package:tuchat/services/supabase_storage_service.dart';

class ChatService extends BaseService {
  ChatService({
    EncryptionService? encryptionService,
    SupabaseStorageService? storageService,
  }) : _encryptionService = encryptionService ?? EncryptionService(),
       _storageService = storageService ?? SupabaseStorageService();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final EncryptionService _encryptionService;
  final SupabaseStorageService _storageService;

  Future<List<AppUser>> searchUsersByUsername(
    String query, {
    String? excludeUid,
    int limit = 20,
  }) async {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) {
      return const [];
    }

    try {
      final snapshot = await _firestore
          .collection('users')
          .orderBy('usernameLowercase')
          .startAt([normalized])
          .endAt(['$normalized\uf8ff'])
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) => AppUser.fromMap(doc.data(), doc.id))
          .where((user) => user.uid != excludeUid && user.username.isNotEmpty)
          .toList();
    } catch (e) {
      logError('Failed to search users: $e');
      throw handleException(e);
    }
  }

  Future<AppUser?> getUserByUid(String uid) async {
    try {
      final snapshot = await _firestore.collection('users').doc(uid).get();
      if (!snapshot.exists) {
        return null;
      }

      final data = snapshot.data();
      if (data == null) {
        return null;
      }

      return AppUser.fromMap(data, snapshot.id);
    } catch (e) {
      logError('Failed to get user by uid: $e');
      throw handleException(e);
    }
  }

  Future<void> addContact({
    required String ownerUid,
    required String contactUid,
  }) async {
    if (ownerUid == contactUid) {
      throw 'You cannot add yourself as a contact.';
    }

    try {
      final contactUser = await getUserByUid(contactUid);
      if (contactUser == null) {
        throw 'No user found for the scanned QR code.';
      }

      final batch = _firestore.batch();
      final ownerContactRef = _firestore
          .collection('users')
          .doc(ownerUid)
          .collection('contacts')
          .doc(contactUid);
      final reverseContactRef = _firestore
          .collection('users')
          .doc(contactUid)
          .collection('contacts')
          .doc(ownerUid);

      batch.set(ownerContactRef, {
        'uid': contactUid,
        'addedAt': _nowTimestamp(),
      });
      batch.set(reverseContactRef, {
        'uid': ownerUid,
        'addedAt': _nowTimestamp(),
      });

      await batch.commit();
    } catch (e) {
      logError('Failed to add contact: $e');
      rethrow;
    }
  }

  Future<void> removeContact({
    required String ownerUid,
    required String contactUid,
  }) async {
    if (ownerUid == contactUid) {
      throw 'You cannot remove yourself as a contact.';
    }

    try {
      final batch = _firestore.batch();
      final ownerContactRef = _firestore
          .collection('users')
          .doc(ownerUid)
          .collection('contacts')
          .doc(contactUid);
      final reverseContactRef = _firestore
          .collection('users')
          .doc(contactUid)
          .collection('contacts')
          .doc(ownerUid);

      batch.delete(ownerContactRef);
      batch.delete(reverseContactRef);
      await batch.commit();
    } catch (e) {
      logError('Failed to remove contact: $e');
      throw handleException(e);
    }
  }

  Stream<List<AppUser>> streamContacts(String ownerUid) {
    return _firestore
        .collection('users')
        .doc(ownerUid)
        .collection('contacts')
        .orderBy('addedAt', descending: true)
        .snapshots()
        .asyncMap((snapshot) async {
          if (snapshot.docs.isEmpty) {
            return const <AppUser>[];
          }

          final futures = snapshot.docs
              .map((doc) => getUserByUid((doc.data()['uid'] ?? '').toString()))
              .toList();
          final users = await Future.wait(futures);
          return users.whereType<AppUser>().toList();
        });
  }

  Stream<List<Chat>> streamChats(String uid) {
    return _firestore
        .collection('chats')
        .where('participants', arrayContains: uid)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Chat.fromMap(doc.data(), doc.id))
              .where(
                (chat) =>
                    chat.lastMessageTime != null ||
                    (chat.lastMessage?.trim().isNotEmpty == true),
              )
              .toList(),
        );
  }

  Stream<Chat?> streamChat(String chatId) {
    return _firestore.collection('chats').doc(chatId).snapshots().map((doc) {
      if (!doc.exists) {
        return null;
      }

      final data = doc.data();
      if (data == null) {
        return null;
      }

      return Chat.fromMap(data, doc.id);
    });
  }

  Stream<List<Message>> streamMessages(String chatId) {
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Message.fromMap(doc.data(), doc.id))
              .toList(),
        );
  }

  Future<Chat> createOrGetDirectChat({
    required String currentUserId,
    required String otherUserId,
    bool isSecretChat = false,
  }) async {
    if (currentUserId == otherUserId) {
      throw 'You cannot chat with yourself.';
    }

    final chatId = buildDirectChatId(
      currentUserId,
      otherUserId,
      isSecretChat: isSecretChat,
    );

    return Chat(
      id: chatId,
      participants: _sortedParticipants(currentUserId, otherUserId),
      isSecretChat: isSecretChat,
    );
  }

  Future<void> sendTextMessage({
    required Chat chat,
    required String senderId,
    required String receiverId,
    required String content,
  }) async {
    final trimmed = content.trim();
    if (trimmed.isEmpty) {
      throw 'Message cannot be empty.';
    }

    try {
      await _ensureChatDocument(
        chat: chat,
        currentUserId: senderId,
        otherUserId: receiverId,
      );

      final messageRef = _firestore
          .collection('chats')
          .doc(chat.id)
          .collection('messages')
          .doc();
      final now = _nowTimestamp();

      String plainContent = trimmed;
      String? encryptedContent;
      String? recipientEncryptedSymmetricKey;
      String? senderEncryptedSymmetricKey;
      String? initializationVector;

      if (chat.isSecretChat) {
        final sender = await getUserByUid(senderId);
        final recipient = await getUserByUid(receiverId);
        if (sender == null ||
            sender.publicKey.isEmpty ||
            recipient == null ||
            recipient.publicKey.isEmpty) {
          throw 'Recipient encryption key is missing.';
        }

        final payload = await _encryptionService.encryptMessage(
          plainText: trimmed,
          senderPublicKey: sender.publicKey,
          recipientPublicKey: recipient.publicKey,
        );
        plainContent = '';
        encryptedContent = payload.encryptedMessage;
        recipientEncryptedSymmetricKey = payload.recipientEncryptedSymmetricKey;
        senderEncryptedSymmetricKey = payload.senderEncryptedSymmetricKey;
        initializationVector = payload.initializationVector;
      }

      await messageRef.set({
        'id': messageRef.id,
        'chatId': chat.id,
        'senderId': senderId,
        'receiverId': receiverId,
        'content': plainContent,
        'encryptedContent': encryptedContent,
        'encryptedSymmetricKey': recipientEncryptedSymmetricKey,
        'recipientEncryptedSymmetricKey': recipientEncryptedSymmetricKey,
        'senderEncryptedSymmetricKey': senderEncryptedSymmetricKey,
        'initializationVector': initializationVector,
        'timestamp': now,
        'isRead': false,
        'readAt': null,
        'type': MessageType.text.name,
        'mediaUrl': null,
        'storagePath': null,
        'mimeType': null,
        'fileName': null,
        'isEdited': false,
        'editedAt': null,
        'isDeleted': false,
        'deletedAt': null,
        'isSecret': chat.isSecretChat,
      });

      await _updateChatAfterMessage(
        chat: chat,
        senderId: senderId,
        receiverId: receiverId,
        preview: chat.isSecretChat ? 'Encrypted message' : trimmed,
        previewType: MessagePreviewType.text,
      );
    } catch (e) {
      logError('Failed to send text message: $e');
      throw handleException(e);
    }
  }

  Future<void> editMessage({
    required Chat chat,
    required String messageId,
    required String editorId,
    required String newContent,
    required String receiverId,
  }) async {
    final trimmed = newContent.trim();
    if (trimmed.isEmpty) {
      throw 'Message cannot be empty.';
    }

    final messageRef = _firestore
        .collection('chats')
        .doc(chat.id)
        .collection('messages')
        .doc(messageId);
    final messageSnapshot = await messageRef.get();
    final data = messageSnapshot.data();
    if (!messageSnapshot.exists || data == null) {
      throw 'Message no longer exists.';
    }

    final existingMessage = Message.fromMap(data, messageSnapshot.id);
    if (existingMessage.senderId != editorId) {
      throw 'You can only edit your own messages.';
    }

    try {
      String plainContent = trimmed;
      String? encryptedContent;
      String? recipientEncryptedSymmetricKey;
      String? senderEncryptedSymmetricKey;
      String? initializationVector;

      if (chat.isSecretChat) {
        final sender = await getUserByUid(editorId);
        final recipient = await getUserByUid(receiverId);
        if (sender == null ||
            sender.publicKey.isEmpty ||
            recipient == null ||
            recipient.publicKey.isEmpty) {
          throw 'Recipient encryption key is missing.';
        }

        final payload = await _encryptionService.encryptMessage(
          plainText: trimmed,
          senderPublicKey: sender.publicKey,
          recipientPublicKey: recipient.publicKey,
        );
        plainContent = '';
        encryptedContent = payload.encryptedMessage;
        recipientEncryptedSymmetricKey = payload.recipientEncryptedSymmetricKey;
        senderEncryptedSymmetricKey = payload.senderEncryptedSymmetricKey;
        initializationVector = payload.initializationVector;
      }

      await messageRef.update({
        'content': plainContent,
        'encryptedContent': encryptedContent,
        'encryptedSymmetricKey': recipientEncryptedSymmetricKey,
        'recipientEncryptedSymmetricKey': recipientEncryptedSymmetricKey,
        'senderEncryptedSymmetricKey': senderEncryptedSymmetricKey,
        'initializationVector': initializationVector,
        'isEdited': true,
        'editedAt': FieldValue.serverTimestamp(),
      });

      await _syncLastMessagePreview(chat.id);
    } catch (e) {
      logError('Failed to edit message: $e');
      throw handleException(e);
    }
  }

  Future<void> deleteMessage({
    required String chatId,
    required String messageId,
    required String requesterId,
  }) async {
    final messageRef = _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc(messageId);
    final snapshot = await messageRef.get();
    final data = snapshot.data();
    if (!snapshot.exists || data == null) {
      throw 'Message no longer exists.';
    }

    final existingMessage = Message.fromMap(data, snapshot.id);
    if (existingMessage.senderId != requesterId) {
      throw 'You can only delete your own messages.';
    }

    await messageRef.update({
      'content': '',
      'encryptedContent': null,
      'encryptedSymmetricKey': null,
      'recipientEncryptedSymmetricKey': null,
      'senderEncryptedSymmetricKey': null,
      'initializationVector': null,
      'mediaUrl': null,
      'storagePath': null,
      'mimeType': null,
      'fileName': null,
      'isDeleted': true,
      'deletedAt': FieldValue.serverTimestamp(),
      'type': MessageType.text.name,
    });

    await _syncLastMessagePreview(chatId);
  }

  Future<void> markMessagesAsRead({
    required String chatId,
    required String viewerId,
  }) async {
    try {
      final unreadMessages = await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .where('receiverId', isEqualTo: viewerId)
          .where('isRead', isEqualTo: false)
          .get();

      if (unreadMessages.docs.isEmpty) {
        await _firestore.collection('chats').doc(chatId).set({
          'unreadCounts': {viewerId: 0},
        }, SetOptions(merge: true));
        return;
      }

      final batch = _firestore.batch();
      for (final doc in unreadMessages.docs) {
        batch.update(doc.reference, {
          'isRead': true,
          'readAt': FieldValue.serverTimestamp(),
        });
      }
      batch.set(_firestore.collection('chats').doc(chatId), {
        'unreadCounts': {viewerId: 0},
      }, SetOptions(merge: true));

      await batch.commit();
    } catch (e) {
      logError('Failed to mark messages as read: $e');
      throw handleException(e);
    }
  }

  Future<void> updateTypingStatus({
    required String chatId,
    required String userId,
    required bool isTyping,
  }) async {
    try {
      await _firestore.collection('chats').doc(chatId).set({
        'typingUsers': {userId: isTyping},
      }, SetOptions(merge: true));
    } catch (e) {
      logError('Failed to update typing status: $e');
      throw handleException(e);
    }
  }

  Future<void> sendMediaMessage({
    required Chat chat,
    required String senderId,
    required String receiverId,
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
    required MessageType type,
  }) async {
    if (type != MessageType.image && type != MessageType.video) {
      throw 'Only image and video uploads are supported right now.';
    }

    try {
      await _ensureChatDocument(
        chat: chat,
        currentUserId: senderId,
        otherUserId: receiverId,
      );

      final messageRef = _firestore
          .collection('chats')
          .doc(chat.id)
          .collection('messages')
          .doc();
      final now = _nowTimestamp();
      final fileExtension = _fileExtension(fileName, mimeType);
      final storagePath =
          '${chat.id}/${DateTime.now().millisecondsSinceEpoch}_${messageRef.id}$fileExtension';

      var uploadBytes = bytes;
      String? encryptedContent;
      String? recipientEncryptedSymmetricKey;
      String? senderEncryptedSymmetricKey;
      String? initializationVector;

      if (chat.isSecretChat) {
        final sender = await getUserByUid(senderId);
        final recipient = await getUserByUid(receiverId);
        if (sender == null ||
            sender.publicKey.isEmpty ||
            recipient == null ||
            recipient.publicKey.isEmpty) {
          throw 'Encryption keys are missing for this secret chat.';
        }

        final payload = await _encryptionService.encryptBinary(
          bytes: bytes,
          senderPublicKey: sender.publicKey,
          recipientPublicKey: recipient.publicKey,
        );
        uploadBytes = Uint8List.fromList(base64Decode(payload.encryptedMessage));
        encryptedContent = payload.encryptedMessage;
        recipientEncryptedSymmetricKey = payload.recipientEncryptedSymmetricKey;
        senderEncryptedSymmetricKey = payload.senderEncryptedSymmetricKey;
        initializationVector = payload.initializationVector;
      }

      final upload = await _storageService.uploadBytes(
        bytes: uploadBytes,
        path: storagePath,
        mimeType: chat.isSecretChat ? 'application/octet-stream' : mimeType,
      );

      await messageRef.set({
        'id': messageRef.id,
        'chatId': chat.id,
        'senderId': senderId,
        'receiverId': receiverId,
        'content': '',
        'encryptedContent': encryptedContent,
        'encryptedSymmetricKey': recipientEncryptedSymmetricKey,
        'recipientEncryptedSymmetricKey': recipientEncryptedSymmetricKey,
        'senderEncryptedSymmetricKey': senderEncryptedSymmetricKey,
        'initializationVector': initializationVector,
        'timestamp': now,
        'isRead': false,
        'readAt': null,
        'type': type.name,
        'mediaUrl': upload.publicUrl,
        'storagePath': upload.path,
        'mimeType': mimeType,
        'fileName': fileName,
        'isEdited': false,
        'editedAt': null,
        'isDeleted': false,
        'deletedAt': null,
        'isSecret': chat.isSecretChat,
      });

      await _updateChatAfterMessage(
        chat: chat,
        senderId: senderId,
        receiverId: receiverId,
        preview: type == MessageType.image ? 'Image' : 'Video',
        previewType: type == MessageType.image
            ? MessagePreviewType.image
            : MessagePreviewType.video,
      );
    } catch (e) {
      logError('Failed to send media message: $e');
      throw handleException(e);
    }
  }

  String buildDirectChatId(
    String firstUid,
    String secondUid, {
    bool isSecretChat = false,
  }) {
    final sorted = _sortedParticipants(firstUid, secondUid);
    final prefix = isSecretChat ? 'secret' : 'direct';
    return '$prefix:${sorted.join('_')}';
  }

  List<String> _sortedParticipants(String firstUid, String secondUid) {
    final participants = [firstUid, secondUid]..sort();
    return participants;
  }

  Future<void> _ensureChatDocument({
    required Chat chat,
    required String currentUserId,
    required String otherUserId,
  }) {
    final now = _nowTimestamp();
    return _firestore.collection('chats').doc(chat.id).set({
      'participants': _sortedParticipants(currentUserId, otherUserId),
      'isSecretChat': chat.isSecretChat,
      'lastMessage': null,
      'lastMessageTime': null,
      'lastSenderId': null,
      'lastMessageType': MessagePreviewType.text.name,
      'unreadCounts': {
        currentUserId: 0,
        otherUserId: 0,
      },
      'typingUsers': {
        currentUserId: false,
        otherUserId: false,
      },
      'createdAt': now,
      'updatedAt': now,
    }, SetOptions(merge: true));
  }

  Future<void> _updateChatAfterMessage({
    required Chat chat,
    required String senderId,
    required String receiverId,
    required String preview,
    required MessagePreviewType previewType,
  }) async {
    final senderUnread = chat.unreadCountFor(senderId);
    final receiverUnread = chat.unreadCountFor(receiverId);
    final now = _nowTimestamp();

    await _firestore.collection('chats').doc(chat.id).set({
      'lastMessage': preview,
      'lastMessageTime': now,
      'lastSenderId': senderId,
      'lastMessageType': previewType.name,
      'typingUsers': {senderId: false},
      'unreadCounts': {
        senderId: senderUnread,
        receiverId: receiverUnread + 1,
      },
      'updatedAt': now,
    }, SetOptions(merge: true));
  }

  Future<void> _syncLastMessagePreview(String chatId) async {
    final latestSnapshot = await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .limit(1)
        .get();

    if (latestSnapshot.docs.isEmpty) {
      await _firestore.collection('chats').doc(chatId).set({
        'lastMessage': null,
        'lastMessageTime': null,
        'lastSenderId': null,
        'lastMessageType': MessagePreviewType.text.name,
        'updatedAt': _nowTimestamp(),
      }, SetOptions(merge: true));
      return;
    }

    final latestMessage = Message.fromMap(
      latestSnapshot.docs.first.data(),
      latestSnapshot.docs.first.id,
    );
    await _firestore.collection('chats').doc(chatId).set({
      'lastMessage': _previewForMessage(latestMessage),
      'lastMessageTime': latestSnapshot.docs.first.data()['timestamp'],
      'lastSenderId': latestMessage.senderId,
      'lastMessageType': _previewTypeForMessage(latestMessage).name,
      'updatedAt': latestSnapshot.docs.first.data()['timestamp'],
    }, SetOptions(merge: true));
  }

  String _previewForMessage(Message message) {
    if (message.isDeleted) {
      return 'Message deleted';
    }

    switch (message.type) {
      case MessageType.image:
        return 'Image';
      case MessageType.video:
        return 'Video';
      case MessageType.audio:
        return 'Audio';
      case MessageType.file:
        return message.fileName?.isNotEmpty == true ? message.fileName! : 'File';
      case MessageType.text:
        if (message.isSecret) {
          return 'Encrypted message';
        }
        return message.content;
    }
  }

  MessagePreviewType _previewTypeForMessage(Message message) {
    if (message.isDeleted) {
      return MessagePreviewType.deleted;
    }

    switch (message.type) {
      case MessageType.image:
        return MessagePreviewType.image;
      case MessageType.video:
        return MessagePreviewType.video;
      case MessageType.audio:
        return MessagePreviewType.audio;
      case MessageType.file:
        return MessagePreviewType.file;
      case MessageType.text:
        return MessagePreviewType.text;
    }
  }

  Future<String> decryptMessageForUser({
    required String uid,
    required Message message,
  }) async {
    if (!message.isSecret) {
      return message.content;
    }

    final encryptedContent = message.encryptedContent;
    final encryptedSymmetricKey = message.recipientEncryptedSymmetricKey;
    final initializationVector = message.initializationVector;

    if (encryptedContent == null ||
        encryptedSymmetricKey == null ||
        initializationVector == null) {
      throw 'Encrypted message payload is incomplete.';
    }

    return _encryptionService.decryptMessage(
      uid: uid,
      useSenderKey: uid == message.senderId,
      payload: EncryptedMessagePayload(
        encryptedMessage: encryptedContent,
        recipientEncryptedSymmetricKey: encryptedSymmetricKey,
        initializationVector: initializationVector,
        senderEncryptedSymmetricKey: message.senderEncryptedSymmetricKey,
      ),
    );
  }

  Future<Uint8List> downloadAndDecryptMedia({
    required String uid,
    required Message message,
  }) async {
    final storagePath = message.storagePath;
    if (storagePath == null || storagePath.isEmpty) {
      throw 'Media path is missing.';
    }

    final bytes = await _storageService.downloadBytes(storagePath);
    if (!message.isSecret) {
      return bytes;
    }

    final encryptedContent = message.encryptedContent;
    final recipientKey = message.recipientEncryptedSymmetricKey;
    final initializationVector = message.initializationVector;
    if (encryptedContent == null ||
        recipientKey == null ||
        initializationVector == null) {
      throw 'Encrypted media metadata is incomplete.';
    }

    return _encryptionService.decryptBinary(
      uid: uid,
      useSenderKey: uid == message.senderId,
      payload: EncryptedMessagePayload(
        encryptedMessage: encryptedContent,
        recipientEncryptedSymmetricKey: recipientKey,
        initializationVector: initializationVector,
        senderEncryptedSymmetricKey: message.senderEncryptedSymmetricKey,
      ),
    );
  }

  String _fileExtension(String fileName, String mimeType) {
    final normalizedName = fileName.toLowerCase();
    if (normalizedName.contains('.')) {
      return '.${normalizedName.split('.').last}';
    }

    if (mimeType.contains('png')) {
      return '.png';
    }
    if (mimeType.contains('jpeg') || mimeType.contains('jpg')) {
      return '.jpg';
    }
    if (mimeType.contains('mp4')) {
      return '.mp4';
    }
    if (mimeType.contains('mov')) {
      return '.mov';
    }
    return '';
  }

  Timestamp _nowTimestamp() => Timestamp.fromDate(DateTime.now());
}
