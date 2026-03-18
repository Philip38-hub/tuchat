# TuChat

TuChat is a secure mobile messaging app built with Flutter. The current app is
wired to Firebase for authentication, Firestore, storage, messaging, and
biometric device unlock.

## Project Structure

```text
lib/
  models/
  providers/
  screens/
  services/
```

- `services/` contains backend and device-facing logic.
- `providers/` contains UI-facing state management built with Provider.
- `screens/` contains Flutter screens and screen wrappers.

## Current Backend

The app currently runs against Firebase project `tuchat-d0a3b`.

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
6. Configure this app:
   - `flutterfire configure --project=<firebase-project-id> --platforms=android,ios`
7. In Firebase Console, enable Email/Password under Authentication.
8. Create a Firestore database and paste the rules from `firestore.rules`.

## Run The App

1. Install dependencies:
   - `flutter pub get`
2. Verify the project:
   - `flutter analyze`
   - `flutter test`
3. List devices:
   - `flutter devices`
4. Run on Android:
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

## Next Cleanup Targets

- Move auth and chat screens into `lib/screens/`
- Add dedicated chat and session providers
- Introduce repository classes between services and providers
- Add integration tests for login, signup, and biometric unlock
