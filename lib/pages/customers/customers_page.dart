import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'users_page.dart';
import 'package:inli_connect/utils/logger.dart';

class CustomersPage extends StatefulWidget {
  const CustomersPage({super.key});

  @override
  State<CustomersPage> createState() => _CustomersPageState();
}

class _CustomersPageState extends State<CustomersPage> {
  List<dynamic> customers = [];
  List<dynamic> filteredCustomers = [];
  bool isLoading = true;
  String? authToken;
  final TextEditingController searchController = TextEditingController();

  final String apiUrl =
      "https://iot.inlisol.com/api/customers?pageSize=10&page=0&sortProperty=createdTime&sortOrder=DESC";

  final FlutterSecureStorage storage = const FlutterSecureStorage();

  @override
  void initState() {
    super.initState();
    _fetchTokenAndCustomers();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchTokenAndCustomers() async {
    String? token = await storage.read(key: 'bearer_token');

    if (!mounted) return;

    if (token == null) {
      _showLoginRequiredMessage();
      return;
    }

    setState(() {
      authToken = token;
    });

    await _fetchCustomers();
  }

  Future<void> _fetchCustomers() async {
    try {
      if (authToken == null) {
        _showLoginRequiredMessage();
        return;
      }

      final response = await http.get(
        Uri.parse(apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'X-Authorization': 'Bearer $authToken',
        },
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final decodedResponse = json.decode(response.body);
        setState(() {
          customers = decodedResponse["data"] ?? [];
          filteredCustomers = customers;
          isLoading = false;
        });

        Logger.i("Customers fetched: ${customers.length}");
      } else if (response.statusCode == 401) {
        _handleTokenExpired();
      } else {
        Logger.e("Failed to load customers. Status code: ${response.statusCode}");
        setState(() {
          isLoading = false;
        });
        _showErrorMessage("Failed to load customers. Please try again.");
      }
    } catch (e) {
      Logger.e("Error fetching customers", e);
      if (mounted) {
        setState(() => isLoading = false);
        _showErrorMessage("Network error. Please check your connection.");
      }
    }
  }

  Future<void> _handleTokenExpired() async {
    Logger.w("Token expired. Logging out...");
    await storage.delete(key: 'bearer_token');
    
    if (!mounted) return;
    
    _showLoginRequiredMessage();
  }

  void _showLoginRequiredMessage() {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Session expired. Please log in again."),
        backgroundColor: Colors.red,
      ),
    );

    // Store navigator reference before async gap
    final navigator = Navigator.of(context);
    Future.delayed(const Duration(seconds: 2), () {
      navigator.pushReplacementNamed('/login');
    });
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _filterCustomers(String query) {
    setState(() {
      filteredCustomers = customers
          .where((customer) =>
              customer['title'].toString().toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F3F3),
      appBar: AppBar(
        title: const Text("Select Customer"),
        backgroundColor: const Color(0xFF185856),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() => isLoading = true);
              _fetchCustomers();
            },
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Search Bar
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: TextField(
                    controller: searchController,
                    onChanged: _filterCustomers,
                    decoration: InputDecoration(
                      hintText: "Search Customers...",
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                searchController.clear();
                                _filterCustomers("");
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                
                // Customer count
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    children: [
                      Text(
                        '${filteredCustomers.length} Customers',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).textTheme.bodyLarge?.color?.withAlpha(178),
                        ),
                      ),
                      const Spacer(),
                      if (customers.isNotEmpty && filteredCustomers.isEmpty)
                        const Text("No matching customers", style: TextStyle(fontStyle: FontStyle.italic)),
                    ],
                  ),
                ),
                
                const SizedBox(height: 8),
                
                // Customer list
                Expanded(
                  child: filteredCustomers.isEmpty 
                      ? _buildEmptyState()
                      : RefreshIndicator(
                          onRefresh: _fetchCustomers,
                          child: ListView.builder(
                            itemCount: filteredCustomers.length,
                            itemBuilder: (context, index) {
                              final String customerId =
                                  filteredCustomers[index]['id']['id'] ?? 'Unknown ID';
                              final String customerName =
                                  filteredCustomers[index]['title'] ?? 'Unknown Customer';

                              return Card(
                                elevation: 3,
                                margin: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: ListTile(
                                  leading: const Icon(Icons.business, color: Color(0xFF185856)),
                                  title: Text(
                                    customerName,
                                    style: const TextStyle(
                                        fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                                  onTap: () {
                                    Logger.d("Navigating to UsersPage with customerId: $customerId");

                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => UsersPage(
                                          customerId: customerId,
                                          authToken: authToken ?? '',
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              );
                            },
                          ),
                        ),
                ),
              ],
            ),
    );
  }
  
  Widget _buildEmptyState() {
    // Show different empty states based on whether user is searching or not
    if (searchController.text.isNotEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              "No matching customers",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              "Try a different search term",
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    } else {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.business_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              "No customers found",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              "Try refreshing or check your connection",
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }
  }
}