# Firebase Cloud Messaging — setup checklist

The Dart-side push wiring is in place
(`lib/data/services/push_notification_service.dart`,
`NotificationRepository.registerPushToken`, splash + logout hooks).
You still need to do the **per-platform Firebase project setup** once before
push works. None of this costs money — FCM is free.

## 1. Create the Firebase project

1. Go to <https://console.firebase.google.com> and create a project
   (or pick an existing one).
2. Add an Android app: package name `com.krishimantra.krishimantra`
   (match `applicationId` in `android/app/build.gradle`).
3. Add an iOS app: bundle id matches the one in
   `ios/Runner.xcodeproj/project.pbxproj`.

## 2. Android

1. Download `google-services.json` from the Firebase console and drop it at
   `android/app/google-services.json`. **Do NOT commit it** — it's in
   `.gitignore` per Firebase guidance.
2. Add the Google services Gradle plugin:

   `android/build.gradle` (or `android/settings.gradle.kts` for newer
   templates) — add the classpath dependency:

   ```gradle
   buildscript {
       dependencies {
           classpath 'com.google.gms:google-services:4.4.2'
       }
   }
   ```

3. `android/app/build.gradle` — apply the plugin at the bottom of the
   file:

   ```gradle
   apply plugin: 'com.google.gms.google-services'
   ```

4. Confirm `minSdkVersion` is at least `21` (firebase_messaging requires
   it).
5. Android 13+: the OS shows a runtime permission prompt. The Dart code
   already calls `requestPermission()`, but you must also declare the
   permission in `android/app/src/main/AndroidManifest.xml`:

   ```xml
   <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
   ```

## 3. iOS

1. Download `GoogleService-Info.plist` and drag it into
   `ios/Runner/` via Xcode (so it gets added to the build phase).
2. Enable **Push Notifications** + **Background Modes → Remote
   notifications** in `Runner` target capabilities.
3. Upload your APNs auth key (`.p8`) to Firebase console →
   Project settings → Cloud Messaging → Apple app config.
4. `ios/Runner/AppDelegate.swift` — add the FCM imports and registration.
   See [firebase_messaging README](https://pub.dev/packages/firebase_messaging#ios)
   for the exact snippet (don't paste blindly; the snippet differs
   between Flutter SDK versions).

## 4. Server-side credentials

The notification-service needs Firebase admin credentials to actually
dispatch pushes. Set ONE of:

- `FIREBASE_SERVICE_ACCOUNT_JSON` — paste the entire service-account
  JSON blob into the env var (preferred for k8s secrets).
- `FIREBASE_SERVICE_ACCOUNT_PATH` — filesystem path to the JSON.
- `GOOGLE_APPLICATION_CREDENTIALS` — standard Google ADC env var.

If none is set, the service still boots; push is just disabled and
logged once at startup (`FCM provider initialisation failed`). In-app +
websocket notifications continue to work.

## 5. Verify end-to-end

1. Build + run the app on a real device (push doesn't work on the
   simulator without an APNs cert).
2. Log in. Watch logs for:
   - `FCM SDK initialised`
   - `PushNotificationService.start` resolving without error
   - `PUT /api/notification/users/{userId}/push-token` returning 200
3. Trigger a test notification:
   ```sh
   curl -X POST https://api.krishimantra.com/api/notification/users/<userId>/notifications/test \
     -H "Authorization: Bearer <token>"
   ```
4. The OS tray should show the notification within a few seconds.

## 6. Cost note

FCM has no per-message charge. Quotas (1 message/sec/topic, 8 KB
payload, etc.) are far above ordinary use. A real APNs auth key is
also free from your Apple Developer account.
