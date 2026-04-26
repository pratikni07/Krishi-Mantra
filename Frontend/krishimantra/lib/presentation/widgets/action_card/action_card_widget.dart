import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/constants/colors.dart';
import '../../../data/models/action_item.dart';
import '../../controllers/action_card_controller.dart';
import 'action_item_tile.dart';
import 'farmer_input_row.dart';

/// Top-of-home action card. Renders today's recommended actions, the
/// completed strip, and the farmer-input row that feeds tomorrow's AI.
///
/// Mounts ActionCardController via Get.find — caller is responsible for
/// registering the binding (see DI).
class ActionCardWidget extends StatelessWidget {
  const ActionCardWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Get.find<ActionCardController>();
    return Obx(() {
      if (c.isLoading.value && c.card.value == null) {
        return const _SkeletonCard();
      }
      final card = c.card.value;
      if (card == null) {
        return _ErrorCard(message: c.errorMessage.value, onRetry: () => c.load());
      }
      if (card.empty || card.items.isEmpty) {
        return _EmptyCard(reason: card.emptyReason);
      }
      final pending = card.items.where((i) => i.isPending).toList();
      final done = card.items.where((i) => !i.isPending).toList();
      return Card(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        elevation: 2,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Header(card: card, isRefreshing: c.isRefreshing.value, onRefresh: () => c.load(force: true)),
            if (pending.isNotEmpty)
              ...pending.map((it) => ActionItemTile(item: it))
            else
              const _AllDoneStrip(),
            if (done.isNotEmpty) _CompletedStrip(items: done),
            const Divider(height: 1),
            const FarmerInputRow(),
          ],
        ),
      );
    });
  }
}

class _Header extends StatelessWidget {
  final ActionCard card;
  final bool isRefreshing;
  final VoidCallback onRefresh;
  const _Header({required this.card, required this.isRefreshing, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
      child: Row(
        children: [
          const Icon(Icons.eco, color: AppColors.green, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'आजची कामे — ${_formatDate(card.localDate)}',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
          ),
          isRefreshing
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: onRefresh,
                  tooltip: 'पुन्हा लोड करा',
                ),
        ],
      ),
    );
  }

  String _formatDate(String iso) {
    if (iso.length < 10) return iso;
    return '${iso.substring(8, 10)}/${iso.substring(5, 7)}';
  }
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();
  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Container(
        height: 180,
        padding: const EdgeInsets.all(16),
        child: const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  final String? reason;
  const _EmptyCard({this.reason});
  @override
  Widget build(BuildContext context) {
    final r = reason ?? '';
    String message;
    if (r == 'no_profile' || r == 'onboarding_incomplete') {
      message = 'Tell us about your farm to see today\'s actions.';
    } else if (r == 'no_active_crops') {
      message = 'Add a crop to get personalised actions.';
    } else {
      message = 'No actions today — check back tomorrow.';
    }
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.info_outline, color: AppColors.textLight),
            const SizedBox(width: 12),
            Expanded(child: Text(message, style: const TextStyle(color: AppColors.textLight))),
          ],
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorCard({required this.message, required this.onRetry});
  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: ListTile(
        leading: const Icon(Icons.error_outline, color: Colors.orange),
        title: Text(
          message.isEmpty ? 'Couldn\'t load today\'s actions.' : message,
        ),
        trailing: TextButton(onPressed: onRetry, child: const Text('Retry')),
      ),
    );
  }
}

class _AllDoneStrip extends StatelessWidget {
  const _AllDoneStrip();
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: const [
          Icon(Icons.check_circle, color: AppColors.green),
          SizedBox(width: 8),
          Text('आजची सर्व कामे झाली. छान!',
              style: TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _CompletedStrip extends StatelessWidget {
  final List<ActionItem> items;
  const _CompletedStrip({required this.items});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Row(
        children: [
          const Icon(Icons.check_circle, size: 14, color: AppColors.green),
          const SizedBox(width: 6),
          Text(
            '${items.length} task${items.length > 1 ? 's' : ''} completed today',
            style: const TextStyle(fontSize: 12, color: AppColors.textLight),
          ),
        ],
      ),
    );
  }
}
