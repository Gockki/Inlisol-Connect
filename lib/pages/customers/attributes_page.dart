import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:inli_connect/pages/customers/location_tracking.dart'; 

class AttributesPage extends StatefulWidget {
  final String roomId;
  final String authToken;

  const AttributesPage({super.key, required this.roomId, required this.authToken});

  @override
  _AttributesPageState createState() => _AttributesPageState();
}

class _AttributesPageState extends State<AttributesPage> {
  Map<String, dynamic> roomSizeData = {};
  Map<String, dynamic> bedInfoData = {};
  bool isLoading = true;
  bool hasError = false;
  String errorMessage = "";
  final _formKey = GlobalKey<FormState>();

  // Persistent controllers for editing
  late TextEditingController enableController;
  late TextEditingController lengthController;
  late TextEditingController width1Controller;
  late TextEditingController width2Controller;
  late TextEditingController bedLengthController;
  late TextEditingController bedWidthController;
  late TextEditingController bedXController;
  late TextEditingController bedYController;

  @override
  void initState() {
    super.initState();
    // Initialize controllers with empty values first
    enableController = TextEditingController();
    lengthController = TextEditingController();
    width1Controller = TextEditingController();
    width2Controller = TextEditingController();
    bedLengthController = TextEditingController();
    bedWidthController = TextEditingController();
    bedXController = TextEditingController();
    bedYController = TextEditingController();
    
    _fetchAttributes();
  }

  @override
  void dispose() {
    // Dispose all controllers to prevent memory leaks
    enableController.dispose();
    lengthController.dispose();
    width1Controller.dispose();
    width2Controller.dispose();
    bedLengthController.dispose();
    bedWidthController.dispose();
    bedXController.dispose();
    bedYController.dispose();
    super.dispose();
  }

  /// Fetch room attributes (room_size & bed_info)
  Future<void> _fetchAttributes() async {
    final String url =
        "https://iot.inlisol.com/api/plugins/telemetry/ASSET/${widget.roomId}/values/attributes/SERVER_SCOPE";

    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {'X-Authorization': 'Bearer ${widget.authToken}'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);

        for (var item in data) {
          if (item['key'] == 'room_size') {
            roomSizeData = Map<String, dynamic>.from(item['value']);
          } else if (item['key'] == 'bed_info') {
            bedInfoData = Map<String, dynamic>.from(item['value']);
          }
        }

        // Update controllers with current values
        enableController.text = roomSizeData['enable']?.toString() ?? "false";
        lengthController.text = roomSizeData['length']?.toString() ?? "";
        width1Controller.text = roomSizeData['width1']?.toString() ?? "";
        width2Controller.text = roomSizeData['width2']?.toString() ?? "";
        bedLengthController.text = bedInfoData['bed_length']?.toString() ?? "";
        bedWidthController.text = bedInfoData['bed_width']?.toString() ?? "";
        bedXController.text = bedInfoData['bed_x']?.toString() ?? "";
        bedYController.text = bedInfoData['bed_y']?.toString() ?? "";

        setState(() {
          isLoading = false;
          hasError = false;
        });
      } else {
        setState(() {
          isLoading = false;
          hasError = true;
          errorMessage = "Server error: ${response.statusCode}";
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to load attributes (${response.statusCode})"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (error) {
      setState(() {
        isLoading = false;
        hasError = true;
        errorMessage = error.toString();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Failed to load attributes: $error"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Update room attributes
  Future<void> _updateAttributes() async {
    setState(() {
      isLoading = true;
    });
    
    final String url =
        "https://iot.inlisol.com/api/plugins/telemetry/ASSET/${widget.roomId}/SERVER_SCOPE";

    try {
      // Clean input values before parsing (replace comma with dot for decimal)
      String cleanLength = lengthController.text.trim().replaceAll(',', '.');
      String cleanWidth1 = width1Controller.text.trim().replaceAll(',', '.');
      String cleanWidth2 = width2Controller.text.trim().replaceAll(',', '.');
      String cleanBedLength = bedLengthController.text.trim().replaceAll(',', '.');
      String cleanBedWidth = bedWidthController.text.trim().replaceAll(',', '.');
      String cleanBedX = bedXController.text.trim().replaceAll(',', '.');
      String cleanBedY = bedYController.text.trim().replaceAll(',', '.');
      
      // Update values with better validation for decimal and negative numbers
      roomSizeData = {
        "enable": enableController.text.toLowerCase() == 'true',
        "length": double.tryParse(cleanLength) ?? roomSizeData['length'] ?? 0,
        "width1": double.tryParse(cleanWidth1) ?? roomSizeData['width1'] ?? 0,
        "width2": double.tryParse(cleanWidth2) ?? roomSizeData['width2'] ?? 0,
      };

      bedInfoData = {
        "bed_length": double.tryParse(cleanBedLength) ?? bedInfoData['bed_length'] ?? 0,
        "bed_width": double.tryParse(cleanBedWidth) ?? bedInfoData['bed_width'] ?? 0,
        "bed_x": double.tryParse(cleanBedX) ?? bedInfoData['bed_x'] ?? 0,
        "bed_y": double.tryParse(cleanBedY) ?? bedInfoData['bed_y'] ?? 0,
      };

      final Map<String, dynamic> body = {
        'room_size': roomSizeData,
        'bed_info': bedInfoData,
      };

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'X-Authorization': 'Bearer ${widget.authToken}',
          'Content-Type': 'application/json',
        },
        body: json.encode(body),
      );

      setState(() {
        isLoading = false;
      });

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Attributes Updated Successfully"),
            backgroundColor: Color(0xFF185856),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to update attributes (${response.statusCode})"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (error) {
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error: $error"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  /// Get the associated device ID for a room
  Future<String> _getAssociatedDeviceId(String roomId) async {
    final String url = 
        "https://iot.inlisol.com/api/relations/info?fromId=$roomId&fromType=ASSET";

    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {'X-Authorization': 'Bearer ${widget.authToken}'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> relations = json.decode(response.body);
        
        // Find the first device relation
        for (var relation in relations) {
          if (relation['to']['entityType'] == 'DEVICE') {
            return relation['to']['id'];
          }
        }
      }
      return ''; // Return empty string if no device found
    } catch (error) {
      return '';
    }
  }
  
  /// Navigate to the location tracking page
  void _navigateToLocationTracking() async {
    setState(() {
      isLoading = true;
    });
    
    String deviceId = await _getAssociatedDeviceId(widget.roomId);
    
    setState(() {
      isLoading = false;
    });
    
    if (deviceId.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => LocationTrackingPage(
            roomId: widget.roomId,
            deviceId: deviceId,
            authToken: widget.authToken,
            roomSizeData: roomSizeData,
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("No tracking device associated with this room"),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Company color
    const Color companyColor = Color(0xFF185856);
    
    return Scaffold(
      appBar: AppBar(
        backgroundColor: companyColor,
        foregroundColor: Colors.white,
        title: const Text('Modify Room Attributes'),
        actions: [
          // Added location tracking button in app bar
          IconButton(
            icon: const Icon(Icons.location_on),
            tooltip: 'Location Tracking',
            onPressed: _navigateToLocationTracking,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Data',
            onPressed: () {
              setState(() {
                isLoading = true;
              });
              _fetchAttributes();
            },
          ),
        ],
      ),
      body: isLoading 
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF185856)),
              )
            )
          : hasError
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 48),
                      const SizedBox(height: 16),
                      const Text(
                        "Failed to load data",
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
                        style: ElevatedButton.styleFrom(
                          backgroundColor: companyColor,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () {
                          setState(() {
                            isLoading = true;
                            hasError = false;
                          });
                          _fetchAttributes();
                        },
                        child: const Text("Retry"),
                      ),
                    ],
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Form(
                    key: _formKey,
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Room Size Section
                          Card(
                            elevation: 2,
                            margin: const EdgeInsets.only(bottom: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: const BorderSide(color: companyColor, width: 1),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    "🏠 Room Size",
                                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: companyColor),
                                  ),
                                  const SizedBox(height: 16),
                                  DropdownButtonFormField<String>(
                                    value: enableController.text.toLowerCase() == 'true' ? 'true' : 'false',
                                    decoration: const InputDecoration(
                                      labelText: 'Enable',
                                      border: OutlineInputBorder(),
                                      focusedBorder: OutlineInputBorder(
                                        borderSide: BorderSide(color: companyColor),
                                      ),
                                      labelStyle: TextStyle(color: companyColor),
                                    ),
                                    items: const [
                                      DropdownMenuItem(value: 'true', child: Text('Yes (true)')),
                                      DropdownMenuItem(value: 'false', child: Text('No (false)')),
                                    ],
                                    onChanged: (value) {
                                      if (value != null) {
                                        enableController.text = value;
                                      }
                                    },
                                  ),
                                  const SizedBox(height: 16),
                                  TextFormField(
                                    controller: lengthController,
                                    decoration: const InputDecoration(
                                      labelText: 'Length',
                                      helperText: 'Enter a number (decimals allowed)',
                                      border: OutlineInputBorder(),
                                      focusedBorder: OutlineInputBorder(
                                        borderSide: BorderSide(color: companyColor),
                                      ),
                                      labelStyle: TextStyle(color: companyColor),
                                    ),
                                    keyboardType: TextInputType.numberWithOptions(decimal: true, signed: true),
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Please enter a value';
                                      }
                                      // Allow comma as decimal separator
                                      String cleanValue = value.trim().replaceAll(',', '.');
                                      if (double.tryParse(cleanValue) == null) {
                                        return 'Please enter a valid number';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 16),
                                  TextFormField(
                                    controller: width1Controller,
                                    decoration: const InputDecoration(
                                      labelText: 'Width1',
                                      helperText: 'Enter a number (decimals allowed)',
                                      border: OutlineInputBorder(),
                                      focusedBorder: OutlineInputBorder(
                                        borderSide: BorderSide(color: companyColor),
                                      ),
                                      labelStyle: TextStyle(color: companyColor),
                                    ),
                                    keyboardType: TextInputType.numberWithOptions(decimal: true, signed: true),
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Please enter a value';
                                      }
                                      // Allow comma as decimal separator
                                      String cleanValue = value.trim().replaceAll(',', '.');
                                      if (double.tryParse(cleanValue) == null) {
                                        return 'Please enter a valid number';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 16),
                                  TextFormField(
                                    controller: width2Controller,
                                    decoration: const InputDecoration(
                                      labelText: 'Width2',
                                      helperText: 'Enter a number (decimals allowed)',
                                      border: OutlineInputBorder(),
                                      focusedBorder: OutlineInputBorder(
                                        borderSide: BorderSide(color: companyColor),
                                      ),
                                      labelStyle: TextStyle(color: companyColor),
                                    ),
                                    keyboardType: TextInputType.numberWithOptions(decimal: true, signed: true),
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Please enter a value';
                                      }
                                      // Allow comma as decimal separator
                                      String cleanValue = value.trim().replaceAll(',', '.');
                                      if (double.tryParse(cleanValue) == null) {
                                        return 'Please enter a valid number';
                                      }
                                      return null;
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Bed Info Section
                          Card(
                            elevation: 2,
                            margin: const EdgeInsets.only(bottom: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: const BorderSide(color: companyColor, width: 1),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    "🛏 Bed Info",
                                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: companyColor),
                                  ),
                                  const SizedBox(height: 16),
                                  TextFormField(
                                    controller: bedLengthController,
                                    decoration: const InputDecoration(
                                      labelText: 'Bed Length',
                                      helperText: 'Enter a number (decimals allowed)',
                                      border: OutlineInputBorder(),
                                      focusedBorder: OutlineInputBorder(
                                        borderSide: BorderSide(color: companyColor),
                                      ),
                                      labelStyle: TextStyle(color: companyColor),
                                    ),
                                    keyboardType: TextInputType.numberWithOptions(decimal: true, signed: true),
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Please enter a value';
                                      }
                                      // Allow comma as decimal separator
                                      String cleanValue = value.trim().replaceAll(',', '.');
                                      if (double.tryParse(cleanValue) == null) {
                                        return 'Please enter a valid number';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 16),
                                  TextFormField(
                                    controller: bedWidthController,
                                    decoration: const InputDecoration(
                                      labelText: 'Bed Width',
                                      helperText: 'Enter a number (decimals allowed)',
                                      border: OutlineInputBorder(),
                                      focusedBorder: OutlineInputBorder(
                                        borderSide: BorderSide(color: companyColor),
                                      ),
                                      labelStyle: TextStyle(color: companyColor),
                                    ),
                                    keyboardType: TextInputType.numberWithOptions(decimal: true, signed: true),
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Please enter a value';
                                      }
                                      // Allow comma as decimal separator
                                      String cleanValue = value.trim().replaceAll(',', '.');
                                      if (double.tryParse(cleanValue) == null) {
                                        return 'Please enter a valid number';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 16),
                                  TextFormField(
                                    controller: bedXController,
                                    decoration: const InputDecoration(
                                      labelText: 'Bed X Position',
                                      helperText: 'Enter a number (decimals allowed)',
                                      border: OutlineInputBorder(),
                                      focusedBorder: OutlineInputBorder(
                                        borderSide: BorderSide(color: companyColor),
                                      ),
                                      labelStyle: TextStyle(color: companyColor),
                                    ),
                                    keyboardType: TextInputType.numberWithOptions(decimal: true, signed: true),
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Please enter a value';
                                      }
                                      // Allow comma as decimal separator
                                      String cleanValue = value.trim().replaceAll(',', '.');
                                      if (double.tryParse(cleanValue) == null) {
                                        return 'Please enter a valid number';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 16),
                                  TextFormField(
                                    controller: bedYController,
                                    decoration: const InputDecoration(
                                      labelText: 'Bed Y Position',
                                      helperText: 'Enter a number (decimals allowed)',
                                      border: OutlineInputBorder(),
                                      focusedBorder: OutlineInputBorder(
                                        borderSide: BorderSide(color: companyColor),
                                      ),
                                      labelStyle: TextStyle(color: companyColor),
                                    ),
                                    keyboardType: TextInputType.numberWithOptions(decimal: true, signed: true),
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Please enter a value';
                                      }
                                      // Allow comma as decimal separator
                                      String cleanValue = value.trim().replaceAll(',', '.');
                                      if (double.tryParse(cleanValue) == null) {
                                        return 'Please enter a valid number';
                                      }
                                      return null;
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Location tracking button
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.location_on, color: companyColor),
                              label: const Text(
                                "View Location Tracking",
                                style: TextStyle(fontSize: 16, color: companyColor),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: companyColor),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              onPressed: _navigateToLocationTracking,
                            ),
                          ),
                          const SizedBox(height: 16),
                          
                          // Update Button
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: companyColor,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              onPressed: () {
                                if (_formKey.currentState!.validate()) {
                                  _updateAttributes();
                                }
                              },
                              child: const Text(
                                "Update Attributes",
                                style: TextStyle(fontSize: 16),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
    );
  }
}