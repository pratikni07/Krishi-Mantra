import 'package:dio/dio.dart';
import '../models/farm_profile.dart';
import '../services/api_service.dart';
import '../../core/constants/api_constants.dart';

class FarmProfileRepository {
  final ApiService _api;

  FarmProfileRepository(this._api);

  Future<FarmProfile?> getMyProfile() async {
    try {
      final res = await _api.get(ApiConstants.FARM_PROFILE_ME);
      final data = res.data as Map<String, dynamic>?;
      final payload = data?['profile'];
      if (payload == null) return null;
      return FarmProfile.fromJson(Map<String, dynamic>.from(payload));
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<FarmProfile> upsertProfile(FarmProfile profile) async {
    final res = await _api.put(
      ApiConstants.FARM_PROFILE_ME,
      data: profile.toServerPayload(),
    );
    final payload = (res.data as Map<String, dynamic>)['profile'];
    return FarmProfile.fromJson(Map<String, dynamic>.from(payload));
  }

  Future<FarmProfile> patchProfile(Map<String, dynamic> updates) async {
    final res = await _api.patch(ApiConstants.FARM_PROFILE_ME, data: updates);
    final payload = (res.data as Map<String, dynamic>)['profile'];
    return FarmProfile.fromJson(Map<String, dynamic>.from(payload));
  }

  Future<CropEntry> addCrop(CropEntry crop) async {
    final res = await _api.post(
      ApiConstants.FARM_PROFILE_CROPS,
      data: crop.toJson(),
    );
    final payload = (res.data as Map<String, dynamic>)['crop'];
    return CropEntry.fromJson(Map<String, dynamic>.from(payload));
  }

  Future<CropEntry> updateCrop(String cropEntryId, Map<String, dynamic> patches) async {
    final path = ApiConstants.FARM_PROFILE_CROP_BY_ID.replaceAll(':id', cropEntryId);
    final res = await _api.patch(path, data: patches);
    final payload = (res.data as Map<String, dynamic>)['crop'];
    return CropEntry.fromJson(Map<String, dynamic>.from(payload));
  }

  Future<void> removeCrop(String cropEntryId) async {
    final path = ApiConstants.FARM_PROFILE_CROP_BY_ID.replaceAll(':id', cropEntryId);
    await _api.delete(path);
  }

  Future<List<MasterCrop>> searchCrops({String query = '', int limit = 20}) async {
    final res = await _api.get(
      ApiConstants.FARM_PROFILE_CROP_SEARCH,
      queryParameters: {
        if (query.isNotEmpty) 'q': query,
        'limit': limit,
      },
      cacheDuration: const Duration(minutes: 10),
    );
    final data = (res.data as Map<String, dynamic>)['crops'] as List?;
    return (data ?? [])
        .map((c) => MasterCrop.fromJson(Map<String, dynamic>.from(c)))
        .toList();
  }
}
