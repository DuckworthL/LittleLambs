import 'package:flutter/foundation.dart';

// Simple logger utility
class Logger {
  static void log(String message) {
    if (kDebugMode) {
      print('[LOG] $message');
    }
  }

  static void error(String message, [Object? error, StackTrace? stackTrace]) {
    if (kDebugMode) {
      print('[ERROR] $message');
      if (error != null) print('Exception: $error');
      if (stackTrace != null) print('Stack trace: $stackTrace');
    }
  }
}
