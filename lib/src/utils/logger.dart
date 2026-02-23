/// Logging levels
enum LogLevel {
  none,
  error,
  warning,
  info,
  debug,
  verbose,
}

/// Log entry passed to observers
class LogEntry {
  /// Log level (ERROR, WARN, INFO, DEBUG, VERBOSE)
  final String level;

  /// Log message
  final String message;

  /// Optional error object
  final Object? error;

  /// Optional stack trace
  final StackTrace? stackTrace;

  /// Timestamp when log was created
  final DateTime timestamp;

  LogEntry({
    required this.level,
    required this.message,
    this.error,
    this.stackTrace,
  }) : timestamp = DateTime.now();
}

/// Callback type for log observers
typedef LogObserver = void Function(LogEntry entry);

/// Simple logger for LinkGravity SDK
///
/// Supports external observers for integrating with logging libraries
/// like Talker, Firebase Crashlytics, or custom log viewers.
///
/// Example:
/// ```dart
/// // Add an observer to capture all SDK logs
/// LinkGravityLogger.addObserver((entry) {
///   myTalker.log(entry.message);
/// });
/// ```
class LinkGravityLogger {
  static LogLevel _currentLevel = LogLevel.info;
  static final List<LogObserver> _observers = [];

  /// Set the logging level
  static void setLevel(LogLevel level) {
    _currentLevel = level;
  }

  /// Get current logging level
  static LogLevel get level => _currentLevel;

  /// Add a log observer
  ///
  /// Observers receive all log entries that pass the current log level filter.
  /// Use this to integrate with external logging libraries like Talker.
  ///
  /// Example:
  /// ```dart
  /// LinkGravityLogger.addObserver((entry) {
  ///   switch (entry.level) {
  ///     case 'ERROR':
  ///       talker.error(entry.message, entry.error, entry.stackTrace);
  ///       break;
  ///     case 'WARN':
  ///       talker.warning(entry.message);
  ///       break;
  ///     default:
  ///       talker.info(entry.message);
  ///   }
  /// });
  /// ```
  static void addObserver(LogObserver observer) {
    _observers.add(observer);
  }

  /// Remove a specific log observer
  static void removeObserver(LogObserver observer) {
    _observers.remove(observer);
  }

  /// Remove all log observers
  static void clearObservers() {
    _observers.clear();
  }

  /// Get count of active observers (useful for debugging)
  static int get observerCount => _observers.length;

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
    final logMessage = '[$timestamp] [LinkGravity] [$level] $message';

    // Print to console (works in debug mode)
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

    // Notify all observers
    if (_observers.isNotEmpty) {
      final entry = LogEntry(
        level: level,
        message: message,
        error: error,
        stackTrace: stackTrace,
      );

      for (final observer in _observers) {
        try {
          observer(entry);
        } catch (e) {
          // Don't let observer errors break logging
          // ignore: avoid_print
          print('[LinkGravity] [ERROR] Log observer threw: $e');
        }
      }
    }
  }
}