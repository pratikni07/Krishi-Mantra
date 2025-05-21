import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:krishimantra/core/constants/colors.dart';
import 'package:krishimantra/presentation/controllers/connectivity_controller.dart';
import 'package:krishimantra/data/services/UserService.dart';
import 'package:krishimantra/core/theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final ConnectivityController _connectivityController =
      Get.find<ConnectivityController>();
  final UserService _userService = Get.find<UserService>();
  final ThemeService _themeService = Get.find<ThemeService>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.green,
        elevation: 0,
      ),
      body: SafeArea(
        child: ListView(
          children: [
            const SizedBox(height: 16),

            // Network Section
            _buildSectionHeader('Network'),

            // Offline Mode Toggle
            Obx(() => SwitchListTile(
                  title: const Text('Offline Mode'),
                  subtitle:
                      const Text('Use cached data without network requests'),
                  value: _connectivityController.isOfflineMode.value,
                  onChanged: (value) {
                    _connectivityController.toggleOfflineMode(value);
                    if (value) {
                      Get.snackbar(
                        'Offline Mode Enabled',
                        'App will use cached data without making network requests',
                        snackPosition: SnackPosition.BOTTOM,
                        backgroundColor: Colors.amber.shade700,
                        colorText: Colors.white,
                        duration: const Duration(seconds: 3),
                      );
                    } else {
                      Get.snackbar(
                        'Offline Mode Disabled',
                        'App will now sync with the server',
                        snackPosition: SnackPosition.BOTTOM,
                        backgroundColor: AppColors.green,
                        colorText: Colors.white,
                        duration: const Duration(seconds: 3),
                      );
                    }
                  },
                  activeColor: AppColors.green,
                  secondary: const Icon(Icons.wifi_off_outlined),
                )),

            // Network Status
            Obx(() => ListTile(
                  title: const Text('Network Status'),
                  subtitle: Text(
                    _connectivityController.isConnected.value
                        ? 'Connected'
                        : 'Disconnected',
                    style: TextStyle(
                      color: _connectivityController.isConnected.value
                          ? Colors.green
                          : Colors.red,
                    ),
                  ),
                  leading: Icon(
                    _connectivityController.isConnected.value
                        ? Icons.wifi
                        : Icons.wifi_off,
                    color: _connectivityController.isConnected.value
                        ? Colors.green
                        : Colors.red,
                  ),
                )),

            const Divider(),

            // Cache Section
            _buildSectionHeader('Cache'),

            // Refresh All Data
            ListTile(
              title: const Text('Refresh All Data'),
              subtitle: const Text('Download fresh data from server'),
              leading: const Icon(Icons.refresh),
              onTap: () => _connectivityController.forceRefreshAll(),
            ),

            // Clear Cache
            ListTile(
              title: const Text('Clear Cache'),
              subtitle: const Text('Remove all cached data'),
              leading: const Icon(Icons.delete_outline),
              onTap: () {
                _showClearCacheConfirmation();
              },
            ),

            const Divider(),

            // Appearance Section
            _buildSectionHeader('Appearance'),

            // Theme Toggle
            Obx(() => SwitchListTile(
                  title: const Text('Dark Mode'),
                  subtitle: const Text('Switch between light and dark theme'),
                  value: _themeService.theme == ThemeMode.dark,
                  onChanged: (value) {
                    _themeService.switchTheme();
                  },
                  activeColor: AppColors.green,
                  secondary: Icon(
                    _themeService.theme == ThemeMode.dark
                        ? Icons.dark_mode
                        : Icons.light_mode,
                  ),
                )),

            const Divider(),

            // About Section
            _buildSectionHeader('About'),

            // App Version
            const ListTile(
              title: Text('App Version'),
              subtitle: Text('1.0.0'),
              leading: Icon(Icons.info_outline),
            ),

            // Terms and Privacy
            ListTile(
              title: const Text('Terms & Privacy Policy'),
              leading: const Icon(Icons.description_outlined),
              onTap: () {
                // Navigate to terms and privacy policy
              },
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, top: 16, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: AppColors.green,
        ),
      ),
    );
  }

  void _showClearCacheConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Cache?'),
        content: const Text(
          'This will remove all cached data including offline content. '
          'You\'ll need an internet connection to reload the data.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () {
              _connectivityController.clearAllCache();
              Navigator.of(context).pop();
            },
            child: const Text('CLEAR'),
          ),
        ],
      ),
    );
  }
}
