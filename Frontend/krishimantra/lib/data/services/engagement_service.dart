import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:get/get.dart';
import '../services/api_service.dart';
import '../../core/utils/app_logger.dart';
import '../../core/constants/api_constants.dart';

/// Event categories for tracking
class EventCategory {
  static const String navigation = 'navigation';
  static const String engagement = 'engagement';
  static const String content = 'content';
  static const String social = 'social';
  static const String commerce = 'commerce';
  static const String communication = 'communication';
  static const String ai = 'ai';
  static const String system = 'system';
}

/// Event names for tracking
class EventName {
  // Navigation events
  static const String screenView = 'screen_view';
  static const String screenExit = 'screen_exit';
  static const String appOpen = 'app_open';
  static const String appClose = 'app_close';
  static const String appBackground = 'app_background';
  static const String appForeground = 'app_foreground';

  // Feed events
  static const String feedView = 'feed_view';
  static const String feedLike = 'feed_like';
  static const String feedUnlike = 'feed_unlike';
  static const String feedComment = 'feed_comment';
  static const String feedShare = 'feed_share';
  static const String feedCreate = 'feed_create';
  static const String feedScroll = 'feed_scroll';

  // Reel events
  static const String reelView = 'reel_view';
  static const String reelLike = 'reel_like';
  static const String reelComment = 'reel_comment';
  static const String reelShare = 'reel_share';
  static const String reelComplete = 'reel_complete';
  static const String reelSkip = 'reel_skip';

  // Product events
  static const String productView = 'product_view';
  static const String productSearch = 'product_search';
  static const String productAddCart = 'product_add_cart';
  static const String productPurchase = 'product_purchase';
  static const String productInquiry = 'product_inquiry';

  // Chat events
  static const String chatOpen = 'chat_open';
  static const String chatMessageSent = 'chat_message_sent';
  static const String chatMessageReceived = 'chat_message_received';

  // AI events
  static const String aiChatStart = 'ai_chat_start';
  static const String aiChatMessage = 'ai_chat_message';
  static const String aiCropScan = 'ai_crop_scan';

  // Other feature events
  static const String schemeView = 'scheme_view';
  static const String weatherCheck = 'weather_check';
  static const String cropCalendarView = 'crop_calendar_view';
  static const String videoTutorialView = 'video_tutorial_view';
  static const String notificationClick = 'notification_click';
  static const String notificationReceived = 'notification_received';

  // User events
  static const String userLogin = 'user_login';
  static const String userLogout = 'user_logout';
  static const String userSignup = 'user_signup';
  static const String userProfileUpdate = 'user_profile_update';

  // Consultant events
  static const String consultantDirectoryView = 'consultant_directory_view';
  static const String consultantProfileView = 'consultant_profile_view';
  static const String consultantChatRequest = 'consultant_chat_request';
  static const String consultantChatAccepted = 'consultant_chat_accepted';
  static const String consultantChatCompleted = 'consultant_chat_completed';
  static const String consultantRatingSubmitted = 'consultant_rating_submitted';

  // Marketplace extras
  static const String marketplaceCreateStarted = 'marketplace_create_started';
  static const String marketplaceCreateCompleted = 'marketplace_create_completed';
  static const String marketplaceComment = 'marketplace_comment';

  // Crop calendar / agronomy extras
  static const String cropActivityView = 'crop_activity_view';
  static const String cropShare = 'crop_share';

  // Mandi
  static const String mandiListView = 'mandi_list_view';
  static const String mandiPriceCheck = 'mandi_price_check';

  // Onboarding / farm profile
  static const String onboardingStepCompleted = 'onboarding_step_completed';
  static const String onboardingCompleted = 'onboarding_completed';
  static const String farmCropAdded = 'farm_crop_added';
  static const String farmCropRemoved = 'farm_crop_removed';

  // Subscription
  static const String subscriptionPlansView = 'subscription_plans_view';
  static const String subscriptionPlanSelected = 'subscription_plan_selected';
  static const String subscriptionCheckoutStart = 'subscription_checkout_start';
  static const String subscriptionPurchase = 'subscription_purchase';
  static const String subscriptionCancelStart = 'subscription_cancel_start';
  static const String subscriptionCancelConfirmed = 'subscription_cancel_confirmed';
  static const String subscriptionResume = 'subscription_resume';
}

/// Screen names for tracking
class ScreenName {
  static const String home = 'home';
  static const String feed = 'feed';
  static const String feedDetails = 'feed_details';
  static const String reels = 'reels';
  static const String marketplace = 'marketplace';
  static const String productDetails = 'product_details';
  static const String chatList = 'chat_list';
  static const String chatDetail = 'chat_detail';
  static const String aiChat = 'ai_chat';
  static const String cropCalendar = 'crop_calendar';
  static const String cropDetails = 'crop_details';
  static const String weather = 'weather';
  static const String schemes = 'schemes';
  static const String schemeDetails = 'scheme_details';
  static const String videoTutorials = 'video_tutorials';
  static const String companies = 'companies';
  static const String companyDetails = 'company_details';
  static const String profile = 'profile';
  static const String settings = 'settings';
  static const String notifications = 'notifications';
  static const String login = 'login';
  static const String signup = 'signup';
  static const String otp = 'otp';
  static const String language = 'language';
}

/// Mirror of the backend `event.model.js` enum. Events with names not in
/// this set are silently rejected by Mongoose validation on the server,
/// so emitting one is the same as throwing the event away.
///
/// Keep this list in sync with `Backend-JS/engagement-service/src/models/event.model.js`.
/// Phase 8 of the observability plan replaces this with codegen from a
/// shared YAML source of truth.
const Set<String> _knownEventNames = <String>{
  // Screen events
  'screen_view', 'screen_exit',
  // Feed events
  'feed_view', 'feed_like', 'feed_unlike', 'feed_comment', 'feed_share',
  'feed_save', 'feed_create', 'feed_delete', 'feed_scroll',
  // Reel events
  'reel_view', 'reel_like', 'reel_unlike', 'reel_comment', 'reel_share',
  'reel_swipe', 'reel_watch_complete', 'reel_complete', 'reel_skip',
  // Chat events
  'chat_open', 'chat_message_send', 'chat_message_sent', 'chat_message_received',
  'chat_message_read', 'group_create', 'group_join', 'group_leave',
  // Consultant events
  'consultant_directory_view', 'consultant_profile_view',
  'consultant_chat_request', 'consultant_chat_accepted',
  'consultant_chat_completed', 'consultant_rating_submitted',
  // AI events
  'ai_chat_start', 'ai_chat_message', 'ai_message_send', 'ai_image_analyze',
  'ai_crop_scan',
  // Marketplace events
  'product_view', 'product_search', 'product_filter', 'product_share',
  'product_add_cart', 'product_purchase', 'product_inquiry',
  'marketplace_create_started', 'marketplace_create_completed',
  'marketplace_comment',
  // Company events
  'company_view', 'company_search', 'company_contact',
  // Crop calendar / agronomy
  'crop_calendar_view', 'crop_activity_view', 'crop_share',
  // Mandi
  'mandi_list_view', 'mandi_price_check',
  // Farm profile / onboarding
  'onboarding_step_completed', 'onboarding_completed',
  'farm_crop_added', 'farm_crop_removed',
  // Subscription
  'subscription_plans_view', 'subscription_plan_selected',
  'subscription_checkout_start', 'subscription_purchase',
  'subscription_cancel_start', 'subscription_cancel_confirmed',
  'subscription_resume',
  // Content / discovery
  'scheme_view', 'weather_check', 'video_tutorial_view',
  // Notifications
  'notification_click', 'notification_dismiss', 'notification_received',
  // Profile / user lifecycle
  'profile_view', 'profile_edit', 'settings_change',
  'login', 'logout',
  'user_login', 'user_logout', 'user_signup', 'user_profile_update',
  // App lifecycle
  'app_open', 'app_close', 'app_background', 'app_foreground',
  // Misc
  'search_query', 'hashtag_click', 'error', 'custom',
};

/// Engagement Service for tracking user activities
/// Designed for high throughput with batching and offline support
class EngagementService {
  static final EngagementService _instance = EngagementService._internal();
  factory EngagementService() => _instance;
  EngagementService._internal();

  ApiService? _apiService;

  ApiService get apiService {
    _apiService ??= Get.find<ApiService>();
    return _apiService!;
  }

  String? _sessionId;
  String? _userId;
  String? _currentScreen;
  String? _previousScreen;
  DateTime? _screenEnteredAt;
  Map<String, dynamic>? _deviceInfo;

  // Event buffer for batch processing
  final List<Map<String, dynamic>> _eventBuffer = [];
  Timer? _flushTimer;
  Timer? _heartbeatTimer;

  // Configuration
  static const int _batchSize = 20;
  static const Duration _flushInterval = Duration(seconds: 30);
  static const Duration _heartbeatInterval = Duration(minutes: 5);
  static const String _sessionIdKey = 'engagement_session_id';
  static const String _pendingEventsKey = 'pending_engagement_events';

  bool _isInitialized = false;

  /// Initialize the engagement service
  Future<void> init(String userId) async {
    if (_isInitialized && _userId == userId) return;

    _userId = userId;
    await _loadDeviceInfo();
    await _loadPendingEvents();

    // Start new session
    await _startSession();

    // Start timers
    _startFlushTimer();
    _startHeartbeatTimer();

    _isInitialized = true;
    logger.i('EngagementService initialized for user: $userId', tag: 'Engagement');
  }

  /// Load device information
  Future<void> _loadDeviceInfo() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      final packageInfo = await PackageInfo.fromPlatform();

      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        _deviceInfo = {
          'deviceId': androidInfo.id,
          'platform': 'android',
          'osVersion': androidInfo.version.release,
          'appVersion': packageInfo.version,
          'deviceModel': androidInfo.model,
          'manufacturer': androidInfo.manufacturer,
        };
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        _deviceInfo = {
          'deviceId': iosInfo.identifierForVendor ?? '',
          'platform': 'ios',
          'osVersion': iosInfo.systemVersion,
          'appVersion': packageInfo.version,
          'deviceModel': iosInfo.model,
          'manufacturer': 'Apple',
        };
      }
    } catch (e) {
      logger.e('Failed to load device info', tag: 'Engagement', error: e);
      _deviceInfo = {
        'platform': Platform.isAndroid ? 'android' : 'ios',
        'appVersion': '1.0.0',
      };
    }
  }

  /// Load pending events from local storage. Only events whose `userId`
  /// matches the current user are restored — events from a previous login
  /// would otherwise be reattributed to the new user (the backend stamps
  /// the trusted userId onto every event in a batch).
  Future<void> _loadPendingEvents() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pendingJson = prefs.getString(_pendingEventsKey);
      if (pendingJson != null) {
        final List<dynamic> pending = json.decode(pendingJson);
        final mine = pending
            .cast<Map<String, dynamic>>()
            .where((e) => e['userId'] == _userId)
            .toList();
        final dropped = pending.length - mine.length;
        _eventBuffer.addAll(mine);
        if (dropped > 0) {
          logger.w(
            'Dropped $dropped pending events for other users on user switch',
            tag: 'Engagement',
          );
          // Persist the filtered list so we don't carry stale entries forever.
          await _savePendingEvents();
        }
        logger.i('Loaded ${mine.length} pending events', tag: 'Engagement');
      }
    } catch (e) {
      logger.e('Failed to load pending events', tag: 'Engagement', error: e);
    }
  }

  /// Save pending events to local storage
  Future<void> _savePendingEvents() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_pendingEventsKey, json.encode(_eventBuffer));
    } catch (e) {
      logger.e('Failed to save pending events', tag: 'Engagement', error: e);
    }
  }

  /// Start a new session
  Future<void> _startSession() async {
    try {
      final response = await apiService.post(
        ApiConstants.ENGAGEMENT_SESSION_START,
        data: {
          'userId': _userId,
          'device': _deviceInfo,
        },
      );

      if (response.statusCode == 201 && response.data['success'] == true) {
        _sessionId = response.data['sessionId'];

        // Save session ID locally
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_sessionIdKey, _sessionId!);

        logger.i('Session started: $_sessionId', tag: 'Engagement');
      }
    } catch (e) {
      logger.e('Failed to start session', tag: 'Engagement', error: e);
      // Generate local session ID as fallback
      _sessionId = '${_userId}_${DateTime.now().millisecondsSinceEpoch}';
    }
  }

  /// End the current session
  Future<void> endSession() async {
    if (_sessionId == null) return;

    try {
      // Track screen time for current screen
      _trackScreenTime();

      // Flush all pending events
      await _flushEvents();

      await apiService.post(
        ApiConstants.ENGAGEMENT_SESSION_END,
        data: {
          'sessionId': _sessionId,
          'userId': _userId,
          'exitScreen': _currentScreen,
        },
      );

      logger.i('Session ended: $_sessionId', tag: 'Engagement');
    } catch (e) {
      logger.e('Failed to end session', tag: 'Engagement', error: e);
    } finally {
      _sessionId = null;
      _userId = null;
      _currentScreen = null;
      _previousScreen = null;
      _screenEnteredAt = null;
      _isInitialized = false;
      _stopTimers();
    }
  }

  /// Track an event
  void trackEvent(
    String eventName, {
    String? eventCategory,
    Map<String, dynamic>? properties,
  }) {
    if (_userId == null) return;

    // Catch typos / drift from the backend enum during development.
    // Non-fatal because Phase 2 of the observability plan still has to
    // reconcile a number of pre-existing FE/BE drift cases. Once Phase 2
    // lands, swap this for an `assert` so unknown names fail fast in dev.
    if (kDebugMode && !_knownEventNames.contains(eventName)) {
      logger.w(
        'Engagement: emitting event "$eventName" not in backend enum — '
        'will be silently rejected by Mongoose. Add it to the BE enum '
        'and to _knownEventNames in engagement_service.dart.',
        tag: 'Engagement',
      );
    }

    final event = {
      'userId': _userId,
      'sessionId': _sessionId,
      'eventName': eventName,
      'eventCategory': eventCategory ?? _getEventCategory(eventName),
      'properties': properties ?? {},
      'device': _deviceInfo,
      'timestamp': DateTime.now().toUtc().toIso8601String(),
    };

    _eventBuffer.add(event);

    // Flush if buffer is full
    if (_eventBuffer.length >= _batchSize) {
      _flushEvents();
    }
  }

  /// Track screen view
  void trackScreenView(String screenName, {Map<String, dynamic>? properties}) {
    // Track time spent on previous screen
    _trackScreenTime();

    _previousScreen = _currentScreen;
    _currentScreen = screenName;
    _screenEnteredAt = DateTime.now();

    trackEvent(
      EventName.screenView,
      eventCategory: EventCategory.navigation,
      properties: {
        'screenName': screenName,
        'previousScreen': _previousScreen,
        ...?properties,
      },
    );
  }

  /// Close the screen-time window for the current screen and emit a
  /// `screen_exit` event with duration. Safe to call multiple times — only
  /// fires once per screen entry. Called by the navigator observer on push/pop
  /// and by the lifecycle observer when the app goes to background.
  void markScreenExit() => _trackScreenTime();

  /// Track screen time for current screen
  void _trackScreenTime() {
    if (_currentScreen != null && _screenEnteredAt != null) {
      final duration = DateTime.now().difference(_screenEnteredAt!).inSeconds;
      if (duration > 0) {
        trackEvent(
          EventName.screenExit,
          eventCategory: EventCategory.navigation,
          properties: {
            'screenName': _currentScreen,
            'previousScreen': _previousScreen,
            'duration': duration,
          },
        );
      }
      _screenEnteredAt = null;
    }
  }

  /// Track feed view
  void trackFeedView(String feedId, {Map<String, dynamic>? properties}) {
    trackEvent(
      EventName.feedView,
      eventCategory: EventCategory.content,
      properties: {
        'contentId': feedId,
        ...?properties,
      },
    );
  }

  /// Track feed like
  void trackFeedLike(String feedId, {bool isLike = true}) {
    trackEvent(
      isLike ? EventName.feedLike : EventName.feedUnlike,
      eventCategory: EventCategory.engagement,
      properties: {'contentId': feedId},
    );
  }

  /// Track feed comment
  void trackFeedComment(String feedId) {
    trackEvent(
      EventName.feedComment,
      eventCategory: EventCategory.social,
      properties: {'contentId': feedId},
    );
  }

  /// Track feed share
  void trackFeedShare(String feedId, String shareMethod) {
    trackEvent(
      EventName.feedShare,
      eventCategory: EventCategory.social,
      properties: {
        'contentId': feedId,
        'shareMethod': shareMethod,
      },
    );
  }

  /// Track reel view
  void trackReelView(String reelId, {int? watchDuration, double? completionRate}) {
    trackEvent(
      EventName.reelView,
      eventCategory: EventCategory.content,
      properties: {
        'contentId': reelId,
        if (watchDuration != null) 'watchDuration': watchDuration,
        if (completionRate != null) 'completionRate': completionRate,
      },
    );
  }

  /// Track reel like
  void trackReelLike(String reelId) {
    trackEvent(
      EventName.reelLike,
      eventCategory: EventCategory.engagement,
      properties: {'contentId': reelId},
    );
  }

  /// Track reel complete
  void trackReelComplete(String reelId, int watchDuration) {
    trackEvent(
      EventName.reelComplete,
      eventCategory: EventCategory.engagement,
      properties: {
        'contentId': reelId,
        'watchDuration': watchDuration,
      },
    );
  }

  /// Track product view
  void trackProductView(String productId, {String? categoryId}) {
    trackEvent(
      EventName.productView,
      eventCategory: EventCategory.commerce,
      properties: {
        'contentId': productId,
        if (categoryId != null) 'categoryId': categoryId,
      },
    );
  }

  /// Track product search
  void trackProductSearch(String query, int resultsCount) {
    trackEvent(
      EventName.productSearch,
      eventCategory: EventCategory.commerce,
      properties: {
        'query': query,
        'resultsCount': resultsCount,
      },
    );
  }

  /// Track AI chat start
  void trackAIChatStart() {
    trackEvent(
      EventName.aiChatStart,
      eventCategory: EventCategory.ai,
    );
  }

  /// Track AI chat message
  void trackAIChatMessage({bool isUserMessage = true}) {
    trackEvent(
      EventName.aiChatMessage,
      eventCategory: EventCategory.ai,
      properties: {'isUserMessage': isUserMessage},
    );
  }

  /// Track chat message sent
  void trackChatMessageSent(String chatId) {
    trackEvent(
      EventName.chatMessageSent,
      eventCategory: EventCategory.communication,
      properties: {'chatId': chatId},
    );
  }

  /// Track scheme view
  void trackSchemeView(String schemeId) {
    trackEvent(
      EventName.schemeView,
      eventCategory: EventCategory.content,
      properties: {'contentId': schemeId},
    );
  }

  /// Track weather check
  void trackWeatherCheck({String? location}) {
    trackEvent(
      EventName.weatherCheck,
      eventCategory: EventCategory.content,
      properties: {
        if (location != null) 'location': location,
      },
    );
  }

  /// Track video tutorial view
  void trackVideoTutorialView(String videoId, {int? watchDuration}) {
    trackEvent(
      EventName.videoTutorialView,
      eventCategory: EventCategory.content,
      properties: {
        'contentId': videoId,
        if (watchDuration != null) 'watchDuration': watchDuration,
      },
    );
  }

  /// Track notification click
  void trackNotificationClick(String notificationId, String type) {
    trackEvent(
      EventName.notificationClick,
      eventCategory: EventCategory.engagement,
      properties: {
        'notificationId': notificationId,
        'notificationType': type,
      },
    );
  }

  /// Track user login
  void trackLogin() {
    trackEvent(
      EventName.userLogin,
      eventCategory: EventCategory.system,
    );
  }

  /// Track user logout
  void trackLogout() {
    trackEvent(
      EventName.userLogout,
      eventCategory: EventCategory.system,
    );
  }

  /// Get event category from event name
  String _getEventCategory(String eventName) {
    if (eventName.startsWith('screen') || eventName.startsWith('app')) {
      return EventCategory.navigation;
    }
    if (eventName.contains('like') || eventName.contains('complete')) {
      return EventCategory.engagement;
    }
    if (eventName.contains('comment') || eventName.contains('share')) {
      return EventCategory.social;
    }
    if (eventName.contains('product') || eventName.contains('cart')) {
      return EventCategory.commerce;
    }
    if (eventName.contains('chat') || eventName.contains('message')) {
      return EventCategory.communication;
    }
    if (eventName.startsWith('ai')) {
      return EventCategory.ai;
    }
    if (eventName.contains('view')) {
      return EventCategory.content;
    }
    return EventCategory.system;
  }

  /// Start flush timer
  void _startFlushTimer() {
    _flushTimer?.cancel();
    _flushTimer = Timer.periodic(_flushInterval, (_) => _flushEvents());
  }

  /// Start heartbeat timer
  void _startHeartbeatTimer() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (_) => _sendHeartbeat());
  }

  /// Stop all timers
  void _stopTimers() {
    _flushTimer?.cancel();
    _heartbeatTimer?.cancel();
    _flushTimer = null;
    _heartbeatTimer = null;
  }

  /// Flush events to server
  Future<void> _flushEvents() async {
    if (_eventBuffer.isEmpty) return;

    final eventsToSend = List<Map<String, dynamic>>.from(_eventBuffer);
    _eventBuffer.clear();

    try {
      final response = await apiService.post(
        ApiConstants.ENGAGEMENT_EVENTS_BATCH,
        data: {'events': eventsToSend},
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        logger.i('Flushed ${eventsToSend.length} events', tag: 'Engagement');
        // Clear saved pending events
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_pendingEventsKey);
      } else {
        // Put events back in buffer
        _eventBuffer.addAll(eventsToSend);
        await _savePendingEvents();
      }
    } catch (e) {
      logger.e('Failed to flush events', tag: 'Engagement', error: e);
      // Put events back in buffer for retry
      _eventBuffer.addAll(eventsToSend);
      await _savePendingEvents();
    }
  }

  /// Send heartbeat to keep session alive
  Future<void> _sendHeartbeat() async {
    if (_sessionId == null) return;

    try {
      await apiService.post(
        ApiConstants.ENGAGEMENT_SESSION_HEARTBEAT,
        data: {
          'sessionId': _sessionId,
          'userId': _userId,
          'currentScreen': _currentScreen,
        },
      );
    } catch (e) {
      logger.e('Failed to send heartbeat', tag: 'Engagement', error: e);
    }
  }

  /// Handle app lifecycle changes
  void onAppLifecycleChange(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
        // Close the active screen-time window before going to background so
        // the duration isn't lost or inflated by background time.
        _trackScreenTime();
        trackEvent(EventName.appBackground, eventCategory: EventCategory.navigation);
        _flushEvents();
        break;
      case AppLifecycleState.resumed:
        // Reset the screen entry timestamp so post-resume time isn't credited
        // to the pre-pause window.
        if (_currentScreen != null) {
          _screenEnteredAt = DateTime.now();
        }
        trackEvent(EventName.appForeground, eventCategory: EventCategory.navigation);
        break;
      case AppLifecycleState.detached:
        _trackScreenTime();
        endSession();
        break;
      default:
        break;
    }
  }

  /// Dispose the service
  void dispose() {
    _stopTimers();
    _savePendingEvents();
  }
}
