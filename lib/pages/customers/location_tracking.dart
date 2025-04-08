import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:inli_connect/utils/logger.dart';

/// Helper function to navigate to location tracking with proper data fetching
Future<void> navigateToLocationTracking(BuildContext context, String assetId, String authToken) async {
  // Show loading indicator
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => const Center(child: CircularProgressIndicator()),
  );
  
  try {
    // 1. Fetch the asset-device relation
    final String relationsUrl = 
        "https://iot.inlisol.com/api/relations/info?fromId=$assetId&fromType=ASSET";
    
    final relationsResponse = await http.get(
      Uri.parse(relationsUrl),
      headers: {'X-Authorization': 'Bearer $authToken'},
    );
    
    Logger.d("Relations Response Status: ${relationsResponse.statusCode}");
    Logger.d("Relations Response Body: ${relationsResponse.body}");
    
    if (relationsResponse.statusCode != 200) {
      throw Exception("Failed to fetch device relations: ${relationsResponse.statusCode}");
    }
    
    // Parse relations data
    final List<dynamic> relations = json.decode(relationsResponse.body);
    
    // Find the device related to this asset with enhanced debugging
    Map<String, dynamic>? deviceRelation;
    Logger.d("Looking for device relations. Total relations: ${relations.length}");
    
    for (var relation in relations) {
      Logger.d("Checking relation: ${relation['to']['entityType']} (${relation['toName'] ?? 'unnamed'})");
      
      if (relation['to']['entityType'].toString().toUpperCase() == 'DEVICE') {
        deviceRelation = relation;
        Logger.d("Found device relation: ${relation['to']['id']} (${relation['toName'] ?? 'unnamed'})");
        break;
      }
    }
    
    // Fallback approach if no device was found
    if (deviceRelation == null) {
      Logger.w("No device found with primary method, trying fallback...");
      
      // Just take the first device if there's only one
      if (relations.length == 2) {
        for (var relation in relations) {
          if (relation['to']['entityType'] != 'ASSET') {
            deviceRelation = relation;
            Logger.d("Found potential device via elimination: ${relation['to']['id']}");
            break;
          }
        }
      }
      
      // If still null, try by name pattern
      if (deviceRelation == null) {
        for (var relation in relations) {
          if (relation['toName'] != null && 
              (relation['toName'].toString().toLowerCase().contains('angel') || 
              relation['toName'].toString().toLowerCase().contains('device'))) {
            deviceRelation = relation;
            Logger.d("Found potential device via name: ${relation['to']['id']}");
            break;
          }
        }
      }
    }
    
    if (deviceRelation == null) {
      // Last resort: just grab any non-ASSET relation
      for (var relation in relations) {
        if (relation['to']['entityType'] != 'ASSET') {
          deviceRelation = relation;
          Logger.w("Last resort: Using non-ASSET relation: ${relation['to']['entityType']} - ${relation['to']['id']}");
          break;
        }
      }
    }
    
    if (deviceRelation == null) {
      throw Exception("No related device found for this room. Please check device assignment.");
    }
    
    final String deviceId = deviceRelation['to']['id'];
    Logger.d("Using Device ID: $deviceId");
    
    // 2. Fetch room size data from asset attributes
    final String roomAttributesUrl = 
        "https://iot.inlisol.com/api/plugins/telemetry/ASSET/$assetId/values/attributes?keys=length,width1";
    
    final attributesResponse = await http.get(
      Uri.parse(roomAttributesUrl),
      headers: {'X-Authorization': 'Bearer $authToken'},
    );
    
    Logger.d("Room Attributes Response: ${attributesResponse.body}");
    
    if (attributesResponse.statusCode != 200) {
      throw Exception("Failed to fetch room attributes: ${attributesResponse.statusCode}");
    }
    
    // Parse room size data with better error handling
    final Map<String, dynamic> attributes = json.decode(attributesResponse.body);
    final Map<String, dynamic> roomSizeData = {
      'length': _getAttributeValue(attributes, 'length', 300) * 1000,  // Convert meters to mm
      'width1': _getAttributeValue(attributes, 'width1', 200) * 1000,  // Convert meters to mm
    };
    
    Logger.d("Room Size Data: $roomSizeData");
    
    // 3. Navigate to location tracking page with all required data
    Navigator.pop(context); // Close loading dialog
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LocationTrackingPage(
          roomId: assetId,
          deviceId: deviceId,
          authToken: authToken,
          roomSizeData: roomSizeData,
        ),
      ),
    );
    
  } catch (error) {
    Logger.e("Navigation Error", error);
    Navigator.pop(context); // Close loading dialog
    
    // Show error dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Error"),
        content: Text("Failed to load tracking data: $error"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }
}

// Helper to extract attribute value with default fallback
double _getAttributeValue(Map<String, dynamic> attributes, String key, double defaultValue) {
  if (attributes.containsKey(key) && attributes[key] is List && attributes[key].isNotEmpty) {
    final value = attributes[key][0]['value'];
    if (value != null) {
      return double.tryParse(value.toString()) ?? defaultValue;
    }
  }
  Logger.w("Using default value for $key: $defaultValue");
  return defaultValue;
}

class LocationTrackingPage extends StatefulWidget {
  final String roomId;
  final String deviceId;
  final String authToken;
  final Map<String, dynamic> roomSizeData;

  const LocationTrackingPage({
    super.key,
    required this.roomId,
    required this.deviceId,
    required this.authToken,
    required this.roomSizeData,
  });

  @override
  _LocationTrackingPageState createState() => _LocationTrackingPageState();
}

class _LocationTrackingPageState extends State<LocationTrackingPage> {
  Map<String, dynamic> positionData = {};
  bool isLoading = true;
  bool hasError = false;
  String errorMessage = "";
  Timer? _refreshTimer;
  List<Map<String, dynamic>> positionHistory = [];
  bool showHistory = false;

  @override
  void initState() {
    super.initState();
    _fetchPositionData();
    // Set up a timer to refresh position data every 5 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _fetchPositionData();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  /// Fetch the latest position data from the device telemetry
  Future<void> _fetchPositionData() async {
    final String url =
        "https://iot.inlisol.com/api/plugins/telemetry/DEVICE/${widget.deviceId}/values/timeseries?keys=fall_position_x,fall_position_y";

    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {'X-Authorization': 'Bearer ${widget.authToken}'},
      );

      Logger.d("Raw Position Response: ${response.body}");

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        
        if (data.containsKey('fall_position_x') && 
            data.containsKey('fall_position_y') &&
            data['fall_position_x'].isNotEmpty &&
            data['fall_position_y'].isNotEmpty) {
          
          // Get the latest position values
          final double x = double.tryParse(data['fall_position_x'][0]['value'].toString()) ?? 0;
          final double y = double.tryParse(data['fall_position_y'][0]['value'].toString()) ?? 0;
          final String timestamp = data['fall_position_x'][0]['ts'].toString();
          
          // Create position data object
          final newPosition = {
            'x': x,
            'y': y,
            'timestamp': timestamp,
          };
          
          // Add to history if it's a new position
          if (positionHistory.isEmpty || 
              positionHistory.last['x'] != x || 
              positionHistory.last['y'] != y) {
            positionHistory.add(newPosition);
            // Keep only the last 10 positions
            if (positionHistory.length > 10) {
              positionHistory.removeAt(0);
            }
          }
          
          setState(() {
            positionData = newPosition;
            isLoading = false;
            hasError = false;
          });
          
          Logger.d("Position Data: $positionData");
          
        } else {
          setState(() {
            isLoading = false;
            hasError = true;
            errorMessage = "No position data available";
          });
        }
      } else {
        Logger.e("Error fetching position data: ${response.statusCode}");
        setState(() {
          isLoading = false;
          hasError = true;
          errorMessage = "Server error: ${response.statusCode}";
        });
      }
    } catch (error) {
      Logger.e("Request failed", error);
      setState(() {
        isLoading = false;
        hasError = true;
        errorMessage = error.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Location Tracking'),
        actions: [
          // Toggle history button
          IconButton(
            icon: Icon(showHistory ? Icons.history : Icons.history_toggle_off),
            tooltip: showHistory ? 'Hide History' : 'Show History',
            onPressed: () {
              setState(() {
                showHistory = !showHistory;
              });
            },
          ),
          // Manual refresh button
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Data',
            onPressed: () {
              setState(() {
                isLoading = true;
              });
              _fetchPositionData();
            },
          ),
        ],
      ),
      body: isLoading 
          ? const Center(child: CircularProgressIndicator())
          : hasError
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 48),
                      const SizedBox(height: 16),
                      const Text(
                        "Failed to load position data",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        errorMessage,
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            isLoading = true;
                            hasError = false;
                          });
                          _fetchPositionData();
                        },
                        child: const Text("Retry"),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // Room visualization
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Card(
                          elevation: 4,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              width: double.infinity,
                              height: double.infinity,
                              color: Colors.grey[200],
                              child: CustomPaint(
                                painter: RoomPainter(
                                  roomSizeData: widget.roomSizeData,
                                  currentPosition: positionData,
                                  positionHistory: showHistory ? positionHistory : [],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    
                    // Position info panel
                    Container(
                      padding: const EdgeInsets.all(16),
                      color: Colors.blue[50],
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "📍 Current Position",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _buildInfoCard(
                                  title: "X Position",
                                  value: "${positionData['x']?.toStringAsFixed(2) ?? 'N/A'} mm",
                                  icon: Icons.arrow_right_alt,
                                ),
                                const SizedBox(width: 8),
                                _buildInfoCard(
                                  title: "Y Position",
                                  value: "${positionData['y']?.toStringAsFixed(2) ?? 'N/A'} mm",
                                  icon: Icons.arrow_upward,
                                ),
                                const SizedBox(width: 8),
                                _buildInfoCard(
                                  title: "Last Updated",
                                  value: _formatTimestamp(positionData['timestamp']),
                                  icon: Icons.access_time,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "Room dimensions: ${widget.roomSizeData['length']}m × ${widget.roomSizeData['width1']}m",
                            style: TextStyle(
                              fontStyle: FontStyle.italic,
                              color: Colors.grey[700],
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildInfoCard({
    required String title,
    required String value,
    required IconData icon,
  }) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          children: [Icon(icon, color: Colors.blue),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(fontSize: 12, color: Colors.grey[700]),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimestamp(String? timestamp) {
    if (timestamp == null) return 'N/A';
    
    try {
      // Convert timestamp to milliseconds and create DateTime
      final int ts = int.parse(timestamp);
      final DateTime dateTime = DateTime.fromMillisecondsSinceEpoch(ts);
      
      // Format the time as HH:MM:SS
      return "${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}:${dateTime.second.toString().padLeft(2, '0')}";
    } catch (e) {
      return 'Invalid timestamp';
    }
  }
}

class RoomPainter extends CustomPainter {
  final Map<String, dynamic> roomSizeData;
  final Map<String, dynamic> currentPosition;
  final List<Map<String, dynamic>> positionHistory;
  
  // Add debug mode
  final bool debugMode = true;

  RoomPainter({
    required this.roomSizeData,
    required this.currentPosition,
    required this.positionHistory,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Print debug info
    if (debugMode) {
      Logger.d("Drawing room with size: $size");
      Logger.d("Current position data: $currentPosition");
      Logger.d("Room size data: $roomSizeData");
    }
    
    final Paint roomPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final Paint roomBorderPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final Paint positionPaint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.fill;

    // Get room dimensions and ensure they're not zero
    double roomLength = (roomSizeData['length'] ?? 5000).toDouble(); // in mm
    double roomWidth = (roomSizeData['width1'] ?? 4000).toDouble(); // in mm
    
    // Safety check - ensure we have non-zero dimensions
    if (roomLength <= 100) roomLength = 5000; // Default to 5m
    if (roomWidth <= 100) roomWidth = 4000;   // Default to 4m
    
    if (debugMode) {
      Logger.d("Room dimensions: ${roomLength}mm x ${roomWidth}mm");
    }

    // Scale factor to fit room within canvas, with some padding
    final double padding = 20;
    final double availableWidth = size.width - (padding * 2);
    final double availableHeight = size.height - (padding * 2);
    
    final double scaleX = availableWidth / roomLength;
    final double scaleY = availableHeight / roomWidth;
    final double scale = scaleX < scaleY ? scaleX : scaleY;
    
    if (debugMode) {
      Logger.d("Scale factor: $scale");
    }

    // Calculate scaled dimensions and position
    final double roomWidthScaled = roomWidth * scale;
    final double roomLengthScaled = roomLength * scale;
    final double offsetX = padding + (availableWidth - roomLengthScaled) / 2;
    final double offsetY = padding + (availableHeight - roomWidthScaled) / 2;

    // Draw room rectangle
    final Rect roomRect = Rect.fromLTWH(
      offsetX,
      offsetY,
      roomLengthScaled,
      roomWidthScaled,
    );
    
    if (debugMode) {
      Logger.d("Room rectangle: $roomRect");
    }

    canvas.drawRect(roomRect, roomPaint);
    canvas.drawRect(roomRect, roomBorderPaint);

    // Draw grid lines
    final Paint gridPaint = Paint()
      ..color = Colors.grey[300]!
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    // Draw vertical grid lines every meter
    for (int i = 1000; i < roomLength; i += 1000) {
      final double x = offsetX + (i / roomLength) * roomLengthScaled;
      canvas.drawLine(
        Offset(x, offsetY),
        Offset(x, offsetY + roomWidthScaled),
        gridPaint,
      );
    }

    // Draw horizontal grid lines every meter
    for (int i = 1000; i < roomWidth; i += 1000) {
      final double y = offsetY + (i / roomWidth) * roomWidthScaled;
      canvas.drawLine(
        Offset(offsetX, y),
        Offset(offsetX + roomLengthScaled, y),
        gridPaint,
      );
    }

    // Device location drawing logic
    final Offset devicePosition = Offset(
      offsetX + roomLengthScaled / 2,  // Center horizontally
      offsetY + roomWidthScaled,       // Bottom edge
    );
    
    canvas.drawCircle(devicePosition, 8, Paint()..color = Colors.blue);
    
    // Device label
    final TextPainter deviceTextPainter = TextPainter(
      text: TextSpan(
        text: 'Sensor',
        style: TextStyle(
          color: Colors.blue[800],
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    deviceTextPainter.layout();
    deviceTextPainter.paint(canvas, devicePosition + Offset(-deviceTextPainter.width/2, 10));

    // Coordinate conversion function
    Offset telemetryToCanvas(double x_mm, double y_mm) {
      final double originX = devicePosition.dx;
      final double originY = devicePosition.dy;
      
      double mappedX = originX + (x_mm * scale);
      double mappedY = originY - (y_mm * scale);
      
      if (debugMode) {
        Logger.d("Mapping ($x_mm, $y_mm)mm to canvas: (${mappedX.toStringAsFixed(1)}, ${mappedY.toStringAsFixed(1)})");
      }
      
      return Offset(mappedX, mappedY);
    }
    
    // Draw current position
    if (currentPosition.containsKey('x') && currentPosition.containsKey('y')) {
      final double x_mm = currentPosition['x']?.toDouble() ?? 0;
      final double y_mm = currentPosition['y']?.toDouble() ?? 0;
      
      if (debugMode) {
        Logger.d("Drawing position point at: ($x_mm, $y_mm)mm");
      }
      
      final Offset positionPoint = telemetryToCanvas(x_mm, y_mm);
      
      // Position marker
      canvas.drawCircle(
        positionPoint, 
        12, 
        Paint()..color = Colors.white..style = PaintingStyle.fill
      );
      canvas.drawCircle(
        positionPoint, 
        12, 
        Paint()..color = Colors.red..style = PaintingStyle.stroke..strokeWidth = 2
      );
      canvas.drawCircle(
        positionPoint, 
        8, 
        Paint()..color = Colors.red..style = PaintingStyle.fill
      );
      
      // Position label
      final TextSpan positionTextSpan = TextSpan(
        text: '(${x_mm.toStringAsFixed(0)}, ${y_mm.toStringAsFixed(0)})',
        style: TextStyle(
          color: Colors.black,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          backgroundColor: Colors.white.withOpacity(0.7),
        ),
      );
      
      final TextPainter positionTextPainter = TextPainter(
        text: positionTextSpan,
        textDirection: TextDirection.ltr,
      );
      positionTextPainter.layout();
      
      // Position text placement
      double textX = positionPoint.dx + 15;
      double textY = positionPoint.dy - 15;
      
      // Adjust text position to stay within canvas
      if (textX + positionTextPainter.width > size.width - 10) {
        textX = positionPoint.dx - positionTextPainter.width - 15;
      }
      if (textY - positionTextPainter.height < 10) {
        textY = positionPoint.dy + 15;
      }
      
      positionTextPainter.paint(canvas, Offset(textX, textY));
      
      // Connecting line
      canvas.drawLine(
        positionPoint,
        Offset(textX, textY + positionTextPainter.height/2),
        Paint()
          ..color = Colors.black
          ..strokeWidth = 1
          ..style = PaintingStyle.stroke,
      );
    } else {
      if (debugMode) {
        Logger.d("No current position data available");
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class RoomDetailsPage extends StatelessWidget {
  final String assetId;
  final String authToken;

  const RoomDetailsPage({
    super.key, 
    required this.assetId, 
    required this.authToken
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Room Details'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 20),
            
            ElevatedButton.icon(
              icon: const Icon(Icons.location_on),
              label: const Text("View Location Tracking"),
              onPressed: () {
                navigateToLocationTracking(context, assetId, authToken);
              },
            ),
          ],
        ),
      ),
    );
  }
}