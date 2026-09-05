import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:local_auth/local_auth.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:anant_abhyaas_ultra/screens/sandbox_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AnantUltraApp());
}

class AnantUltraApp extends StatelessWidget {
  const AnantUltraApp({super.key});

  static const String serverBaseUrl = 'https://anant-abhyaas-ultra.onrender.com';

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
        Uri.parse('${AnantUltraApp.serverBaseUrl}/api/admin/handshake'),
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
// 2. मास्टर नेविगेशन हब (सर्वर-ड्रिवन UI सहित 4 टैब)
// ==========================================
class MasterNavigationHub extends StatefulWidget {
  const MasterNavigationHub({super.key});

  @override
  State<MasterNavigationHub> createState() => _MasterNavigationHubState();
}

class _MasterNavigationHubState extends State<MasterNavigationHub> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    DynamicServerDrivenScreen(backendUrl: AnantUltraApp.serverBaseUrl),
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
        type: BottomNavigationBarType.fixed,
        backgroundColor: const Color(0xFF131B2E),
        selectedItemColor: const Color(0xFF00FFCC),
        unselectedItemColor: Colors.white54,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dynamic_feed), label: 'सर्वर-ड्रिवन UI'),
          BottomNavigationBarItem(icon: Icon(Icons.grid_view), label: 'डैशबोर्ड'),
          BottomNavigationBarItem(icon: Icon(Icons.handyman_outlined), label: 'ऐप बिल्डर'),
          BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outline), label: 'AI चैट'),
        ],
      ),
    );
  }
}

// ==========================================
// 3. सर्वर-ड्रिवन UI रेंडरर और एक्शन हैंडलर्स
// ==========================================
class DynamicServerDrivenScreen extends StatefulWidget {
  final String backendUrl;
  const DynamicServerDrivenScreen({super.key, required this.backendUrl});

  @override
  State<DynamicServerDrivenScreen> createState() => _DynamicServerDrivenScreenState();
}

class _DynamicServerDrivenScreenState extends State<DynamicServerDrivenScreen> {
  Map<String, dynamic>? _screenData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchDynamicLayout();
  }

  Future<void> _fetchDynamicLayout() async {
    try {
      final res = await http.get(Uri.parse('${widget.backendUrl}/api/ui/dynamic-screen'));
      if (res.statusCode == 200) {
        if (!mounted) return;
        setState(() {
          _screenData = jsonDecode(utf8.decode(res.bodyBytes));
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _handleAction(String? actionKey) {
    if (actionKey == null) return;

    switch (actionKey) {
      case 'OPEN_WHATSAPP_SIM':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => WhatsAppSimulatorScreen(backendUrl: widget.backendUrl),
          ),
        );
        break;

      case 'OPEN_SANDBOX':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const AutonomousSandboxScreen(
              repoName: "anant-abhyaas-ultra",
            ),
          ),
        );
        break;

      case 'OPEN_CODE_PASTE':
        _showCodePasteSheet(context);
        break;

      default:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("एक्शन ट्रिगर: $actionKey")),
        );
    }
  }

  void _showCodePasteSheet(BuildContext context) {
    final TextEditingController codeController = TextEditingController();
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "⚡ स्वायत्त कोड कमिट (Direct Push)",
                style: TextStyle(color: Colors.cyanAccent, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              const Text(
                "कोड यहाँ पेस्ट करें। इंजन इसकी पहचान करके रिपॉजिटरी में स्वतः कमिट कर देगा।",
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: codeController,
                maxLines: 8,
                style: const TextStyle(color: Colors.white, fontFamily: 'monospace', fontSize: 12),
                decoration: InputDecoration(
                  hintText: "// अपना Dart, Go या JS कोड यहाँ पेस्ट करें...",
                  hintStyle: const TextStyle(color: Colors.grey),
                  filled: true,
                  fillColor: const Color(0xFF0F172A),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigoAccent,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          if (codeController.text.trim().isEmpty) return;
                          setSheetState(() => isSubmitting = true);

                          try {
                            final res = await http.post(
                              Uri.parse('${widget.backendUrl}/api/builder/direct-commit'),
                              headers: {'Content-Type': 'application/json'},
                              body: jsonEncode({
                                "repo_name": "anant-abhyaas-ultra",
                                "raw_code": codeController.text,
                              }),
                            );

                            if (!context.mounted) return;
                            Navigator.pop(context);
                            final responseData = jsonDecode(utf8.decode(res.bodyBytes));
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(responseData['message'] ?? "कमिट सफल रहा!"),
                                backgroundColor: res.statusCode == 200 ? Colors.green : Colors.red,
                              ),
                            );
                          } catch (e) {
                            setSheetState(() => isSubmitting = false);
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text("एरर: $e"), backgroundColor: Colors.red),
                            );
                          }
                        },
                  child: isSubmitting
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text("GitHub पर सीधे कमिट करें", style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildComponent(Map<String, dynamic> comp) {
    switch (comp['type']) {
      case 'banner':
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blueGrey.shade900,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.blueAccent),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(comp['title'] ?? '', style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 16)),
              if (comp['subtitle'] != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(comp['subtitle'], style: const TextStyle(color: Colors.white70, fontSize: 13)),
                ),
            ],
          ),
        );

      case 'card':
        return Card(
          color: const Color(0xFF1E293B),
          margin: const EdgeInsets.symmetric(vertical: 8),
          child: ListTile(
            title: Text(comp['title'] ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            subtitle: comp['subtitle'] != null ? Text(comp['subtitle'], style: const TextStyle(color: Colors.grey)) : null,
            trailing: const Icon(Icons.arrow_forward_ios, color: Colors.greenAccent, size: 16),
            onTap: () => _handleAction(comp['action_key']),
          ),
        );

      case 'button':
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigoAccent,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => _handleAction(comp['action_key']),
            child: Text(comp['title'] ?? 'सबमिट', style: const TextStyle(color: Colors.white, fontSize: 15)),
          ),
        );

      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0F172A),
        body: Center(child: CircularProgressIndicator(color: Colors.cyanAccent)),
      );
    }

    final components = _screenData?['components'] as List<dynamic>? ?? [];

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: Text(_screenData?['screen_title'] ?? 'अनंत अभ्यास सॉवरन स्टूडियो'),
        backgroundColor: const Color(0xFF1E293B),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.cyanAccent),
            onPressed: () {
              setState(() => _isLoading = true);
              _fetchDynamicLayout();
            },
          )
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchDynamicLayout,
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: components.length,
          itemBuilder: (context, index) => _buildComponent(components[index]),
        ),
      ),
    );
  }
}

// ==========================================
// 4. WhatsApp लाइव चैट सिम्युलेटर स्क्रीन
// ==========================================
class WhatsAppSimulatorScreen extends StatefulWidget {
  final String backendUrl;
  const WhatsAppSimulatorScreen({super.key, required this.backendUrl});

  @override
  State<WhatsAppSimulatorScreen> createState() => _WhatsAppSimulatorScreenState();
}

class _WhatsAppSimulatorScreenState extends State<WhatsAppSimulatorScreen> {
  final TextEditingController _msgController = TextEditingController();
  final List<Map<String, String>> _messages = [
    {"sender": "bot", "text": "🟢 WhatsApp लाइव गेटवे तैयार है। 'Hi' या कोई कमांड भेजें।"}
  ];
  bool _sending = false;

  Future<void> _sendMessage() async {
    final text = _msgController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add({"sender": "user", "text": text});
      _sending = true;
    });
    _msgController.clear();

    try {
      final res = await http.get(
        Uri.parse('${widget.backendUrl}/api/builder/universal-sim?platform=WHATSAPP&msg=${Uri.encodeComponent(text)}'),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(utf8.decode(res.bodyBytes));
        if (!mounted) return;
        setState(() {
          _messages.add({"sender": "bot", "text": data['response'] ?? "कोई उत्तर नहीं मिला"});
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add({"sender": "bot", "text": "त्रुटि: सर्वर से कनेक्ट नहीं हो सका।"});
        });
      }
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    reurn Scaffold(
      backgroundColor: const Color(0xFF0B141A),
      appBar: AppBar(
        title: const Text("WhatsApp Simulator", style: TextStyle(color: Colors.white, fontSize: 16)),
        backgroundColor: const Color(0xFF1F2C34),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _messages.length,
              itemBuilder: (context, i) {
                final isUser = _messages[i]['sender'] == 'user';
                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isUser ? const Color(0xFF005C4B) : const Color(0xFF1F2C34),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(_messages[i]['text'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 14)),
                  ),
                );
              },
            ),
          ),
          if (_sending) const LinearProgressIndicator(color: Color(0xFF00A884), minHeight: 2),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            color: const Color(0xFF1F2C34),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _msgController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: "संदेश लिखें...",
                      hintStyle: TextStyle(color: Colors.grey),
                      border: InputBorder.none,
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: Color(0xFF00A884)),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
// ==========================================
// 5. डैशबोर्ड
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

  final String currentAppVersion = "v1.0.0-LIVE";
  final String renderBaseUrl = AnantUltraApp.serverBaseUrl;

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

        if (serverVersion != currentAppVersion) {
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
