import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:get/get.dart';
import 'package:app_settings/app_settings.dart';

class PermissionHelper {
  // Request location permission
  static Future<bool> requestLocationPermission(BuildContext context) async {
    // Check location permission status
    final status = await Permission.location.status;
    
    if (status.isGranted) {
      return true;
    }
    
    if (status.isPermanentlyDenied) {
      // Show dialog to open settings
      final shouldOpenSettings = await _showOpenSettingsDialog(
        context: context,
        permission: 'location',
        message: 'Location permission is required to provide personalized content.',
      );
      
      if (shouldOpenSettings) {
        await AppSettings.openAppSettings();
      }
      
      return false;
    }
    
    // Request permission
    final result = await Permission.location.request();
    return result.isGranted;
  }
  
  // Request camera permission
  static Future<bool> requestCameraPermission(BuildContext context) async {
    final status = await Permission.camera.status;
    
    if (status.isGranted) {
      return true;
    }
    
    if (status.isPermanentlyDenied) {
      final shouldOpenSettings = await _showOpenSettingsDialog(
        context: context,
        permission: 'camera',
        message: 'Camera permission is required to take photos for crop analysis.',
      );
      
      if (shouldOpenSettings) {
        await AppSettings.openAppSettings();
      }
      
      return false;
    }
    
    final result = await Permission.camera.request();
    return result.isGranted;
  }
  
  // Request photo library permission
  static Future<bool> requestGalleryPermission(BuildContext context) async {
    // For Android 13+ we need to use photos permission
    // For older Android versions we use storage permission
    Permission permission;
    
    // Check android version
    if (GetPlatform.isAndroid) {
      if (await _isAndroid13OrHigher()) {
        permission = Permission.photos;
      } else {
        permission = Permission.storage;
      }
    } else {
      permission = Permission.photos;
    }
    
    final status = await permission.status;
    
    if (status.isGranted) {
      return true;
    }
    
    if (status.isPermanentlyDenied) {
      final shouldOpenSettings = await _showOpenSettingsDialog(
        context: context,
        permission: 'gallery',
        message: 'Photo library access is required to select images for crop analysis.',
      );
      
      if (shouldOpenSettings) {
        await AppSettings.openAppSettings();
      }
      
      return false;
    }
    
    final result = await permission.request();
    return result.isGranted;
  }
  
  // Check if device is running Android 13 or higher
  static Future<bool> _isAndroid13OrHigher() async {
    try {
      // Android 13 is SDK 33+
      // Checking if photos permission exists (only available on Android 13+)
      return await Permission.photos.status.isGranted || 
             await Permission.photos.status.isDenied || 
             await Permission.photos.status.isPermanentlyDenied;
    } catch (e) {
      // If the permission doesn't exist, we're on a lower Android version
      return false;
    }
  }
  
  // Show dialog to open settings
  static Future<bool> _showOpenSettingsDialog({
    required BuildContext context,
    required String permission,
    required String message,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$permission permission required'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
    
    return result ?? false;
  }
} 