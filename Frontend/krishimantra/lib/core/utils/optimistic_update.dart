// Helpers for optimistic UI updates across feed, reel, and video flows.
//
// Pattern: apply the user-visible change immediately (so the UI feels
// snappy), fire the network request, and either reconcile with the server's
// authoritative response on success or roll back on failure.
//
// Important: rollback only fires on errors that are *the operation's fault*
// (4xx, validation failures). Timeouts and connection errors leave the
// optimistic state in place because the operation may have actually
// succeeded server-side — the next refetch will reconcile.

import 'package:dio/dio.dart' as dio;

/// Categorise an error so we know whether to roll back the optimistic UI.
///
/// Returns true for "the request definitely failed and the server didn't
/// commit anything" — that's the only case where rolling the UI back is
/// correct. For ambiguous failures (timeout, network, breaker) we keep the
/// optimistic state and let the next refetch reconcile.
bool isDefiniteFailure(Object error) {
  if (error is dio.DioException) {
    final status = error.response?.statusCode;
    if (status != null && status >= 400 && status < 500) return true;
    // 5xx and lower-level Dio types fall through to ambiguous.
    return false;
  }
  final s = error.toString().toLowerCase();
  if (s.contains('timeout') ||
      s.contains('connection') ||
      s.contains('circuit breaker') ||
      s.contains('socketexception')) {
    return false;
  }
  // Plain Exception('...') with no transport hints — treat as definite.
  return true;
}

/// Run an optimistic update with rollback + reconcile.
///
/// 1. Calls [applyOptimistic] synchronously to update the UI.
/// 2. Awaits [request].
/// 3. On success, calls [reconcile] with the server response (optional).
/// 4. On error, calls [rollback] iff [isDefiniteFailure] returns true.
///
/// Returns the request's result, or null if the request failed (callers
/// usually don't need the value back — the reconcile handles UI state).
Future<R?> optimistic<R>({
  required Future<R> Function() request,
  required void Function() applyOptimistic,
  required void Function() rollback,
  void Function(R result)? reconcile,
}) async {
  applyOptimistic();
  try {
    final result = await request();
    reconcile?.call(result);
    return result;
  } catch (e) {
    if (isDefiniteFailure(e)) {
      rollback();
    }
    rethrow;
  }
}
