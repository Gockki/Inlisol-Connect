import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _isDarkMode = false;

  @override
  void initState() {
    super.initState();
    _loadThemePreference();
  }

  Future<void> _loadThemePreference() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarkMode = prefs.getBool('isDarkMode') ?? false;
    });
  }

  Future<void> _toggleTheme(bool value) async {
    setState(() {
      _isDarkMode = value;
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', _isDarkMode);

    (context as Element).reassemble(); // ✅ Force app rebuild
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Settings")),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Dark Mode Toggle
          ListTile(
            title: const Text("🌙 Dark Mode"),
            trailing: Switch(
              value: _isDarkMode,
              onChanged: _toggleTheme,
            ),
          ),
          const Divider(height: 30, thickness: 1),

          // Inlisol Contact Information
          const Text(
            "Inlisol Contact Information",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          const ListTile(
            leading: Icon(Icons.email, color: Colors.blue),
            title: Text("support@inlisol.com"),
          ),
          const ListTile(
            leading: Icon(Icons.phone, color: Colors.green),
            title: Text("+358 457 8302156"),
          ),
          const Divider(height: 30, thickness: 1),

          // App Information
          const Text(
            "App Information",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          const ListTile(
            leading: Icon(Icons.info, color: Colors.orange),
            title: Text("Inli Connect"),
            subtitle: Text("Version: 1.0.0"),
          ),
          const Divider(height: 30, thickness: 1),

          // About Inlisol
          const Text(
            "About Inlisol",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              "Inlisol provides IoT solutions for healthcare and smart monitoring."
              "Our goal is to improve patient safety and care.",
              textAlign: TextAlign.justify,
            ),
          ),
        ],
      ),
    );
  }
}
