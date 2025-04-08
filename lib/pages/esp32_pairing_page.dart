import 'dart:async';
import 'package:flutter/material.dart';
import 'package:esp_smartconfig/esp_smartconfig.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:inli_connect/utils/logger.dart';

class ESPPairingPage extends StatefulWidget {
  const ESPPairingPage({super.key});

  @override
  State<ESPPairingPage> createState() => _ESPPairingPageState();
}

class _ESPPairingPageState extends State<ESPPairingPage> {
  final TextEditingController _ssidController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isProvisioning = false;
  bool _obscurePassword = true;
  Timer? _timeoutTimer;
  final int _provisioningTimeout = 60;
  late Provisioner _provisioner;

  String? _bssid;
  String? _errorMessage;
  bool _isLoadingWifi = true;

  @override
  void initState() {
    super.initState();
    _fetchNetworkInfo();
  }

  Future<void> _fetchNetworkInfo() async {
    setState(() {
      _isLoadingWifi = true;
      _errorMessage = null;
    });

    try {
      // Request location permissions for Wi-Fi info on Android
      if (await Permission.location.request().isGranted) {
        final info = NetworkInfo();
        
        // Fetch Wi-Fi SSID
        String? ssid = await info.getWifiName();
        
        // Fetch BSSID
        String? bssid = await info.getWifiBSSID();

        Logger.d("Detected SSID: $ssid");
        Logger.d("Detected BSSID: $bssid");

        if (ssid != null) {
          // Remove quotes that might be added by some devices
          ssid = ssid.replaceAll('"', '');
          _ssidController.text = ssid;
        }

        setState(() {
          _bssid = bssid;
          _isLoadingWifi = false;
        });
      } else {
        setState(() {
          _errorMessage = "Location permission is required to fetch Wi-Fi info.";
          _isLoadingWifi = false;
        });
      }
    } catch (e) {
      Logger.e("Failed to get network info", e);
      setState(() {
        _errorMessage = "Could not retrieve Wi-Fi information.";
        _isLoadingWifi = false;
      });
    }
  }

  void _startProvisioning() async {
    if (_ssidController.text.isEmpty || _passwordController.text.isEmpty) {
      setState(() {
        _errorMessage = "Wi-Fi SSID and Password cannot be empty.";
      });
      return;
    }

    setState(() {
      _errorMessage = null;
      _isProvisioning = true;
    });

    _provisioner = Provisioner.espTouch();

    Logger.d("Starting SmartConfig...");
    Logger.d("Sending Wi-Fi SSID: ${_ssidController.text}");
    Logger.d("Sending Password: ${_passwordController.text}");
    Logger.d("Using BSSID: $_bssid");

    _provisioner.listen((response) {
      Logger.d("ESP32 Response Received: ${response.ipAddressText}, BSSID: ${response.bssidText}");
      if (mounted) {
        _stopProvisioning();
        _showSuccessDialog(response);
      }
    });

    _provisioner.start(ProvisioningRequest.fromStrings(
      ssid: _ssidController.text,
      bssid: _bssid ?? '00:00:00:00:00:00',
      password: _passwordController.text,
    ));

    _timeoutTimer = Timer(Duration(seconds: _provisioningTimeout), () {
      if (_isProvisioning) {
        _stopProvisioning();
        _showErrorDialog("Failed to connect to device within timeout.");
      }
    });

    _showProvisioningDialog();
  }

  void _stopProvisioning() {
    if (_provisioner.running) {
      _provisioner.stop();
      Logger.d("Stopped SmartConfig provisioning.");
    }
    _timeoutTimer?.cancel();
    setState(() {
      _isProvisioning = false;
    });
  }

  void _showProvisioningDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text("Provisioning in Progress"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text("Connecting device to Wi-Fi... Timeout in $_provisioningTimeout seconds."),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                _stopProvisioning();
                Navigator.of(context).pop();
              },
              child: const Text("Cancel"),
            ),
          ],
        );
      },
    );
  }

  void _showSuccessDialog(ProvisioningResponse response) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Device Connected"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Connected to ${_ssidController.text}"),
              const SizedBox(height: 10),
              Text("IP: ${response.ipAddressText}"),
              Text("BSSID: ${response.bssidText}"),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("OK"),
            ),
          ],
        );
      },
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Error"),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("OK"),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    _ssidController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF185856), // Your company's main color
              Color(0xFF1E6A68), // Slightly lighter teal
              Color(0xFF24A19C)  // Vibrant aqua for contrast
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),

              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(context),
              ),

              const SizedBox(height: 20),

              const Text(
                "Pair ESP32 Device",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
              ),

              const SizedBox(height: 20),

              TextField(
                controller: _ssidController,
                enabled: !_isLoadingWifi,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: "Wi-Fi SSID",
                  labelStyle: const TextStyle(color: Colors.white70),
                  border: const OutlineInputBorder(),
                  suffixIcon: _isLoadingWifi 
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : IconButton(
                        icon: const Icon(Icons.refresh, color: Colors.white),
                        onPressed: _fetchNetworkInfo,
                      ),
                ),
              ),

              const SizedBox(height: 10),

              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: "Wi-Fi Password",
                  labelStyle: const TextStyle(color: Colors.white70),
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: Colors.white),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                ),
              ),

              const SizedBox(height: 20),

              if (_errorMessage != null)
                Text(_errorMessage!, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),

              const SizedBox(height: 20),

              ElevatedButton(
                onPressed: _isProvisioning || _isLoadingWifi ? null : _startProvisioning,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.white),
                child: _isProvisioning
                    ? const CircularProgressIndicator()
                    : const Text("Start Pairing", style: TextStyle(color: Colors.black)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}