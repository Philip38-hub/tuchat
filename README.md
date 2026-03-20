# TuChat

TuChat is a secure mobile messaging app built with Flutter and Firebase. It
currently supports Firebase email/password auth, biometric app unlock, profile
setup, contact discovery, QR-based adding, end-to-end encryption for secret
chats, and real-time one-to-one messaging.

## Current Status

Completed so far:

- Phase 1: project structure, Provider-based state management, auth service,
  biometric unlock wrapper, and Firebase Auth wiring
- Phase 2: Firestore user schema, profile setup/edit flow, inline profile image
  handling, username search, and QR add-contact flow
- Phase 3: RSA keypair generation, secure local private-key storage, Firestore
  public-key storage, and hybrid AES/RSA encryption for secret chats
- Phase 4: real-time chat UI, message streams, typing indicators, read
  receipts, edit/delete actions, contact streaming, and chat/security rule
  fixes

Working now:

- Sign up and sign in
- Biometric gate before entering the app
- Profile creation and profile editing
- Username search and add contact
- Open normal chat and secret chat
- Send text messages in real time
- Read receipts
- Typing indicators
- Edit and delete your own messages

Not fully complete yet:

- Media upload/send for images and videos
- Alternative storage provider for media
- Group chats
- Push-notification handling in chat flows
- Broader automated test coverage

## Project Structure

```text
lib/
  models/
  providers/
  screens/
  services/
  utils/
```

- `services/` contains Firebase, encryption, and device-facing logic
- `providers/` contains UI-facing state management built with Provider
- `screens/` contains authentication, profile, contact, and chat screens
- `models/` contains Firestore/domain models such as users, chats, and messages

## Firebase Project

This workspace is wired to Firebase project `tuchat-d0a3b`.

Generated Firebase files:

- `lib/firebase_options.dart`
- `android/app/google-services.json`

## Firebase Setup

1. Install Flutter and Android Studio or the Android SDK command-line tools.
2. Install the Firebase CLI:
   - `npm install -g firebase-tools`
3. Install the FlutterFire CLI:
   - `dart pub global activate flutterfire_cli`
4. Make sure `~/.pub-cache/bin` is on your shell `PATH`.
5. Log in to Firebase:
   - `firebase login`
6. Configure this app if needed:
   - `flutterfire configure --project=<firebase-project-id> --platforms=android,ios`
7. In Firebase Console, enable Email/Password under Authentication.
8. Create a Firestore database.
9. Deploy the Firestore rules from this repo:
   - `firebase deploy --only firestore:rules --project tuchat-d0a3b`

## Firestore Notes

- The app relies on `firestore.rules` for contacts, chats, and messages.
- If chat list queries prompt for an index, create the index from the Firebase
  Console link shown in the error.
- Secret chats store RSA public keys in user documents and keep private keys on
  device in secure storage.

## Run The App

1. Install dependencies:
   - `flutter pub get`
2. Verify the project:
   - `flutter analyze`
   - `flutter test`
3. List devices:
   - `flutter devices`
4. Run on Android or iOS:
   - `flutter run -d <device-id>`

Example from this workspace:

- `flutter run -d RZ8W10PB5RZ`

## Android Permissions

Configured in `android/app/src/main/AndroidManifest.xml`:

- `android.permission.USE_BIOMETRIC`
- `android.permission.USE_FINGERPRINT`
- `android.permission.CAMERA`

## iOS Permissions

Configured in `ios/Runner/Info.plist`:

- `NSFaceIDUsageDescription`
- `NSCameraUsageDescription`

## Current Packages In Use

Key packages currently used in the app:

- `provider`
- `firebase_auth`
- `cloud_firestore`
- `firebase_messaging`
- `flutter_secure_storage`
- `encrypt`
- `asn1lib`
- `pointycastle`
- `local_auth`
- `qr_flutter`
- `mobile_scanner`
- `image_picker`
- `cached_network_image`
- `video_player`

## Known Limitations

- Media sending is intentionally blocked until a storage provider is chosen and
  integrated.
- Secret chat encryption is implemented for text messages; media encryption will
  come with the media pipeline.
- Existing widget tests are still minimal and do not yet cover full chat flows.
