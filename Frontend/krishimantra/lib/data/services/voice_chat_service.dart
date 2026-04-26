import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../../core/constants/api_constants.dart';
import '_sse.dart';
import 'UserService.dart';

class VoiceTurnRequest {
  final File audio;
  final String mimeType;
  final String? chatId;
  final String preferredLanguage;
  final String? userName;
  final String? userProfilePhoto;
  final String? voiceName;

  const VoiceTurnRequest({
    required this.audio,
    this.mimeType = 'audio/mp4',
    this.chatId,
    this.preferredLanguage = 'en',
    this.userName,
    this.userProfilePhoto,
    this.voiceName,
  });
}

/// Posts the recorded audio to `/api/voice/chat` and yields normalized SSE
/// frames as the server streams transcript → AI deltas → TTS audio chunks
/// → done. Caller drives a UI state machine off these events.
class VoiceChatService {
  final UserService _user;
  final http.Client _client;

  VoiceChatService(this._user, {http.Client? client})
      : _client = client ?? http.Client();

  Stream<SseFrame> sendVoiceTurn(VoiceTurnRequest req) async* {
    final token = await _user.getToken();
    final base = ApiConstants.BASE_URL;
    final uri = Uri.parse('$base/api/voice/chat');

    final mp = http.MultipartRequest('POST', uri);
    if (token != null && token.isNotEmpty) {
      mp.headers['Authorization'] = 'Bearer $token';
    }
    mp.headers['Accept'] = 'text/event-stream';
    if (req.chatId != null) mp.fields['chatId'] = req.chatId!;
    mp.fields['preferredLanguage'] = req.preferredLanguage;
    if (req.userName != null) mp.fields['userName'] = req.userName!;
    if (req.userProfilePhoto != null) {
      mp.fields['userProfilePhoto'] = req.userProfilePhoto!;
    }
    if (req.voiceName != null) mp.fields['voiceName'] = req.voiceName!;

    mp.files.add(
      await http.MultipartFile.fromPath(
        'audio',
        req.audio.path,
        contentType: _parseMime(req.mimeType),
      ),
    );

    http.StreamedResponse resp;
    try {
      resp = await _client.send(mp);
    } catch (e) {
      yield SseFrame(
        type: 'error',
        data: {'code': 'CONNECTION_FAILED', 'message': '$e'},
      );
      return;
    }

    if (resp.statusCode == 429) {
      final body = await resp.stream.bytesToString();
      yield SseFrame(type: 'error', data: {
        'code': 'RATE_LIMIT',
        'status': 429,
        'body': _safeJson(body),
      });
      return;
    }
    if (resp.statusCode == 401 || resp.statusCode == 403) {
      yield SseFrame(type: 'error', data: {
        'code': 'UNAUTHENTICATED',
        'status': resp.statusCode,
      });
      return;
    }
    if (resp.statusCode >= 400) {
      final body = await resp.stream.bytesToString();
      yield SseFrame(type: 'error', data: {
        'code': 'HTTP_${resp.statusCode}',
        'status': resp.statusCode,
        'body': _safeJson(body),
      });
      return;
    }

    final ct = resp.headers['content-type'] ?? '';
    if (!ct.contains('text/event-stream')) {
      // Non-SSE fallback — treat as a single JSON envelope and synthesize done.
      final body = await resp.stream.bytesToString();
      final parsed = _safeJson(body);
      if (parsed is Map<String, dynamic>) {
        yield SseFrame(type: 'done', data: parsed);
      } else {
        yield SseFrame(type: 'error', data: {
          'code': 'INVALID_RESPONSE',
          'body': parsed,
        });
      }
      return;
    }

    bool sawDone = false;
    await for (final frame in parseSseStream(resp.stream)) {
      yield frame;
      if (frame.type == 'done' || frame.type == 'error') {
        sawDone = true;
        break;
      }
    }
    if (!sawDone) {
      yield SseFrame(type: 'error', data: {'code': 'STREAM_CLOSED'});
    }
  }

  /// One-shot fetch of the cached TTS audio for a previous assistant message.
  /// Returns `(bytes, mime)` or `null` if the cache expired (24h default).
  Future<({List<int> bytes, String mime})?> fetchReplay(
    String messageId, {
    String voice = 'default',
  }) async {
    final token = await _user.getToken();
    final base = ApiConstants.BASE_URL;
    final uri = Uri.parse('$base/api/voice/replay/$messageId?voice=$voice');
    final headers = <String, String>{};
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    final res = await _client.get(uri, headers: headers);
    if (res.statusCode == 404) return null;
    if (res.statusCode != 200) return null;
    return (
      bytes: res.bodyBytes,
      mime: res.headers['content-type'] ?? 'audio/mp3',
    );
  }

  void close() {
    _client.close();
  }

  MediaType _parseMime(String s) {
    final parts = s.split('/');
    if (parts.length != 2) return MediaType('audio', 'mp4');
    return MediaType(parts[0], parts[1]);
  }

  Object? _safeJson(String body) {
    if (body.isEmpty) return null;
    try {
      return jsonDecode(body);
    } catch (_) {
      return body;
    }
  }
}
