import 'package:flutter/foundation.dart';

/// Debug-only logger. Compiles to a no-op in release builds so nothing
/// executes or leaks to production logs. Use instead of raw debugPrint.
void logDebug(Object? message) {
  if (kDebugMode) {
    debugPrint(message?.toString());
  }
}
