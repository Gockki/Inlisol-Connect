import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'rooms_page.dart';
import 'package:inli_connect/pages/auth/login_page.dart'; // Ensure login page is available
import 'package:inli_connect/utils/logger.dart'; // Added logger import

class FloorsPage extends StatefulWidget {
  final String departmentId;
  final String authToken; // ✅ Ensure authToken is used dynamically

  const FloorsPage({super.key, required this.departmentId, required this.authToken});

  @override
  State<FloorsPage> createState() => _FloorsPageState();
}

class _FloorsPageState extends State<FloorsPage> {
  List<dynamic> floors = [];
  bool isLoading = true;
  String errorMessage = "";
  final FlutterSecureStorage storage = FlutterSecureStorage();

  @override
  void initState() {
    super.initState();
    Logger.i("FloorsPage initState() called! Fetching floors...");
    _fetchFloors();
  }

  Future<void> _fetchFloors() async {
    final url =
        "https://iot.inlisol.com/api/relations/info?fromId=${widget.departmentId}&fromType=ASSET";

    Logger.d("Fetching floors for Department ID: ${widget.departmentId}");
    Logger.d("🔑 Using Auth Token: ${widget.authToken}");

    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'X-Authorization': 'Bearer ${widget.authToken}', // ✅ Use dynamic token
          'Content-Type': 'application/json',
        },
      );

      Logger.d("HTTP Status: ${response.statusCode}");
      Logger.d("Raw Response: ${response.body}");

      if (response.statusCode == 200) {
        final decodedResponse = json.decode(response.body);
        Logger.d("Decoded JSON: $decodedResponse");

        setState(() {
          floors = decodedResponse ?? [];
          isLoading = false;
        });
        
        Logger.i("Floors fetched successfully: ${floors.length} found");
      } else if (response.statusCode == 401) {
        _handleTokenExpired();
      } else {
        setState(() {
          errorMessage = "Error ${response.statusCode}: ${response.body}";
          isLoading = false;
        });
        
        Logger.e("API Error ${response.statusCode}: ${response.body}");
      }
    } catch (e) {
      setState(() {
        errorMessage = "Exception: $e";
        isLoading = false;
      });
      
      Logger.e("Exception fetching floors", e);
    }
  }

  void _handleTokenExpired() async {
    Logger.w("Token expired. Logging out...");
    await storage.delete(key: 'bearer_token'); // Remove expired token

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Session expired. Please log in again."),
        backgroundColor: Colors.red,
      ),
    );

    Future.delayed(const Duration(seconds: 2), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => LoginPage()), // Redirect to LoginPage
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    Logger.d("FloorsPage build() called!");

    return Scaffold(
      appBar: AppBar(title: const Text('Select Floor')),
      body: Column(
        children: [
          if (errorMessage.isNotEmpty || floors.isEmpty)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: ElevatedButton(
                onPressed: () {
                  Logger.d("Manual refresh triggered");
                  setState(() => isLoading = true);
                  _fetchFloors();
                },
                child: const Text("Refresh Floors"),
              ),
            ),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : errorMessage.isNotEmpty
                    ? Center(child: Text(errorMessage, style: const TextStyle(color: Colors.red)))
                    : floors.isEmpty
                        ? const Center(child: Text("No floors found"))
                        : ListView.builder(
                            itemCount: floors.length,
                            itemBuilder: (context, index) {
                              final floor = floors[index];
                              final String floorId = floor['to']['id'] ?? 'Unknown ID';
                              final String floorName = floor['toName'] ?? 'Unknown Floor';

                              return ListTile(
                                title: Text(floorName),
                                trailing: const Icon(Icons.arrow_forward),
                                onTap: () {
                                  Logger.d("Navigating to RoomsPage with floorId: $floorId and authToken: ${widget.authToken}");

                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => RoomsPage(
                                        floorId: floorId, // ✅ Ensure correct ID is passed
                                        authToken: widget.authToken, // ✅ Ensure correct token is passed
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}