import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'floors_page.dart';
import 'package:inli_connect/pages/auth/login_page.dart';

class DepartmentsPage extends StatefulWidget {
  final String userId;
  final String authToken;

  const DepartmentsPage({super.key, required this.userId, required this.authToken});

  @override
  State<DepartmentsPage> createState() => _DepartmentsPageState();
}

class _DepartmentsPageState extends State<DepartmentsPage> {
  List<dynamic> departments = [];
  bool isLoading = true;
  String errorMessage = "";
  final FlutterSecureStorage storage = const FlutterSecureStorage();

  @override
  void initState() {
    super.initState();
    _fetchDepartments();
  }

  Future<void> _fetchDepartments() async {
    final url =
        "https://iot.inlisol.com/api/relations/info?fromId=${widget.userId}&fromType=USER";

    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'X-Authorization': 'Bearer ${widget.authToken}',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final decodedResponse = json.decode(response.body);
        setState(() {
          departments = decodedResponse ?? [];
          isLoading = false;
        });
      } else if (response.statusCode == 401) {
        _handleTokenExpired();
      } else {
        setState(() {
          errorMessage = "Error ${response.statusCode}: ${response.body}";
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = "Exception: $e";
        isLoading = false;
      });
    }
  }

  void _handleTokenExpired() async {
    await storage.delete(key: 'bearer_token');

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Session expired. Please log in again."),
        backgroundColor: Colors.red,
      ),
    );

    Future.delayed(const Duration(seconds: 2), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => LoginPage()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F3F3),
      appBar: AppBar(
        title: const Text('Select Department'),
        backgroundColor: const Color(0xFF185856),
      ),
      body: Column(
        children: [
          if (errorMessage.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(10.0),
              child: ElevatedButton(
                onPressed: _fetchDepartments,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text("Retry Fetching Departments"),
              ),
            ),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : departments.isEmpty
                    ? const Center(child: Text("No departments found"))
                    : ListView.builder(
                        itemCount: departments.length,
                        itemBuilder: (context, index) {
                          final department = departments[index];
                          final String departmentId = department['to']['id'] ?? 'Unknown ID';
                          final String departmentName = department['toName'] ?? 'Unknown Department';

                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            elevation: 3,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ListTile(
                              leading: const Icon(Icons.apartment, color: Color(0xFF185856)),
                              title: Text(
                                departmentName,
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => FloorsPage(
                                      departmentId: departmentId,
                                      authToken: widget.authToken,
                                    ),
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
