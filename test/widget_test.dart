import 'package:flutter_test/flutter_test.dart';
import 'package:tuchat/models/user.dart';

void main() {
  test('AppUser reports profile completion from username', () {
    final incompleteUser = AppUser(
      uid: 'uid-1',
      username: '',
      email: 'incomplete@example.com',
      profilePicUrl: '',
      publicKey: 'key-1',
      createdAt: DateTime(2026, 3, 19),
    );

    final completeUser = AppUser(
      uid: 'uid-2',
      username: 'alice',
      email: 'alice@example.com',
      profilePicUrl: '',
      publicKey: 'key-2',
      createdAt: DateTime(2026, 3, 19),
    );

    expect(incompleteUser.isProfileComplete, isFalse);
    expect(completeUser.isProfileComplete, isTrue);
    expect(completeUser.displayName, 'alice');
  });
}
