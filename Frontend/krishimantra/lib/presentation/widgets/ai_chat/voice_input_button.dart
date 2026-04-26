import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/constants/colors.dart';
import '../../../data/services/feature_flag_service.dart';
import '../../controllers/voice_recorder_controller.dart';
import 'voice_record_overlay.dart';

/// Hold-to-talk mic button. Sits to the LEFT of the existing send button
/// in the AI chat composer. Long-press starts recording and shows the
/// fullscreen overlay; release commits.
class VoiceInputButton extends StatelessWidget {
  const VoiceInputButton({super.key});

  bool get _featureEnabled {
    if (!Get.isRegistered<FeatureFlagService>()) return true;
    final ff = Get.find<FeatureFlagService>();
    // Default true — backend killswitch handles emergency shutoff.
    final flags = ff.flags;
    final v = flags['VOICE_CHAT_ENABLED'];
    return v == null || v == true;
  }

  @override
  Widget build(BuildContext context) {
    if (!_featureEnabled) return const SizedBox.shrink();
    final c = Get.isRegistered<VoiceRecorderController>()
        ? Get.find<VoiceRecorderController>()
        : Get.put<VoiceRecorderController>(VoiceRecorderController());
    return Obx(() {
      if (c.isDisabled.value) return const _DisabledMicIcon();
      final recording = c.phase.value == VoiceRecorderPhase.recording;
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onLongPressStart: (_) {
          c.startRecording();
          // Push the recording overlay AFTER state has flipped to "recording"
          // so the overlay's `Obx` paints the correct UI on first build.
          Future.microtask(() {
            if (Get.context != null && Get.find<VoiceRecorderController>().isRecording) {
              Get.dialog(
                const VoiceRecordOverlay(),
                barrierDismissible: false,
                barrierColor: Colors.black54,
              );
            }
          });
        },
        onLongPressMoveUpdate: (d) =>
            c.updateGesture(d.localOffsetFromOrigin.dy),
        onLongPressEnd: (_) async {
          await c.stopRecording(commit: true);
          if (Get.isDialogOpen ?? false) Get.back();
        },
        onLongPressCancel: () async {
          await c.stopRecording(commit: false);
          if (Get.isDialogOpen ?? false) Get.back();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 48, height: 48,
          decoration: BoxDecoration(
            color: recording ? Colors.red : AppColors.green,
            shape: BoxShape.circle,
          ),
          child: Icon(
            recording ? Icons.stop : Icons.mic,
            color: Colors.white,
            size: 22,
          ),
        ),
      );
    });
  }
}

class _DisabledMicIcon extends StatelessWidget {
  const _DisabledMicIcon();
  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Voice unavailable',
      child: Container(
        width: 48, height: 48,
        decoration: BoxDecoration(
          color: AppColors.textMuted.withOpacity(0.4),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.mic_off, color: Colors.white, size: 20),
      ),
    );
  }
}
