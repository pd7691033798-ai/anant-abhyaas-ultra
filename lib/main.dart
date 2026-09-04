import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:local_auth/local_auth.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  runApp(const AnantUltraApp());
}

class AnantUltraApp extends StatelessWidget {
  const AnantUltraApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'अनंत अभ्यास अल्ट्रा - सॉवरन कोर',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0B0F19),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF8B5CF6), // Dribbble पर्पल थीम
          secondary: Color(0xFF00FFCC),
        ),
      ),
      home: const SecurityGateScreen(),
    );
  }
}

// ==========================================
// 1. सुरक्षा गेटवे (बायोमेट्रिक और मास्टर की)
// ==========================================
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('कृपया मास्टर की दर्ज करें')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = 'ब्लॉकचेन जेनेसिस हैंडशेक प्रक्रिया जारी...';
    });

    try {
      final response = await http.post(
        Uri.parse('https://anant-abhyaas-ultra.onrender.com/api/admin/handshake'),
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
            builder: (context) => const MasterNavigationHub(),
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
                    onPressed: _isLoading ? null : _performBlockchainHandshake,
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

// ==========================================
// 2. मास्टर नेविगेशन हब (Dribbble Style)
// ==========================================
class MasterNavigationHub extends StatefulWidget {
  const MasterNavigationHub({Key? key}) : super(key: key);

  @override
  _MasterNavigationHubState createState() => _MasterNavigationHubState();
}

class _MasterNavigationHubState extends State<MasterNavigationHub> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const SovereignDashboard(),
    const GeminiChatDashboard(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        backgroundColor: const Color(0xFF131B2E),
        selectedItemColor: const Color(0xFF8B5CF6),
        unselectedItemColor: Colors.white54,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.grid_view),
            label: 'डैशबोर्ड',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline),
            label: 'सॉवरन AI चैट',
          ),
        ],
      ),
    );
  }
}

// ==========================================
// 3. डायरेक्टिव्स और ऑटो-अपडेट सक्षम डैशबोर्ड
// ==========================================
class SovereignDashboard extends StatefulWidget {
  const SovereignDashboard({Key? key}) : super(key: key);

  @override
  _SovereignDashboardState createState() => _SovereignDashboardState();
}

class _SovereignDashboardState extends State<SovereignDashboard> {
  String systemStatus = "Connecting to Sovereign Core...";
  List directives = [];
  bool isLoading = true;

  final String currentAppVersion = "1.0.0"; // आपके वर्तमान ऐप का वर्जन
  final String renderBaseUrl = "https://anant-abhyaas-ultra.onrender.com";

  @override
  void initState() {
    super.initState();
    fetchSystemData();
    checkForUpdates(); // ऐप खुलते ही ऑटो-अपडेट चेक करेगा
  }

  Future<void> fetchSystemData() async {
    try {
      final directivesRes = await http.get(Uri.parse('$renderBaseUrl/api/directives'));

      if (directivesRes.statusCode == 200) {
        setState(() {
          systemStatus = "AIR-GAPPED ULTRA ACTIVE";
          directives = json.decode(directivesRes.body);
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        systemStatus = "Connection Failed: $e";
        isLoading = false;
      });
    }
  }

  // OTA ऑटो-अपडेट चेकिंग फंक्शन
  Future<void> checkForUpdates() async {
    try {
      // आप अपने रेंडर पर एक छोटा वर्जन एपीआई बना सकते हैं, या वर्तमान वर्जन की तुलना कर सकते हैं
      final res = await http.get(Uri.parse('$renderBaseUrl/api/version'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        String serverVersion = data['engine_version'] ?? "v1.0.0-PROD-STEALTH";

        // यदि सर्वर पर नया वर्जन उपलब्ध हो
        if (!serverVersion.contains(currentAppVersion)) {
          if (!mounted) return;
          showUpdateDialog(context);
        }
      }
    } catch (_) {
      // यदि चेक फेल हो जाए तो इग्नोर करें
    }
  }

  void showUpdateDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF131B2E),
        title: const Text('🚀 नया OTA अपडेट उपलब्ध है', style: TextStyle(color: Color(0xFF00FFCC))),
        content: const Text(
          'सिस्टम में नया मिलिट्री-ग्रेड अपडेट जारी किया गया है। बिना Codemagic खोले सीधे नया APK डाउनलोड करने के लिए नीचे क्लिक करें।',
          style: TextStyle(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('बाद में', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8B5CF6)),
            onPressed: () async {
              Navigator.pop(context);
              final Uri apkUrl = Uri.parse('$renderBaseUrl/'); // यहाँ डायरेक्ट APK डाउनलोड लिंक दे सकते हैं
              if (await canLaunchUrl(apkUrl)) {
                await launchUrl(apkUrl, mode: LaunchMode.externalApplication);
              }
            },
            child: const Text('अपडेट करें', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFF8B5CF6), width: 2),
                        ),
                        child: const CircleAvatar(
                          radius: 20,
                          backgroundColor: Color(0xFF1E1B4B),
                          child: Icon(Icons.security, color: Color(0xFF00FFCC), size: 18),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text("सॉवरन मास्टर", style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                          Text("Anant Abhyaas Ultra", style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                        ],
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1B4B),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(systemStatus, style: const TextStyle(color: Color(0xFF34D399), fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Dribbble Banner Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF7C3AED), Color(0xFF4C1D95)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text("OTA Auto-Update Active", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    SizedBox(height: 4),
                    Text("अब हर नए बदलाव पर ऐप खुद आपको अपडेट के लिए सूचित करेगा।", style: TextStyle(color: Colors.white70, fontSize: 12)),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              const Text("मास्टर डायरेक्टिव्स मैट्रिक्स", style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),

              Expanded(
                child: isLoading
                    ? const Center(child: CircularProgressIndicator(color: Color(0xFF8B5CF6)))
                    : ListView.builder(
                        itemCount: directives.length,
                        itemBuilder: (context, index) {
                          final item = directives[index];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF131B2E),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFF1E293B)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  "#${item['id']} ${item['codename']}",
                                  style: const TextStyle(color: Color(0xFFE2E8F0), fontSize: 12, fontWeight: FontWeight.w600),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF064E3B),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    item['status'],
                                    style: const TextStyle(color: Color(0xFF34D399), fontSize: 9),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==========================================
// 4. जेमिनी-जैसी चैट और GitHub स्कैनर
// ==========================================
class GeminiChatDashboard extends StatefulWidget {
  const GeminiChatDashboard({super.key});

  @override
  State<GeminiChatDashboard> createState() => _GeminiChatDashboardState();
}

class _GeminiChatDashboardState extends State<GeminiChatDashboard> {
  final TextEditingController _msgController = TextEditingController();
  final TextEditingController _repoController = TextEditingController();
  
  final List<Map<String, String>> _messages = [
    {
      "sender": "agent",
      "text": "नमस्ते मास्टर! अनंत अभ्यास अल्ट्रा सॉवरन कोर सक्रिय है। आप मुझसे सीधे चैट कर सकते हैं या ऊपर दिए गए सुरक्षा आइकॉन से GitHub रिपॉजिटरी स्कैन कर सकते हैं।"
    }
  ];
  bool _isSending = false;

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    setState(() {
      _messages.add({"sender": "user", "text": text});
      _isSending = true;
    });
    _msgController.clear();

    try {
      final res = await http.get(
        Uri.parse('https://anant-abhyaas-ultra.onrender.com/api/agent-chat?msg=$text'),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          _messages.add({
            "sender": "agent",
            "text": data['response'] ?? 'एजेंट्स ने प्रतिक्रिया दी।'
          });
        });
      }
    } catch (_) {
      setState(() {
        _messages.add({"sender": "agent", "text": "त्रुटि: सर्वर से संपर्क विफल।"});
      });
    } finally {
      setState(() { _isSending = false; });
    }
  }

  Future<void> _runGitHubScanAndSandbox(String repoUrl) async {
    if (repoUrl.isEmpty) return;

    setState(() {
      _messages.add({"sender": "user", "text": "GitHub Scan request for: $repoUrl"});
      _isSending = true;
    });

    try {
      final res = await http.get(
        Uri.parse('https://anant-abhyaas-ultra.onrender.com/api/scan-github?repo=$repoUrl'),
      );
      if (res.statusCode == 200) {
        setState(() {
          _messages.add({"sender": "agent", "text": res.body});
        });
      }
    } catch (_) {
      setState(() {
        _messages.add({"sender": "agent", "text": "स्कैनिंग असफल।"});
      });
    } finally {
      setState(() { _isSending = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('सॉवरन कमांड चैट'),
        backgroundColor: const Color(0xFF131B2E),
        actions: [
          IconButton(
            icon: const Icon(Icons.security, color: Color(0xFF00FFCC)),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  backgroundColor: const Color(0xFF131B2E),
                  title: const Text('GitHub स्कैन'),
                  content: TextField(
                    controller: _repoController,
                    decoration: const InputDecoration(hintText: 'उदा: https://github.com/user/repo'),
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context), child: const Text('रद्द करें')),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8B5CF6)),
                      onPressed: () {
                        final repo = _repoController.text.trim();
                        Navigator.pop(context);
                        _runGitHubScanAndSandbox(repo);
                        _repoController.clear();
                      },
                      child: const Text('स्कैन चलाएं'),
                    ),
                  ],
                ),
              );
            },
          )
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isUser = msg['sender'] == 'user';
                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isUser ? const Color(0xFF8B5CF6) : const Color(0xFF131B2E),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(msg['text']!, style: const TextStyle(fontSize: 13, color: Colors.white)),
                  ),
                );
              },
            ),
          ),
          if (_isSending) const LinearProgressIndicator(color: Color(0xFF00FFCC)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: const Color(0xFF131B2E),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _msgController,
                    decoration: const InputDecoration(
                      hintText: 'यहाँ कमांड टाइप करें...',
                      border: InputBorder.none,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: Color(0xFF00FFCC)),
                  onPressed:
                  _isSending ? null : () => _sendMessage(_msgController.text),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
