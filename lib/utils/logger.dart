import 'package:flutter/foundation.dart';

/// A simple logging utility for the application.
/// 
/// This class provides static methods for logging messages at different levels.
/// In debug mode, messages are printed to the console.
/// In release mode, only error messages are processed (and could be sent to a
/// monitoring service in a production app).
class Logger {
  /// Log a debug message.
  /// Only appears in debug builds.
  static void d(String message) {
    if (kDebugMode) {
      print("DEBUG: $message");
    }
  }
  
  /// Log an informational message.
  /// Only appears in debug builds.
  static void i(String message) {
    if (kDebugMode) {
      print("INFO: $message");
    }
    // In a real production app, you might want to log important info
    // even in production using a service like Firebase Crashlytics
  }
  
  /// Log a warning message.
  /// Only appears in debug builds.
  static void w(String message) {
    if (kDebugMode) {
      print("WARNING: $message");
    }
    // Consider logging warnings in production
  }
  
  /// Log an error message.
  /// Includes optional error object and stack trace.
  /// Only appears in debug builds.
  static void e(String message, [Object? error, StackTrace? stackTrace]) {
    if (kDebugMode) {
      print("ERROR: $message");
      if (error != null) print(error);
      if (stackTrace != null) print(stackTrace);
    }
    // In production, you would want to log errors
    // to a service like Firebase Crashlytics or Sentry
    // Example:
    // FirebaseCrashlytics.instance.recordError(error, stackTrace, reason: message);
  }
}