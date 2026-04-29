import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get/get.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

import '../../data/models/subscription_model.dart';
import '../../data/repositories/subscription_repository.dart';

class SubscriptionController extends GetxController {
  final SubscriptionRepository _repository;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  SubscriptionController(this._repository);

  // Observable states
  final isLoading = false.obs;
  final isProcessingPayment = false.obs;
  final plans = <SubscriptionPlan>[].obs;
  final currentSubscription = Rxn<UserSubscription>();
  final currentPlan = Rxn<SubscriptionPlan>();
  final usageStats = Rxn<UsageStats>();
  final paymentHistory = <PaymentHistory>[].obs;
  final isFreePlan = true.obs;
  final error = Rxn<String>();

  // Per-section error state. Setting these surfaces an inline error+retry
  // banner on the relevant subscription UI panel instead of silently
  // leaving stale (or zeroed) values, which previously made it look like
  // the user had no usage data when in fact the API had failed.
  final usageStatsError = Rxn<String>();
  final currentSubscriptionError = Rxn<String>();

  // Selected billing cycle
  final selectedBillingCycle = 'monthly'.obs;

  // IoT Add-on states
  final iotAddons = <IotAddon>[].obs;
  final userIotAddons = <UserIotAddon>[].obs;
  final isLoadingIotAddons = false.obs;

  @override
  void onInit() {
    super.onInit();
    _initializeStripe();
    // Don't fetch anything on init. Subscription data is only relevant
    // once the user opens the subscription screen — kicking off
    // auth-required calls at app boot can race with the auth flow
    // (especially the phone-OTP screen) and cause 401s, refresh loops,
    // or unwanted re-routes via the global auth-failure handler.
    // Each consumer screen should call refreshAll() explicitly.
  }

  /// Initialize Stripe
  // Inject per-build: --dart-define=STRIPE_PUBLISHABLE_KEY=pk_live_...
  static const String _stripePublishableKey =
      String.fromEnvironment('STRIPE_PUBLISHABLE_KEY', defaultValue: '');

  void _initializeStripe() {
    if (_stripePublishableKey.isEmpty) {
      // Fail loudly so a misconfigured build surfaces immediately
      // instead of charging against a stale test key in production.
      throw StateError(
        'STRIPE_PUBLISHABLE_KEY not set. Pass via --dart-define at build time.',
      );
    }
    Stripe.publishableKey = _stripePublishableKey;
    Stripe.merchantIdentifier = 'merchant.com.krishimantra';
  }

  /// Load all subscription plans
  Future<void> loadPlans() async {
    try {
      isLoading.value = true;
      error.value = null;

      final loadedPlans = await _repository.getPlans();
      plans.assignAll(loadedPlans);
    } catch (e) {
      error.value = 'Failed to load plans: $e';
      print('Error loading plans: $e');
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> _isAuthenticated() async {
    final token = await _storage.read(key: 'auth_token');
    return token != null;
  }

  /// Load current user's subscription. Errors are now surfaced via
  /// `currentSubscriptionError` so the UI can render a retry affordance
  /// instead of silently leaving the previous (possibly empty) state.
  Future<void> loadCurrentSubscription() async {
    try {
      if (!await _isAuthenticated()) return;
      currentSubscriptionError.value = null;

      final result = await _repository.getCurrentSubscription();

      currentSubscription.value = result['subscription'];
      currentPlan.value = result['currentPlan'];
      isFreePlan.value = result['isFreePlan'] ?? true;

      // Also load usage stats
      await loadUsageStats();
    } catch (e) {
      currentSubscriptionError.value =
          "Couldn't load your subscription. Tap retry.";
    }
  }

  /// Load usage stats. Errors set `usageStatsError` so the UI shows an
  /// inline retry instead of falling back to hardcoded "free tier" counts.
  Future<void> loadUsageStats() async {
    try {
      if (!await _isAuthenticated()) return;
      usageStatsError.value = null;

      final stats = await _repository.getUsageStats();
      usageStats.value = stats;
    } catch (e) {
      usageStatsError.value =
          "Couldn't load usage stats. Tap retry.";
    }
  }

  /// Subscribe to a plan
  Future<bool> subscribeToPlan(SubscriptionPlan plan) async {
    if (plan.isFree) {
      Get.snackbar(
        'Info',
        'You are already on the free plan',
        snackPosition: SnackPosition.BOTTOM,
      );
      return false;
    }

    try {
      isProcessingPayment.value = true;
      error.value = null;

      // Create payment intent
      final paymentData = await _repository.createPaymentIntent(
        planName: plan.name,
        billingCycle: selectedBillingCycle.value,
      );

      // Initialize payment sheet
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: paymentData['clientSecret'],
          merchantDisplayName: 'Krishi Mantra',
          style: ThemeMode.system,
          appearance: const PaymentSheetAppearance(
            colors: PaymentSheetAppearanceColors(
              primary: Color(0xFF4CAF50),
            ),
          ),
        ),
      );

      // Present payment sheet
      await Stripe.instance.presentPaymentSheet();

      // Confirm payment on backend
      final result = await _repository.confirmPayment(
        paymentIntentId: paymentData['paymentIntentId'],
        planName: plan.name,
        billingCycle: selectedBillingCycle.value,
      );

      // Update state
      currentSubscription.value = result['subscription'];
      currentPlan.value = result['plan'];
      isFreePlan.value = false;

      Get.snackbar(
        'Success',
        'Successfully subscribed to ${plan.displayName}!',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );

      // Reload usage stats
      await loadUsageStats();

      return true;
    } on StripeException catch (e) {
      if (e.error.code == FailureCode.Canceled) {
        Get.snackbar(
          'Cancelled',
          'Payment was cancelled',
          snackPosition: SnackPosition.BOTTOM,
        );
      } else {
        error.value = e.error.localizedMessage ?? 'Payment failed';
        Get.snackbar(
          'Error',
          error.value!,
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
      return false;
    } catch (e) {
      error.value = 'Failed to process payment: $e';
      Get.snackbar(
        'Error',
        error.value!,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return false;
    } finally {
      isProcessingPayment.value = false;
    }
  }

  /// Cancel subscription
  Future<bool> cancelSubscription({
    bool cancelImmediately = false,
    String? reason,
  }) async {
    try {
      isLoading.value = true;

      final subscription = await _repository.cancelSubscription(
        cancelImmediately: cancelImmediately,
        reason: reason,
      );

      currentSubscription.value = subscription;

      if (cancelImmediately) {
        isFreePlan.value = true;
        currentPlan.value = plans.firstWhereOrNull((p) => p.isDefault);
      }

      Get.snackbar(
        'Success',
        cancelImmediately
            ? 'Subscription cancelled'
            : 'Subscription will be cancelled at the end of the billing period',
        snackPosition: SnackPosition.BOTTOM,
      );

      return true;
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to cancel subscription: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  /// Resume subscription
  Future<bool> resumeSubscription() async {
    try {
      isLoading.value = true;

      final subscription = await _repository.resumeSubscription();
      currentSubscription.value = subscription;

      Get.snackbar(
        'Success',
        'Subscription resumed successfully',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );

      return true;
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to resume subscription: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  /// Load payment history
  Future<void> loadPaymentHistory({int page = 1}) async {
    try {
      final payments = await _repository.getPaymentHistory(page: page);
      if (page == 1) {
        paymentHistory.assignAll(payments);
      } else {
        paymentHistory.addAll(payments);
      }
    } catch (e) {
      print('Error loading payment history: $e');
    }
  }

  /// Check if user can access a feature.
  ///
  /// Defaults to DENY on error. Allowing on error means any failure of the
  /// subscription API hands premium features to free users — a paywall
  /// bypass. The cost of denying on a transient failure is a momentary
  /// "unavailable" state for legitimate paying users; the cost of allowing
  /// on error is unbounded revenue leak.
  Future<bool> canAccessFeature(String feature) async {
    try {
      final result = await _repository.checkFeatureAccess(feature);
      return result['allowed'] ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Get remaining AI messages
  int get remainingAiMessages {
    return usageStats.value?.aiMessages.remaining ?? 5;
  }

  /// Get remaining image analyses
  int get remainingImageAnalyses {
    return usageStats.value?.imageAnalysis.remaining ?? 2;
  }

  /// Get remaining consultant chats
  int get remainingConsultantChats {
    return usageStats.value?.consultantChats.remaining ?? 10;
  }

  /// Check if AI messages limit reached
  bool get isAiMessagesLimitReached {
    final stats = usageStats.value;
    if (stats == null) return false;
    return stats.aiMessages.isLimitReached;
  }

  /// Check if image analysis limit reached
  bool get isImageAnalysisLimitReached {
    final stats = usageStats.value;
    if (stats == null) return false;
    return stats.imageAnalysis.isLimitReached;
  }

  /// Check if consultant chat limit reached
  bool get isConsultantChatLimitReached {
    final stats = usageStats.value;
    if (stats == null) return false;
    return stats.consultantChats.isLimitReached;
  }

  /// Get plan by name
  SubscriptionPlan? getPlanByName(String name) {
    return plans.firstWhereOrNull((p) => p.name == name);
  }

  /// Toggle billing cycle
  void toggleBillingCycle() {
    selectedBillingCycle.value =
        selectedBillingCycle.value == 'monthly' ? 'yearly' : 'monthly';
  }

  /// Get price for selected billing cycle
  String getPriceForPlan(SubscriptionPlan plan) {
    if (selectedBillingCycle.value == 'yearly') {
      return plan.formattedYearlyPrice;
    }
    return plan.formattedMonthlyPrice;
  }

  /// Refresh all data
  Future<void> refreshAll() async {
    await Future.wait([
      loadPlans(),
      loadCurrentSubscription(),
      loadIotAddons(),
      loadUserIotAddons(),
    ]);
  }

  // ========== IoT ADD-ON METHODS ==========

  /// Load all IoT add-ons
  Future<void> loadIotAddons() async {
    try {
      if (!await _isAuthenticated()) return;

      isLoadingIotAddons.value = true;
      final addons = await _repository.getIotAddons();
      iotAddons.assignAll(addons);
      // Also load user's active addons
      await loadUserIotAddons();
    } catch (e) {
      print('Error loading IoT add-ons: $e');
    } finally {
      isLoadingIotAddons.value = false;
    }
  }

  /// Load user's active IoT add-ons
  Future<void> loadUserIotAddons() async {
    try {
      if (!await _isAuthenticated()) return;

      final addons = await _repository.getUserIotAddons();
      userIotAddons.assignAll(addons);
    } catch (e) {
      print('Error loading user IoT add-ons: $e');
    }
  }

  /// Subscribe to an IoT add-on
  Future<bool> subscribeToIotAddon(IotAddon addon) async {
    try {
      isProcessingPayment.value = true;
      error.value = null;

      // Check if already has this addon or bundle
      final hasBundle = userIotAddons.any((a) => a.addonName == 'IOT_BUNDLE' && a.isActive);
      if (hasBundle) {
        Get.snackbar(
          'Info',
          'You already have the IoT Bundle which includes all features',
          snackPosition: SnackPosition.BOTTOM,
        );
        return false;
      }

      final hasAddon = userIotAddons.any((a) => a.addonName == addon.name && a.isActive);
      if (hasAddon) {
        Get.snackbar(
          'Info',
          'You already have this IoT add-on',
          snackPosition: SnackPosition.BOTTOM,
        );
        return false;
      }

      // Create payment intent
      final paymentData = await _repository.createIotAddonPaymentIntent(
        addonName: addon.name,
        billingCycle: selectedBillingCycle.value,
      );

      // Initialize payment sheet
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: paymentData['clientSecret'],
          merchantDisplayName: 'Krishi Mantra',
          style: ThemeMode.system,
          appearance: const PaymentSheetAppearance(
            colors: PaymentSheetAppearanceColors(
              primary: Color(0xFF4CAF50),
            ),
          ),
        ),
      );

      // Present payment sheet
      await Stripe.instance.presentPaymentSheet();

      // Confirm payment on backend
      await _repository.confirmIotAddonPayment(
        paymentIntentId: paymentData['paymentIntentId'],
        addonName: addon.name,
        billingCycle: selectedBillingCycle.value,
      );

      Get.snackbar(
        'Success',
        'Successfully subscribed to ${addon.displayName}!',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );

      // Reload user's IoT addons
      await loadUserIotAddons();

      return true;
    } on StripeException catch (e) {
      if (e.error.code == FailureCode.Canceled) {
        Get.snackbar(
          'Cancelled',
          'Payment was cancelled',
          snackPosition: SnackPosition.BOTTOM,
        );
      } else {
        error.value = e.error.localizedMessage ?? 'Payment failed';
        Get.snackbar(
          'Error',
          error.value!,
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
      return false;
    } catch (e) {
      error.value = 'Failed to process payment: $e';
      Get.snackbar(
        'Error',
        error.value!,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return false;
    } finally {
      isProcessingPayment.value = false;
    }
  }

  /// Cancel IoT add-on subscription
  Future<bool> cancelIotAddon(String addonName, {bool cancelImmediately = false}) async {
    try {
      isLoading.value = true;

      await _repository.cancelIotAddon(
        addonName: addonName,
        cancelImmediately: cancelImmediately,
      );

      Get.snackbar(
        'Success',
        cancelImmediately
            ? 'IoT add-on cancelled'
            : 'IoT add-on will be cancelled at the end of the billing period',
        snackPosition: SnackPosition.BOTTOM,
      );

      await loadUserIotAddons();

      return true;
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to cancel IoT add-on: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  /// Check if user has water pump access
  bool get hasWaterPumpAccess {
    return userIotAddons.any((a) =>
        (a.addonName == 'WATER_PUMP' || a.addonName == 'IOT_BUNDLE') && a.isActive);
  }

  /// Check if user has crop monitoring access
  bool get hasCropMonitoringAccess {
    return userIotAddons.any((a) =>
        (a.addonName == 'CROP_IOT' || a.addonName == 'IOT_BUNDLE') && a.isActive);
  }

  /// Check if user has any IoT add-on
  bool get hasAnyIotAddon {
    return userIotAddons.any((a) => a.isActive);
  }

  /// Get price for IoT add-on based on selected billing cycle
  String getPriceForIotAddon(IotAddon addon) {
    if (selectedBillingCycle.value == 'yearly') {
      return addon.formattedYearlyPrice;
    }
    return addon.formattedMonthlyPrice;
  }

  /// Get IoT addon by name
  IotAddon? getIotAddonByName(String name) {
    return iotAddons.firstWhereOrNull((a) => a.name == name);
  }

  /// Link IoT device
  Future<bool> linkDevice({
    required String addonName,
    required String deviceId,
    required String deviceType,
    String? deviceName,
  }) async {
    try {
      await _repository.linkIotDevice(
        addonName: addonName,
        deviceId: deviceId,
        deviceType: deviceType,
        deviceName: deviceName,
      );

      Get.snackbar(
        'Success',
        'Device linked successfully',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );

      await loadUserIotAddons();
      return true;
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to link device: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return false;
    }
  }

  /// Unlink IoT device
  Future<bool> unlinkDevice({
    required String addonName,
    required String deviceId,
  }) async {
    try {
      await _repository.unlinkIotDevice(
        addonName: addonName,
        deviceId: deviceId,
      );

      Get.snackbar(
        'Success',
        'Device unlinked successfully',
        snackPosition: SnackPosition.BOTTOM,
      );

      await loadUserIotAddons();
      return true;
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to unlink device: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return false;
    }
  }
}
