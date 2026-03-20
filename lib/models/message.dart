import 'package:cloud_firestore/cloud_firestore.dart';

class Message {
  final String id;
  final String chatId;
  final String senderId;
  final String receiverId;
  final String content;
  final String? encryptedContent;
  final String? recipientEncryptedSymmetricKey;
  final String? senderEncryptedSymmetricKey;
  final String? initializationVector;
  final DateTime timestamp;
  final bool isRead;
  final DateTime? readAt;
  final MessageType type;
  final String? mediaUrl;
  final String? storagePath;
  final String? mimeType;
  final String? fileName;
  final bool isEdited;
  final DateTime? editedAt;
  final bool isDeleted;
  final DateTime? deletedAt;
  final bool isSecret;

  Message({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.receiverId,
    required this.content,
    this.encryptedContent,
    this.recipientEncryptedSymmetricKey,
    this.senderEncryptedSymmetricKey,
    this.initializationVector,
    required this.timestamp,
    this.isRead = false,
    this.readAt,
    this.type = MessageType.text,
    this.mediaUrl,
    this.storagePath,
    this.mimeType,
    this.fileName,
    this.isEdited = false,
    this.editedAt,
    this.isDeleted = false,
    this.deletedAt,
    this.isSecret = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'chatId': chatId,
      'senderId': senderId,
      'receiverId': receiverId,
      'content': content,
      'encryptedContent': encryptedContent,
      'encryptedSymmetricKey': recipientEncryptedSymmetricKey,
      'recipientEncryptedSymmetricKey': recipientEncryptedSymmetricKey,
      'senderEncryptedSymmetricKey': senderEncryptedSymmetricKey,
      'initializationVector': initializationVector,
      'timestamp': timestamp,
      'isRead': isRead,
      'readAt': readAt,
      'type': type.name,
      'mediaUrl': mediaUrl,
      'storagePath': storagePath,
      'mimeType': mimeType,
      'fileName': fileName,
      'isEdited': isEdited,
      'editedAt': editedAt,
      'isDeleted': isDeleted,
      'deletedAt': deletedAt,
      'isSecret': isSecret,
    };
  }

  factory Message.fromMap(Map<String, dynamic> map, String messageId) {
    return Message(
      id: messageId,
      chatId: map['chatId'] ?? '',
      senderId: map['senderId'] ?? '',
      receiverId: map['receiverId'] ?? '',
      content: map['content'] ?? '',
      encryptedContent: map['encryptedContent'],
      recipientEncryptedSymmetricKey:
          map['recipientEncryptedSymmetricKey'] ?? map['encryptedSymmetricKey'],
      senderEncryptedSymmetricKey: map['senderEncryptedSymmetricKey'],
      initializationVector: map['initializationVector'],
      timestamp: map['timestamp'] is Timestamp
          ? (map['timestamp'] as Timestamp).toDate()
          : DateTime.now(),
      isRead: map['isRead'] ?? false,
      readAt: map['readAt'] is Timestamp
          ? (map['readAt'] as Timestamp).toDate()
          : null,
      type: MessageType.values.firstWhere(
        (type) => type.name == map['type'],
        orElse: () => MessageType.text,
      ),
      mediaUrl: map['mediaUrl'],
      storagePath: map['storagePath'],
      mimeType: map['mimeType'],
      fileName: map['fileName'],
      isEdited: map['isEdited'] ?? false,
      editedAt: map['editedAt'] is Timestamp
          ? (map['editedAt'] as Timestamp).toDate()
          : null,
      isDeleted: map['isDeleted'] ?? false,
      deletedAt: map['deletedAt'] is Timestamp
          ? (map['deletedAt'] as Timestamp).toDate()
          : null,
      isSecret: map['isSecret'] ?? false,
    );
  }
}

enum MessageType { text, image, video, audio, file }
