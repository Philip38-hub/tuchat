import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tuchat/models/user.dart';
import 'package:tuchat/services/base_service.dart';

class ChatService extends BaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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
}
