import 'package:dio/dio.dart' as dio;

import '../../core/constants/api_constants.dart';
import '../models/action_item.dart';
import '../services/api_service.dart';

class ActionCardRepository {
  final ApiService _api;
  ActionCardRepository(this._api);

  Future<ActionCard?> today() async {
    try {
      final res = await _api.get(
        ApiConstants.ACTION_CARD_TODAY,
        cacheDuration: const Duration(minutes: 10),
      );
      if (res.statusCode != 200 || res.data is! Map) return null;
      final data = Map<String, dynamic>.from(res.data as Map);
      if (data['success'] != true) return null;
      return ActionCard.fromJson(data);
    } catch (e) {
      return null;
    }
  }

  Future<ActionItem> markStatus(
    String cardId,
    String itemId,
    String action, {
    String? reason,
    String? notes,
  }) async {
    final pathTpl = action == 'done'
        ? ApiConstants.ACTION_CARD_ITEM_DONE
        : action == 'skip'
            ? ApiConstants.ACTION_CARD_ITEM_SKIP
            : ApiConstants.ACTION_CARD_ITEM_SNOOZE;
    final path = pathTpl.replaceAll(':cardId', cardId).replaceAll(':itemId', itemId);
    final body = <String, dynamic>{};
    if (reason != null) body['reason'] = reason;
    if (notes != null) body['notes'] = notes;
    final res = await _api.post(path, data: body);
    final payload = (res.data as Map<String, dynamic>)['item'];
    return ActionItem.fromJson(Map<String, dynamic>.from(payload));
  }

  Future<FarmerInput> submitFarmerInput(
    String cardId, {
    String? text,
    List<String> imageUrls = const [],
  }) async {
    final path = ApiConstants.ACTION_CARD_FARMER_INPUT.replaceAll(':cardId', cardId);
    final res = await _api.post(
      path,
      data: {
        if (text != null && text.trim().isNotEmpty) 'text': text.trim(),
        if (imageUrls.isNotEmpty) 'imageUrls': imageUrls,
      },
    );
    final payload = (res.data as Map<String, dynamic>)['farmerInput'];
    return FarmerInput.fromJson(Map<String, dynamic>.from(payload));
  }

  Future<ActionCard?> regenerate() async {
    try {
      final res = await _api.post(ApiConstants.ACTION_CARD_REGENERATE);
      if (res.statusCode != 200 || res.data is! Map) return null;
      return ActionCard.fromJson(Map<String, dynamic>.from(res.data as Map));
    } on dio.DioException catch (e) {
      if (e.response?.statusCode == 429) return null;
      rethrow;
    }
  }
}
