import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:krishimantra/core/constants/colors.dart';
import 'package:krishimantra/core/utils/responsive_utils.dart';
import 'package:krishimantra/core/utils/language_helper.dart';
import 'package:krishimantra/presentation/controllers/connectivity_controller.dart';
import 'package:krishimantra/presentation/controllers/subscription_controller.dart';
import 'package:krishimantra/routes/app_routes.dart';
import 'package:krishimantra/presentation/widgets/ai_chat/voice_settings_section.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> with TranslationMixin {
  final ConnectivityController _connectivityController =
      Get.find<ConnectivityController>();
  final SubscriptionController _subscriptionController =
      Get.find<SubscriptionController>();

  // Translation keys
  static const String KEY_SETTINGS = 'settings';
  static const String KEY_NETWORK = 'network';
  static const String KEY_OFFLINE_MODE = 'offline_mode';
  static const String KEY_OFFLINE_MODE_DESC = 'offline_mode_desc';
  static const String KEY_OFFLINE_MODE_ENABLED = 'offline_mode_enabled';
  static const String KEY_OFFLINE_MODE_ENABLED_MSG = 'offline_mode_enabled_msg';
  static const String KEY_OFFLINE_MODE_DISABLED = 'offline_mode_disabled';
  static const String KEY_OFFLINE_MODE_DISABLED_MSG = 'offline_mode_disabled_msg';
  static const String KEY_NETWORK_STATUS = 'network_status';
  static const String KEY_CONNECTED = 'connected';
  static const String KEY_DISCONNECTED = 'disconnected';
  static const String KEY_CACHE = 'cache';
  static const String KEY_REFRESH_DATA = 'refresh_data';
  static const String KEY_REFRESH_DATA_DESC = 'refresh_data_desc';
  static const String KEY_CLEAR_CACHE = 'clear_cache';
  static const String KEY_CLEAR_CACHE_DESC = 'clear_cache_desc';
  static const String KEY_ABOUT = 'about';
  static const String KEY_APP_VERSION = 'app_version';
  static const String KEY_TERMS_PRIVACY = 'terms_privacy';
  static const String KEY_CLEAR_CACHE_CONFIRM = 'clear_cache_confirm';
  static const String KEY_CLEAR_CACHE_MSG = 'clear_cache_msg';
  static const String KEY_CANCEL = 'cancel';
  static const String KEY_CLEAR = 'clear';
  static const String KEY_SUBSCRIPTION = 'subscription';
  static const String KEY_MANAGE_SUBSCRIPTION = 'manage_subscription';
  static const String KEY_MANAGE_SUBSCRIPTION_DESC = 'manage_subscription_desc';
  static const String KEY_CURRENT_PLAN = 'current_plan';

  @override
  void initState() {
    super.initState();
    _registerTranslations();
    _initializeLanguage();
  }

  void _registerTranslations() {
    registerTranslation(KEY_SETTINGS, 'Settings');
    registerTranslation(KEY_NETWORK, 'Network');
    registerTranslation(KEY_OFFLINE_MODE, 'Offline Mode');
    registerTranslation(KEY_OFFLINE_MODE_DESC, 'Use cached data without network requests');
    registerTranslation(KEY_OFFLINE_MODE_ENABLED, 'Offline Mode Enabled');
    registerTranslation(KEY_OFFLINE_MODE_ENABLED_MSG, 'App will use cached data without making network requests');
    registerTranslation(KEY_OFFLINE_MODE_DISABLED, 'Offline Mode Disabled');
    registerTranslation(KEY_OFFLINE_MODE_DISABLED_MSG, 'App will now sync with the server');
    registerTranslation(KEY_NETWORK_STATUS, 'Network Status');
    registerTranslation(KEY_CONNECTED, 'Connected');
    registerTranslation(KEY_DISCONNECTED, 'Disconnected');
    registerTranslation(KEY_CACHE, 'Cache');
    registerTranslation(KEY_REFRESH_DATA, 'Refresh All Data');
    registerTranslation(KEY_REFRESH_DATA_DESC, 'Download fresh data from server');
    registerTranslation(KEY_CLEAR_CACHE, 'Clear Cache');
    registerTranslation(KEY_CLEAR_CACHE_DESC, 'Remove all cached data');
    registerTranslation(KEY_ABOUT, 'About');
    registerTranslation(KEY_APP_VERSION, 'App Version');
    registerTranslation(KEY_TERMS_PRIVACY, 'Terms & Privacy Policy');
    registerTranslation(KEY_CLEAR_CACHE_CONFIRM, 'Clear Cache?');
    registerTranslation(KEY_CLEAR_CACHE_MSG, "This will remove all cached data including offline content. You'll need an internet connection to reload the data.");
    registerTranslation(KEY_CANCEL, 'CANCEL');
    registerTranslation(KEY_CLEAR, 'CLEAR');
    registerTranslation(KEY_SUBSCRIPTION, 'Subscription');
    registerTranslation(KEY_MANAGE_SUBSCRIPTION, 'Manage Subscription');
    registerTranslation(KEY_MANAGE_SUBSCRIPTION_DESC, 'View plans, usage and payment history');
    registerTranslation(KEY_CURRENT_PLAN, 'Current Plan');
  }

  Future<void> _initializeLanguage() async {
    await updateTranslations();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    ResponsiveUtils.init(context);

    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        title: Text(
          getTranslation(KEY_SETTINGS),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.white,
            fontSize: AppSizes.fontXL,
          ),
        ),
        backgroundColor: AppColors.green,
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.white, size: AppSizes.iconM),
      ),
      body: SafeArea(
        child: ListView(
          padding: RPadding.symmetric(vertical: 8),
          children: [
            SizedBox(height: AppSizes.paddingL),

            // Subscription Section
            _buildSectionHeader(getTranslation(KEY_SUBSCRIPTION)),
            _buildSubscriptionTile(),
            const Divider(color: AppColors.divider),

            // Network Section
            _buildSectionHeader(getTranslation(KEY_NETWORK)),

            // Offline Mode Toggle
            Obx(() => SwitchListTile(
                  title: Text(
                    getTranslation(KEY_OFFLINE_MODE),
                    style: TextStyle(
                      color: AppColors.textDark,
                      fontSize: AppSizes.fontL,
                    ),
                  ),
                  subtitle: Text(
                    getTranslation(KEY_OFFLINE_MODE_DESC),
                    style: TextStyle(
                      color: AppColors.textLight,
                      fontSize: AppSizes.fontS,
                    ),
                  ),
                  value: _connectivityController.isOfflineMode.value,
                  onChanged: (value) {
                    _connectivityController.toggleOfflineMode(value);
                    if (value) {
                      Get.snackbar(
                        getTranslation(KEY_OFFLINE_MODE_ENABLED),
                        getTranslation(KEY_OFFLINE_MODE_ENABLED_MSG),
                        snackPosition: SnackPosition.BOTTOM,
                        backgroundColor: AppColors.warning,
                        colorText: AppColors.white,
                        duration: const Duration(seconds: 3),
                      );
                    } else {
                      Get.snackbar(
                        getTranslation(KEY_OFFLINE_MODE_DISABLED),
                        getTranslation(KEY_OFFLINE_MODE_DISABLED_MSG),
                        snackPosition: SnackPosition.BOTTOM,
                        backgroundColor: AppColors.green,
                        colorText: AppColors.white,
                        duration: const Duration(seconds: 3),
                      );
                    }
                  },
                  activeColor: AppColors.green,
                  secondary: Icon(Icons.wifi_off_outlined,
                    color: AppColors.textGrey,
                    size: AppSizes.iconM,
                  ),
                )),

            // Network Status
            Obx(() => ListTile(
                  title: Text(
                    getTranslation(KEY_NETWORK_STATUS),
                    style: TextStyle(
                      color: AppColors.textDark,
                      fontSize: AppSizes.fontL,
                    ),
                  ),
                  subtitle: Text(
                    _connectivityController.isConnected.value
                        ? getTranslation(KEY_CONNECTED)
                        : getTranslation(KEY_DISCONNECTED),
                    style: TextStyle(
                      color: _connectivityController.isConnected.value
                          ? AppColors.success
                          : AppColors.error,
                      fontSize: AppSizes.fontS,
                    ),
                  ),
                  leading: Icon(
                    _connectivityController.isConnected.value
                        ? Icons.wifi
                        : Icons.wifi_off,
                    color: _connectivityController.isConnected.value
                        ? AppColors.success
                        : AppColors.error,
                    size: AppSizes.iconM,
                  ),
                )),

            const Divider(color: AppColors.divider),

            // Voice section (krishi-ai Build B)
            const VoiceSettingsSection(),

            const Divider(color: AppColors.divider),

            // Cache Section
            _buildSectionHeader(getTranslation(KEY_CACHE)),

            // Refresh All Data
            ListTile(
              title: Text(
                getTranslation(KEY_REFRESH_DATA),
                style: TextStyle(
                  color: AppColors.textDark,
                  fontSize: AppSizes.fontL,
                ),
              ),
              subtitle: Text(
                getTranslation(KEY_REFRESH_DATA_DESC),
                style: TextStyle(
                  color: AppColors.textLight,
                  fontSize: AppSizes.fontS,
                ),
              ),
              leading: Icon(Icons.refresh, color: AppColors.textGrey, size: AppSizes.iconM),
              onTap: () => _connectivityController.forceRefreshAll(),
            ),

            // Clear Cache
            ListTile(
              title: Text(
                getTranslation(KEY_CLEAR_CACHE),
                style: TextStyle(
                  color: AppColors.textDark,
                  fontSize: AppSizes.fontL,
                ),
              ),
              subtitle: Text(
                getTranslation(KEY_CLEAR_CACHE_DESC),
                style: TextStyle(
                  color: AppColors.textLight,
                  fontSize: AppSizes.fontS,
                ),
              ),
              leading: Icon(Icons.delete_outline, color: AppColors.textGrey, size: AppSizes.iconM),
              onTap: () {
                _showClearCacheConfirmation();
              },
            ),

            const Divider(color: AppColors.divider),

            // About Section
            _buildSectionHeader(getTranslation(KEY_ABOUT)),

            // App Version
            ListTile(
              title: Text(
                getTranslation(KEY_APP_VERSION),
                style: TextStyle(
                  color: AppColors.textDark,
                  fontSize: AppSizes.fontL,
                ),
              ),
              subtitle: Text(
                '1.0.0',
                style: TextStyle(
                  color: AppColors.textLight,
                  fontSize: AppSizes.fontS,
                ),
              ),
              leading: Icon(Icons.info_outline, color: AppColors.textGrey, size: AppSizes.iconM),
            ),

            // Terms and Privacy
            ListTile(
              title: Text(
                getTranslation(KEY_TERMS_PRIVACY),
                style: TextStyle(
                  color: AppColors.textDark,
                  fontSize: AppSizes.fontL,
                ),
              ),
              leading: Icon(Icons.description_outlined, color: AppColors.textGrey, size: AppSizes.iconM),
              onTap: () {
                // Navigate to terms and privacy policy
              },
            ),

            SizedBox(height: AppSizes.paddingXXL),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: RPadding.only(left: 16, top: 16, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: AppSizes.fontM,
          fontWeight: FontWeight.bold,
          color: AppColors.green,
        ),
      ),
    );
  }

  Widget _buildSubscriptionTile() {
    return Obx(() {
      final currentPlan = _subscriptionController.currentPlan.value;
      final isFreePlan = _subscriptionController.isFreePlan.value;
      final planName = currentPlan?.displayName ?? 'Kisan (Free)';

      return ListTile(
        title: Text(
          getTranslation(KEY_MANAGE_SUBSCRIPTION),
          style: TextStyle(
            color: AppColors.textDark,
            fontSize: AppSizes.fontL,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              getTranslation(KEY_MANAGE_SUBSCRIPTION_DESC),
              style: TextStyle(
                color: AppColors.textLight,
                fontSize: AppSizes.fontS,
              ),
            ),
            SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: isFreePlan ? Colors.grey.shade200 : AppColors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '${getTranslation(KEY_CURRENT_PLAN)}: $planName',
                style: TextStyle(
                  color: isFreePlan ? Colors.grey.shade700 : AppColors.green,
                  fontSize: AppSizes.fontXS,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isFreePlan ? Colors.grey.shade100 : AppColors.green.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            isFreePlan ? Icons.card_membership : Icons.star,
            color: isFreePlan ? Colors.grey.shade600 : AppColors.green,
            size: AppSizes.iconM,
          ),
        ),
        trailing: Icon(
          Icons.chevron_right,
          color: AppColors.textGrey,
        ),
        onTap: () {
          Get.toNamed(AppRoutes.SUBSCRIPTION_PLANS);
        },
      );
    });
  }

  void _showClearCacheConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusXL),
        ),
        title: Text(
          getTranslation(KEY_CLEAR_CACHE_CONFIRM),
          style: TextStyle(
            color: AppColors.textDark,
            fontWeight: FontWeight.bold,
            fontSize: AppSizes.fontXL,
          ),
        ),
        content: Text(
          getTranslation(KEY_CLEAR_CACHE_MSG),
          style: TextStyle(
            color: AppColors.textGrey,
            fontSize: AppSizes.fontM,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              getTranslation(KEY_CANCEL),
              style: TextStyle(
                color: AppColors.textGrey,
                fontWeight: FontWeight.w600,
                fontSize: AppSizes.fontM,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              _connectivityController.clearAllCache();
              Navigator.of(context).pop();
            },
            child: Text(
              getTranslation(KEY_CLEAR),
              style: TextStyle(
                color: AppColors.error,
                fontWeight: FontWeight.w600,
                fontSize: AppSizes.fontM,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
