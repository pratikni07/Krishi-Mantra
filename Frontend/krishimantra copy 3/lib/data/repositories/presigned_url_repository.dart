import 'package:krishimantra/data/services/api_service.dart';
import 'package:krishimantra/core/constants/api_constants.dart';

class PresignedUrlRepository {
  final ApiService _apiService;

  PresignedUrlRepository(this._apiService);

  Future<Map<String, dynamic>> getPresignedUrl({
    required String fileName,
    required String fileType,
    required String contentType,
    String? userId,
  }) async {
    try {
      final response = await _apiService.post(
        ApiConstants.GET_PRESIGNED_URL,
        data: {
          'fileName': fileName,
          'fileType': fileType,
          'contentType': contentType,
          if (userId != null) 'userId': userId,
        },
      );

      if (response.statusCode == 200 && response.data['status'] == 'success') {
        return response.data['data'];
      } else {
        throw Exception(
            'Failed to get presigned URL: ${response.data['message']}');
      }
    } catch (e) {
      throw Exception('Failed to get presigned URL: $e');
    }
  }

  Future<List<String>> getContentTypes() async {
    try {
      final response = await _apiService.get('/api/upload/contentTypes');

      if (response.statusCode == 200 && response.data['status'] == 'success') {
        final List<dynamic> contentTypes =
            response.data['data']['contentTypes'];
        return contentTypes.map((type) => type.toString()).toList();
      } else {
        throw Exception('Failed to get content types');
      }
    } catch (e) {
      throw Exception('Failed to get content types: $e');
    }
  }
}
