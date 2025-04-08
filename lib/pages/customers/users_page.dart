import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'departments_page.dart';
import 'package:inli_connect/pages/auth/login_page.dart';

class UsersPage extends StatefulWidget {
  final String customerId;
  final String authToken;

  const UsersPage({super.key, required this.customerId, required this.authToken});

  @override
  State<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> {
  List<dynamic> users = [];
  bool isLoading = true;
  String errorMessage = "";
  final FlutterSecureStorage storage = const FlutterSecureStorage();

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  Future<void> _fetchUsers() async {
    final url = "https://iot.inlisol.com/api/customer/${widget.customerId}/users?pageSize=10&page=0&sortProperty=createdTime&sortOrder=DESC";

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
          users = decodedResponse["data"] ?? [];
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
        title: const Text('Select User'),
        backgroundColor: const Color(0xFF185856),
      ),
      body: Column(
        children: [
          if (errorMessage.isNotEmpty) 
            Padding(
              padding: const EdgeInsets.all(10.0),
              child: ElevatedButton(
                onPressed: () => _fetchUsers(),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text("Retry Fetching Users"),
              ),
            ),

          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator()) 
                : users.isEmpty
                    ? const Center(child: Text("No users found"))
                    : ListView.builder(
                        itemCount: users.length,
                        itemBuilder: (context, index) {
                          final user = users[index];
                          final String userId = user['id']['id'] ?? 'Unknown ID';
                          final String email = user['email'] ?? 'No Email';

                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            elevation: 3,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ListTile(
                              leading: const Icon(Icons.person, color: Color(0xFF185856)),
                              title: Text(
                                email,
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              subtitle: Text("User ID: $userId"),
                              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => DepartmentsPage(
                                      userId: userId,
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