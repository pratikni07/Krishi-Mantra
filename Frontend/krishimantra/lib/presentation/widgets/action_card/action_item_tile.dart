import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/constants/colors.dart';
import '../../../data/models/action_item.dart';
import '../../../routes/app_routes.dart';
import '../../controllers/action_card_controller.dart';

class ActionItemTile extends StatelessWidget {
  final ActionItem item;
  const ActionItemTile({super.key, required this.item});

  Color _urgencyColor() {
    switch (item.urgency) {
      case 'urgent':
        return Colors.red;
      case 'high':
        return Colors.orange;
      case 'low':
        return AppColors.textMuted;
      default:
        return AppColors.green;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = Get.find<ActionCardController>();
    return Container(
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: _urgencyColor(), width: 4),
          bottom: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: AppColors.faintGreen,
                child: const Icon(Icons.grass, size: 16, color: AppColors.green),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${item.cropName}${item.cropVariety != null ? " (${item.cropVariety})" : ""}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              if (item.isUrgent)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _urgencyColor().withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    item.urgency,
                    style: TextStyle(fontSize: 11, color: _urgencyColor(), fontWeight: FontWeight.w600),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(item.title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          if ((item.detail ?? '').isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(item.detail!,
                style: const TextStyle(fontSize: 14, color: AppColors.textGrey)),
          ],
          if ((item.safetyNote ?? '').isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('⚠ ',
                    style: TextStyle(color: Colors.orange, fontSize: 13)),
                Expanded(
                  child: Text(item.safetyNote!,
                      style: const TextStyle(fontSize: 13, color: AppColors.textGrey)),
                ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          Obx(() {
            final busy = c.mutating.contains(item.itemId);
            return Row(
              children: [
                ElevatedButton.icon(
                  onPressed: busy ? null : () => c.markDone(item),
                  icon: const Icon(Icons.check, size: 16),
                  label: const Text('केले'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.green,
                    foregroundColor: AppColors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: busy ? null : () => _showSkipSheet(context, c),
                  icon: const Icon(Icons.skip_next, size: 16),
                  label: const Text('नंतर'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: busy ? null : () => _onTellMeMore(),
                  icon: const Icon(Icons.chat_bubble_outline, size: 20),
                  tooltip: 'अधिक',
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  void _showSkipSheet(BuildContext context, ActionCardController c) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Why are you skipping?',
                  style: TextStyle(fontWeight: FontWeight.w600)),
            ),
            ListTile(
              title: const Text('आधीच केले'),
              onTap: () { Navigator.pop(context); c.markSkipped(item, 'already_done'); },
            ),
            ListTile(
              title: const Text('गरज नाही'),
              onTap: () { Navigator.pop(context); c.markSkipped(item, 'not_needed'); },
            ),
            ListTile(
              title: const Text('नंतर करेन'),
              onTap: () { Navigator.pop(context); c.markSkipped(item, 'will_do_later'); },
            ),
            ListTile(
              title: const Text('आज शक्य नाही'),
              onTap: () { Navigator.pop(context); c.markSkipped(item, 'cant_do'); },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _onTellMeMore() {
    final autoMessage =
        'Tell me more about: "${item.title}". Crop: ${item.cropName}${item.cropVariety != null ? " (${item.cropVariety})" : ""}. '
        'Why this dose, and what to watch for?';
    Get.toNamed(AppRoutes.KRISHI_AI, arguments: {
      'autoSendMessage': autoMessage,
      'sourceItemId': item.itemId,
    });
  }
}
