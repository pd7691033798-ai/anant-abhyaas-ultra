import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:local_auth/local_auth.dart';

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
        scaffoldBackgroundColor: const Color(0xFF080C14),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00FFCC),
          secondary: Color(0xFF38BDF8),
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
// 2. मास्टर नेविगेशन हब (डैशबोर्ड और चैट के बीच स्विच करने के लिए)
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
        backgroundColor: const Color(0xFF111827),
        selectedItemColor: const Color(0xFF00FFCC),
        unselectedItemColor: Colors.white54,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'डायरेक्टिव्स मैट्रिक्स',
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
// 3. डायरेक्टिव्स और सिस्टम स्टेटस डैशबोर्ड
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

  final String renderBaseUrl = "https://anant-abhyaas-ultra.onrender.com";

  @override
  void initState() {
    super.initState();
    fetchSystemData();
  }

  Future<void> fetchSystemData() async {
    try {
      final versionRes = await http.get(Uri.parse('$renderBaseUrl/api/version'));
      final directivesRes = await http.get(Uri.parse('$renderBaseUrl/api/directives'));

      if (versionRes.statusCode == 200 && directivesRes.statusCode == 200) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF111827),
        elevation: 0,
        title: const Text(
          "🚀 अनंत अभ्यास अल्ट्रा - कमांड सेंटर",
          style: TextStyle(color: Color(0xFF38BDF8), fontSize: 16, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF00FFCC)))
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: ListView(
                children: [
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: const Color(0xFF111827),
                      border: Border.all(color: const Color(0xFF1F2937)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "SECURITY STATUS",
                          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          systemStatus,
                          style: const TextStyle(color: Color(0xFF10B981), fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "📜 मास्टर डायरेक्टिव्स मैट्रिक्स (40/40)",
                    style: TextStyle(color: Color(0xFFF8FAFC), fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: directives.length,
                    itemBuilder: (context, index) {
                      final item = directives[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF111827),
                          border: Border.all(color: const Color(0xFF1F2937)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "#${item['id']} ${item['codename']}",
                              style: const TextStyle(color: Color(0xFF93C5FD), fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF064E3B),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                item['status'],
                                style: const TextStyle(color: Color(0xFF34D399), fontSize: 10),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
    );
  }
}

// ==========================================
// 4. जेमिनी-जैसी चैट, GitHub स्कैनर और सैंडबॉक्स डैशबोर्ड
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
      "text": "नमस्ते मास्टर! अनंत अभ्यास अल्ट्रा सॉवरन कोर सक्रिय है। आप मुझसे सीधे चैट कर सकते हैं या ऊपर दिए गए सुरक्षा (Security) आइकॉन से GitHub रिपॉजिटरी और सैंडबॉक्स डेमो रन कर सकते हैं।"
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
      } else {
        setState(() {
          _messages.add({
            "sender": "agent",
            "text": "त्रुटि: सर्वर से अमान्य रिस्पॉन्स प्राप्त हुआ।"
          });
        });
      }
    } catch (_) {
      setState(() {
        _messages.add({
          "sender": "agent",
          "text": "त्रुटि: सर्वर से संपर्क विफल।"
        });
      });
    } finally {
      setState(() {
        _isSending = false;
      });
    }
  }

  Future<void> _runGitHubScanAndSandbox(String repoUrl) async {
    if (repoUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('कृपया रिपॉजिटरी URL दर्ज करें')),
      );
      return;
    }

    setState(() {
      _messages.add({
        "sender": "user",
        "text": "GitHub Scan & Sandbox Demo request for: $repoUrl"
      });
      _isSending = true;
    });

    try {
      final res = await http.get(
        Uri.parse('https://anant-abhyaas-ultra.onrender.com/api/scan-github?repo=$repoUrl'),
      );
      if (res.statusCode == 200) {
        setState(() {
          _messages.add({
            "sender": "agent",
            "text": res.body
          });
        });
      } else {
        setState(() {
          _messages.add({
            "sender": "agent",
            "text": "स्कैनिंग असफल: सर्वर त्रुटि।"
          });
        });
      }
    } catch (_) {
      setState(() {
        _messages.add({
          "sender": "agent",
          "text": "नेटवर्क त्रुटि: रिपॉजिटरी स्कैनिंग विफल।"
        });
      });
    } finally {
      setState(() {
        _isSending = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('सॉवरन कमांड चैट (Gemini Style)'),
        backgroundColor: const Color(0xFF1E293B),
        actions: [
          IconButton(
            icon: const Icon(Icons.security, color: Color(0xFF00FFCC)),
            tooltip: 'GitHub स्कैन और सैंडबॉक्स डेमो',
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  backgroundColor: const Color(0xFF1E293B),
                  title: const Text('GitHub स्कैन और सैंडबॉक्स डेमो'),
                  content: TextField(
                    controller: _repoController,
                    decoration: const InputDecoration(
                      labelText: 'GitHub Repo URL या प्रोजेक्ट नाम',
                      hintText: 'उदा: https://github.com/user/repo',
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('रद्द करें', style: TextStyle(color: Colors.white70)),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00FFCC),
                        foregroundColor: Colors.black,
                      ),
                      onPressed: () {
                        final repo = _repoController.text.trim();
                        Navigator.pop(context);
                        _runGitHubScanAndSandbox(repo);
                        _repoController.clear();
                      },
                      child: const Text('स्कैन व डेमो चलाएं'),
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
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.75,
                    ),
                    decoration: BoxDecoration(
                      color: isUser ? const Color(0xFF38BDF8) : const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      msg['text']!,
                      style: TextStyle(
                        color: isUser ? Colors.black : Colors.white,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  if (_isSending)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: LinearProgressIndicator(color: Color(0xFF00FFCC)),
            ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: const Color(0xFF1E293B),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _msgController,
                    decoration: const InputDecoration(
                      hintText: 'यहाँ अपना संदेश या कमांड टाइप करें...',
                      border: InputBorder.none,
                      hintStyle: TextStyle(color: Colors.white54),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: Color(0xFF00FFCC)),
                  onPressed: () => _sendMessage(_msgController.text),
                ),
              ],
            ),
  
