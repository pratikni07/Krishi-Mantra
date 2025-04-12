import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'permission_helper.dart';

class ImagePickerHelper {
  static final ImagePicker _picker = ImagePicker();
  
  /// Pick an image from gallery
  static Future<XFile?> pickImageFromGallery(BuildContext context) async {
    // Request permission first
    final hasPermission = await PermissionHelper.requestGalleryPermission(context);
    
    if (!hasPermission) {
      return null;
    }
    
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );
      return image;
    } catch (e) {
      debugPrint('Error picking image from gallery: $e');
      return null;
    }
  }
  
  /// Take a photo with the camera
  static Future<XFile?> takePhoto(BuildContext context) async {
    // Request permission first
    final hasPermission = await PermissionHelper.requestCameraPermission(context);
    
    if (!hasPermission) {
      return null;
    }
    
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
      );
      return photo;
    } catch (e) {
      debugPrint('Error taking photo: $e');
      return null;
    }
  }
  
  /// Pick multiple images from gallery
  static Future<List<XFile>?> pickMultipleImages(BuildContext context) async {
    // Request permission first
    final hasPermission = await PermissionHelper.requestGalleryPermission(context);
    
    if (!hasPermission) {
      return null;
    }
    
    try {
      final List<XFile>? images = await _picker.pickMultiImage(
        imageQuality: 80,
      );
      return images;
    } catch (e) {
      debugPrint('Error picking multiple images: $e');
      return null;
    }
  }
  
  /// Show a bottom sheet with options to choose camera or gallery
  static Future<XFile?> showImageSourceActionSheet(BuildContext context) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take a photo'),
              onTap: () => Navigator.of(context).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.of(context).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    
    if (source == null) {
      return null;
    }
    
    return source == ImageSource.camera
        ? await takePhoto(context)
        : await pickImageFromGallery(context);
  }
} 