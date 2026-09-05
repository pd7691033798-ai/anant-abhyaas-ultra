import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class AutonomousSandboxScreen extends StatefulWidget {
  final String repoName;
  const AutonomousSandboxScreen({Key? key, required this.repoName}) : super(key: key);

  @override
  State<AutonomousSandboxScreen> createState() => _AutonomousSandboxScreenState();
}

class _AutonomousSandboxScreenState extends State<AutonomousSandboxScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _chatController = TextEditingController();
  final List<Map<String, String>> _messages = [
    {"sender": "bot", "text": "WhatsApp ऑटोमेशन सक्रिय है। 'START' या 'SCAN' लिखकर टेस्ट करें।"}
  ];

  bool _isBuildingApk = false;
  String? _finalApkUrl;
  int _counter = 0;
  String _taskStatus = "लंबित (Pending)";

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  Future<void> _sendWhatsAppMessage() async {
    final text = _chatController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add({"sender": "user", "text": text});
      _chatController.clear();
    });

    try {
      final res = await http.post(
        Uri.parse("https://anant-abhyaas-ultra.onrender.com/api/whatsapp/demo-chat"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"user_message": text}),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          _messages.add({"sender": "bot", "text": data["bot_reply"] ?? "कमांड निष्पादित"});
        });
      }
    } catch (_) {
      setState(() {
        _messages.add({"sender": "bot", "text": "सर्वर से संपर्क नहीं हो सका"});
      });
    }
  }

  Future<void> _approveAndBuild() async {
    setState(() => _isBuildingApk = true);
    try {
      final res = await http.post(
        Uri.parse("https://anant-abhyaas-ultra.onrender.com/api/sandbox/approve-build"),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          _finalApkUrl = data["apk_download_url"];
        });
      }
    } finally {
      setState(() => _isBuildingApk = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("सैंडबॉक्स: ${widget.repoName}"),
        backgroundColor: const Color(0xFF075E54),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(icon: Icon(Icons.chat), text: "WhatsApp"),
            Tab(icon: Icon(Icons.phone_android), text: "यूजर UI"),
            Tab(icon: Icon(Icons.verified_user), text: "एडमिन गेट"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildWhatsAppTab(),
          _buildUserUiTab(),
          _buildAdminGateTab(),
        ],
      ),
    );
  }

  Widget _buildWhatsAppTab() {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: _messages.length,
            itemBuilder: (context, i) {
              final isUser = _messages[i]["sender"] == "user";
              return Align(
                alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isUser ? const Color(0xFFDCF8C6) : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 3)],
                  ),
                  child: Text(_messages[i]["text"]!, style: const TextStyle(fontSize: 15)),
                ),
              );
            },
          ),
        ),
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _chatController,
                  decoration: const InputDecoration(
                    hintText: "कमांड लिखें (START, SCAN)...",
                    border: InputBorder.none,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.send, color: Color(0xFF075E54)),
                onPressed: _sendWhatsAppMessage,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildUserUiTab() {
    return Container(
      color: Colors.grey.shade100,
      padding: const EdgeInsets.all(16),
      child: Center(
        child: Card(
          elevation: 6,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.apps, size: 50, color: Color(0xFF1E88E5)),
                const SizedBox(height: 12),
                const Text("लाइव यूजर इंटरफेस", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Text("टास्क स्टेटस: $_taskStatus", style: const TextStyle(color: Colors.blueGrey)),
                const Divider(height: 30),
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _counter++;
                      _taskStatus = "सक्रिय ($_counter एक्शन निष्पादित)";
                    });
                  },
                  icon: const Icon(Icons.touch_app),
                  label: Text("एक्शन ट्रिगर (क्लिक: $_counter)"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAdminGateTab() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.verified, size: 70, color: Colors.green),
          const SizedBox(height: 16),
          const Text("सैंडबॉक्स सत्यापन", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text("सैंडबॉक्स डेमो की पुष्टि के बाद फ़ाइनल बिल्ड जनरेट करें।", textAlign: TextAlign.center),
          const SizedBox(height: 24),
          if (_isBuildingApk)
            const CircularProgressIndicator()
          else
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade700,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              ),
              onPressed: _approveAndBuild,
              child: const Text("Approve & Generate APK", style: TextStyle(color: Colors.white)),
            ),
          if (_finalApkUrl != null) ...[
            const SizedBox(height: 20),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade700,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              ),
              onPressed: () => launchUrl(Uri.parse(_finalApkUrl!)),
              icon: const Icon(Icons.download, color: Colors.white),
              label: const Text("Download & Install Final APK", style: TextStyle(color: Colors.white)),
            ),
          ]
        ],
      ),
    );
  }
}
