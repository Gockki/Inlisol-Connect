// background_worker.dart
import 'dart:convert';
import 'package:workmanager/workmanager.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      print("Background task started: $task");
      
      switch (task) {
        case 'fetchDevicesTask':
          String? authToken = inputData?['authToken'];
          if (authToken != null) {
            print("Fetching devices in the background...");
            
            // Check device status and send notifications if needed
            await checkDeviceStatus(authToken);
          }
          break;
        case 'clearCacheTask':
          // This is a one-time task to clear the cache
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove('device_locations');
          print("Device locations cache cleared");
          break;
      }
      
      return Future.value(true);
    } catch (e) {
      print("Error in background task: $e");
      return Future.value(false);
    }
  });
}

// This function is the core monitoring logic - used by both background task and foreground timer
Future<void> checkDeviceStatus(String authToken) async {
  try {
    // Initialize notifications
    await _initializeNotifications();
    
    // Load previous device status with extra safeguards
    final prefs = await SharedPreferences.getInstance();
    
    // Debug - print all keys in SharedPreferences
    print("Available SharedPreferences keys: ${prefs.getKeys()}");
    
    // Get previous state with extra validation
    String? previousStatusJson = prefs.getString('last_device_status');
    print("Raw previous status: $previousStatusJson");
    
    Map<String, dynamic> previousStatus = {};
    if (previousStatusJson != null && previousStatusJson.isNotEmpty) {
      try {
        previousStatus = json.decode(previousStatusJson);
      } catch (e) {
        print("Error decoding previous status: $e");
        // Reset if corrupted
        previousStatus = {};
      }
    }
    
    print("Previous device status had ${previousStatus.length} devices");
    
    // Fetch current active devices
    final activeDevices = await _fetchActiveDevices(authToken);
    print("Found ${activeDevices.length} active devices");
    
    // Log more detailed comparison information
    print("Previous status had ${previousStatus.length} devices, current status has ${activeDevices.length} devices");
    if (previousStatus.length > activeDevices.length) {
      print("ALERT: ${previousStatus.length - activeDevices.length} devices appear to have gone offline");
      
      // For debugging, print the IDs that are missing
      Set<String> previousIds = previousStatus.keys.toSet();
      Set<String> currentIds = activeDevices.toSet();
      Set<String> missingIds = previousIds.difference(currentIds);
      
      if (missingIds.isNotEmpty) {
        print("Missing device IDs: $missingIds");
      }
    }
    
    // Check for devices that were previously online but now offline
    List<String> offlineDevices = [];
    previousStatus.forEach((deviceId, wasActive) {
      if (wasActive == true && !activeDevices.contains(deviceId)) {
        print("Device $deviceId was previously online but is now offline");
        offlineDevices.add(deviceId);
      }
    });
    
    print("Found ${offlineDevices.length} offline devices");
    
    // Send notifications for offline devices
    if (offlineDevices.isNotEmpty) {
      for (String deviceId in offlineDevices) {
        // Get floor name for the device
        String floorName = await _getDeviceLocation(deviceId, authToken) ?? "Unknown Floor";
        
        print("Sending notification for offline device $deviceId on floor: $floorName");
        
        // Send notification with only floor information
        await _sendLocalNotification(
          "Device Offline", 
          "Device on Floor '$floorName' has gone offline"
        );
      }
    }
    
    // Update status for current active devices
    Map<String, dynamic> newStatus = {};
    for (String deviceId in activeDevices) {
      newStatus[deviceId] = true;
    }
    
    // Save updated status for next run - with verification and awaiting
    if (newStatus.isNotEmpty) {
      String encodedStatus = json.encode(newStatus);
      
      // Make sure the save completes by awaiting it
      await prefs.setString('last_device_status', encodedStatus);
      
      // Add a small delay to ensure the write is fully committed
      await Future.delayed(Duration(milliseconds: 100));
      
      // Verify it was saved correctly
      String? verifiedStatus = prefs.getString('last_device_status');
      
      if (verifiedStatus == encodedStatus) {
        print("Status saved successfully with ${newStatus.length} devices");
      } else {
        print("WARNING: Status may not have saved correctly!");
        print("Original: $encodedStatus");
        print("Retrieved: $verifiedStatus");
      }
    } else {
      print("WARNING: Not saving empty device list to avoid false alerts");
    }
  } catch (e) {
    print("Error in checkDeviceStatus: $e");
  }
}

Future<void> _initializeNotifications() async {
  FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = 
      FlutterLocalNotificationsPlugin();
  
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@drawable/ic_stat_notification');
  
  final InitializationSettings initializationSettings =
      InitializationSettings(android: initializationSettingsAndroid);
  
  await flutterLocalNotificationsPlugin.initialize(initializationSettings);
}

Future<void> _sendLocalNotification(String title, String body) async {
  FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = 
      FlutterLocalNotificationsPlugin();
  
  const AndroidNotificationDetails androidPlatformChannelSpecifics =
      AndroidNotificationDetails(
        'device_alerts',
        'Device Alerts',
        importance: Importance.max,
        priority: Priority.high,
        showWhen: true,
        icon: '@drawable/ic_stat_notification'
      );
  
  const NotificationDetails platformChannelSpecifics =
      NotificationDetails(android: androidPlatformChannelSpecifics);
  
  await flutterLocalNotificationsPlugin.show(
    0, title, body, platformChannelSpecifics);
  
  print("Notification sent: $title - $body");
}

Future<List<String>> _fetchActiveDevices(String authToken) async {
  print("Fetching active devices...");
  
  final url = "https://iot.inlisol.com/api/tenant/deviceInfos?pageSize=100&page=0&sortProperty=createdTime&sortOrder=DESC&active=true";
  
  try {
    final response = await http.get(
      Uri.parse(url),
      headers: {'X-Authorization': 'Bearer $authToken'},
    );
    
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      List<String> deviceIds = [];
      
      for (var device in data['data']) {
        String deviceId = device['id']['id'];
        deviceIds.add(deviceId);
      }
      
      print("Retrieved Active Devices: ${deviceIds.length}");
      return deviceIds;
    } else {
      print("Error fetching devices: HTTP ${response.statusCode}");
    }
  } catch (e) {
    print("Exception fetching active devices: $e");
  }
  
  return [];
}

Future<String?> _getDeviceLocation(String deviceId, String authToken) async {
  // Get floor name directly without using cache
  try {
    // First get the room asset
    final roomUrl = "https://iot.inlisol.com/api/relations/info?toId=$deviceId&toType=DEVICE";
    final roomResponse = await http.get(
      Uri.parse(roomUrl),
      headers: {'X-Authorization': 'Bearer $authToken'},
    );
    
    if (roomResponse.statusCode == 200) {
      final List<dynamic> relations = json.decode(roomResponse.body);
      String roomId = "";
      
      // Find the room this device belongs to
      for (var relation in relations) {
        if (relation.containsKey('from') && relation['from']['entityType'] == "ASSET") {
          roomId = relation['from']['id'];
          break;
        }
      }
      
      // If we found a room, try to get its floor
      if (roomId.isNotEmpty) {
        // Now get the floor for this room
        final floorUrl = "https://iot.inlisol.com/api/relations/info?toId=$roomId&toType=ASSET";
        final floorResponse = await http.get(
          Uri.parse(floorUrl),
          headers: {'X-Authorization': 'Bearer $authToken'},
        );
        
        if (floorResponse.statusCode == 200) {
          final List<dynamic> floorRelations = json.decode(floorResponse.body);
          
          // Based on the API response, the floor name is in fromName
          if (floorRelations.isNotEmpty && floorRelations[0].containsKey('fromName')) {
            String floorName = floorRelations[0]['fromName'] ?? "Unknown Floor";
            
            print("Device $deviceId is on floor: $floorName");
            return floorName; // Return just the floor name
          }
        }
      }
    }
  } catch (e) {
    print("Error getting device location: $e");
  }
  
  return "Unknown Floor";
}

// Test function to manually trigger a notification for debugging
Future<void> testNotification(String authToken) async {
  // Get the first device ID from your list
  final devices = await _fetchActiveDevices(authToken);
  if (devices.isNotEmpty) {
    final deviceId = devices.first;
    final floorName = await _getDeviceLocation(deviceId, authToken) ?? "Unknown Floor";
    
    await _sendLocalNotification(
      "Test Notification", 
      "Device on Floor '$floorName' has gone offline"
    );
  }
}

// Function to clear the cache (call this once when updating implementation)
Future<void> clearLocationCache() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove('device_locations');
  print("Device locations cache cleared");
}