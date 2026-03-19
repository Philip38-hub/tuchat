import 'package:cloud_firestore/cloud_firestore.dart';

class Message {
  final String id;
  final String senderId;
  final String receiverId;
  final String content;
  final String? encryptedContent;
  final DateTime timestamp;
  final bool isRead;
  final MessageType type;

  Message({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.content,
    this.encryptedContent,
    required this.timestamp,
    this.isRead = false,
    this.type = MessageType.text,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'senderId': senderId,
      'receiverId': receiverId,
      'content': content,
      'encryptedContent': encryptedContent,
      'timestamp': timestamp,
      'isRead': isRead,
      'type': type.toString(),
    };
  }

  factory Message.fromMap(Map<String, dynamic> map, String messageId) {
    return Message(
      id: messageId,
      senderId: map['senderId'] ?? '',
      receiverId: map['receiverId'] ?? '',
      content: map['content'] ?? '',
      encryptedContent: map['encryptedContent'],
      timestamp: (map['timestamp'] as Timestamp).toDate(),
      isRead: map['isRead'] ?? false,
      type: MessageType.values.firstWhere(
        (type) => type.toString() == map['type'],
        orElse: () => MessageType.text,
      ),
    );
  }
}

enum MessageType { text, image, video, audio, file }
