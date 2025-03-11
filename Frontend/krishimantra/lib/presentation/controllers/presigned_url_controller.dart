import 'package:get/get.dart';
import 'package:krishimantra/data/repositories/presigned_url_repository.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:mime/mime.dart';

class PresignedUrlController extends GetxController {
  final PresignedUrlRepository _repository;

  PresignedUrlController(this._repository);

  RxBool isLoading = false.obs;
  RxString uploadedFileUrl = ''.obs;
  RxString error = ''.obs;
  RxList<String> contentTypes = <String>[].obs;

  @override
  void onInit() {
    super.onInit();
    loadContentTypes();
  }

  Future<void> loadContentTypes() async {
    try {
      isLoading.value = true;
      contentTypes.value = await _repository.getContentTypes();
    } catch (e) {
      error.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  // New method specifically for uploading images
  Future<String?> uploadImage({
    required File imageFile,
    required String contentType,
    String? userId,
  }) async {
    try {
      isLoading.value = true;
      error.value = '';

      final String fileName = path.basename(imageFile.path);
      final String? mimeType = lookupMimeType(imageFile.path);

      if (mimeType == null || !mimeType.startsWith('image/')) {
        error.value = 'Invalid image file type';
        return null;
      }

      // Get presigned URL from the server
      final presignedData = await _repository.getPresignedUrl(
        fileName: fileName,
        fileType: mimeType,
        contentType: contentType,
        userId: userId,
      );

      // Upload image to the presigned URL
      final fileBytes = await imageFile.readAsBytes();
      final response = await http.put(
        Uri.parse(presignedData['presignedUrl']),
        body: fileBytes,
        headers: {
          'Content-Type': mimeType,
        },
      );

      if (response.statusCode != 200) {
        error.value =
            'Failed to upload image: ${response.statusCode} - ${response.body}';
        print(
            'Failed to upload image: ${response.statusCode} - ${response.body}');
        return null;
      }

      if (response.statusCode == 200) {
        // Return the CloudFront URL for the uploaded image
        final fileUrl = presignedData['fileUrl'];
        uploadedFileUrl.value = fileUrl;
        return fileUrl;
      } else {
        error.value = 'Failed to upload image: ${response.statusCode}';
        return null;
      }
    } catch (e) {
      error.value = 'Upload error: $e';
      return null;
    } finally {
      isLoading.value = false;
    }
  }

  // General file upload method remains unchanged
  Future<String?> uploadFile({
    required File file,
    required String contentType,
    String? userId,
  }) async {
    try {
      isLoading.value = true;
      error.value = '';

      final String fileName = path.basename(file.path);
      final String? mimeType = lookupMimeType(file.path);

      if (mimeType == null) {
        error.value = 'Could not determine file type';
        return null;
      }

      // Get presigned URL from the server
      final presignedData = await _repository.getPresignedUrl(
        fileName: fileName,
        fileType: mimeType,
        contentType: contentType,
        userId: userId,
      );

      // Extract presigned URL and file URL
      final String presignedUrl = presignedData['presignedUrl'];
      final String fileUrl = presignedData['fileUrl'];

      // Upload file to the presigned URL
      final fileBytes = await file.readAsBytes();
      final response = await http.put(
        Uri.parse(presignedUrl),
        body: fileBytes,
        headers: {
          'Content-Type': mimeType,
        },
      );

      if (response.statusCode == 200) {
        uploadedFileUrl.value = fileUrl;
        return fileUrl;
      } else {
        error.value = 'Failed to upload file: ${response.statusCode}';
        return null;
      }
    } catch (e) {
      error.value = 'Upload error: $e';
      return null;
    } finally {
      isLoading.value = false;
    }
  }
}
