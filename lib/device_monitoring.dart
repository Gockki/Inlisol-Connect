// device_monitoring.dart
import 'dart:async';
import 'package:workmanager/workmanager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:inli_connect/utils/logger.dart';
import 'package:inli_connect/background_worker.dart' as bg_worker;

// Timer for more frequent foreground checks
Timer? _foregroundTimer;
bool _isAppInForeground = true;

// Start both background and foreground monitoring
void startDeviceMonitoring(String authToken) async {
  Logger.d("Starting device monitoring...");
  
  // 1. Start background monitoring with Workmanager (15-minute interval)
  await Workmanager().registerPeriodicTask(
    "deviceMonitoring",
    "fetchDevicesTask",
    frequency: const Duration(minutes: 15),
    constraints: Constraints(
      networkType: NetworkType.connected,
    ),
    inputData: {
      'authToken': authToken
    },
    existingWorkPolicy: ExistingWorkPolicy.replace,
  );
  
  Logger.d("Background monitoring scheduled (15-minute intervals)");
  
  // 2. Start foreground timer for more frequent checks when app is open
  startForegroundMonitoring(authToken);
}

// Start more frequent monitoring when app is in foreground
void startForegroundMonitoring(String authToken) {
  // Cancel any existing timer
  _foregroundTimer?.cancel();
  
  // Start a new timer that runs every minute when app is in foreground
  _foregroundTimer = Timer.periodic(const Duration(minutes: 1), (timer) async {
    if (_isAppInForeground) {
      Logger.d("Running foreground device check");
      await bg_worker.checkDeviceStatus(authToken);
    }
  });
  
  Logger.d("Foreground monitoring started (1-minute intervals)");
}

// Stop foreground monitoring
void stopForegroundMonitoring() {
  _foregroundTimer?.cancel();
  _foregroundTimer = null;
  Logger.d("Foreground monitoring stopped");
}

// Call when app goes to background
void appSentToBackground() {
  _isAppInForeground = false;
  Logger.d("App moved to background, pausing frequent checks");
}

// Call when app comes to foreground
void appReturnedToForeground() {
  _isAppInForeground = true;
  Logger.d("App returned to foreground, resuming frequent checks");
}

// Stop all monitoring (call on logout)
void stopAllMonitoring() async {
  // Cancel foreground timer
  stopForegroundMonitoring();
  
  // Cancel background task
  await Workmanager().cancelByUniqueName("deviceMonitoring");
  
  // Clear stored data
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove('last_device_status');
  
  Logger.d("All device monitoring stopped");
}