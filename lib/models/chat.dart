import 'package:cloud_firestore/cloud_firestore.dart';

class Chat {
  final String id;
  final List<String> participants;
  final bool isSecretChat;
  final String? lastMessage;
  final DateTime? lastMessageTime;
  final String? lastSenderId;
  final MessagePreviewType lastMessageType;
  final Map<String, int> unreadCounts;
  final Map<String, bool> typingUsers;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Chat({
    required this.id,
    required this.participants,
    this.isSecretChat = false,
    this.lastMessage,
    this.lastMessageTime,
    this.lastSenderId,
    this.lastMessageType = MessagePreviewType.text,
    this.unreadCounts = const {},
    this.typingUsers = const {},
    this.createdAt,
    this.updatedAt,
  });

  int unreadCountFor(String uid) => unreadCounts[uid] ?? 0;

  bool isUserTyping(String uid) => typingUsers[uid] ?? false;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'participants': participants,
      'isSecretChat': isSecretChat,
      'lastMessage': lastMessage,
      'lastMessageTime': lastMessageTime,
      'lastSenderId': lastSenderId,
      'lastMessageType': lastMessageType.name,
      'unreadCounts': unreadCounts,
      'typingUsers': typingUsers,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  factory Chat.fromMap(Map<String, dynamic> map, String chatId) {
    final unreadCountsMap = (map['unreadCounts'] as Map<String, dynamic>?) ?? {};
    final typingUsersMap = (map['typingUsers'] as Map<String, dynamic>?) ?? {};

    return Chat(
      id: chatId,
      participants: List<String>.from(map['participants'] ?? []),
      isSecretChat: map['isSecretChat'] == true,
      lastMessage: map['lastMessage'],
      lastMessageTime: map['lastMessageTime'] != null
          ? (map['lastMessageTime'] as Timestamp).toDate()
          : null,
      lastSenderId: map['lastSenderId'],
      lastMessageType: MessagePreviewType.values.firstWhere(
        (type) => type.name == map['lastMessageType'],
        orElse: () => MessagePreviewType.text,
      ),
      unreadCounts: unreadCountsMap.map(
        (key, value) => MapEntry(key, (value as num?)?.toInt() ?? 0),
      ),
      typingUsers: typingUsersMap.map(
        (key, value) => MapEntry(key, value == true),
      ),
      createdAt: map['createdAt'] is Timestamp
          ? (map['createdAt'] as Timestamp).toDate()
          : null,
      updatedAt: map['updatedAt'] is Timestamp
          ? (map['updatedAt'] as Timestamp).toDate()
          : null,
    );
  }
}

enum MessagePreviewType { text, image, video, audio, file, deleted }
