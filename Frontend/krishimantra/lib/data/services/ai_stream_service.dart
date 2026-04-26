import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/constants/api_constants.dart';
import 'UserService.dart';

/// Normalized event matching the backend's `utils/sse.js` shape.
/// Mirrors the OpenAI/Vertex-normalized contract from the provider interface.
class AiStreamEvent {
  final String type; // "delta" | "done" | "error"
  final String? text; // for delta
  final Map<String, dynamic>? payload; // for done/error
  const AiStreamEvent({required this.type, this.text, this.payload});

  factory AiStreamEvent.fromJson(Map<String, dynamic> json) {
    return AiStreamEvent(
      type: json['type']?.toString() ?? 'delta',
      text: json['text']?.toString(),
      payload: json,
    );
  }
}

class AiStreamRequest {
  final String message;
  final String? chatId;
  final String preferredLanguage;
  final String? userName;
  final String? userProfilePhoto;
  final Map<String, dynamic>? location;
  final Map<String, dynamic>? weather;

  const AiStreamRequest({
    required this.message,
    this.chatId,
    this.preferredLanguage = 'en',
    this.userName,
    this.userProfilePhoto,
    this.location,
    this.weather,
  });

  Map<String, dynamic> toJson() => {
        'message': message,
        if (chatId != null) 'chatId': chatId,
        'preferredLanguage': preferredLanguage,
        if (userName != null) 'userName': userName,
        if (userProfilePhoto != null) 'userProfilePhoto': userProfilePhoto,
        if (location != null) 'location': location,
        if (weather != null) 'weather': weather,
      };
}

/// Server-Sent-Events client for the v2 AI chat path.
/// Backend opens SSE only when `Accept: text/event-stream` is present;
/// otherwise the same endpoint returns a single JSON. We always request SSE
/// here, but fall back gracefully if the server returns JSON instead.
class AiStreamService {
  final http.Client _client;
  final UserService _userService;

  AiStreamService({http.Client? client, required UserService userService})
      : _client = client ?? http.Client(),
        _userService = userService;

  /// Returns a broadcast stream of normalized events. The stream completes
  /// after `done` (or `error`). Caller should `cancel()` the subscription
  /// to abort early — that closes the underlying HTTP request.
  Stream<AiStreamEvent> sendChat(AiStreamRequest req) async* {
    final token = await _userService.getToken();
    final base = ApiConstants.BASE_URL;
    final uri = Uri.parse('$base/api/ai/chat');

    final request = http.Request('POST', uri);
    request.headers['Content-Type'] = 'application/json';
    request.headers['Accept'] = 'text/event-stream';
    if (token != null && token.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    request.body = jsonEncode(req.toJson());

    http.StreamedResponse response;
    try {
      response = await _client.send(request);
    } catch (e) {
      yield AiStreamEvent(
        type: 'error',
        payload: {'message': 'connection_failed: $e'},
      );
      return;
    }

    final contentType = response.headers['content-type'] ?? '';
    final isSse = contentType.contains('text/event-stream');

    if (response.statusCode == 429) {
      final body = await response.stream.bytesToString();
      yield AiStreamEvent(
        type: 'error',
        payload: {
          'code': 'RATE_LIMIT',
          'status': response.statusCode,
          'body': _safeJson(body),
        },
      );
      return;
    }
    if (response.statusCode >= 400) {
      final body = await response.stream.bytesToString();
      yield AiStreamEvent(
        type: 'error',
        payload: {
          'code': 'HTTP_${response.statusCode}',
          'status': response.statusCode,
          'body': _safeJson(body),
        },
      );
      return;
    }

    if (!isSse) {
      // Server returned a single JSON envelope (legacy or non-SSE registry path).
      // Synthesize a single delta + done so the caller's UI works unchanged.
      final body = await response.stream.bytesToString();
      try {
        final parsed = jsonDecode(body) as Map<String, dynamic>;
        final text = parsed['message']?.toString() ?? '';
        if (text.isNotEmpty) yield AiStreamEvent(type: 'delta', text: text);
        yield AiStreamEvent(type: 'done', payload: parsed);
      } catch (e) {
        yield AiStreamEvent(
          type: 'error',
          payload: {'message': 'invalid_response: $e', 'body': body},
        );
      }
      return;
    }

    // True SSE stream: lines arrive as utf-8 chunks; events terminate with `\n\n`.
    String buffer = '';
    await for (final chunk in response.stream.transform(utf8.decoder)) {
      buffer += chunk;
      while (true) {
        final boundary = buffer.indexOf('\n\n');
        if (boundary == -1) break;
        final raw = buffer.substring(0, boundary);
        buffer = buffer.substring(boundary + 2);
        final ev = _parseSseFrame(raw);
        if (ev != null) {
          yield ev;
          if (ev.type == 'done' || ev.type == 'error') return;
        }
      }
    }
    // Connection closed without `done` — surface as error so UI can react.
    yield const AiStreamEvent(
      type: 'error',
      payload: {'code': 'STREAM_CLOSED'},
    );
  }

  AiStreamEvent? _parseSseFrame(String frame) {
    final lines = frame.split('\n');
    final dataLines = <String>[];
    for (final line in lines) {
      if (line.startsWith('data:')) {
        dataLines.add(line.substring(5).trimLeft());
      }
      // ignore comment/keepalive lines starting with ":"
    }
    if (dataLines.isEmpty) return null;
    final payload = dataLines.join('\n');
    try {
      final json = jsonDecode(payload);
      if (json is Map<String, dynamic>) return AiStreamEvent.fromJson(json);
    } catch (_) {}
    return AiStreamEvent(
      type: 'delta',
      text: payload,
      payload: const {},
    );
  }

  Object _safeJson(String body) {
    try {
      return jsonDecode(body);
    } catch (_) {
      return body;
    }
  }

  void close() {
    _client.close();
  }
}
