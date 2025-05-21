import 'dart:async';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../data/services/api_service.dart';

/// Controller to manage connectivity and offline mode functionality
class ConnectivityController extends GetxController {
  final ApiService _apiService;
  final Connectivity _connectivity = Connectivity();
  final GetStorage _storage = GetStorage();

  // Storage key for offline mode
  static const String OFFLINE_MODE_KEY = 'offline_mode';

  // Observable variables
  final RxBool isConnected = true.obs;
  final RxBool isOfflineMode = false.obs;

  // Track if we are currently refreshing data
  final RxBool isRefreshing = false.obs;

  // Stream subscription to listen for connectivity changes
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;

  // Constructor
  ConnectivityController(this._apiService);

  @override
  void onInit() {
    super.onInit();
    // Load saved offline mode preference
    _loadOfflineModePreference();
    // Setup connectivity listener
    _connectivitySubscription =
        _connectivity.onConnectivityChanged.listen(_updateConnectionStatus);
    _checkInitialConnection();
  }

  @override
  void onClose() {
    _connectivitySubscription?.cancel();
    super.onClose();
  }

  /// Load saved offline mode preference from storage
  void _loadOfflineModePreference() {
    try {
      final savedOfflineMode = _storage.read<bool>(OFFLINE_MODE_KEY);
      if (savedOfflineMode != null) {
        isOfflineMode.value = savedOfflineMode;
        print('Loaded offline mode preference: $savedOfflineMode');
      }
    } catch (e) {
      print('Error loading offline mode preference: $e');
      // Default to false if there's an error
      isOfflineMode.value = false;
    }
  }

  /// Save offline mode preference to storage
  void _saveOfflineModePreference(bool value) {
    try {
      _storage.write(OFFLINE_MODE_KEY, value);
      print('Saved offline mode preference: $value');
    } catch (e) {
      print('Error saving offline mode preference: $e');
      // Continue even if save fails
    }
  }

  /// Initialize connectivity and check current status
  Future<void> _checkInitialConnection() async {
    try {
      final result = await _connectivity.checkConnectivity();
      _updateConnectionStatus(result);
    } catch (e) {
      print('Failed to get connectivity status: $e');
      isConnected.value = false;
    }
  }

  /// Update connection status and take appropriate actions
  void _updateConnectionStatus(ConnectivityResult result) {
    final bool wasConnected = isConnected.value;
    isConnected.value = result != ConnectivityResult.none;

    // If connection status changed and now connected and not in forced offline mode
    if (!wasConnected && isConnected.value && !isOfflineMode.value) {
      _refreshCachedData();
    }
  }

  /// Toggle offline mode (user-initiated)
  void toggleOfflineMode(bool enabled) {
    isOfflineMode.value = enabled;
    _saveOfflineModePreference(enabled);

    // If coming back online from forced offline mode, refresh data
    if (!enabled && isConnected.value) {
      _refreshCachedData();
    }
  }

  /// Refresh any stale cached data when coming back online
  Future<void> _refreshCachedData() async {
    if (isRefreshing.value) return; // Prevent multiple concurrent refreshes

    try {
      isRefreshing.value = true;

      // Trigger a refresh for each repository or controller that needs updating
      // This could dispatch events to other controllers or directly call repository methods
      await _apiService.clearCacheEntry('feeds');
      await _apiService.clearCacheEntry('products');
      await _apiService.clearCacheEntry('schemes');

      print('Network restored - refreshed cached data');
    } catch (e) {
      print('Error refreshing cached data: $e');
      // Don't show error to user - this is a background operation
    } finally {
      isRefreshing.value = false;
    }
  }

  /// Check if connection is available before making a request
  /// Returns true if connection is available or in offline mode
  bool shouldUseCache() {
    return !isConnected.value || isOfflineMode.value;
  }

  /// Force refresh all cached data
  Future<void> forceRefreshAll() async {
    if (!isConnected.value) {
      Get.snackbar(
        'Offline Mode',
        'Cannot refresh data while offline',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    if (isRefreshing.value) {
      Get.snackbar(
        'Already Refreshing',
        'Data refresh is already in progress',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    try {
      isRefreshing.value = true;
      await _refreshCachedData();

      Get.snackbar(
        'Refresh Complete',
        'All data has been refreshed',
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      print('Error during force refresh: $e');
      Get.snackbar(
        'Refresh Error',
        'Could not refresh all data. Please try again.',
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      isRefreshing.value = false;
    }
  }

  /// Clear all cached data
  Future<void> clearAllCache() async {
    try {
      await _apiService.clearCache();
      Get.snackbar(
        'Cache Cleared',
        'All cached data has been cleared',
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      print('Error clearing cache: $e');
      Get.snackbar(
        'Error',
        'Could not clear cache. Please try again.',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }
}
