import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:local_auth/local_auth.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
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
// 3. डैशबोर्ड (ओवरफ़्लो फिक्स्ड + डायरेक्ट OTA APK इंस्टॉलर)
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

  Future<void> downloadAndInstallAPK(BuildContext dialogContext, String apkUrl) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("नया अपडेट डाउनलोड हो रहा है... कृपया प्रतीक्षा करें")),
      );

      final response = await http.get(Uri.parse(apkUrl));
      if (response.statusCode != 200) {
        throw Exception("डाउनलोड विफल: सर्वर स्टेटस ${response.statusCode}");
      }

      final directory = await getTemporaryDirectory();
      final filePath = "${directory.path}/update.apk";
      final file = File(filePath);
      await file.writeAsBytes(response.bodyBytes);

      final result = await OpenFilex.open(filePath);
      if (result.type != ResultType.done) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("इंस्टॉलेशन शुरू नहीं हो सका: ${result.message}")),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("अपडेट त्रुटि: $e")),
      );
    }
  }

  void showUpdateDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: const Color(0xFF131B2E),
        title: const Text('🚀 नया OTA अपडेट उपलब्ध है', style: TextStyle(color: Color(0xFF00FFCC))),
        content: const Text(
          'सिस्टम में नया अपडेट उपलब्ध है। सीधे नया APK डाउनलोड करके इंस्टॉल करने के लिए नीचे क्लिक करें।',
          style: TextStyle(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('बाद में', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8B5CF6)),
            onPressed: () {
              Navigator.pop(dialogCtx);
              downloadAndInstallAPK(context, '$renderBaseUrl/');
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
        setState(() => _pipelineStatus = "डेमो तैयार करने में विफलता: कोड त्रुटि ${buildRes.statusCode}");
      }
    } catch (e) {
      setState(() => _pipelineStatus = "सैंडबॉक्स एरर: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _buildStandaloneApk() async {
    if (_selectedRepoUrl == null) return;

    setState(() {
      _isLoading = true;
      _pipelineStatus = "क्लाउड कंपाइलर सक्रिय: '$_selectedRepoName' का APK बिल्ड हो रहा है...";
    });

    try {
      final apkRes = await http.post(
        Uri.parse('$_backendUrl/api/builder/compile-apk'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'repo': _selectedRepoUrl,
          'app_name': _selectedRepoName,
        }),
      );

      if (apkRes.statusCode == 200) {
        final data = jsonDecode(apkRes.body);
        setState(() {
          _downloadApkUrl = data['apk_download_url'];
          _pipelineStatus = "बिल्ड सफल! '$_selectedRepoName' का APK तैयार है। नीचे से डाउनलोड करें।";
        });
      } else {
        setState(() => _pipelineStatus = "APK कंपाइलेशन विफल रहा। कोड लॉग जांचें।");
      }
    } catch (e) {
      setState(() => _pipelineStatus = "कंपाइलर एरर: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _downloadAndInstallApk() async {
    if (_downloadApkUrl == null) return;
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("$_selectedRepoName.apk डाउनलोड हो रहा है...")),
      );

      final response = await http.get(Uri.parse(_downloadApkUrl!));
      if (response.statusCode != 200) {
        throw Exception("डाउनलोड विफल: स्टेटस ${response.statusCode}");
      }

      final directory = await getTemporaryDirectory();
      final filePath = "${directory.path}/${_selectedRepoName ?? 'app'}.apk";
      final file = File(filePath);
      await file.writeAsBytes(response.bodyBytes);

      final result = await OpenFilex.open(filePath);
      if (result.type != ResultType.done) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("इंस्टॉलेशन शुरू नहीं हो सका: ${result.message}")),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("त्रुटि: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0F19),
      appBar: AppBar(
        title: const Text('सॉवरन ऐप बिल्डर स्टूडियो', style: TextStyle(color: Colors.white, fontSize: 16)),
        backgroundColor: const Color(0xFF131B2E),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            color: const Color(0xFF131B2E),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _tokenController,
                    obscureText: true,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    decoration: const InputDecoration(
                      hintText: 'GitHub Personal Access Token (PAT)',
                      hintStyle: TextStyle(color: Colors.white38),
                      border: InputBorder.none,
                    ),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00FFCC), foregroundColor: Colors.black),
                  onPressed: _isLoading ? null : _fetchRepositories,
                  child: const Text('सिंक करें', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: const Color(0xFF1E293B),
            child: Text(
              _pipelineStatus,
              style: const TextStyle(color: Color(0xFF00FFCC), fontSize: 11, fontFamily: 'monospace'),
            ),
          ),
          if (_isLoading) const LinearProgressIndicator(color: Color(0xFF8B5CF6), minHeight: 2),
          if (_repositories.isNotEmpty)
            Container(
              height: 52,
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _repositories.length,
                itemBuilder: (context, index) {
                  final repo = _repositories[index];
                  final isSelected = _selectedRepoUrl == repo['html_url'];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: isSelected ? const Color(0xFF00FFCC) : const Color(0xFF8B5CF6)),
                        backgroundColor: isSelected ? const Color(0xFF8B5CF6).withValues(alpha: 0.2) : Colors.transparent,
                      ),
                      onPressed: _isLoading ? null : () => _analyzeAndRunDemo(repo['html_url'], repo['name']),
                      child: Text(repo['name'], style: const TextStyle(color: Colors.white, fontSize: 11)),
                    ),
                  );
                },
              ),
            ),
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF1E293B)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _isDemoReady && _webViewController != null
                    ? WebViewWidget(controller: _webViewController!)
                    : Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.build_circle_outlined, color: Colors.white24, size: 50),
                            SizedBox(height: 10),
                            Text(
                              "ऊपर से किसी रिपॉजिटरी को चुनें।\nउसका लाइव डेमो यहाँ लोड होगा।",
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.white38, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
              ),
            ),
          ),
          if (_isDemoReady)
            Container(
              padding: const EdgeInsets.all(12),
              color: const Color(0xFF131B2E),
              child: _downloadApkUrl == null
                  ? SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF8B5CF6),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: _isLoading ? null : _buildStandaloneApk,
                        icon: const Icon(Icons.android, color: Colors.white),
                        label: Text(
                          "डेमो सही है: '$_selectedRepoName' का APK बनाएं",
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                    )
                  : SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00FFCC),
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: _downloadAndInstallApk,
                        icon: const Icon(Icons.download),
                        label: Text(
                          "डाउनलोड करें: $_selectedRepoName.apk",
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
            ),
        ],
      ),
    );
  }
}

// ==========================================
// 5. जेमिनी AI चैट व क्विक स्कैनर
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
      "text": "नमस्ते मास्टर! अनंत अभ्यास अल्ट्रा सॉवरन कोर सक्रिय है। आप मुझसे चैट कर सकते हैं या किसी भी गिटहब रिपॉजिटरी का त्वरित विश्लेषण ले सकते हैं।"
    }
  ];
  bool _isSending = false;

  @override
  void dispose() {
    _msgController.dispose();
    _repoController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage(String text) async {
    final cleanText = text.trim();
    if (cleanText.isEmpty || _isSending) return;

    setState(() {
      _messages.add({"sender": "user", "text": cleanText});
      _isSending = true;
    });
    _msgController.clear();

    try {
      final uri = Uri.https(
        'anant-abhyaas-ultra.onrender.com',
        '/api/agent-chat',
        {'msg': cleanText},
      );

      final res = await http.get(uri);

      if (!mounted) return;

      if (res.statusCode == 200) {
        final data = jsonDecode(utf8.decode(res.bodyBytes));
        setState(() {
          _messages.add({
            "sender": "agent",
            "text": data['response']?.toString() ?? 'एजेंट्स ने प्रतिक्रिया दी।'
          });
        });
      } else {
        setState(() {
          _messages.add({"sender": "agent", "text": "त्रुटि: कोड ${res.statusCode}"});
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _messages.add({"sender": "agent", "text": "त्रुटि: सर्वर से संपर्क विफल।"});
      });
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  Future<void> _runGitHubScanAndSandbox(String repoUrl) async {
    final cleanRepo = repoUrl.trim();
    if (cleanRepo.isEmpty || _isSending) return;

    setState(() {
      _messages.add({"sender": "user", "text": "GitHub Scan request: $cleanRepo"});
      _isSending = true;
    });

    try {
      final uri = Uri.https(
        'anant-abhyaas-ultra.onrender.com',
        '/api/scan-github',
        {'repo': cleanRepo},
      );

      final res = await http.get(uri);

      if (!mounted) return;

      if (res.statusCode == 200) {
        setState(() {
          _messages.add({"sender": "agent", "text": utf8.decode(res.bodyBytes)});
        });
      } else {
        setState(() {
          _messages.add({"sender": "agent", "text": "स्कैन विफल: कोड ${res.statusCode}"});
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _messages.add({"sender": "agent", "text": "स्कैनिंग असफल।"});
      });
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
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
                  title: const Text('त्वरित GitHub स्कैन', style: TextStyle(color: Colors.white)),
                  content: TextField(
                    controller: _repoController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: 'उदा: https://github.com/user/repo',
                      hintStyle: TextStyle(color: Colors.white38),
                    ),
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context), child: const Text('रद्द करें')),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8B5CF6)),
                      onPressed: () {
                        final repo = _repoController.text;
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
                    child: Text(msg['text'] ?? '', style: const TextStyle(fontSize: 13, color: Colors.white)),
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
                    style: const TextStyle(color: Colors.white),
                    onSubmitted: (val) => _sendMessage(val),
                    decoration: const InputDecoration(
                      hintText: 'यहाँ कमांड टाइप करें...',
                      border: InputBorder.none,
                      hintStyle: TextStyle(color: Colors.white38),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: Color(0xFF00FFCC)),
                  onPressed: _isSending ? null : () => _sendMessage(_msgController.text),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
