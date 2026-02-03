import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/constants/colors.dart';
import '../../../data/models/subscription_model.dart';
import '../../controllers/subscription_controller.dart';

class SubscriptionPlansScreen extends StatelessWidget {
  const SubscriptionPlansScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<SubscriptionController>();

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        title: const Text(
          'Subscription Plans',
          style: TextStyle(
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
                  child: const Text('Retry'),
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
                        'Current Plan',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        plan?.displayName ?? 'Kisan (Free)',
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
                    child: Text(
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
                    ? 'Ends on ${_formatDate(subscription.endDate)}'
                    : 'Renews on ${_formatDate(subscription.nextPaymentDate ?? subscription.endDate)}',
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
                      'Monthly',
                      style: TextStyle(
                        color: controller.selectedBillingCycle.value == 'monthly'
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
                        'Yearly',
                        style: TextStyle(
                          color: controller.selectedBillingCycle.value == 'yearly'
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
                        child: const Text(
                          'Save 16%',
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
                          price == 0 ? 'Free' : '₹${price.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: AppColors.green,
                          ),
                        ),
                        if (price > 0)
                          Text(
                            '/${billingCycle == 'yearly' ? 'year' : 'month'}',
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
                Text(
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
                  'AI Crop Doctor',
                  plan.features.getFeatureDisplay('aiMessagesPerDay'),
                ),
                _buildFeatureItem(
                  Icons.image_outlined,
                  'Image Analysis',
                  plan.features.getFeatureDisplay('imageAnalysisPerDay'),
                ),
                _buildFeatureItem(
                  Icons.support_agent,
                  'Consultant Chats',
                  plan.features.getFeatureDisplay('consultantChatsPerDay'),
                ),
                if (plan.features.videoConsultationsPerMonth != 0)
                  _buildFeatureItem(
                    Icons.video_call_outlined,
                    'Video Consultations',
                    plan.features.getFeatureDisplay('videoConsultationsPerMonth'),
                  ),
                if (plan.features.canCreatePosts)
                  _buildFeatureItem(
                    Icons.post_add,
                    'Create Posts',
                    'Yes',
                    isEnabled: true,
                  ),
                if (plan.features.marketplaceListings != 0)
                  _buildFeatureItem(
                    Icons.storefront_outlined,
                    'Marketplace Listings',
                    plan.features.getFeatureDisplay('marketplaceListings'),
                  ),
                if (plan.features.adFree)
                  _buildFeatureItem(
                    Icons.block,
                    'Ad-Free Experience',
                    'Yes',
                    isEnabled: true,
                  ),
                if (plan.features.prioritySupport)
                  _buildFeatureItem(
                    Icons.support,
                    'Priority Support',
                    'Yes',
                    isEnabled: true,
                  ),

                const SizedBox(height: 16),

                // Subscribe Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isCurrentPlan ||
                            controller.isProcessingPayment.value
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
                                ? 'Current Plan'
                                : plan.isFree
                                    ? 'Free Forever'
                                    : 'Subscribe Now',
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
                child: const Text(
                  '⭐ Most Popular',
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
                child: const Text(
                  '✓ Current',
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
            child: Text(
              feature,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 14,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: value == 'Unlimited' || isEnabled
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
          const Text(
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
            Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 14,
              ),
            ),
            Text(
              usage.displayString,
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
        // Navigate to payment history
        Get.toNamed('/payment-history');
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
              child: Text(
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
        title: Text('Subscribe to ${plan.displayName}'),
        content: Text(
          'You will be charged ${controller.getPriceForPlan(plan)} for the ${controller.selectedBillingCycle.value} subscription.\n\nProceed with payment?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.green,
            ),
            child: const Text('Subscribe'),
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
                    const Text(
                      'IoT Add-ons',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Smart farming devices & sensors',
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
                        'Active',
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
                    'Coming Soon: Connect IoT devices for smart farming!',
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
            const Text(
              'Your Active Add-ons',
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
          const Text(
            'Available Add-ons',
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
                  'Ends: ${_formatDate(userAddon.endDate)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => _handleCancelIotAddon(context, userAddon, controller),
            child: Text(
              'Cancel',
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
      (a) => (a.addonName == addon.name ||
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
                    color: isBundle
                        ? Colors.blue.shade50
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    _getAddonIcon(addon.name),
                    color: isBundle ? Colors.blue.shade700 : Colors.grey.shade700,
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
                                'Save ${addon.formattedSavings}',
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
            Text(
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
                'Water Pump Control',
                '${addon.features.waterPump.maxDevices} devices',
              ),
            if (addon.hasCropMonitoring) ...[
              _buildAddonFeatureItem(
                Icons.grass_outlined,
                'Crop Sensors',
                '${addon.features.cropMonitoring.maxSensors} sensors',
              ),
              if (addon.features.cropMonitoring.aiRecommendations)
                _buildAddonFeatureItem(
                  Icons.psychology_outlined,
                  'AI Recommendations',
                  'Included',
                  isEnabled: true,
                ),
            ],
            if (addon.features.weatherStation.enabled)
              _buildAddonFeatureItem(
                Icons.cloud_outlined,
                'Weather Alerts',
                '${addon.features.weatherStation.forecastDays} day forecast',
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
                        color: isBundle ? Colors.blue.shade700 : AppColors.green,
                      ),
                    ),
                    Text(
                      '/${billingCycle == 'yearly' ? 'year' : 'month'}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
                ElevatedButton(
                  onPressed: isSubscribed || controller.isProcessingPayment.value
                      ? null
                      : () => _handleSubscribeIotAddon(context, addon, controller),
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
                          isSubscribed ? 'Subscribed' : 'Add',
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
            child: Text(
              feature,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 13,
              ),
            ),
          ),
          Text(
            value,
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
        title: Text('Add ${addon.displayName}'),
        content: Text(
          'You will be charged ${controller.getPriceForIotAddon(addon)} for the ${controller.selectedBillingCycle.value} add-on.\n\nThis will be billed separately from your subscription.\n\nProceed with payment?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: addon.isBundle ? Colors.blue : AppColors.green,
            ),
            child: const Text('Add Now'),
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
        title: Text('Cancel ${userAddon.displayName}'),
        content: const Text(
          'How would you like to cancel?\n\n• Cancel at end of billing period: Continue using until current period ends\n• Cancel immediately: Lose access right away',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('Back'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'end'),
            child: const Text('At Period End'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'now'),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Cancel Now'),
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
