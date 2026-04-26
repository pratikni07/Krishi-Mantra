import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/constants/colors.dart';
import '../../controllers/voice_recorder_controller.dart';

/// Full-screen modal shown while the user is holding the mic. Includes:
///   - Live waveform (30 bars updated from amplitude stream).
///   - Elapsed timer (turns red after 50s).
///   - "Slide up to cancel" hint (highlights when armed).
///
/// Closed by the VoiceInputButton when the gesture ends.
class VoiceRecordOverlay extends StatelessWidget {
  const VoiceRecordOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Get.find<VoiceRecorderController>();
    return Material(
      color: Colors.transparent,
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 24)],
          ),
          child: Obx(() {
            final cancelArmed = c.cancelArmed.value;
            final elapsed = c.elapsedMs.value;
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  cancelArmed ? Icons.delete_outline : Icons.mic,
                  color: cancelArmed ? Colors.red : AppColors.green,
                  size: 36,
                ),
                const SizedBox(height: 12),
                Text(
                  cancelArmed ? 'Release to cancel' : 'Recording…',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: cancelArmed ? Colors.red : AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _fmtDuration(elapsed),
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: elapsed >= 50000 ? Colors.red : AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 20),
                _Waveform(),
                const SizedBox(height: 20),
                Text(
                  cancelArmed
                      ? 'Release to cancel'
                      : 'Release to send · ↑ Slide to cancel',
                  style: const TextStyle(fontSize: 12, color: AppColors.textLight),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }

  String _fmtDuration(int ms) {
    final s = (ms / 1000).floor();
    final mm = (s ~/ 60).toString().padLeft(2, '0');
    final ss = (s % 60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }
}

class _Waveform extends StatelessWidget {
  const _Waveform();

  @override
  Widget build(BuildContext context) {
    final c = Get.find<VoiceRecorderController>();
    return SizedBox(
      height: 36,
      child: Obx(() {
        final amp = c.amplitude.value.clamp(0.0, 1.0);
        // 30 bars; deterministic visual based on bar index + amp so it
        // moves with the user's voice without per-frame state.
        final bars = List<double>.generate(30, (i) {
          final base = ((i * 31) % 11) / 30.0; // 0..0.33
          final dynamic_ = amp * (0.4 + ((i * 7) % 11) / 25.0);
          return (base + dynamic_).clamp(0.06, 1.0);
        });
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: bars
              .map((h) => Container(
                    margin: const EdgeInsets.symmetric(horizontal: 1.5),
                    width: 3,
                    height: 36 * h,
                    decoration: BoxDecoration(
                      color: AppColors.green,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ))
              .toList(),
        );
      }),
    );
  }
}
