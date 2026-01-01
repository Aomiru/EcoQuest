import 'dart:developer' as developer;

/// Centralized application logger to replace direct print statements.
/// Uses dart:developer log with simple level conventions.
class AppLogger {
  static const String _name = 'AISpeciesService';

  static void debug(String message) {
    developer.log(message, name: _name, level: 500); // FINE
  }

  static void info(String message) {
    developer.log(message, name: _name, level: 800); // INFO
  }

  static void warning(String message) {
    developer.log(message, name: _name, level: 900); // WARNING
  }

  static void error(String message, [Object? error, StackTrace? stackTrace]) {
    developer.log(
      message,
      name: _name,
      level: 1000,
      error: error,
      stackTrace: stackTrace,
    ); // SEVERE
  }
}
