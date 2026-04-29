import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../data/services/engagement_service.dart';

/// Navigation observer for automatic screen tracking
class EngagementNavigatorObserver extends NavigatorObserver {
  final EngagementService _engagementService = EngagementService();

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    // Close the prior screen-time window before opening the new screen.
    _engagementService.markScreenExit();
    _trackScreenView(route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    // The popped route is what the user was on. Close its window first.
    _engagementService.markScreenExit();
    if (previousRoute != null) {
      _trackScreenView(previousRoute);
    }
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    _engagementService.markScreenExit();
    if (newRoute != null) {
      _trackScreenView(newRoute);
    }
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didRemove(route, previousRoute);
    // didRemove fires for offstage removals (e.g. routes removed below the
    // current top). Close the active window so we don't credit time after the
    // screen is gone.
    _engagementService.markScreenExit();
    if (previousRoute != null) {
      _trackScreenView(previousRoute);
    }
  }

  void _trackScreenView(Route<dynamic> route) {
    final screenName = _getScreenName(route);
    if (screenName != null) {
      _engagementService.trackScreenView(screenName);
    }
  }

  String? _getScreenName(Route<dynamic> route) {
    // Try to get route name from settings
    final routeName = route.settings.name;
    if (routeName != null && routeName.isNotEmpty) {
      // Remove leading slash and convert to screen name format
      return routeName.replaceFirst('/', '').replaceAll('-', '_');
    }

    // Try to get from GetPage if using GetX
    if (route is GetPageRoute) {
      return route.settings.name?.replaceFirst('/', '').replaceAll('-', '_');
    }

    return null;
  }
}

/// Lifecycle observer for app state changes
class EngagementLifecycleObserver extends WidgetsBindingObserver {
  final EngagementService _engagementService = EngagementService();

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _engagementService.onAppLifecycleChange(state);
  }
}

/// Mixin for controllers to easily track screen views
mixin EngagementTrackingMixin {
  final EngagementService engagementService = EngagementService();

  /// Track when screen is viewed
  void trackScreenView(String screenName, {Map<String, dynamic>? properties}) {
    engagementService.trackScreenView(screenName, properties: properties);
  }

  /// Track custom event
  void trackEvent(String eventName, {String? category, Map<String, dynamic>? properties}) {
    engagementService.trackEvent(eventName, eventCategory: category, properties: properties);
  }
}
