import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';

/// Streams concatenated audio chunks to `just_audio` for gapless playback.
///
/// The voice-turn SSE pipe yields `audio` events containing base64 audio
/// segments per assistant sentence. We buffer the first ~8 KB before
/// starting playback (avoids stutter on cold open / slow uplink), then keep
/// appending segments to the same `ConcatenatingAudioSource` so transitions
/// are seamless.
///
///  - startNewQueue() — call before each new turn.
///  - enqueueBase64(...) — push the next chunk.
///  - playCachedReplay(bytes, mime) — one-shot playback for /replay endpoint.
///  - stop() — release resources, halt audio.
///
/// Uses `audio_session` to pin output to the speaker even if a Bluetooth
/// device is connected (Bluetooth car-speakers have caused playback weirdness
/// in field testing).
class VoicePlayerService {
  AudioPlayer? _player;
  ConcatenatingAudioSource? _queue;
  final BytesBuilder _preBuffer = BytesBuilder();
  String? _currentMime;
  bool _started = false;
  AudioSession? _session;

  static const int _PREBUFFER_BYTES = 8 * 1024;

  Future<void> _ensureSession() async {
    _session ??= await AudioSession.instance;
    try {
      await _session!.configure(const AudioSessionConfiguration.speech());
    } catch (_) {}
  }

  Future<void> startNewQueue() async {
    await stop();
    await _ensureSession();
    _player = AudioPlayer();
    _preBuffer.clear();
    _currentMime = null;
    _started = false;
  }

  /// Called for every `audio` SSE frame. `seq` is included by the backend
  /// but we don't need it for ordering — server emits chunks in order on
  /// the same SSE stream.
  Future<void> enqueueBase64({
    required String b64,
    required String mime,
    int seq = 0,
  }) async {
    if (_player == null) await startNewQueue();
    final bytes = base64Decode(b64);
    if (bytes.isEmpty) return;
    _currentMime = mime;
    if (!_started) {
      _preBuffer.add(bytes);
      if (_preBuffer.length >= _PREBUFFER_BYTES) {
        await _startPlayback(_preBuffer.toBytes(), mime);
        _started = true;
      }
      return;
    }
    await _appendChunk(bytes, mime);
  }

  Future<void> _startPlayback(Uint8List bytes, String mime) async {
    if (_player == null) return;
    _queue = ConcatenatingAudioSource(
      children: [_BytesAudioSource(Uint8List.fromList(bytes), mime)],
    );
    await _player!.setAudioSource(_queue!, preload: true);
    unawaited(_player!.play());
  }

  Future<void> _appendChunk(Uint8List bytes, String mime) async {
    if (_queue == null) return;
    await _queue!.add(_BytesAudioSource(bytes, mime));
  }

  /// Flush any pre-buffer that didn't reach the start threshold. Called
  /// by the chat service when the SSE stream ends — even small responses
  /// must play.
  Future<void> flush() async {
    if (_started || _player == null) return;
    if (_preBuffer.isEmpty) return;
    final mime = _currentMime ?? 'audio/mp3';
    await _startPlayback(_preBuffer.toBytes(), mime);
    _started = true;
  }

  /// One-shot playback for the /replay endpoint. Bytes are the full audio
  /// blob the server cached.
  Future<void> playCachedReplay(Uint8List bytes, String mime) async {
    await startNewQueue();
    await _startPlayback(bytes, mime);
    _started = true;
  }

  Future<void> stop() async {
    try {
      await _player?.stop();
    } catch (_) {}
    try {
      await _player?.dispose();
    } catch (_) {}
    _player = null;
    _queue = null;
    _started = false;
    _preBuffer.clear();
  }
}

/// Bytes-backed audio source — feeds an in-memory chunk to `just_audio`.
/// Required for `ConcatenatingAudioSource` since it streams sequentially.
class _BytesAudioSource extends StreamAudioSource {
  final Uint8List _bytes;
  final String _mime;
  _BytesAudioSource(this._bytes, this._mime);

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    final s = start ?? 0;
    final e = end ?? _bytes.length;
    return StreamAudioResponse(
      sourceLength: _bytes.length,
      contentLength: e - s,
      offset: s,
      stream: Stream.value(_bytes.sublist(s, e)),
      contentType: _mime,
    );
  }
}
