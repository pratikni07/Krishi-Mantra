import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/constants/colors.dart';
import '../../../data/services/UserService.dart';
import '../../../data/services/voice_chat_service.dart';
import '../../../data/services/voice_player_service.dart';

/// Per-bubble replay icon. Fetches the cached TTS audio from the backend's
/// `/api/voice/replay/:messageId` endpoint and plays it via VoicePlayerService.
///
/// If the cache expired (24h) the server returns 404 → snackbar "audio expired".
class VoiceReplayButton extends StatefulWidget {
  final String messageId;
  final String voiceName;

  const VoiceReplayButton({
    super.key,
    required this.messageId,
    this.voiceName = 'default',
  });

  @override
  State<VoiceReplayButton> createState() => _VoiceReplayButtonState();
}

class _VoiceReplayButtonState extends State<VoiceReplayButton> {
  bool _busy = false;

  Future<void> _onTap() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final user = Get.find<UserService>();
      final svc = VoiceChatService(user);
      final result = await svc.fetchReplay(widget.messageId, voice: widget.voiceName);
      svc.close();
      if (result == null) {
        Get.snackbar(
          'Audio expired',
          'Recording cached for 24 hours only',
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      }
      final player = Get.isRegistered<VoicePlayerService>()
          ? Get.find<VoicePlayerService>()
          : Get.put<VoicePlayerService>(VoicePlayerService(), permanent: true);
      await player.playCachedReplay(
        Uint8List.fromList(result.bytes),
        result.mime,
      );
    } catch (e) {
      Get.snackbar(
        'Could not play',
        e.toString(),
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: _onTap,
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: _busy
            ? const SizedBox(
                width: 16, height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.play_circle_fill,
                size: 22, color: AppColors.green),
      ),
    );
  }
}
