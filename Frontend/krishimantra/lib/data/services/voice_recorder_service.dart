import 'dart:async';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

/// Wraps the `record` package with the format we send to the backend
/// (AAC mono 16 kHz 16 kbps — ~32 KB / 20 s, fits flaky 4G).
///
/// Lifecycle:
///   await recorder.start()         → returns the on-disk output path
///   await recorder.stop()          → stops + returns the recorded File
///   recorder.amplitudeStream       → 10 Hz amplitude (0..1) for waveform UI
///   await recorder.requestPermission()
class VoiceRecorderService {
  final AudioRecorder _rec = AudioRecorder();
  StreamSubscription<Amplitude>? _ampSub;
  final _ampController = StreamController<double>.broadcast();
  String? _outputPath;

  Stream<double> get amplitudeStream => _ampController.stream;

  Future<bool> requestPermission() async {
    final status = await Permission.microphone.status;
    if (status.isGranted) return true;
    if (status.isPermanentlyDenied) return false;
    final granted = await Permission.microphone.request();
    return granted.isGranted;
  }

  bool get isRecording => _outputPath != null;

  Future<String?> start() async {
    if (_outputPath != null) return _outputPath;
    final granted = await _rec.hasPermission();
    if (!granted) return null;
    final dir = await getTemporaryDirectory();
    final ts = DateTime.now().millisecondsSinceEpoch;
    final path = '${dir.path}/voice_$ts.m4a';
    await _rec.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 16000,
        sampleRate: 16000,
        numChannels: 1,
        // No noise suppression; the STT-side adaptation handles ambient noise
        // better than the device-level cleanup which often strips Marathi
        // sibilants at 16 kHz.
      ),
      path: path,
    );
    _outputPath = path;
    _ampSub = _rec
        .onAmplitudeChanged(const Duration(milliseconds: 100))
        .listen((amp) {
      // dBFS amp (-160 to 0). Normalize to 0..1 for the UI.
      final db = amp.current.isFinite ? amp.current : -60.0;
      final norm = ((db + 60.0) / 60.0).clamp(0.0, 1.0);
      _ampController.add(norm);
    });
    return path;
  }

  Future<File?> stop() async {
    if (_outputPath == null) return null;
    final pathOnStop = await _rec.stop();
    await _ampSub?.cancel();
    _ampSub = null;
    _outputPath = null;
    if (pathOnStop == null) return null;
    final f = File(pathOnStop);
    if (!await f.exists()) return null;
    return f;
  }

  Future<void> cancel() async {
    if (_outputPath == null) return;
    await _ampSub?.cancel();
    _ampSub = null;
    try {
      await _rec.cancel();
    } catch (_) {}
    final p = _outputPath;
    _outputPath = null;
    if (p != null) {
      final f = File(p);
      if (await f.exists()) {
        try { await f.delete(); } catch (_) {}
      }
    }
  }

  Future<void> dispose() async {
    await _ampSub?.cancel();
    await _ampController.close();
    await _rec.dispose();
  }
}
