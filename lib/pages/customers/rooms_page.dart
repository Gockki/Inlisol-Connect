import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'attributes_page.dart';
import 'package:inli_connect/pages/auth/login_page.dart';
import 'package:inli_connect/utils/logger.dart';

// Simple enum for device types - simplified from the original
enum DeviceType {
  vitals(1, 'Vitals'),
  fallDetector(8, 'Fall Detector');

  final int code;
  final String label;

  const DeviceType(this.code, this.label);

  static DeviceType? fromCode(int code) {
    if (code == 1) return DeviceType.vitals;
    if (code == 8) return DeviceType.fallDetector;
    return null;
  }
}

class RoomsPage extends StatefulWidget {
  final String floorId;
  final String authToken;

  const RoomsPage({super.key, required this.floorId, required this.authToken});

  @override
  _RoomsPageState createState() => _RoomsPageState();
}

class _RoomsPageState extends State<RoomsPage> {
  List<dynamic> rooms = [];
  bool isLoading = true;
  String errorMessage = "";
  final FlutterSecureStorage storage = FlutterSecureStorage();
  
  // Enhanced room metadata tracking
  Map<String, Map<String, dynamic>> roomMetadata = {};
  // Device status tracking
  Map<String, bool> deviceActivityStatus = {};
  // Device IDs for each room
  Map<String, String> roomToDeviceMap = {};
  
  String searchQuery = "";
  final TextEditingController _searchController = TextEditingController();
  // Add loading indicator state
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _fetchRooms();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchRooms() async {
    setState(() {
      isLoading = true;
      errorMessage = "";
    });
    
    final String url = "https://iot.inlisol.com/api/relations/info?fromId=${widget.floorId}&fromType=ASSET";

    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {'X-Authorization': 'Bearer ${widget.authToken}', 'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        setState(() {
          rooms = json.decode(response.body) ?? [];
          isLoading = false;
        });
        
        // Fetch detailed attributes for all rooms
        for (var room in rooms) {
          final String roomId = room['to']['id'] ?? 'Unknown ID';
          await _fetchRoomAttributes(roomId);
          await _fetchConnectedDevice(roomId);
        }
      } else {
        Logger.e("Error fetching rooms with status code: ${response.statusCode}");
        _handleError(response.statusCode);
      }
    } catch (e) {
      Logger.e("Exception fetching rooms", e);
      setState(() {
        errorMessage = "Exception: $e";
        isLoading = false;
      });
    }
  }

  Future<void> _fetchRoomAttributes(String roomId) async {
    final String url = "https://iot.inlisol.com/api/plugins/telemetry/ASSET/$roomId/values/attributes/SERVER_SCOPE";

    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {'X-Authorization': 'Bearer ${widget.authToken}', 'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> attributes = json.decode(response.body);
        
        Map<String, dynamic> metadata = {};
        
        for (var attr in attributes) {
          metadata[attr['key']] = attr['value'];
        }

        setState(() {
          roomMetadata[roomId] = metadata;
        });
      }
    } catch (e) {
      Logger.e("Exception fetching attributes for room $roomId", e);
    }
  }

  Future<void> _fetchConnectedDevice(String roomId) async {
    final String url = "https://iot.inlisol.com/api/relations/info?fromId=$roomId&fromType=ASSET";

    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {'X-Authorization': 'Bearer ${widget.authToken}', 'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> relations = json.decode(response.body);
        
        // Find the device related to this room
        for (var relation in relations) {
          if (relation['to'] != null && 
              relation['to']['entityType'] == 'DEVICE') {
            
            String deviceId = relation['to']['id'];
            String deviceName = relation['toName'] ?? 'Unknown Device';
            
            // Store the device ID for this room
            setState(() {
              roomToDeviceMap[roomId] = deviceId;
            });
            
            Logger.d("Found device: $deviceName (ID: $deviceId) for room $roomId");
            
            // Fetch the device's active status
            await _fetchDeviceActivityStatus(deviceId);
            
            break; // We found what we needed
          }
        }
      }
    } catch (e) {
      Logger.e("Exception fetching connected device for room $roomId", e);
    }
  }

  Future<void> _fetchDeviceActivityStatus(String deviceId) async {
    final String url = "https://iot.inlisol.com/api/plugins/telemetry/DEVICE/$deviceId/values/attributes/SERVER_SCOPE";

    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {'X-Authorization': 'Bearer ${widget.authToken}', 'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> attributes = json.decode(response.body);
        
        // Find the active attribute
        for (var attr in attributes) {
          if (attr['key'] == 'active') {
            bool isActive = attr['value'].toString().toLowerCase() == 'true';
            
            // Store the activity status
            setState(() {
              deviceActivityStatus[deviceId] = isActive;
            });
            
            break;
          }
        }
      }
    } catch (e) {
      Logger.e("Exception fetching activity status for device $deviceId", e);
    }
  }

  void _handleError(int statusCode) async {
    if (statusCode == 401) {
      await storage.delete(key: 'bearer_token');
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => LoginPage()));
    }
    setState(() {
      errorMessage = "Error $statusCode: Failed to fetch rooms.";
      isLoading = false;
    });
  }

  void _scanQRCode() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Scan QR Code"),
        content: SizedBox(
          width: 300,
          height: 300,
          child: Stack(
            alignment: Alignment.center,
            children: [
              MobileScanner(
                onDetect: (barcodeCapture) {
                  final Barcode? barcode = barcodeCapture.barcodes.first;
                  if (barcode?.rawValue != null) {
                    Navigator.of(context).pop();
                    _showLoadingDialog("Processing QR code...");
                    _fetchRoomBySerial(barcode!.rawValue!);
                  }
                },
              ),
              // Simple scanning guide
              Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Theme.of(context).primaryColor.withOpacity(0.6),
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                width: 200,
                height: 200,
              ),
              // Scanning indicator text
              Positioned(
                bottom: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 16, 
                        height: 16, 
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(width: 8),
                      Text(
                        "Scanning...",
                        style: TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("Cancel"),
          ),
        ],
      ),
    );
  }

  void _showLoadingDialog(String message) {
    // Set processing state
    setState(() {
      _isProcessing = true;
    });
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          content: Row(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(width: 20),
              Text(message),
            ],
          ),
        );
      },
    );
  }

  void _hideLoadingDialog() {
    setState(() {
      _isProcessing = false;
    });
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _fetchRoomBySerial(String serial) async {
    final String url = "https://iot.inlisol.com/api/tenant/assets?pageSize=100&page=0&type=Room";

    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {'X-Authorization': 'Bearer ${widget.authToken}', 'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> rooms = json.decode(response.body)['data'];

        for (var room in rooms) {
          final String roomId = room['id']['id'];
          bool found = await _checkRoomSerialNumber(roomId, serial);
          if (found) {
            _hideLoadingDialog();
            _confirmRoomLinking(roomId, room['name']);
            return;
          }
        }

        _hideLoadingDialog();
        _showError("No matching room found for serial: $serial");
      } else {
        _hideLoadingDialog();
        _handleError(response.statusCode);
      }
    } catch (e) {
      _hideLoadingDialog();
      _showError("Failed to fetch room data. Try again later.");
    }
  }

  Future<bool> _checkRoomSerialNumber(String roomId, String serial) async {
    final String attrUrl = "https://iot.inlisol.com/api/plugins/telemetry/ASSET/$roomId/values/attributes/SERVER_SCOPE";

    try {
      final response = await http.get(
        Uri.parse(attrUrl),
        headers: {'X-Authorization': 'Bearer ${widget.authToken}'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> attributes = json.decode(response.body);
        
        for (var attr in attributes) {
          if (attr['key'] == 'serialNumber' && attr['value'] == serial) {
            return true;
          }
        }
      }
    } catch (e) {
      Logger.e("Failed to fetch attributes for room $roomId", e);
    }
    return false;
  }

  void _confirmRoomLinking(String roomId, [String? roomName]) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Room Found"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Room: ${roomName ?? 'Unknown'}",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text("Do you want to link this room to the floor?"),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _showLoadingDialog("Linking room...");
              _linkRoomToFloor(roomId);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
            ),
            child: const Text("Link Room", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _linkRoomToFloor(String roomId) async {
    final String url = "https://iot.inlisol.com/api/relation";
    final Map<String, dynamic> body = {
      "from": {"entityType": "ASSET", "id": widget.floorId},
      "to": {"entityType": "ASSET", "id": roomId},
      "type": "Contains",
      "typeGroup": "COMMON"
    };

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {'X-Authorization': 'Bearer ${widget.authToken}', 'Content-Type': 'application/json'},
        body: json.encode(body),
      );

      _hideLoadingDialog();
      
      if (response.statusCode == 200) {
        _showSuccess("Room successfully linked to the floor!");
        _fetchRooms(); // Refresh room list
      } else {
        _handleError(response.statusCode);
      }
    } catch (e) {
      _hideLoadingDialog();
      _showError("Failed to link room to floor. Try again later.");
    }
  }

  void _confirmRoomUnlinking(String roomId, String roomName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirm Room Removal"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 32),
            const SizedBox(height: 16),
            Text("Are you sure you want to remove the room '$roomName' from this floor?"),
            const SizedBox(height: 8),
            const Text("This will only remove the room from this floor, not delete it from the system.",
              style: TextStyle(
                fontSize: 12, 
                fontStyle: FontStyle.italic,
                color: Colors.grey,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _showLoadingDialog("Removing room...");
              _unlinkRoomFromFloor(roomId);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text("Remove Room", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _unlinkRoomFromFloor(String roomId) async {
    final String url = "https://iot.inlisol.com/api/relation?fromId=${widget.floorId}&fromType=ASSET&toId=$roomId&toType=ASSET&relationType=Contains";

    try {
      final response = await http.delete(
        Uri.parse(url),
        headers: {'X-Authorization': 'Bearer ${widget.authToken}', 'Content-Type': 'application/json'},
      );

      _hideLoadingDialog();
      
      if (response.statusCode == 200) {
        _showSuccess("Room successfully removed from the floor!");
        _fetchRooms(); // Refresh room list
      } else {
        _handleError(response.statusCode);
      }
    } catch (e) {
      _hideLoadingDialog();
      _showError("Failed to remove room from floor: $e");
      Logger.e("Error removing room from floor", e);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  // Filter rooms based on search query
  List<dynamic> get filteredRooms {
    if (searchQuery.isEmpty) {
      return rooms;
    }
    return rooms.where((room) {
      final String roomName = room['toName'] ?? 'Unknown Room';
      final String roomId = room['to']['id'] ?? '';
      final Map<String, dynamic> metadata = roomMetadata[roomId] ?? {};
      final String serial = metadata['serialNumber'] ?? '';
      final String physicalRoomName = metadata['physicalRoomName'] ?? '';
      
      return roomName.toLowerCase().contains(searchQuery.toLowerCase()) ||
            serial.toLowerCase().contains(searchQuery.toLowerCase()) ||
            physicalRoomName.toLowerCase().contains(searchQuery.toLowerCase());
    }).toList();
  }

  Widget _buildRoomItem(dynamic room, BuildContext context) {
    final String roomId = room['to']['id'] ?? 'Unknown ID';
    final String roomName = room['toName'] ?? 'Unknown Room';
    final Map<String, dynamic> metadata = roomMetadata[roomId] ?? {};
    final String deviceId = roomToDeviceMap[roomId] ?? '';
    final bool isDeviceActive = deviceActivityStatus[deviceId] ?? false;
    
    // Get device type and physical room name
    DeviceType? deviceType;
    String physicalRoomName = metadata['physicalRoomName'] ?? '';
    
    if (metadata['device_type'] != null) {
      int deviceTypeCode = int.tryParse(metadata['device_type'].toString()) ?? 0;
      deviceType = DeviceType.fromCode(deviceTypeCode);
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 8.0),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AttributesPage(
                roomId: roomId,
                authToken: widget.authToken,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              // Activity Status Indicator
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: isDeviceActive ? Colors.green : Colors.red,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 16),
              
              // Room Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      roomName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    // First row: Device Type + Physical Room Name
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            deviceType?.label ?? 'Unknown',
                            style: const TextStyle(
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (physicalRoomName.isNotEmpty) ...[
                          Text(
                            ' · ',
                            style: TextStyle(
                              color: Colors.grey[600],
                            ),
                          ),
                          Flexible(
                            child: Text(
                              physicalRoomName,
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: Colors.grey[600],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                    // Second row: Serial Number
                    const SizedBox(height: 2),
                    Text(
                      metadata['serialNumber'] ?? 'No Serial',
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontSize: 14,
                        fontFamily: 'Monospace',
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              
              // Actions Menu
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                onSelected: (value) {
                  if (value == 'delete') {
                    _confirmRoomUnlinking(roomId, roomName);
                  } else if (value == 'details') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AttributesPage(
                          roomId: roomId,
                          authToken: widget.authToken,
                        ),
                      ),
                    );
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'details',
                    child: Row(
                      children: [
                        Icon(Icons.info_outline),
                        SizedBox(width: 8),
                        Text('View Details'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Remove'),
                      ],
                    ),
                  ),
                ],
              ),
              
              // Forward indicator
              const Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Colors.grey,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Room'),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: _scanQRCode,
            tooltip: 'Scan QR Code',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchRooms,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search rooms by name or serial',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            searchQuery = "";
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Theme.of(context).primaryColor),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
              onChanged: (value) {
                setState(() {
                  searchQuery = value;
                });
              },
            ),
          ),
          
          // Room count
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                Text(
                  '${filteredRooms.length} Rooms',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).textTheme.bodyLarge?.color?.withOpacity(0.7),
                  ),
                ),
                const Spacer(),
                if (rooms.isNotEmpty && filteredRooms.isEmpty)
                  const Text("No matching rooms", style: TextStyle(fontStyle: FontStyle.italic)),
              ],
            ),
          ),
          
          const SizedBox(height: 8),
          
          // Main content
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : errorMessage.isNotEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline, color: Colors.red, size: 48),
                            const SizedBox(height: 16),
                            Text(errorMessage, style: const TextStyle(color: Colors.red)),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _fetchRooms,
                              child: const Text("Try Again"),
                            ),
                          ],
                        ),
                      )
                    : rooms.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.meeting_room_outlined, size: 64, color: Colors.grey),
                                const SizedBox(height: 16),
                                const Text(
                                  "No rooms found",
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  "Scan a QR code to add a room",
                                  style: TextStyle(color: Colors.grey),
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton.icon(
                                  icon: const Icon(Icons.qr_code_scanner),
                                  label: const Text("Scan QR Code"),
                                  onPressed: _scanQRCode,
                                ),
                              ],
                            ),
                          )
                        : Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8.0),
                            child: ListView.builder(
                              itemCount: filteredRooms.length,
                              itemBuilder: (context, index) {
                                return _buildRoomItem(filteredRooms[index], context);
                              },
                            ),
                          ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _scanQRCode,
        tooltip: 'Add Room',
        child: const Icon(Icons.add),
      ),
    );
  }
}