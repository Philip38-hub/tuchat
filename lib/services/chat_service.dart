import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tuchat/models/chat.dart';
import 'package:tuchat/models/encrypted_message_payload.dart';
import 'package:tuchat/models/message.dart';
import 'package:tuchat/models/user.dart';
import 'package:tuchat/services/base_service.dart';
import 'package:tuchat/services/encryption_service.dart';

class ChatService extends BaseService {
  ChatService({EncryptionService? encryptionService})
    : _encryptionService = encryptionService ?? EncryptionService();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final EncryptionService _encryptionService;

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
        'addedAt': FieldValue.serverTimestamp(),
      });
      batch.set(reverseContactRef, {
        'uid': ownerUid,
        'addedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();
    } catch (e) {
      logError('Failed to add contact: $e');
      rethrow;
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
        .orderBy('lastMessageTime', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Chat.fromMap(doc.data(), doc.id))
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
    final chatRef = _firestore.collection('chats').doc(chatId);

    await chatRef.set({
      'participants': _sortedParticipants(currentUserId, otherUserId),
      'isSecretChat': isSecretChat,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

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
      final messageRef = _firestore
          .collection('chats')
          .doc(chat.id)
          .collection('messages')
          .doc();

      String plainContent = trimmed;
      String? encryptedContent;
      String? encryptedSymmetricKey;
      String? initializationVector;

      if (chat.isSecretChat) {
        final recipient = await getUserByUid(receiverId);
        if (recipient == null || recipient.publicKey.isEmpty) {
          throw 'Recipient encryption key is missing.';
        }

        final payload = await _encryptionService.encryptMessage(
          plainText: trimmed,
          recipientPublicKey: recipient.publicKey,
        );
        plainContent = '';
        encryptedContent = payload.encryptedMessage;
        encryptedSymmetricKey = payload.encryptedSymmetricKey;
        initializationVector = payload.initializationVector;
      }

      await messageRef.set({
        'id': messageRef.id,
        'chatId': chat.id,
        'senderId': senderId,
        'receiverId': receiverId,
        'content': plainContent,
        'encryptedContent': encryptedContent,
        'encryptedSymmetricKey': encryptedSymmetricKey,
        'initializationVector': initializationVector,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
        'readAt': null,
        'type': MessageType.text.name,
        'mediaUrl': null,
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
      String? encryptedSymmetricKey;
      String? initializationVector;

      if (chat.isSecretChat) {
        final recipient = await getUserByUid(receiverId);
        if (recipient == null || recipient.publicKey.isEmpty) {
          throw 'Recipient encryption key is missing.';
        }

        final payload = await _encryptionService.encryptMessage(
          plainText: trimmed,
          recipientPublicKey: recipient.publicKey,
        );
        plainContent = '';
        encryptedContent = payload.encryptedMessage;
        encryptedSymmetricKey = payload.encryptedSymmetricKey;
        initializationVector = payload.initializationVector;
      }

      await messageRef.update({
        'content': plainContent,
        'encryptedContent': encryptedContent,
        'encryptedSymmetricKey': encryptedSymmetricKey,
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
      'initializationVector': null,
      'mediaUrl': null,
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
        'updatedAt': FieldValue.serverTimestamp(),
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
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      logError('Failed to update typing status: $e');
      throw handleException(e);
    }
  }

  Future<void> sendMediaMessage({
    required String chatId,
    required String senderId,
    required String receiverId,
  }) async {
    throw 'Media uploads are not configured yet. We need a storage provider before image/video sending can go live.';
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

  Future<void> _updateChatAfterMessage({
    required Chat chat,
    required String senderId,
    required String receiverId,
    required String preview,
    required MessagePreviewType previewType,
  }) async {
    final senderUnread = chat.unreadCountFor(senderId);
    final receiverUnread = chat.unreadCountFor(receiverId);

    await _firestore.collection('chats').doc(chat.id).set({
      'lastMessage': preview,
      'lastMessageTime': FieldValue.serverTimestamp(),
      'lastSenderId': senderId,
      'lastMessageType': previewType.name,
      'typingUsers': {senderId: false},
      'unreadCounts': {
        senderId: senderUnread,
        receiverId: receiverUnread + 1,
      },
      'updatedAt': FieldValue.serverTimestamp(),
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
        'updatedAt': FieldValue.serverTimestamp(),
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
      'updatedAt': FieldValue.serverTimestamp(),
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
    final encryptedSymmetricKey = message.encryptedSymmetricKey;
    final initializationVector = message.initializationVector;

    if (encryptedContent == null ||
        encryptedSymmetricKey == null ||
        initializationVector == null) {
      throw 'Encrypted message payload is incomplete.';
    }

    return _encryptionService.decryptMessage(
      uid: uid,
      payload: EncryptedMessagePayload(
        encryptedMessage: encryptedContent,
        encryptedSymmetricKey: encryptedSymmetricKey,
        initializationVector: initializationVector,
      ),
    );
  }
}
