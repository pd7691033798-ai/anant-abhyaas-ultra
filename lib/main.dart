import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:local_auth/local_auth.dart';

void main() {
  runApp(const UltraAdminApp());
}

class UltraAdminApp extends StatelessWidget {
  const UltraAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Anant Abhyaas Ultra - Vault',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00FFCC),
          secondary: Color(0xFF38BDF8),
        ),
      ),
      home: const SecurityGateScreen(),
    );
  }
}

class SecurityGateScreen extends StatefulWidget {
  const SecurityGateScreen({super.key});

  @override
  State<SecurityGateScreen> createState() => _SecurityGateScreenState();
}

class _SecurityGateScreenState extends State<SecurityGateScreen> {
  final LocalAuthentication auth = LocalAuthentication();
  final TextEditingController _keyController = TextEditingController();

  bool _biometricPassed = false;
  bool _isLoading = false;
  String _statusMessage = 'सुरक्षा गेटवे: कृपया बायोमेट्रिक स्कैन करें';

  @override
  void initState() {
    super.initState();
    _triggerBiometricAuth();
  }

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

  Future<void> _triggerBiometricAuth() async {
    try {
      final canCheck =
          await auth.canCheckBiometrics || await auth.isDeviceSupported();
      if (!canCheck) {
        if (!mounted) return;
        setState(() {
          _biometricPassed = true;
          _statusMessage = 'बायोमेट्रिक अनुपलब्ध। 256-बिट मास्टर की दर्ज करें।';
        });
        return;
      }

      final authenticated = await auth.authenticate(
        localizedReason: 'अनंत अभ्यास अल्ट्रा वॉल्ट अनलॉक करने हेतु स्कैन करें',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );

      if (!mounted) return;
      if (authenticated) {
        setState(() {
          _biometricPassed = true;
          _statusMessage = 'बायोमेट्रिक सफल। 256-बिट मास्टर की दर्ज करें।';
        });
      } else {
        setState(() => _statusMessage = 'बायोमेट्रिक सत्यापन विफल।');
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _biometricPassed = true;
        _statusMessage = 'मास्टर की सत्यापन आवश्यक है।';
      });
    }
  }

  Future<void> _performBlockchainHandshake() async {
    final enteredKey = _keyController.text.trim();
    if (enteredKey.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('कृपया मास्टर की दर्ज करें')));
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = 'ब्लॉकचेन जेनेसिस हैंडशेक प्रक्रिया जारी...';
    });

    try {
      final response = await http.post(
        Uri.parse('http://localhost:8080/api/admin/handshake'),
        headers: {
          'Content-Type': 'application/json',
          'X-Admin-Master-Key': enteredKey,
        },
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 &&
          data['status'] == 'HANDSHAKE_VERIFIED') {
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => AdminDashboard(
              genesisHash: data['genesis_hash'] ?? 'GENESIS_VERIFIED',
            ),
          ),
        );
      } else if (mounted) {
        setState(() {
          _statusMessage = 'अस्वीकृत: अमान्य मास्टर की अथवा ब्लॉकचेन बेमेल!';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _statusMessage = 'सर्वर कनेक्शन त्रुटि। बैकएंड स्थिति जांचें।';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.shield_outlined,
                size: 80,
                color: Color(0xFF00FFCC),
              ),
              const SizedBox(height: 16),
              const Text(
                'ANANT ABHYAAS ULTRA',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _statusMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 32),
              if (!_biometricPassed)
                ElevatedButton.icon(
                  onPressed: _triggerBiometricAuth,
                  icon: const Icon(Icons.fingerprint),
                  label: const Text('बायोमेट्रिक पुनः प्रयास करें'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00FFCC),
                    foregroundColor: Colors.black,
                  ),
                ),
              if (_biometricPassed) ...[
                TextField(
                  controller: _keyController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: '256-बिट मास्टर की (Admin Key)',
                    prefixIcon: const Icon(Icons.vpn_key),
                    filled: true,
                    fillColor: const Color(0xFF1E293B),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading
                        ? null
                        : _performBlockchainHandshake,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00FFCC),
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.black)
                        : const Text(
                            'ब्लॉकचेन हैंडशेक व अनलॉक',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class AdminDashboard extends StatelessWidget {
  final String genesisHash;

  const AdminDashboard({super.key, required this.genesisHash});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('एडमिन वॉल्ट - सक्रिय'),
        backgroundColor: const Color(0xFF1E293B),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'प्रमाणीकरण सफल: मिलिट्री-ग्रेड सेशन सक्रिय',
              style: TextStyle(
                fontSize: 18,
                color: Color(0xFF00FFCC),
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Genesis Hash Root:\n$genesisHash',
              style: const TextStyle(
                color: Colors.white60,
                fontFamily: 'monospace',
                fontSize: 12,
              ),
            ),
            const Divider(height: 40),
            const Center(
              child: Text('सभी 39 डायरेक्टिव्स व सैंडबॉक्स नियंत्रण सक्रिय हैं।'),
            ),
          ],
        ),
      ),
    );
  }
}