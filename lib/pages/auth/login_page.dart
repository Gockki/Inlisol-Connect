import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:inli_connect/main.dart';
// Import the device monitoring module with a proper lowercase alias
import 'package:inli_connect/device_monitoring.dart' as device_monitoring;
// Import the logging utility (create this file)
import 'package:inli_connect/utils/logger.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({Key? key}) : super(key: key);

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final FlutterSecureStorage storage = const FlutterSecureStorage();

  bool isLoading = false;
  bool _rememberMe = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
    _requestNotificationPermissions();
    _getDeviceFCMToken();
  }

  Future<void> _loadSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _rememberMe = prefs.getBool("remember_me") ?? false;
      emailController.text = prefs.getString("saved_email") ?? "";
      passwordController.text = prefs.getString("saved_password") ?? "";
    });
  }

  Future<void> _saveCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    if (_rememberMe) {
      await prefs.setString("saved_email", emailController.text);
      await prefs.setString("saved_password", passwordController.text);
      await prefs.setBool("remember_me", true);
    } else {
      await prefs.remove("saved_email");
      await prefs.remove("saved_password");
      await prefs.remove("remember_me");
    }
  }

  Future<void> _requestNotificationPermissions() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;
    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      Logger.i("Notifications allowed");
    } else {
      Logger.w("Notifications denied");
    }
  }

  Future<void> _getDeviceFCMToken() async {
    String? token = await FirebaseMessaging.instance.getToken();
    Logger.d("FCM Device Token: $token");
  }

  Future<void> _login() async {
    setState(() {
      isLoading = true;
    });

    if (emailController.text.isEmpty || passwordController.text.isEmpty) {
      _showErrorSnackbar("Email and password cannot be empty.");
      setState(() {
        isLoading = false;
      });
      return;
    }

    try {
      final url = Uri.parse('https://iot.inlisol.com/api/auth/login');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "username": emailController.text,
          "password": passwordController.text
        }),
      );

      // Check if the widget is still in the tree after async operation
      if (!mounted) return;

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final String token = responseData['token'];

        await storage.write(key: 'bearer_token', value: token);
        await _saveCredentials();

        // Call the function with the correct lowercase namespace
        device_monitoring.startDeviceMonitoring(token);

        // Store navigation context before async call
        final navigator = Navigator.of(context);
        navigator.pushReplacement(
          MaterialPageRoute(builder: (context) => const MainPage()),
        );
      } else {
        _showErrorSnackbar('Login failed. Please check your credentials.');
      }
    } catch (e, stackTrace) {
      Logger.e("Login error", e, stackTrace);
      if (mounted) {
        _showErrorSnackbar('Connection error. Please try again.');
      }
    } finally {
      // Only update state if widget is still mounted
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background Gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF244444), Color(0xFF0D7377)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),

          // Login Form
          Center(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Card(
                elevation: 10,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(25.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Title
                      const Text(
                        "InliConnect",
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF244444),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Email Field
                      TextField(
                        controller: emailController,
                        decoration: InputDecoration(
                          labelText: 'Email',
                          prefixIcon: const Icon(Icons.email),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Password Field
                      TextField(
                        controller: passwordController,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: const Icon(Icons.lock),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword ? Icons.visibility_off : Icons.visibility,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Remember Me Checkbox
                      Row(
                        children: [
                          Checkbox(
                            value: _rememberMe,
                            onChanged: (value) {
                              setState(() {
                                _rememberMe = value!;
                              });
                            },
                          ),
                          const Text("Remember Me"),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Login Button
                      ElevatedButton(
                        onPressed: isLoading ? null : _login,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF244444),
                          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 80),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: isLoading
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text(
                                'Login',
                                style: TextStyle(color: Colors.white, fontSize: 16),
                              ),
                      ),
                      const SizedBox(height: 10),

                      // Forgot Password (Placeholder)
                      TextButton(
                        onPressed: () {},
                        child: const Text("Forgot Password?", style: TextStyle(color: Colors.blue)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}