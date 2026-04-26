import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../data/services/voice_recorder_service.dart';

enum VoiceRecorderPhase { idle, awaitingPermission, recording, cancelling, uploading }

/// State machine + lifecycle for the hold-to-talk gesture. Owns the recorder
/// service, the elapsed timer, the amplitude stream, and the cancel-on-slide
/// gesture state.
///
/// The widget layer drives transitions:
///   - onLongPressStart  → startRecording()
///   - onLongPressMoveUpdate → updateGesture(yOffset)
///   - onLongPressEnd    → stopRecording(commit: true)
///   - onLongPressCancel → stopRecording(commit: false)
///
/// When `stopRecording(commit: true)` produces a file, the controller
/// notifies via `onCommitted(file)`. Caller (the AI chat controller)
/// uploads it via VoiceChatService.
class VoiceRecorderController extends GetxController {
  final VoiceRecorderService _rec;

  VoiceRecorderController({VoiceRecorderService? rec})
      : _rec = rec ?? VoiceRecorderService();

  final phase = VoiceRecorderPhase.idle.obs;
  final amplitude = 0.0.obs;
  final elapsedMs = 0.obs;
  final cancelArmed = false.obs;
  final isDisabled = false.obs;
  final lastError = ''.obs;

  Timer? _ticker;
  StreamSubscription<double>? _ampSub;
  Future<void> Function(File file)? _onCommitted;

  static const Duration _maxDuration = Duration(seconds: 60);
  static const int _minHoldMs = 600;        // ignore accidental short taps
  static const double _cancelThresholdY = -100; // upward slide

  bool get isRecording => phase.value == VoiceRecorderPhase.recording;

  /// Caller registers the upload callback once at composer mount time.
  void bindOnCommitted(Future<void> Function(File file) cb) {
    _onCommitted = cb;
  }

  Future<bool> _ensurePermission() async {
    phase.value = VoiceRecorderPhase.awaitingPermission;
    final granted = await _rec.requestPermission();
    if (!granted) {
      phase.value = VoiceRecorderPhase.idle;
      lastError.value = 'permission_denied';
      return false;
    }
    return true;
  }

  Future<void> startRecording() async {
    if (isDisabled.value) return;
    if (phase.value != VoiceRecorderPhase.idle) return;
    final permitted = await _ensurePermission();
    if (!permitted) return;

    final outPath = await _rec.start();
    if (outPath == null) {
      phase.value = VoiceRecorderPhase.idle;
      lastError.value = 'recorder_start_failed';
      return;
    }
    phase.value = VoiceRecorderPhase.recording;
    elapsedMs.value = 0;
    amplitude.value = 0;
    cancelArmed.value = false;
    HapticFeedback.mediumImpact();

    _ticker = Timer.periodic(const Duration(milliseconds: 100), (_) {
      elapsedMs.value += 100;
      if (elapsedMs.value >= _maxDuration.inMilliseconds) {
        // Auto-stop on the 60s ceiling.
        stopRecording(commit: true);
      }
    });
    _ampSub = _rec.amplitudeStream.listen((v) {
      amplitude.value = v;
    });
  }

  /// Slide-up to cancel: caller passes the gesture's vertical offset from
  /// origin. UI shows a "Slide up to cancel" hint; once below -100 the
  /// release commits as cancel.
  void updateGesture(double dy) {
    if (phase.value != VoiceRecorderPhase.recording) return;
    cancelArmed.value = dy < _cancelThresholdY;
  }

  Future<void> stopRecording({required bool commit}) async {
    if (phase.value != VoiceRecorderPhase.recording) return;
    final shouldCancel = !commit || cancelArmed.value || elapsedMs.value < _minHoldMs;
    _ticker?.cancel();
    _ticker = null;
    await _ampSub?.cancel();
    _ampSub = null;

    if (shouldCancel) {
      phase.value = VoiceRecorderPhase.cancelling;
      await _rec.cancel();
      phase.value = VoiceRecorderPhase.idle;
      cancelArmed.value = false;
      return;
    }

    final file = await _rec.stop();
    if (file == null) {
      phase.value = VoiceRecorderPhase.idle;
      lastError.value = 'recorder_no_file';
      return;
    }
    HapticFeedback.heavyImpact();
    phase.value = VoiceRecorderPhase.uploading;
    try {
      if (_onCommitted != null) {
        await _onCommitted!(file);
      }
    } catch (e) {
      lastError.value = e.toString();
    } finally {
      phase.value = VoiceRecorderPhase.idle;
    }
  }

  @override
  void onClose() {
    _ticker?.cancel();
    _ampSub?.cancel();
    _rec.dispose();
    super.onClose();
  }
}
