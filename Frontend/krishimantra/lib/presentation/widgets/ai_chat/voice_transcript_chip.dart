import 'package:flutter/material.dart';

import '../../../core/constants/colors.dart';
import '../../../data/models/ai_chat_message.dart';

/// Visual annotations on a voice user-bubble:
///   - "Transcribing…" while STT is in flight.
///   - "Wrong? Tap to re-record" pill when confidence is low.
///   - Error badge on transcribingFailed.
class VoiceTranscriptChip extends StatelessWidget {
  final VoiceMeta voice;
  final VoidCallback? onReRecord;

  const VoiceTranscriptChip({
    super.key,
    required this.voice,
    this.onReRecord,
  });

  @override
  Widget build(BuildContext context) {
    if (voice.transcribing) {
      return _Pill(
        icon: const SizedBox(
          width: 12, height: 12,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        label: 'Transcribing…',
        color: AppColors.textLight,
      );
    }
    if (voice.transcribingFailed) {
      return _Pill(
        icon: const Icon(Icons.refresh, size: 14, color: Colors.orange),
        label: 'Couldn\'t catch that — tap to retry',
        color: Colors.orange,
        onTap: onReRecord,
      );
    }
    if (voice.hasLowConfidence) {
      return _Pill(
        icon: const Icon(Icons.help_outline, size: 14, color: Colors.orange),
        label: 'Wrong? Tap to re-record',
        color: Colors.orange,
        onTap: onReRecord,
      );
    }
    return const SizedBox.shrink();
  }
}

class _Pill extends StatelessWidget {
  final Widget icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;
  const _Pill({
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final pill = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          icon,
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 11, color: color)),
        ],
      ),
    );
    if (onTap == null) return pill;
    return InkWell(borderRadius: BorderRadius.circular(10), onTap: onTap, child: pill);
  }
}
