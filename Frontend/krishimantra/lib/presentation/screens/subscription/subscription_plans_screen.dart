import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/constants/colors.dart';
import '../../../core/utils/language_helper.dart';
import '../../../core/utils/translation_manager.dart';
import '../../../data/models/subscription_model.dart';
import '../../../routes/app_routes.dart';
import '../../controllers/subscription_controller.dart';
import '../../widgets/translated_text.dart';

class SubscriptionPlansScreen extends StatefulWidget {
  const SubscriptionPlansScreen({super.key});

  @override
  State<SubscriptionPlansScreen> createState() =>
      _SubscriptionPlansScreenState();
}

class _SubscriptionPlansScreenState extends State<SubscriptionPlansScreen>
    with TranslationMixin {
  static const String _keySubscriptionPlans = 'subscription_plans_title';
  static const String _keyRetry = 'subscription_retry';
  static const String _keyCurrentPlan = 'subscription_current_plan';
  static const String _keyFallbackFreePlan = 'subscription_fallback_free_plan';
  static const String _keyEndsOn = 'subscription_ends_on';
  static const String _keyRenewsOn = 'subscription_renews_on';
  static const String _keyMonthly = 'subscription_monthly';
  static const String _keyYearly = 'subscription_yearly';
  static const String _keyYear = 'subscription_year';
  static const String _keyMonth = 'subscription_month';
  static const String _keyDay = 'subscription_day';
  static const String _keySave16 = 'subscription_save_16';
  static const String _keyFree = 'subscription_free';
  static const String _keyYes = 'subscription_yes';
  static const String _keySubscribeNow = 'subscription_subscribe_now';
  static const String _keyFreeForever = 'subscription_free_forever';
  static const String _keyMostPopular = 'subscription_most_popular';
  static const String _keyCurrent = 'subscription_current';
  static const String _keyUsageToday = 'subscription_usage_today';
  static const String _keyAiMessages = 'subscription_ai_messages';
  static const String _keyImageAnalysis = 'subscription_image_analysis';
  static const String _keyConsultantChats = 'subscription_consultant_chats';
  static const String _keyViewPaymentHistory =
      'subscription_view_payment_history';
  static const String _keySubscribeTo = 'subscription_subscribe_to';
  static const String _keyPlanBillingMsg = 'subscription_plan_billing_msg';
  static const String _keyProceedPayment = 'subscription_proceed_payment';
  static const String _keyCancel = 'subscription_cancel';
  static const String _keySubscribe = 'subscription_subscribe';
  static const String _keyAiCropDoctor = 'subscription_ai_crop_doctor';
  static const String _keyVideoConsultations =
      'subscription_video_consultations';
  static const String _keyCreatePosts = 'subscription_create_posts';
  static const String _keyMarketplaceListings =
      'subscription_marketplace_listings';
  static const String _keyAdFree = 'subscription_ad_free';
  static const String _keyPrioritySupport = 'subscription_priority_support';
  static const String _keyUnlimited = 'subscription_unlimited';
  static const String _keyIotAddons = 'subscription_iot_addons';
  static const String _keySmartFarming = 'subscription_iot_subtitle';
  static const String _keyActive = 'subscription_active';
  static const String _keyComingSoon = 'subscription_iot_coming_soon';
  static const String _keyYourActiveAddons = 'subscription_iot_active_addons';
  static const String _keyAvailableAddons = 'subscription_iot_available_addons';
  static const String _keyEnds = 'subscription_ends';
  static const String _keySubscribed = 'subscription_subscribed';
  static const String _keyAdd = 'subscription_add';
  static const String _keySaveAmount = 'subscription_save_amount';
  static const String _keyWaterPumpControl = 'subscription_water_pump_control';
  static const String _keyDevices = 'subscription_devices';
  static const String _keyCropSensors = 'subscription_crop_sensors';
  static const String _keySensors = 'subscription_sensors';
  static const String _keyAiRecommendations = 'subscription_ai_recommendations';
  static const String _keyIncluded = 'subscription_included';
  static const String _keyWeatherAlerts = 'subscription_weather_alerts';
  static const String _keyDayForecast = 'subscription_day_forecast';
  static const String _keyAddAddon = 'subscription_add_addon';
  static const String _keyAddonBillingMsg = 'subscription_addon_billing_msg';
  static const String _keyAddonSeparateBilling =
      'subscription_addon_separate_billing';
  static const String _keyAddNow = 'subscription_add_now';
  static const String _keyCancelAddon = 'subscription_cancel_addon';
  static const String _keyCancelHow = 'subscription_cancel_how';
  static const String _keyCancelAtEnd = 'subscription_cancel_at_end';
  static const String _keyCancelImmediate = 'subscription_cancel_immediate';
  static const String _keyBack = 'subscription_back';
  static const String _keyAtPeriodEnd = 'subscription_at_period_end';
  static const String _keyCancelNow = 'subscription_cancel_now';
  static const String _keyRemaining = 'subscription_remaining';

  late final SubscriptionController controller;

  @override
  void initState() {
    super.initState();
    controller = Get.find<SubscriptionController>();
    _registerTranslations();
    updateTranslations();
    TranslationManager.instance.addLanguageChangeListener(
      _handleLanguageChange,
    );
  }

  void _handleLanguageChange() {
    updateTranslations();
  }

  void _registerTranslations() {
    registerTranslation(_keySubscriptionPlans, 'Subscription Plans');
    registerTranslation(_keyRetry, 'Retry');
    registerTranslation(_keyCurrentPlan, 'Current Plan');
    registerTranslation(_keyFallbackFreePlan, 'Kisan (Free)');
    registerTranslation(_keyEndsOn, 'Ends on {date}');
    registerTranslation(_keyRenewsOn, 'Renews on {date}');
    registerTranslation(_keyMonthly, 'Monthly');
    registerTranslation(_keyYearly, 'Yearly');
    registerTranslation(_keyYear, 'year');
    registerTranslation(_keyMonth, 'month');
    registerTranslation(_keyDay, 'day');
    registerTranslation(_keySave16, 'Save 16%');
    registerTranslation(_keyFree, 'Free');
    registerTranslation(_keyYes, 'Yes');
    registerTranslation(_keySubscribeNow, 'Subscribe Now');
    registerTranslation(_keyFreeForever, 'Free Forever');
    registerTranslation(_keyMostPopular, '⭐ Most Popular');
    registerTranslation(_keyCurrent, '✓ Current');
    registerTranslation(_keyUsageToday, 'Today\'s Usage');
    registerTranslation(_keyAiMessages, 'AI Messages');
    registerTranslation(_keyImageAnalysis, 'Image Analysis');
    registerTranslation(_keyConsultantChats, 'Consultant Chats');
    registerTranslation(_keyViewPaymentHistory, 'View Payment History');
    registerTranslation(_keySubscribeTo, 'Subscribe to {plan}');
    registerTranslation(
      _keyPlanBillingMsg,
      'You will be charged {price} for the {cycle} subscription.',
    );
    registerTranslation(_keyProceedPayment, 'Proceed with payment?');
    registerTranslation(_keyCancel, 'Cancel');
    registerTranslation(_keySubscribe, 'Subscribe');
    registerTranslation(_keyAiCropDoctor, 'AI Crop Doctor');
    registerTranslation(_keyVideoConsultations, 'Video Consultations');
    registerTranslation(_keyCreatePosts, 'Create Posts');
    registerTranslation(_keyMarketplaceListings, 'Marketplace Listings');
    registerTranslation(_keyAdFree, 'Ad-Free Experience');
    registerTranslation(_keyPrioritySupport, 'Priority Support');
    registerTranslation(_keyUnlimited, 'Unlimited');
    registerTranslation(_keyIotAddons, 'IoT Add-ons');
    registerTranslation(_keySmartFarming, 'Smart farming devices & sensors');
    registerTranslation(_keyActive, 'Active');
    registerTranslation(
        _keyComingSoon, 'Coming Soon: Connect IoT devices for smart farming!');
    registerTranslation(_keyYourActiveAddons, 'Your Active Add-ons');
    registerTranslation(_keyAvailableAddons, 'Available Add-ons');
    registerTranslation(_keyEnds, 'Ends: {date}');
    registerTranslation(_keySubscribed, 'Subscribed');
    registerTranslation(_keyAdd, 'Add');
    registerTranslation(_keySaveAmount, 'Save {amount}');
    registerTranslation(_keyWaterPumpControl, 'Water Pump Control');
    registerTranslation(_keyDevices, '{count} devices');
    registerTranslation(_keyCropSensors, 'Crop Sensors');
    registerTranslation(_keySensors, '{count} sensors');
    registerTranslation(_keyAiRecommendations, 'AI Recommendations');
    registerTranslation(_keyIncluded, 'Included');
    registerTranslation(_keyWeatherAlerts, 'Weather Alerts');
    registerTranslation(_keyDayForecast, '{count} day forecast');
    registerTranslation(_keyAddAddon, 'Add {addon}');
    registerTranslation(
      _keyAddonBillingMsg,
      'You will be charged {price} for the {cycle} add-on.',
    );
    registerTranslation(
      _keyAddonSeparateBilling,
      'This will be billed separately from your subscription.',
    );
    registerTranslation(_keyAddNow, 'Add Now');
    registerTranslation(_keyCancelAddon, 'Cancel {addon}');
    registerTranslation(_keyCancelHow, 'How would you like to cancel?');
    registerTranslation(
      _keyCancelAtEnd,
      '• Cancel at end of billing period: Continue using until current period ends',
    );
    registerTranslation(
      _keyCancelImmediate,
      '• Cancel immediately: Lose access right away',
    );
    registerTranslation(_keyBack, 'Back');
    registerTranslation(_keyAtPeriodEnd, 'At Period End');
    registerTranslation(_keyCancelNow, 'Cancel Now');
    registerTranslation(_keyRemaining, 'remaining');
  }

  String _t(String key, [Map<String, String>? args]) {
    var value = getTranslation(key);
    if (args != null) {
      args.forEach((k, v) {
        value = value.replaceAll('{$k}', v);
      });
    }
    return value;
  }

  String _billingCycleLabel(String cycle) {
    return cycle == 'yearly' ? _t(_keyYearly) : _t(_keyMonthly);
  }

  String _localizedUsageDisplay(UsageInfo usage) {
    if (usage.isUnlimited) return _t(_keyUnlimited);
    return usage.displayString.replaceAll('remaining', _t(_keyRemaining));
  }

  String _localizedValue(String value) {
    var localized = value;
    if (localized.toLowerCase() == 'unlimited') localized = _t(_keyUnlimited);
    if (localized.toLowerCase() == 'yes') localized = _t(_keyYes);
    localized = localized.replaceAll('/day', '/${_t(_keyDay)}');
    localized = localized.replaceAll('/month', '/${_t(_keyMonth)}');
    localized = localized.replaceAll('/year', '/${_t(_keyYear)}');
    return localized;
  }

  @override
  void dispose() {
    TranslationManager.instance.removeLanguageChangeListener(
      _handleLanguageChange,
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        title: Text(
          _t(_keySubscriptionPlans),
          style: const TextStyle(
            color: AppColors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppColors.green,
        iconTheme: const IconThemeData(color: AppColors.white),
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.green),
          );
        }

        if (controller.error.value != null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text(controller.error.value!),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: controller.loadPlans,
                  child: Text(_t(_keyRetry)),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: controller.refreshAll,
          color: AppColors.green,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Current Plan Banner
                _buildCurrentPlanBanner(controller),
                const SizedBox(height: 24),

                // Billing Cycle Toggle
                _buildBillingToggle(controller),
                const SizedBox(height: 24),

                // Plans List
                ...controller.plans.map((plan) => Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _buildPlanCard(context, plan, controller),
                    )),

                const SizedBox(height: 24),

                // IoT Add-ons Section
                _buildIotAddonsSection(context, controller),

                const SizedBox(height: 16),

                // Usage Stats
                if (controller.usageStats.value != null)
                  _buildUsageStats(controller.usageStats.value!),

                const SizedBox(height: 24),

                // Payment History Link
                _buildPaymentHistoryLink(context),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildCurrentPlanBanner(SubscriptionController controller) {
    return Obx(() {
      final plan = controller.currentPlan.value;
      final subscription = controller.currentSubscription.value;
      final isFreePlan = controller.isFreePlan.value;

      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isFreePlan
                ? [Colors.grey.shade600, Colors.grey.shade800]
                : [AppColors.green, AppColors.green.withOpacity(0.8)],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isFreePlan ? Icons.person : Icons.star,
                  color: Colors.white,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _t(_keyCurrentPlan),
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        plan?.displayName ?? _t(_keyFallbackFreePlan),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isFreePlan && subscription != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: TranslatedText(
                      subscription.statusDisplay,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            if (!isFreePlan && subscription != null) ...[
              const SizedBox(height: 12),
              Text(
                subscription.isCancelledButActive
                    ? _t(_keyEndsOn, {
                        'date': _formatDate(subscription.endDate),
                      })
                    : _t(_keyRenewsOn, {
                        'date': _formatDate(subscription.nextPaymentDate ??
                            subscription.endDate),
                      }),
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 13,
                ),
              ),
            ],
          ],
        ),
      );
    });
  }

  Widget _buildBillingToggle(SubscriptionController controller) {
    return Obx(() {
      return Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => controller.selectedBillingCycle.value = 'monthly',
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: controller.selectedBillingCycle.value == 'monthly'
                        ? AppColors.green
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      _t(_keyMonthly),
                      style: TextStyle(
                        color:
                            controller.selectedBillingCycle.value == 'monthly'
                                ? Colors.white
                                : Colors.black87,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: GestureDetector(
                onTap: () => controller.selectedBillingCycle.value = 'yearly',
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: controller.selectedBillingCycle.value == 'yearly'
                        ? AppColors.green
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _t(_keyYearly),
                        style: TextStyle(
                          color:
                              controller.selectedBillingCycle.value == 'yearly'
                                  ? Colors.white
                                  : Colors.black87,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _t(_keySave16),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildPlanCard(
    BuildContext context,
    SubscriptionPlan plan,
    SubscriptionController controller,
  ) {
    final isCurrentPlan = controller.currentPlan.value?.name == plan.name;
    final isPopular = plan.name == 'KISAN_PLUS';

    return Obx(() {
      final billingCycle = controller.selectedBillingCycle.value;
      final price = billingCycle == 'yearly'
          ? plan.yearlyPriceInRupees
          : plan.monthlyPriceInRupees;

      return Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isCurrentPlan
                    ? AppColors.green
                    : isPopular
                        ? Colors.orange
                        : Colors.grey.shade200,
                width: isCurrentPlan || isPopular ? 2 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Plan Name & Price
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          plan.displayName,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          plan.displayNameHindi,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          price == 0
                              ? _t(_keyFree)
                              : '₹${price.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: AppColors.green,
                          ),
                        ),
                        if (price > 0)
                          Text(
                            '/${billingCycle == 'yearly' ? _t(_keyYear) : _t(_keyMonth)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Description
                TranslatedText(
                  plan.description,
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 16),

                // Features
                _buildFeatureItem(
                  Icons.chat_bubble_outline,
                  _t(_keyAiCropDoctor),
                  plan.features.getFeatureDisplay('aiMessagesPerDay'),
                ),
                _buildFeatureItem(
                  Icons.image_outlined,
                  _t(_keyImageAnalysis),
                  plan.features.getFeatureDisplay('imageAnalysisPerDay'),
                ),
                _buildFeatureItem(
                  Icons.support_agent,
                  _t(_keyConsultantChats),
                  plan.features.getFeatureDisplay('consultantChatsPerDay'),
                ),
                if (plan.features.videoConsultationsPerMonth != 0)
                  _buildFeatureItem(
                    Icons.video_call_outlined,
                    _t(_keyVideoConsultations),
                    plan.features
                        .getFeatureDisplay('videoConsultationsPerMonth'),
                  ),
                if (plan.features.canCreatePosts)
                  _buildFeatureItem(
                    Icons.post_add,
                    _t(_keyCreatePosts),
                    _t(_keyYes),
                    isEnabled: true,
                  ),
                if (plan.features.marketplaceListings != 0)
                  _buildFeatureItem(
                    Icons.storefront_outlined,
                    _t(_keyMarketplaceListings),
                    plan.features.getFeatureDisplay('marketplaceListings'),
                  ),
                if (plan.features.adFree)
                  _buildFeatureItem(
                    Icons.block,
                    _t(_keyAdFree),
                    _t(_keyYes),
                    isEnabled: true,
                  ),
                if (plan.features.prioritySupport)
                  _buildFeatureItem(
                    Icons.support,
                    _t(_keyPrioritySupport),
                    _t(_keyYes),
                    isEnabled: true,
                  ),

                const SizedBox(height: 16),

                // Subscribe Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed:
                        isCurrentPlan || controller.isProcessingPayment.value
                            ? null
                            : () => _handleSubscribe(context, plan, controller),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          isCurrentPlan ? Colors.grey : AppColors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: controller.isProcessingPayment.value
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            isCurrentPlan
                                ? _t(_keyCurrentPlan)
                                : plan.isFree
                                    ? _t(_keyFreeForever)
                                    : _t(_keySubscribeNow),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),

          // Popular Badge
          if (isPopular)
            Positioned(
              top: -10,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.orange,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _t(_keyMostPopular),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

          // Current Plan Badge
          if (isCurrentPlan)
            Positioned(
              top: -10,
              left: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.green,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _t(_keyCurrent),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      );
    });
  }

  Widget _buildFeatureItem(
    IconData icon,
    String feature,
    String value, {
    bool isEnabled = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: isEnabled ? AppColors.green : Colors.grey.shade600,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TranslatedText(
              feature,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 14,
              ),
            ),
          ),
          TranslatedText(
            _localizedValue(value),
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: value.toLowerCase() == 'unlimited' || isEnabled
                  ? AppColors.green
                  : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUsageStats(UsageStats stats) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const TranslatedText(
            'Today\'s Usage',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildUsageBar('AI Messages', stats.aiMessages),
          const SizedBox(height: 12),
          _buildUsageBar('Image Analysis', stats.imageAnalysis),
          const SizedBox(height: 12),
          _buildUsageBar('Consultant Chats', stats.consultantChats),
        ],
      ),
    );
  }

  Widget _buildUsageBar(String label, UsageInfo usage) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TranslatedText(
              label,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 14,
              ),
            ),
            TranslatedText(
              _localizedUsageDisplay(usage),
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: usage.isUnlimited
                    ? AppColors.green
                    : usage.isLimitReached
                        ? Colors.red
                        : Colors.black87,
              ),
            ),
          ],
        ),
        if (!usage.isUnlimited) ...[
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: usage.percentageUsed / 100,
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation<Color>(
              usage.isLimitReached ? Colors.red : AppColors.green,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPaymentHistoryLink(BuildContext context) {
    return InkWell(
      onTap: () {
        Get.toNamed(AppRoutes.PAYMENT_HISTORY);
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.receipt_long, color: Colors.grey.shade600),
            const SizedBox(width: 12),
            const Expanded(
              child: TranslatedText(
                'View Payment History',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }

  void _handleSubscribe(
    BuildContext context,
    SubscriptionPlan plan,
    SubscriptionController controller,
  ) async {
    if (plan.isFree) return;

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_t(_keySubscribeTo, {'plan': plan.displayName})),
        content: Text(
          '${_t(_keyPlanBillingMsg, {
                'price': controller.getPriceForPlan(plan),
                'cycle':
                    _billingCycleLabel(controller.selectedBillingCycle.value),
              })}\n\n${_t(_keyProceedPayment)}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(_t(_keyCancel)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.green,
            ),
            child: Text(_t(_keySubscribe)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await controller.subscribeToPlan(plan);
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  // ========== IoT ADD-ONS SECTION ==========

  Widget _buildIotAddonsSection(
    BuildContext context,
    SubscriptionController controller,
  ) {
    return Obx(() {
      if (controller.isLoadingIotAddons.value) {
        return const Center(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: CircularProgressIndicator(color: AppColors.green),
          ),
        );
      }

      if (controller.iotAddons.isEmpty) {
        return const SizedBox.shrink();
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.sensors,
                  color: Colors.blue.shade700,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _t(_keyIotAddons),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      _t(_keySmartFarming),
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              if (controller.hasAnyIotAddon)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check_circle,
                        size: 14,
                        color: AppColors.green,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _t(_keyActive),
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.green,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),

          // Coming Soon / Future Feature Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.amber.shade200),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.upcoming_outlined,
                  color: Colors.amber.shade700,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _t(_keyComingSoon),
                    style: TextStyle(
                      color: Colors.amber.shade900,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // User's Active IoT Addons
          if (controller.userIotAddons.isNotEmpty) ...[
            Text(
              _t(_keyYourActiveAddons),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            ...controller.userIotAddons.map((userAddon) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _buildActiveAddonCard(context, userAddon, controller),
                )),
            const SizedBox(height: 16),
          ],

          // Available IoT Addons
          Text(
            _t(_keyAvailableAddons),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          ...controller.iotAddons.map((addon) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildIotAddonCard(context, addon, controller),
              )),
        ],
      );
    });
  }

  Widget _buildActiveAddonCard(
    BuildContext context,
    UserIotAddon userAddon,
    SubscriptionController controller,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.green.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.green.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              _getAddonIcon(userAddon.addonName),
              color: AppColors.green,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  userAddon.displayName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                Text(
                  _t(_keyEnds, {'date': _formatDate(userAddon.endDate)}),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () =>
                _handleCancelIotAddon(context, userAddon, controller),
            child: Text(
              _t(_keyCancel),
              style: TextStyle(
                color: Colors.red.shade400,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIotAddonCard(
    BuildContext context,
    IotAddon addon,
    SubscriptionController controller,
  ) {
    final isSubscribed = controller.userIotAddons.any(
      (a) =>
          (a.addonName == addon.name ||
              (a.addonName == 'IOT_BUNDLE' && addon.name != 'IOT_BUNDLE')) &&
          a.isActive,
    );
    final isBundle = addon.isBundle;

    return Obx(() {
      final billingCycle = controller.selectedBillingCycle.value;
      final price = billingCycle == 'yearly'
          ? addon.yearlyPriceInRupees
          : addon.monthlyPriceInRupees;

      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isBundle ? Colors.blue.shade300 : Colors.grey.shade200,
            width: isBundle ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color:
                        isBundle ? Colors.blue.shade50 : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    _getAddonIcon(addon.name),
                    color:
                        isBundle ? Colors.blue.shade700 : Colors.grey.shade700,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              addon.displayName,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (isBundle && addon.bundleSavings > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.orange,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                _t(
                                  _keySaveAmount,
                                  {'amount': addon.formattedSavings},
                                ),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                      Text(
                        addon.displayNameHindi,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Description
            TranslatedText(
              addon.description,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 12),

            // Features
            if (addon.hasWaterPump)
              _buildAddonFeatureItem(
                Icons.water_drop_outlined,
                _t(_keyWaterPumpControl),
                _t(_keyDevices, {
                  'count': addon.features.waterPump.maxDevices.toString(),
                }),
              ),
            if (addon.hasCropMonitoring) ...[
              _buildAddonFeatureItem(
                Icons.grass_outlined,
                _t(_keyCropSensors),
                _t(_keySensors, {
                  'count': addon.features.cropMonitoring.maxSensors.toString(),
                }),
              ),
              if (addon.features.cropMonitoring.aiRecommendations)
                _buildAddonFeatureItem(
                  Icons.psychology_outlined,
                  _t(_keyAiRecommendations),
                  _t(_keyIncluded),
                  isEnabled: true,
                ),
            ],
            if (addon.features.weatherStation.enabled)
              _buildAddonFeatureItem(
                Icons.cloud_outlined,
                _t(_keyWeatherAlerts),
                _t(_keyDayForecast, {
                  'count':
                      addon.features.weatherStation.forecastDays.toString(),
                }),
              ),

            const SizedBox(height: 12),

            // Price & Subscribe Button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '+₹${price.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color:
                            isBundle ? Colors.blue.shade700 : AppColors.green,
                      ),
                    ),
                    Text(
                      '/${billingCycle == 'yearly' ? _t(_keyYear) : _t(_keyMonth)}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
                ElevatedButton(
                  onPressed: isSubscribed ||
                          controller.isProcessingPayment.value
                      ? null
                      : () =>
                          _handleSubscribeIotAddon(context, addon, controller),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isSubscribed
                        ? Colors.grey
                        : isBundle
                            ? Colors.blue
                            : AppColors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: controller.isProcessingPayment.value
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          isSubscribed ? _t(_keySubscribed) : _t(_keyAdd),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ],
            ),
          ],
        ),
      );
    });
  }

  Widget _buildAddonFeatureItem(
    IconData icon,
    String feature,
    String value, {
    bool isEnabled = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(
            icon,
            size: 16,
            color: isEnabled ? AppColors.green : Colors.grey.shade500,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TranslatedText(
              feature,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 13,
              ),
            ),
          ),
          TranslatedText(
            _localizedValue(value),
            style: TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 12,
              color: isEnabled ? AppColors.green : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getAddonIcon(String addonName) {
    switch (addonName) {
      case 'WATER_PUMP':
        return Icons.water_drop;
      case 'CROP_IOT':
        return Icons.sensors;
      case 'IOT_BUNDLE':
        return Icons.hub;
      default:
        return Icons.device_hub;
    }
  }

  void _handleSubscribeIotAddon(
    BuildContext context,
    IotAddon addon,
    SubscriptionController controller,
  ) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_t(_keyAddAddon, {'addon': addon.displayName})),
        content: Text(
          '${_t(_keyAddonBillingMsg, {
                'price': controller.getPriceForIotAddon(addon),
                'cycle':
                    _billingCycleLabel(controller.selectedBillingCycle.value),
              })}\n\n${_t(_keyAddonSeparateBilling)}\n\n${_t(_keyProceedPayment)}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(_t(_keyCancel)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: addon.isBundle ? Colors.blue : AppColors.green,
            ),
            child: Text(_t(_keyAddNow)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await controller.subscribeToIotAddon(addon);
    }
  }

  void _handleCancelIotAddon(
    BuildContext context,
    UserIotAddon userAddon,
    SubscriptionController controller,
  ) async {
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_t(_keyCancelAddon, {'addon': userAddon.displayName})),
        content: Text(
          '${_t(_keyCancelHow)}\n\n${_t(_keyCancelAtEnd)}\n${_t(_keyCancelImmediate)}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: Text(_t(_keyBack)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'end'),
            child: Text(_t(_keyAtPeriodEnd)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'now'),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(_t(_keyCancelNow)),
          ),
        ],
      ),
    );

    if (result != null) {
      await controller.cancelIotAddon(
        userAddon.addonName,
        cancelImmediately: result == 'now',
      );
    }
  }
}
