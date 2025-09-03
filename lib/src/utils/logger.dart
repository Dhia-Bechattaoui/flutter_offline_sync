import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';

/// A simple logging utility for the offline sync package.
class Logger {
  final String _name;
  final bool _debugMode;

  const Logger(this._name, {bool debugMode = kDebugMode})
    : _debugMode = debugMode;

  /// Logs a debug message.
  void debug(String message) {
    if (_debugMode) {
      developer.log(
        message,
        name: _name,
        level: 800, // Debug level
      );
    }
  }

  /// Logs an info message.
  void info(String message) {
    developer.log(
      message,
      name: _name,
      level: 700, // Info level
    );
  }

  /// Logs a warning message.
  void warning(String message) {
    developer.log(
      message,
      name: _name,
      level: 900, // Warning level
    );
  }

  /// Logs an error message.
  void error(String message, [Object? error, StackTrace? stackTrace]) {
    developer.log(
      message,
      name: _name,
      level: 1000, // Error level
      error: error,
      stackTrace: stackTrace,
    );
  }

  /// Logs a fatal error message.
  void fatal(String message, [Object? error, StackTrace? stackTrace]) {
    developer.log(
      message,
      name: _name,
      level: 1200, // Fatal level
      error: error,
      stackTrace: stackTrace,
    );
  }
}
