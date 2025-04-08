// main.dart
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:inli_connect/pages/home_page.dart';
import 'package:inli_connect/pages/auth/login_page.dart';
import 'package:inli_connect/device_monitoring.dart' as device_monitor;
import 'package:inli_connect/background_worker.dart';
import 'package:workmanager/workmanager.dart';

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

void setupFirebaseMessaging() {
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {});
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await Firebase.initializeApp();
  setupFirebaseMessaging();
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Initialize Workmanager with our callback dispatcher
  await Workmanager().initialize(
    callbackDispatcher,
    isInDebugMode:false // Set to false in production
  );

  runApp(await MyApp.create());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key, required this.homeScreen, required this.isDarkMode}) : super(key: key);

  static Future<MyApp> create() async {
    final FlutterSecureStorage storage = FlutterSecureStorage();
    String? token = await storage.read(key: 'bearer_token');
    bool isDarkMode = await _loadThemePreference();

    return MyApp(homeScreen: token != null ? const MainPage() : LoginPage(), isDarkMode: isDarkMode);
  }

  static Future<bool> _loadThemePreference() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('isDarkMode') ?? false; // Default to Light Mode
  }

  final Widget homeScreen;
  final bool isDarkMode;

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  late bool _isDarkMode;

  @override
  void initState() {
    super.initState();
    _isDarkMode = widget.isDarkMode;
    
    // Register as an observer to detect app lifecycle changes
    WidgetsBinding.instance.addObserver(this);
  }
  
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || 
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      // App is going to background
      device_monitor.appSentToBackground();
    } else if (state == AppLifecycleState.resumed) {
      // App is coming to foreground
      device_monitor.appReturnedToForeground();
    }
  }

  void _toggleTheme() async {
    setState(() {
      _isDarkMode = !_isDarkMode;
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', _isDarkMode);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Inli Connect',
      theme: ThemeData.light(),
      darkTheme: ThemeData.dark(),
      themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: widget.homeScreen,
    );
  }
}

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  final FlutterSecureStorage storage = FlutterSecureStorage();

  @override
  void initState() {
    super.initState();
    _loadToken();
  }

  Future<void> _loadToken() async {
    String? token = await storage.read(key: 'bearer_token');

    // Start device monitoring if token exists
    if (token != null) {
      device_monitor.startDeviceMonitoring(token);
    }
  }

  Future<void> _logout() async {
    // Stop all monitoring
    device_monitor.stopAllMonitoring();
    
    // Clear token
    await storage.delete(key: 'bearer_token');

    // Navigate to login
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => LoginPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Image.asset(
          'assets/images/Inlisol_logo-black-no-tag-line.png',
          height: 50,
        ),
        backgroundColor: const Color(0xFF185856),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: _logout,
          ),
        ],
      ),
      body: const HomePage(),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Only navigate if we're not already on the main page
          if (ModalRoute.of(context)?.settings.name != '/main') {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(
                builder: (context) => const MainPage(),
                settings: const RouteSettings(name: '/main'),
              ),
              (Route<dynamic> route) => false,
            );
          }
        },
        child: const Icon(Icons.home),
        backgroundColor: const Color(0xFF185856),
      ),
    );
  }
}