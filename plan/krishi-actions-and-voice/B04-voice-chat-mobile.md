# B04 — Voice Chat: Mobile Implementation

The mobile slice is where the user-perceived quality of voice lives or dies. The button has to feel like WhatsApp's voice-note button — that's the bar.

## 1. Module layout (Flutter)

```
Frontend/krishimantra/lib/
├── data/
│   └── services/
│       ├── voice_recorder_service.dart    NEW — wraps record + amplitude polling
│       ├── voice_player_service.dart      NEW — wraps just_audio for streamed chunks
│       └── voice_chat_service.dart        NEW — uploads audio, consumes SSE
├── presentation/
│   ├── controllers/
│   │   ├── ai_chat_controller.dart        EXTENDED — voice send path
│   │   └── voice_recorder_controller.dart NEW — record state machine
│   └── widgets/
│       └── ai_chat/
│           ├── voice_input_button.dart    NEW — hold-to-talk button
│           ├── voice_record_overlay.dart  NEW — full-screen recording UI
│           ├── voice_transcript_chip.dart NEW — "Wrong? Re-record" pill
│           └── voice_replay_button.dart   NEW — replay icon on each bubble
└── core/
    └── constants/
        └── api_constants.dart             EXTENDED — voice endpoints
```

## 2. Dependencies (pubspec.yaml)

Add:
```yaml
record: ^5.1.0           # audio recording
just_audio: ^0.9.36      # gapless audio playback w/ buffer
permission_handler: ^11.0.1   # mic permission
audio_session: ^0.1.18   # iOS audio category, ducking
```

`record` writes AAC mono 16k 16kbps natively on Android + iOS. `just_audio` plays in-memory bytes via a `BytesAudioSource` (we'll wrap chunked playback below).

## 3. The hold-to-talk button (`voice_input_button.dart`)

Sits on the AI chat composer between the text field and the send button.

```
[ अपना सवाल पूछें... ] [ 🎤 ] [ ➤ ]
                       ^^^
                       hold to talk
```

States:
- **idle** — green mic icon. Hint label below: *"दबाकर बोलें"* (Hold to speak).
- **awaiting permission** — first time, shows permission dialog → resumes record on grant.
- **recording** — full-screen overlay; button is hidden.
- **uploading** — small spinner overlay on the chat composer.
- **disabled** — ghost icon if voice killswitch is on or quota exhausted.

```dart
class VoiceInputButton extends StatelessWidget {
  const VoiceInputButton({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Get.find<VoiceRecorderController>();
    return Obx(() {
      if (c.isDisabled.value) return const _DisabledMicIcon();
      return GestureDetector(
        onLongPressStart: (_) => c.startRecording(),
        onLongPressEnd: (_) => c.stopRecording(commit: true),
        onLongPressCancel: () => c.stopRecording(commit: false),
        onTap: () {
          // Single tap = a tiny vibration + tooltip — common UX hint.
          HapticFeedback.lightImpact();
          c.showHoldHint();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 56, height: 56,
          decoration: BoxDecoration(
            color: c.isRecording.value ? AppColors.red : AppColors.green,
            shape: BoxShape.circle,
          ),
          child: Icon(
            c.isRecording.value ? Icons.stop : Icons.mic,
            color: Colors.white,
          ),
        ),
      );
    });
  }
}
```

## 4. Recording overlay (`voice_record_overlay.dart`)

Full-screen modal during recording — locks orientation, shows live waveform, elapsed time, "release to send" / "slide up to cancel" hints.

```
┌──────────────────────────────────┐
│   🎤 Recording... 0:08 / 0:60   │
│                                 │
│   ┃▁▂▃▅▆▇█▇▆▅▃▂▁┃              │
│                                 │
│   Release to send               │
│   ↑ Slide up to cancel          │
└──────────────────────────────────┘
```

- The waveform is a simple amplitude bar — 30 vertical bars updated every 100 ms from `record.onAmplitudeChanged`.
- "Slide up to cancel" cancels the upload (mirrors WhatsApp's behavior). The gesture is `LongPressMoveUpdateDetails.localOffsetFromOrigin.dy < -100`.
- At 50 s the elapsed time turns red; at 60 s the recorder auto-stops and uploads what's there.

## 5. `VoiceRecorderController`

```dart
class VoiceRecorderController extends GetxController {
  final VoiceRecorderService _rec = VoiceRecorderService();
  final VoiceChatService _chat = Get.find<VoiceChatService>();

  final isRecording = false.obs;
  final amplitude = 0.0.obs;
  final elapsedMs = 0.obs;
  final isDisabled = false.obs;
  Timer? _ticker;
  StreamSubscription<double>? _ampSub;
  String? _outputPath;

  Future<void> startRecording() async {
    if (isDisabled.value) return;
    final granted = await _rec.requestPermission();
    if (!granted) {
      Get.snackbar('Permission needed', 'Allow microphone to use voice chat',
          snackPosition: SnackPosition.BOTTOM);
      return;
    }
    HapticFeedback.mediumImpact();
    Get.dialog(const VoiceRecordOverlay(), barrierDismissible: false);
    _outputPath = await _rec.start();
    isRecording.value = true;
    elapsedMs.value = 0;
    _ticker = Timer.periodic(const Duration(milliseconds: 100), (_) {
      elapsedMs.value += 100;
      if (elapsedMs.value >= 60000) stopRecording(commit: true);
    });
    _ampSub = _rec.amplitudeStream.listen((v) => amplitude.value = v);
  }

  Future<void> stopRecording({required bool commit}) async {
    if (!isRecording.value) return;
    _ticker?.cancel();
    await _ampSub?.cancel();
    final file = await _rec.stop();
    isRecording.value = false;
    if (Get.isDialogOpen ?? false) Get.back();
    if (!commit || file == null || elapsedMs.value < 600) return; // 0.6s minimum
    HapticFeedback.heavyImpact();
    await _chat.send(file);
  }
}
```

## 6. `VoiceChatService` — upload + SSE consume

```dart
class VoiceChatService {
  final ApiService _api;
  final UserService _user;
  final AIChatController _chat = Get.find<AIChatController>();

  Future<void> send(File audio) async {
    final token = await _user.getToken();
    final userId = await _user.getUserId();
    final chatId = _chat.currentChat.value?.id;
    final lang = await _chat.preferredLanguage();

    // Open SSE-streaming POST with multipart body
    final stream = _streamPost(
      url: '${ApiConstants.BASE_URL}/api/voice/chat',
      headers: { 'Authorization': 'Bearer $token', 'Accept': 'text/event-stream' },
      file: audio,
      fields: { 'chatId': chatId ?? '', 'preferredLanguage': lang },
    );

    // Pre-create the placeholder bubbles (transcript-pending + assistant-pending)
    final userBubbleIdx = _chat.appendUserPlaceholder(transcript: '...');
    final assistantBubbleIdx = _chat.appendAssistantPlaceholder();
    final player = Get.find<VoicePlayerService>();
    player.startNewQueue();

    await for (final ev in stream) {
      switch (ev.type) {
        case 'transcript':
          _chat.updateUserBubble(userBubbleIdx, transcript: ev.text!, language: ev.lang);
          break;
        case 'delta':
          _chat.appendAssistantText(assistantBubbleIdx, ev.text!);
          break;
        case 'audio':
          await player.enqueueBase64(ev.data!, ev.mime ?? 'audio/mp3', seq: ev.seq ?? 0);
          break;
        case 'done':
          _chat.finalizeAssistantBubble(assistantBubbleIdx, payload: ev.payload);
          break;
        case 'error':
          _chat.markAssistantError(assistantBubbleIdx, ev.payload);
          await player.stop();
          break;
      }
    }
  }
}
```

`_streamPost` is a small utility that posts a multipart body and reads the SSE response line-by-line — same parsing as `ai_stream_service.dart` (we re-use the existing `_parseSseFrame` helper after extracting it to `lib/data/services/_sse.dart`).

## 7. `VoicePlayerService` — gapless chunk playback

The naive approach (play each chunk in sequence with `just_audio.setUrl`) introduces audible gaps. We use a **streaming buffer**:

```dart
import 'dart:typed_data';
import 'package:just_audio/just_audio.dart';

class VoicePlayerService {
  AudioPlayer? _player;
  final _buffer = BytesBuilder();
  String? _mime;
  bool _started = false;

  void startNewQueue() {
    _player?.stop();
    _player = AudioPlayer();
    _buffer.clear();
    _started = false;
  }

  Future<void> enqueueBase64(String b64, String mime, { required int seq }) async {
    final bytes = base64Decode(b64);
    _mime = mime;
    _buffer.add(bytes);
    if (!_started && _buffer.length > 8 * 1024) {
      // Start playback once we have ~8 KB pre-buffered
      _started = true;
      await _player!.setAudioSource(
        ConcatenatingAudioSource(children: [
          BytesAudioSource(_buffer.toBytes(), mime),
        ]),
      );
      _player!.play();
    } else if (_started) {
      // Append a new bytes source; gapless because ConcatenatingAudioSource handles transitions
      await (_player!.audioSource as ConcatenatingAudioSource).add(
        BytesAudioSource(bytes, mime),
      );
    }
  }

  Future<void> stop() async {
    await _player?.stop();
    _player = null;
  }
}

class BytesAudioSource extends StreamAudioSource {
  final Uint8List _bytes;
  final String _mime;
  BytesAudioSource(this._bytes, this._mime);

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
```

The first ~8 KB pre-buffer prevents stutter on slow networks. Each `audio` SSE event arrives ~250 ms after the prior, well within the buffer's tolerance.

## 8. AI chat controller — voice integration

`ai_chat_controller.dart` gains three helpers used by `VoiceChatService`:

```dart
int appendUserPlaceholder({ required String transcript }) {
  messages.add(AIChatMessage(
    role: 'user',
    content: transcript,
    timestamp: DateTime.now(),
    voice: VoiceMeta(transcribing: true),
  ));
  return messages.length - 1;
}

void updateUserBubble(int idx, { required String transcript, String? language }) {
  if (idx < 0 || idx >= messages.length) return;
  messages[idx] = messages[idx].copyWith(
    content: transcript,
    voice: messages[idx].voice?.copyWith(transcribing: false, language: language),
  );
}

int appendAssistantPlaceholder() {...}
void appendAssistantText(int idx, String chunk) {...}
void finalizeAssistantBubble(int idx, { Map<String, dynamic>? payload }) {...}
```

Same optimistic-mutation pattern as the existing streaming AI chat — Rx list emits, only the affected bubble rebuilds.

## 9. Bubble UI changes

The chat bubble already accepts `AIChatMessage`. We extend the model:

```dart
class AIChatMessage {
  // existing fields...
  final VoiceMeta? voice;
}

class VoiceMeta {
  final bool transcribing;       // user side
  final String? language;        // user side, "mr"
  final double? confidence;      // user side
  final String? messageId;       // assistant side, used for /replay
  final String? voiceName;       // assistant side
  final double? totalAudioSec;   // assistant side
  final bool transcribingFailed;
}
```

Visual additions:
- User bubble with `voice` + `confidence < 0.6` shows a subtle red warning chip: *"Wrong? Tap to re-record"*. Tapping replays the original audio (kept locally for 1 min) so the user can confirm what they actually said.
- Assistant bubble with `voice.messageId` shows a `▶ Replay` button on the bottom-right. Tap → `VoicePlayerService.playCached(messageId)` which hits `GET /api/voice/replay/:messageId`.

## 10. Localization for voice UI strings

| Key | en | hi | mr |
|-----|----|----|----|
| `voice.hold_to_speak` | Hold to speak | दबाकर बोलें | दाबून बोला |
| `voice.recording` | Recording... | रिकॉर्डिंग... | रेकॉर्डिंग... |
| `voice.release_to_send` | Release to send | छोड़ने पर भेजें | सोडल्यावर पाठवू |
| `voice.slide_to_cancel` | Slide up to cancel | रद्द करने के लिए स्वाइप करें | रद्द करण्यासाठी स्वाइप करा |
| `voice.permission_needed` | Allow microphone to use voice chat | वॉइस चैट के लिए माइक की अनुमति दें | व्हॉइस चॅटसाठी माइक परवानगी द्या |
| `voice.too_short` | Hold longer to record | अधिक देर तक दबाकर रखें | जास्त वेळ दाबून ठेवा |
| `voice.couldnt_catch` | Couldn't catch that — try again | समझ नहीं आया, फिर बोलें | समजलं नाही, पुन्हा बोला |
| `voice.replay` | Replay | फिर सुनें | पुन्हा ऐका |
| `voice.transcribing` | Transcribing... | लिख रहे हैं... | लिहितोय... |
| `voice.disabled` | Voice unavailable right now | वॉइस अभी उपलब्ध नहीं | व्हॉइस आत्ता उपलब्ध नाही |

Same translation pipeline as the action card (A06).

## 11. Permissions

- **Mic**: requested via `permission_handler.Permission.microphone`. We do NOT request on app start — only on first long-press. Less friction.
- **Notifications** (for action card morning push): handled separately, opt-in.
- **Audio playback**: no permission needed, but we configure `audio_session` to play through the speaker even if Bluetooth is connected (farmer might have a wired earphone hanging off — we don't want the audio routing to a car speaker).

## 12. Offline + flaky network handling

| Network state | Voice button |
|---------------|--------------|
| Offline (no network) | Disabled mic + tooltip *"Voice needs internet"*. |
| Slow upload | Show the upload spinner; if upload > 8 s, show "Bad connection — keep waiting?" with cancel. |
| SSE connection drops mid-stream | Treat like the existing AI streaming auto-fallback — the partial transcript stays; user can re-tap to ask again. |
| TTS audio chunk arrives but player can't decode | Skip that chunk; show text only for that segment. |

## 13. Battery + performance

- The amplitude poll is 10 Hz (100 ms). On a Snapdragon 460 this is ~1% CPU during a recording.
- Recorder hardware path is used (AAC HW encoder), no software re-encode.
- `just_audio` plays in a background isolate; the UI thread stays free.
- The base64-decode of audio chunks happens on a Dart isolate via `compute()` for chunks ≥ 32 KB to keep the UI responsive.

## 14. Replay + history

Every assistant bubble that came through voice has a `voice.messageId`. Replay button:

```dart
Future<void> playReplay(String messageId, String voiceName) async {
  final player = Get.find<VoicePlayerService>();
  player.startNewQueue();
  final res = await _api.get(
    '/api/voice/replay/$messageId',
    queryParameters: { 'voice': voiceName },
    options: dio.Options(responseType: dio.ResponseType.bytes),
  );
  if (res.statusCode == 200 && res.data is Uint8List) {
    await player.enqueueBase64(base64Encode(res.data), 'audio/mp3', seq: 0);
  } else if (res.statusCode == 404) {
    Get.snackbar('Audio expired',
      'Recording cached for 24 hours only.',
      snackPosition: SnackPosition.BOTTOM);
  }
}
```

For users who opted into 30-day retention, the cache is deeper and old replays still work.

## 15. Settings screen additions

`/settings` (existing) gets a "Voice" section:

- Toggle: **Voice replies**: on/off (off = ignore audio chunks; just stream text). Default on.
- Voice gender (per language): Female (default), Male — only languages where Google TTS has both. Saved on the server in `FarmProfile.notifyPrefs.voicePrefs`.
- Toggle: **Keep my voice notes for 30 days** — off by default. Off → server purges audio after 24 h.
- Button: **Delete all voice notes** — confirms, hits a server endpoint that purges the bucket prefix.

## 16. Telemetry the mobile side emits

Reuse `engagement_service`:

```
voice.hold.start              { duration_target_ms_default: 1000 }
voice.hold.short_release      { ms }
voice.upload.start            { bytes, sec }
voice.upload.done             { upload_ms, total_bytes }
voice.upload.failed           { error_code }
voice.transcript.received     { confidence, lang, ms_since_release }
voice.audio.first_play        { ms_since_release }
voice.replay.tap              { messageId, ms_since_message }
voice.session.complete        { total_ms, audio_played_sec }
voice.session.cancel          { reason }
```

## 17. Accessibility

- Hold-to-talk also has an alternate **tap-to-talk** mode in the settings (one tap to start, one tap to stop) — for users with hand tremor or disability who can't sustain a long-press.
- Recording overlay reads "Recording in progress" via TalkBack/VoiceOver.
- Replay button has semantic label "Replay assistant message".

## 18. Testing

- **Widget**: `VoiceInputButton` states (idle, recording, disabled).
- **Controller**: state machine — start → tick → stop(commit=false) cancels cleanly.
- **Mock SSE**: a fake stream serving `transcript`, `delta`, `audio`, `done` in order — assert player + chat controller were updated correctly.
- **Real-device matrix**: Android 8 (low-end), Android 13 (mid), iOS 16 (mid), iOS 17 (latest).
- **Network chaos**: 2G simulator → upload should take < 10 s; voice still works.

## 19. Routes

No new screens. The voice input lives inside the existing `ai_chat_screen.dart`. Settings additions happen on `settings_screen.dart`.

## 20. Dependency injection (additions)

```dart
Get.lazyPut(() => VoiceChatService(Get.find<ApiService>(), Get.find<UserService>()), fenix: true);
Get.lazyPut(() => VoicePlayerService(), fenix: true);
Get.lazyPut(() => VoiceRecorderController(), fenix: true);
```

## 21. Feature-flag gate

The `VoiceInputButton` checks `FeatureFlagService.flags['VOICE_CHAT_ENABLED']`. Default off until backend is healthy. Server-side killswitch (`ai:killswitch:voice`) also makes the button hide.
