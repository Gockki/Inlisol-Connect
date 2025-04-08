import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'customers/customers_page.dart';
import 'esp32_pairing_page.dart';
import 'settings_page.dart';
import 'package:inli_connect/utils/logger.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String userName = "User"; 
  int activeDevices = 0;
  bool isLoading = true;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _fetchActiveDevices();
    _startAutoRefresh();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _startAutoRefresh() {
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _fetchActiveDevices();
    });
  }

  Future<void> _fetchActiveDevices() async {
    String? token = await _storage.read(key: 'bearer_token');
    if (token == null) {
      setState(() {
        isLoading = false;
      });
      return;
    }

    final url = Uri.parse("https://iot.inlisol.com/api/tenant/deviceInfos?pageSize=50&page=0&sortProperty=createdTime&sortOrder=DESC&active=true");

    try {
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'X-Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> devices = jsonDecode(response.body)['data'];
        setState(() {
          activeDevices = devices.length;
          isLoading = false;
        });
      } else {
        Logger.w("Failed to fetch active devices: ${response.statusCode}");
        setState(() {
          isLoading = false;
        });
      }
    } catch (error) {
      Logger.e("Error fetching devices", error);
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Icon(Icons.home, color: Colors.white, size: 30),
        backgroundColor: const Color(0xFF185856),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),

            // Welcome Message
            Text(
              "Welcome back, $userName! 👋",
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),

            // Active Devices Card
            Card(
              elevation: 4,
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    const Icon(Icons.devices, color: Color(0xFF185856), size: 30),
                    const SizedBox(width: 10),
                    isLoading
                        ? const CircularProgressIndicator()
                        : Text(
                            "Active Devices: $activeDevices",
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 30),

            // Navigation Tiles with Better Colors
            _buildNavigationTile(
              context,
              title: "Residents",
              icon: Icons.people,
              color: const Color(0xFF2C3E50), // Dark Slate Blue
              destination: const CustomersPage(),
            ),
            _buildNavigationTile(
              context,
              title: "ESP32 Pairing",
              icon: Icons.wifi,
              color: const Color(0xFF34495E), // Muted Dark Blue
              destination: const ESPPairingPage(),
            ),
            _buildNavigationTile(
              context,
              title: "Settings",
              icon: Icons.settings,
              color: const Color(0xFF566573), // Modern Grey
              destination: const SettingsPage(),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const HomePage()),
            (Route<dynamic> route) => false,
          );
        },
        child: const Icon(Icons.home),
        backgroundColor: const Color(0xFF185856),
      ),
    );
  }

  Widget _buildNavigationTile(BuildContext context, {required String title, required IconData icon, required Color color, required Widget destination}) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => destination));
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
          child: Row(
            children: [
              Icon(icon, size: 30, color: color),
              const SizedBox(width: 15),
              Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
              const Spacer(),
              const Icon(Icons.arrow_forward_ios, size: 20, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}