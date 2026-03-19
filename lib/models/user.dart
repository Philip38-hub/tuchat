import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
  final String uid;
  final String username;
  final String email;
  final String profilePicUrl;
  final String publicKey;
  final DateTime createdAt;
  final DateTime? lastSeen;

  const AppUser({
    required this.uid,
    required this.username,
    required this.email,
    required this.profilePicUrl,
    required this.publicKey,
    required this.createdAt,
    this.lastSeen,
  });

  String get id => uid;
  String? get displayName => username.isEmpty ? null : username;
  String? get photoUrl => profilePicUrl.isEmpty ? null : profilePicUrl;
  bool get isProfileComplete => username.trim().isNotEmpty;

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'username': username,
      'usernameLowercase': username.toLowerCase(),
      'email': email,
      'profilePicUrl': profilePicUrl,
      'publicKey': publicKey,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastSeen': lastSeen != null ? Timestamp.fromDate(lastSeen!) : null,
    };
  }

  AppUser copyWith({
    String? uid,
    String? username,
    String? email,
    String? profilePicUrl,
    String? publicKey,
    DateTime? createdAt,
    DateTime? lastSeen,
  }) {
    return AppUser(
      uid: uid ?? this.uid,
      username: username ?? this.username,
      email: email ?? this.email,
      profilePicUrl: profilePicUrl ?? this.profilePicUrl,
      publicKey: publicKey ?? this.publicKey,
      createdAt: createdAt ?? this.createdAt,
      lastSeen: lastSeen ?? this.lastSeen,
    );
  }

  factory AppUser.fromMap(Map<String, dynamic> map, String uid) {
    final createdAt = map['createdAt'];
    final lastSeen = map['lastSeen'];

    return AppUser(
      uid: uid,
      username: (map['username'] ?? map['displayName'] ?? '').toString(),
      email: (map['email'] ?? '').toString(),
      profilePicUrl: (map['profilePicUrl'] ?? map['photoUrl'] ?? '').toString(),
      publicKey: (map['publicKey'] ?? '').toString(),
      createdAt: createdAt is Timestamp ? createdAt.toDate() : DateTime.now(),
      lastSeen: lastSeen is Timestamp ? lastSeen.toDate() : null,
    );
  }

  factory AppUser.fromFirebaseAuth(Map<String, dynamic> map) {
    return AppUser(
      uid: (map['uid'] ?? '').toString(),
      username: (map['displayName'] ?? '').toString(),
      email: (map['email'] ?? '').toString(),
      profilePicUrl: (map['photoUrl'] ?? '').toString(),
      publicKey: (map['publicKey'] ?? '').toString(),
      createdAt: DateTime.now(),
      lastSeen: DateTime.now(),
    );
  }
}
