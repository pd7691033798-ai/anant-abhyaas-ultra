import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:local_auth/local_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AnantUltraApp());
}

class AnantUltraApp extends StatelessWidget {
  const AnantUltraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'अनंत अभ्यास अल्ट्रा - सॉवरन कोर',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0B0F19),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF8B5CF6),
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
      final canCheck = await auth.canCheckBiometrics || await auth.isDeviceSupported();
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

      if (response.statusCode == 200 && data['status'] == 'HANDSHAKE_VERIFIED') {
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const MasterNavigationHub()),
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
              const Icon(Icons.shield_outlined, size: 80, color: Color(0xFF00FFCC)),
              const SizedBox(height: 16),
              const Text(
                'ANANT ABHYAAS ULTRA',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 2),
              ),
              const SizedBox(height: 8),
              Text(_statusMessage, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 14)),
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
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: '256-बिट मास्टर की (Admin Key)',
                    prefixIcon: const Icon(Icons.vpn_key),
                    filled: true,
                    fillColor: const Color(0xFF1E293B),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.black)
                        : const Text('ब्लॉकचेन हैंडशेक व अनलॉक', style: TextStyle(fontWeight: FontWeight.bold)),
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
// 2. मास्टर नेविगेशन हब (3 टैब: डैशबोर्ड, सैंडबॉक्स/बिल्डर, AI चैट)
// ==========================================
class MasterNavigationHub extends StatefulWidget {
  const MasterNavigationHub({super.key});

  @override
  State<MasterNavigationHub> createState() => _MasterNavigationHubState();
}

class _MasterNavigationHubState extends State<MasterNavigationHub> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    SovereignDashboard(),
    SovereignAppBuilderStudio(),
    GeminiChatDashboard(),
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
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.grid_view), label: 'डैशबोर्ड'),
          BottomNavigationBarItem(icon: Icon(Icons.handyman_outlined), label: 'ऐप बिल्डर सैंडबॉक्स'),
          BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outline), label: 'सॉवरन AI चैट'),
        ],
      ),
    );
  }
}

// ==========================================
// 3. डैशबोर्ड (ओवरफ़्लो फिक्स्ड + OTA चेकर)
// ==========================================
class SovereignDashboard extends StatefulWidget {
  const SovereignDashboard({super.key});

  @override
  State<SovereignDashboard> createState() => _SovereignDashboardState();
}

class _SovereignDashboardState extends State<SovereignDashboard> {
  String systemStatus = "Connecting to Sovereign Core...";
  List directives = [];
  bool isLoading = true;

  final String currentAppVersion = "1.0.0";
  final String renderBaseUrl = "https://anant-abhyaas-ultra.onrender.com";

  @override
  void initState() {
    super.initState();
    fetchSystemData();
    checkForUpdates();
  }

  Future<void> fetchSystemData() async {
    try {
      final directivesRes = await http.get(Uri.parse('$renderBaseUrl/api/directives'));
      if (directivesRes.statusCode == 200) {
        if (!mounted) return;
        setState(() {
          systemStatus = "AIR-GAPPED ULTRA ACTIVE";
          directives = json.decode(utf8.decode(directivesRes.bodyBytes));
          isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        systemStatus = "Connection Failed: $e";
        isLoading = false;
      });
    }
  }

  Future<void> checkForUpdates() async {
    try {
      final res = await http.get(Uri.parse('$renderBaseUrl/api/version'));
      if (res.statusCode == 200) {
        final data = jsonDecode(utf8.decode(res.bodyBytes));
        String serverVersion = data['engine_version'] ?? "v1.0.0-PROD-STEALTH";

        if (!serverVersion.contains(currentAppVersion)) {
          if (!mounted) return;
          showUpdateDialog(context);
        }
      }
    } catch (_) {}
  }

  void showUpdateDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF131B2E),
        title: const Text('🚀 नया OTA अपडेट उपलब्ध है', style: TextStyle(color: Color(0xFF00FFCC))),
        content: const Text(
          'सिस्टम में नया अपडेट उपलब्ध है। सीधे नया APK डाउनलोड करने के लिए नीचे क्लिक करें।',
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
              final Uri apkUrl = Uri.parse('$renderBaseUrl/');
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
                    Text("OTA Auto-Update Engine Active", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    SizedBox(height: 4),
                    Text("अनंत अभ्यास अल्ट्रा कोर अपडेट्स के लिए सीधे सर्वर से सिंक है।", style: TextStyle(color: Colors.white70, fontSize: 12)),
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
                              children: [
                                // ओवरफ़्लो रोकने के लिए Expanded लगाया गया
                                Expanded(
                                  child: Text(
                                    "#${item['id']} ${item['codename']}",
                                    style: const TextStyle(color: Color(0xFFE2E8F0), fontSize: 12, fontWeight: FontWeight.w600),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF064E3B),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    item['status']?.toString() ?? '',
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
// 4. सॉवरन ऐप बिल्डर स्टूडियो (सैंडबॉक्स + लाइव डेमो + APK डाउनलोड)
// ==========================================
class SovereignAppBuilderStudio extends StatefulWidget {
  const SovereignAppBuilderStudio({super.key});

  @override
  State<SovereignAppBuilderStudio> createState() => _SovereignAppBuilderStudioState();
}

class _SovereignAppBuilderStudioState extends State<SovereignAppBuilderStudio> {
  final TextEditingController _tokenController = TextEditingController();
  final String _backendUrl = 'https://anant-abhyaas-ultra.onrender.com';

  List<dynamic> _repositories = [];
  bool _isLoading = false;
  String _pipelineStatus = "GitHub टोकन दर्ज करके रिपॉजिटरी लोड करें।";

  String? _selectedRepoUrl;
  String? _selectedRepoName;
  String? _downloadApkUrl;
  WebViewController? _webViewController;
  bool _isDemoReady = false;

  @override
  void dispose() {
    _tokenController.dispose();
    super.dispose();
  }

  Future<void> _fetchRepositories() async {
    final token = _tokenController.text.trim();
    if (token.isEmpty) return;

    setState(() {
      _isLoading = true;
      _pipelineStatus = "GitHub क्रेडेंशियल्स लोड किए जा रहे हैं...";
    });

    try {
      final res = await http.get(
        Uri.parse('https://api.github.com/user/repos?sort=updated&per_page=25'),
        headers: {
          'Authorization': 'token $token',
          'Accept': 'application/vnd.github.v3+json',
        },
      );

      if (res.statusCode == 200) {
        setState(() {
          _repositories = jsonDecode(res.body);
          _pipelineStatus = "रिपॉजिटरी लोड हो गईं। जिसका ऐप बनाना है उसे चुनें।";
        });
      } else {
        setState(() => _pipelineStatus = "GitHub प्रमाणीकरण विफल: टोकन अमान्य है।");
      }
    } catch (e) {
      setState(() => _pipelineStatus = "कनेक्शन त्रुटि: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _analyzeAndRunDemo(String repoUrl, String repoName) async {
    setState(() {
      _selectedRepoUrl = repoUrl;
      _selectedRepoName = repoName;
      _isLoading = true;
      _isDemoReady = false;
      _downloadApkUrl = null;
      _pipelineStatus = "चरण 1/2: '$repoName' का कोड विश्लेषण और रिपेयर जारी...";
    });

    try {
      final buildRes = await http.post(
        Uri.parse('$_backendUrl/api/builder/prepare-demo'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'repo': repoUrl, 'name': repoName}),
      );

      if (buildRes.statusCode == 200) {
        final data = jsonDecode(buildRes.body);
        final demoUrl = data['demo_url'];

        final controller = WebViewController()
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..loadRequest(Uri.parse(demoUrl));

        setState(() {
          _webViewController = controller;
          _isDemoReady = true;
          _pipelineStatus = "चरण 2/2: डेमो तैयार है! स्क्रीन पर टेस्ट करें, फिर नीचे 'नया APK बनाएं' दबाएं।";
        });
      } else {
        setState(() => _pipelineStatus = "डेमो तैयार करन
