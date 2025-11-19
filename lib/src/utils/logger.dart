import 'package:flutter/foundation.dart';

/// Logging levels
enum LogLevel {
  none,
  error,
  warning,
  info,
  debug,
  verbose,
}

/// Simple logger for SmartLink SDK
class SmartLinkLogger {
  static LogLevel _currentLevel = LogLevel.info;

  /// Set the logging level
  static void setLevel(LogLevel level) {
    _currentLevel = level;
  }

  /// Get current logging level
  static LogLevel get level => _currentLevel;

  /// Log error message
  static void error(String message, [Object? error, StackTrace? stackTrace]) {
    if (_currentLevel.index >= LogLevel.error.index) {
      _log('ERROR', message, error, stackTrace);
    }
  }

  /// Log warning message
  static void warning(String message, [Object? error]) {
    if (_currentLevel.index >= LogLevel.warning.index) {
      _log('WARN', message, error);
    }
  }

  /// Log info message
  static void info(String message) {
    if (_currentLevel.index >= LogLevel.info.index) {
      _log('INFO', message);
    }
  }

  /// Log debug message
  static void debug(String message) {
    if (_currentLevel.index >= LogLevel.debug.index) {
      _log('DEBUG', message);
    }
  }

  /// Log verbose message
  static void verbose(String message) {
    if (_currentLevel.index >= LogLevel.verbose.index) {
      _log('VERBOSE', message);
    }
  }

  static void _log(String level, String message,
      [Object? error, StackTrace? stackTrace]) {
    final timestamp = DateTime.now().toIso8601String();
    final logMessage = '[$timestamp] [SmartLink] [$level] $message';

    if (kDebugMode) {
      // ignore: avoid_print
      print(logMessage);

      if (error != null) {
        // ignore: avoid_print
        print('Error: $error');
      }

      if (stackTrace != null) {
        // ignore: avoid_print
        print('StackTrace: $stackTrace');
      }
    }
  }
}
