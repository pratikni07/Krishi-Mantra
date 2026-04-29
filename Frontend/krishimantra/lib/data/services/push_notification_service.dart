import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';

import '../repositories/notification_repository.dart';
import 'UserService.dart';

/// Background isolate handler. Has to be a top-level function because the
/// background isolate can't see closures from the main isolate.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // The background isolate spins up cold; ensure Firebase is initialised
  // before any messaging API call. We don't render anything here — the OS
  // already shows the system tray notification when the message has a
  // `notification` payload — but we still want the SDK initialised so
  // analytics / token refresh handlers fire.
  await Firebase.initializeApp();
}

/// Push notification service.
///
/// Responsibilities:
///   1. Initialise Firebase + request notification permission once.
///   2. Fetch the FCM token and register it with our notification-service.
///   3. Re-register on token rotation (Firebase rotates after app updates,
///      restore-from-backup, "clear data", etc.).
///   4. Show in-app banners for foreground messages — without this, the
///      OS swallows the notification entirely while the app is open.
///   5. Allow logout to clear the token both locally and server-side, so
///      a different user logging into the same device doesn't receive
///      the previous user's pushes.
///
/// FCM is free; no per-message charge, no paid tier needed. The only cost
/// is the platform setup (google-services.json on Android,
/// GoogleService-Info.plist on iOS) which is a one-time configuration.
class PushNotificationService extends GetxService {
  static const _androidChannelId = 'krishimantra_default';
  static const _androidChannelName = 'KrishiMantra notifications';

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  bool _initialised = false;
  bool _permissionGranted = false;
  String? _currentToken;
  StreamSubscription<String>? _tokenRefreshSub;
  StreamSubscription<RemoteMessage>? _foregroundSub;

  /// True if the user granted notification permission. Use this from the
  /// settings UI to render an "enable notifications" CTA when false.
  bool get permissionGranted => _permissionGranted;

  /// Latest FCM token; null until [start] resolves.
  String? get currentToken => _currentToken;

  /// Initialise Firebase + the local-notification plugin. Safe to call
  /// multiple times (idempotent). Call this from main() before runApp so
  /// background message handler is registered before any push can land.
  Future<void> initialiseSdk() async {
    if (_initialised) return;
    try {
      await Firebase.initializeApp();
    } catch (e) {
      // App might be already initialised (hot restart) — ignore.
      if (e is! FirebaseException || e.code != 'duplicate-app') {
        rethrow;
      }
    }

    // Register the background handler at the top of main() per FCM docs.
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Local-notifications channel is what the OS uses to render the
    // foreground banner. Android 8+ requires an explicit channel.
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _localNotifications.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
    );

    if (Platform.isAndroid) {
      const channel = AndroidNotificationChannel(
        _androidChannelId,
        _androidChannelName,
        description: 'General notifications from KrishiMantra',
        importance: Importance.high,
      );
      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
    }

    _initialised = true;
  }

  /// Request permission, fetch the token, and register it with the
  /// backend. Call this from the post-auth code path (splash) after the
  /// access token has been validated — registering before login means we
  /// have nowhere to attribute the token to.
  Future<void> start() async {
    if (!_initialised) {
      await initialiseSdk();
    }

    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    _permissionGranted =
        settings.authorizationStatus == AuthorizationStatus.authorized ||
            settings.authorizationStatus == AuthorizationStatus.provisional;

    if (!_permissionGranted) {
      // User declined — nothing to register. They can still receive
      // in-app notifications via the websocket; this just means OS-level
      // banners are off.
      return;
    }

    // iOS may not return an APNs token immediately on cold start; the
    // FCM SDK waits internally, but we add a small retry to give it a
    // chance under flaky network conditions. A null token at this point
    // is recoverable — onTokenRefresh will eventually fire.
    String? token;
    for (var attempt = 0; attempt < 3 && token == null; attempt++) {
      try {
        token = await _messaging.getToken();
      } catch (_) {}
      if (token == null) await Future<void>.delayed(const Duration(seconds: 1));
    }
    if (token != null) {
      _currentToken = token;
      await _registerToken(token);
    }

    // Token rotates on app reinstalls, restore-from-backup, clear-data.
    // Replacing eagerly means we never silently drop pushes for a device.
    _tokenRefreshSub?.cancel();
    _tokenRefreshSub = _messaging.onTokenRefresh.listen((newToken) async {
      _currentToken = newToken;
      await _registerToken(newToken);
    });

    // Foreground messages: the OS hides them while the app is in the
    // foreground. We render via flutter_local_notifications so they
    // appear in the system tray consistently with background messages.
    _foregroundSub?.cancel();
    _foregroundSub = FirebaseMessaging.onMessage.listen(_handleForeground);
  }

  Future<void> _registerToken(String token) async {
    try {
      final userService = Get.find<UserService>();
      final user = await userService.getUser();
      if (user == null) return; // Logged out before token resolved.
      final repo = Get.find<NotificationRepository>();
      final platform = Platform.isIOS
          ? 'ios'
          : (Platform.isAndroid ? 'android' : 'web');
      await repo.registerPushToken(
        userId: user.id,
        token: token,
        platform: platform,
      );
    } catch (e) {
      // Silent — registration is best-effort and the next start() retries.
      if (kDebugMode) {
        // ignore: avoid_print
        print('PushNotificationService.registerToken failed: $e');
      }
    }
  }

  void _handleForeground(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;
    _localNotifications.show(
      // Pack the message id into the notification id so duplicate displays
      // for retried deliveries replace, not stack.
      message.messageId.hashCode,
      notification.title,
      notification.body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _androidChannelId,
          _androidChannelName,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      payload: message.data.isEmpty ? null : message.data.toString(),
    );
  }

  /// Tear down on logout. Clears the registered token from the server and
  /// from the FCM SDK so the next user on this device can't receive the
  /// previous user's pushes.
  Future<void> stopAndUnregister() async {
    final tokenToClear = _currentToken;
    final userService = Get.isRegistered<UserService>() ? Get.find<UserService>() : null;
    final user = userService == null ? null : await userService.getUser();

    await _foregroundSub?.cancel();
    _foregroundSub = null;
    await _tokenRefreshSub?.cancel();
    _tokenRefreshSub = null;

    try {
      if (user != null && Get.isRegistered<NotificationRepository>()) {
        await Get.find<NotificationRepository>().unregisterPushToken(userId: user.id);
      }
    } catch (_) {}
    try {
      // Calling deleteToken forces FCM to mint a fresh one on next start,
      // so any messages still in flight to the old token bounce instead
      // of being delivered to the post-logout account.
      await _messaging.deleteToken();
    } catch (_) {}
    _currentToken = tokenToClear == null ? null : null;
  }
}
