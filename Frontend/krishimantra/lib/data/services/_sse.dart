import 'dart:async';
import 'dart:convert';

/// One frame parsed from a server-sent-events stream.
/// Mirrors the backend's `utils/sse.js` payload shape:
///   { type: "transcript" | "delta" | "audio" | "done" | "error", ... }
class SseFrame {
  final String type;
  final Map<String, dynamic> data;
  const SseFrame({required this.type, required this.data});
}

/// Convert a raw `Stream<List<int>>` (from `http.StreamedResponse.stream`)
/// into a stream of normalized `SseFrame`s. Splits on `\n\n`, picks `data:`
/// lines, decodes JSON, and yields one frame per event.
///
/// Falls back to a synthetic `delta` frame containing the raw text when the
/// payload is non-JSON — useful for plain text chunks from misbehaving
/// proxies.
Stream<SseFrame> parseSseStream(Stream<List<int>> byteStream) async* {
  String buffer = '';
  await for (final chunk in byteStream.transform(utf8.decoder)) {
    buffer += chunk;
    while (true) {
      final boundary = buffer.indexOf('\n\n');
      if (boundary == -1) break;
      final raw = buffer.substring(0, boundary);
      buffer = buffer.substring(boundary + 2);
      final frame = parseSseFrame(raw);
      if (frame != null) yield frame;
    }
  }
}

SseFrame? parseSseFrame(String raw) {
  final lines = raw.split('\n');
  final dataLines = <String>[];
  for (final line in lines) {
    if (line.startsWith('data:')) {
      dataLines.add(line.substring(5).trimLeft());
    }
    // skip comment/keepalive lines (start with ":")
  }
  if (dataLines.isEmpty) return null;
  final payload = dataLines.join('\n');
  try {
    final decoded = jsonDecode(payload);
    if (decoded is Map<String, dynamic>) {
      final type = decoded['type']?.toString() ?? 'delta';
      return SseFrame(type: type, data: decoded);
    }
  } catch (_) {}
  return SseFrame(type: 'delta', data: {'text': payload});
}
