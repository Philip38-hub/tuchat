# TuChat

TuChat is a Flutter mobile messaging app that uses Firebase for authentication
and Cloud Firestore data, with Supabase Storage for chat media. It supports
biometric unlock, user profiles, contact discovery, direct chats, secret chats,
and real-time messaging.

## Features

- Email/password sign up and sign in with Firebase Auth
- Biometric gate before entering the app
- User profile creation and editing
- Username search and QR-based contact adding
- Real-time one-to-one chats
- Secret chats with hybrid RSA/AES encryption
- Read receipts and typing indicators
- Edit and delete your own messages
- Image and video media messages backed by Supabase Storage

## Tech Stack

- Flutter
- Provider
- Firebase Auth
- Cloud Firestore
- Flutter Secure Storage
- Supabase Storage
- `encrypt`, `asn1lib`, `pointycastle`
- `local_auth`
- `image_picker`
- `cached_network_image`
- `video_player`

## Project Structure

```text
lib/
  config/
  models/
  providers/
  screens/
  services/
  utils/
```

## Prerequisites

Make sure you have the following installed:

- Flutter SDK
- Android Studio or Xcode
- Firebase CLI
- FlutterFire CLI

Helpful install commands:

```bash
npm install -g firebase-tools
dart pub global activate flutterfire_cli
```

## Local Setup

### 1. Clone and install dependencies

```bash
git clone https://github.com/Philip38-hub/tuchat.git
cd tuchat
flutter pub get
```

### 2. Firebase setup

This project is already wired to Firebase project `tuchat-d0a3b`, but if you
need to reconfigure it:

```bash
firebase login
flutterfire configure --project=tuchat-d0a3b --platforms=android,ios
```

In Firebase Console:

- Enable Email/Password sign-in under Authentication
- Create a Firestore database

Deploy Firestore rules:

```bash
firebase deploy --only firestore:rules --project <PROJECT_ID>
```

Important notes:

- `firestore.rules` controls contacts, chats, and messages.
- When Firestore asks for a composite index, create it from the Firebase
  Console link shown in the error.

### 3. Supabase Storage setup

Create a Supabase project and configure Storage for chat media.

1. Create a bucket named `chat-media` or choose another bucket name.
2. For the current client-side integration, mark the bucket as public.
3. Add storage policies in the Supabase SQL editor:

```sql
drop policy if exists "chat media public read" on storage.objects;
drop policy if exists "chat media public insert" on storage.objects;
drop policy if exists "chat media public update" on storage.objects;

create policy "chat media public read"
on storage.objects
for select
to anon
using (bucket_id = 'chat-media');

create policy "chat media public insert"
on storage.objects
for insert
to anon
with check (bucket_id = 'chat-media');

create policy "chat media public update"
on storage.objects
for update
to anon
using (bucket_id = 'chat-media')
with check (bucket_id = 'chat-media');
```

### 4. Run locally

Provide Supabase values with `--dart-define`:

```bash
flutter run \
  --dart-define=SUPABASE_URL=YOUR_SUPABASE_URL \
  --dart-define=SUPABASE_ANON_KEY=YOUR_SUPABASE_ANON_KEY \
  --dart-define=SUPABASE_STORAGE_BUCKET=chat-media
```

If you want to target a specific device:

```bash
flutter devices
flutter run -d <device-id> \
  --dart-define=SUPABASE_URL=YOUR_SUPABASE_URL \
  --dart-define=SUPABASE_ANON_KEY=YOUR_SUPABASE_ANON_KEY \
  --dart-define=SUPABASE_STORAGE_BUCKET=chat-media
```

## Verification

Run:

```bash
flutter analyze
flutter test
```

## Security Notes

- Firebase Auth is the source of truth for user identity.
- Cloud Firestore is the source of truth for users, contacts, chats, and
  message metadata.
- Supabase Storage stores media file bytes only.
- Secret chat private keys are kept on-device in secure storage and are never
  uploaded.
- Secret chat text and secret media are encrypted on-device before being stored
  or uploaded.

## Platform Permissions

Android:

- `android.permission.USE_BIOMETRIC`
- `android.permission.USE_FINGERPRINT`
- `android.permission.CAMERA`

iOS:

- `NSFaceIDUsageDescription`
- `NSCameraUsageDescription`

## Limitations

- Supabase Storage currently uses a client-side public-bucket flow because the
  app uses Firebase Auth rather than Supabase Auth.
- A production deployment should harden media authorization with a trusted
  backend or Supabase Edge Function.
- Automated test coverage is still light for full chat and media flows.
