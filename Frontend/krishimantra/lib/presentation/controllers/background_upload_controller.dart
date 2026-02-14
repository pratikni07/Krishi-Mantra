import 'dart:io';
import 'package:get/get.dart';
import 'package:dio/dio.dart' as dio;
import '../../data/repositories/feed_repository.dart';
import '../../data/services/UserService.dart';
import '../../core/utils/app_logger.dart';
import '../../core/constants/colors.dart';
import 'feed_controller.dart';

class BackgroundUploadController extends GetxController {
  final FeedRepository _feedRepository;
  final UserService _userService;

  BackgroundUploadController(this._feedRepository, this._userService);

  final RxDouble uploadProgress = 0.0.obs;
  final RxBool isUploading = false.obs;
  final RxString statusMessage = ''.obs;
  final RxBool hasError = false.obs;
  final RxBool isSuccess = false.obs;

  Future<void> startUpload({
    required String description,
    required String content,
    List<File>? mediaFiles,
    Map<String, dynamic>? location,
  }) async {
    if (isUploading.value) {
      Get.snackbar(
        'Wait',
        'Another post is already being uploaded',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    try {
      isUploading.value = true;
      hasError.value = false;
      isSuccess.value = false;
      uploadProgress.value = 0.0;
      statusMessage.value = 'Preparing post...';

      final user = await _userService.getUser();
      if (user == null) throw Exception('User not logged in');

      List<String> mediaUrls = [];

      if (mediaFiles != null && mediaFiles.isNotEmpty) {
        final totalFiles = mediaFiles.length;
        for (int i = 0; i < totalFiles; i++) {
          final file = mediaFiles[i];
          statusMessage.value = 'Getting upload link (${i + 1}/$totalFiles)...';
          final fileName = file.path.split('/').last;
          final fileType = _getMimeType(fileName);

          // 1. Get Presigned URL
          final presignedData = await _feedRepository.getPresignedUrl(
            fileName: fileName,
            fileType: fileType,
            contentType: 'feeds',
            userId: user.id,
          );

          final String uploadUrl = presignedData['presignedUrl'];
          final String fileUrl = presignedData['fileUrl'];

          // 2. Upload to S3
          statusMessage.value = 'Uploading media (${i + 1}/$totalFiles)...';
          await _feedRepository.uploadFileToS3(
            presignedUrl: uploadUrl,
            filePath: file.path,
            contentType: fileType,
            onProgress: (progress) {
              // Calculate overall progress across all files
              final overallProgress = (i + progress) / totalFiles;
              uploadProgress.value = overallProgress;
              statusMessage.value = 'Uploading media ${i + 1}/$totalFiles (${(progress * 100).toInt()}%)...';
            },
          );

          mediaUrls.add(fileUrl);
        }
      }

      // 3. Create Feed Post
      statusMessage.value = 'Finalizing post...';
      
      // Use name field, or construct from firstName/lastName if name is empty
      String userName = user.name;
      if (userName.isEmpty) {
        userName = '${user.firstName} ${user.lastName}'.trim();
      }
      if (userName.isEmpty) {
        userName = 'User';
      }

      final feedData = {
        'userId': user.id,
        'userName': userName,
        'profilePhoto': user.image,
        'description': description,
        'content': content,
        if (mediaUrls.isNotEmpty) 'mediaUrl': mediaUrls.first,
        if (mediaUrls.isNotEmpty) 'mediaUrls': mediaUrls,
        if (location != null) 'location': location,
      };

      await _feedRepository.createFeed(feedData);

      // Refresh feeds if the controller is active
      try {
        if (Get.isRegistered<FeedController>()) {
          Get.find<FeedController>().fetchRecommendedFeeds(refresh: true);
        }
      } catch (e) {
        logger.w('Could not refresh feeds: $e');
      }

      isSuccess.value = true;
      statusMessage.value = 'Post uploaded successfully!';
      
      // Keep overlay visible for 3 seconds to show success
      Future.delayed(const Duration(seconds: 3), () {
        if (!isUploading.value) { // Only clear if we haven't started another upload
           _clearState();
        }
      });
    } catch (e) {
      logger.e('Background Upload Error: $e');
      hasError.value = true;
      statusMessage.value = 'Upload failed properly. Please check credentials.';
      
      // Keep overlay visible for 5 seconds to show error
      Future.delayed(const Duration(seconds: 5), () {
        if (!isUploading.value) {
          _clearState();
        }
      });
    } finally {
      isUploading.value = false;
    }
  }

  void _clearState() {
    uploadProgress.value = 0.0;
    statusMessage.value = '';
    hasError.value = false;
    isSuccess.value = false;
  }

  String _getMimeType(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'mp4':
        return 'video/mp4';
      case 'mov':
        return 'video/quicktime';
      case 'avi':
        return 'video/x-msvideo';
      default:
        return 'application/octet-stream';
    }
  }
}
