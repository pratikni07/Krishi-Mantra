import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../../data/models/action_item.dart';
import '../../data/repositories/action_card_repository.dart';

class ActionCardController extends GetxController {
  final ActionCardRepository _repo;
  ActionCardController(this._repo);

  final card = Rxn<ActionCard>();
  final isLoading = false.obs;
  final isRefreshing = false.obs;
  final isSubmittingInput = false.obs;
  final mutating = <String>{}.obs;
  final errorMessage = ''.obs;

  RxList<ActionItem> get pending {
    final c = card.value;
    if (c == null) return <ActionItem>[].obs;
    return c.items.where((i) => i.isPending).toList().obs;
  }

  RxList<ActionItem> get completed {
    final c = card.value;
    if (c == null) return <ActionItem>[].obs;
    return c.items.where((i) => !i.isPending).toList().obs;
  }

  Future<void> load({bool force = false}) async {
    if (force) isRefreshing.value = true;
    else isLoading.value = true;
    errorMessage.value = '';
    try {
      ActionCard? next;
      if (force) {
        next = await _repo.regenerate();
      }
      next ??= await _repo.today();
      if (next != null) card.value = next;
    } catch (e) {
      errorMessage.value = _readable(e);
    } finally {
      isLoading.value = false;
      isRefreshing.value = false;
    }
  }

  Future<void> markDone(ActionItem item, {String? notes}) =>
      _mutate(item, 'done', notes: notes);

  Future<void> markSkipped(ActionItem item, String reason) =>
      _mutate(item, 'skip', reason: reason);

  Future<void> markSnoozed(ActionItem item) =>
      _mutate(item, 'snooze');

  Future<void> _mutate(ActionItem item, String action, {String? reason, String? notes}) async {
    final cardId = card.value?.cardId;
    if (cardId == null) return;
    mutating.add(item.itemId);
    final original = item;
    final optimisticStatus = action == 'done' ? 'done'
        : action == 'skip' ? 'skipped' : 'snoozed';
    _patchItem(item.copyWith(status: optimisticStatus, statusUpdatedAt: DateTime.now()));
    try {
      final updated = await _repo.markStatus(cardId, item.itemId, action,
          reason: reason, notes: notes);
      _patchItem(updated);
    } catch (e) {
      _patchItem(original);
      Get.snackbar('Could not save', _readable(e),
          snackPosition: SnackPosition.BOTTOM);
    } finally {
      mutating.remove(item.itemId);
    }
  }

  void _patchItem(ActionItem updated) {
    final c = card.value;
    if (c == null) return;
    final idx = c.items.indexWhere((i) => i.itemId == updated.itemId);
    if (idx == -1) return;
    final items = [...c.items];
    items[idx] = updated;
    card.value = ActionCard(
      cardId: c.cardId,
      localDate: c.localDate,
      items: items,
      farmerInput: c.farmerInput,
      cached: c.cached,
      empty: c.empty,
      emptyReason: c.emptyReason,
    );
  }

  Future<bool> submitFarmerInput({String? text, List<String> imageUrls = const []}) async {
    final cardId = card.value?.cardId;
    if (cardId == null) {
      errorMessage.value = 'No card today — try refreshing.';
      return false;
    }
    if ((text == null || text.trim().isEmpty) && imageUrls.isEmpty) {
      errorMessage.value = 'Type a note or add a photo.';
      return false;
    }
    isSubmittingInput.value = true;
    try {
      final fi = await _repo.submitFarmerInput(cardId, text: text, imageUrls: imageUrls);
      final c = card.value;
      if (c != null) {
        card.value = ActionCard(
          cardId: c.cardId,
          localDate: c.localDate,
          items: c.items,
          farmerInput: fi,
          cached: c.cached,
          empty: c.empty,
          emptyReason: c.emptyReason,
        );
      }
      return true;
    } catch (e) {
      errorMessage.value = _readable(e);
      return false;
    } finally {
      isSubmittingInput.value = false;
    }
  }

  String _readable(Object e) {
    final s = e.toString();
    if (s.contains('SocketException')) return 'Network unavailable';
    return s.replaceFirst('Exception: ', '');
  }
}
