import 'dart:convert';
import 'dart:io'; // Needed for file handling
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
// --- NEW IMPORTS ---
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';

void main() {
  runApp(const MyApp());
}

// ==================== 1. APP CONFIGURATION ====================
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Phishing Guard',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF0F4F8), // Light Blue-Grey Background
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1E88E5), // Professional Blue
          primary: const Color(0xFF1E88E5),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          iconTheme: IconThemeData(color: Colors.black87),
          titleTextStyle: TextStyle(
              color: Colors.black87, fontSize: 22, fontWeight: FontWeight.bold),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1E88E5),
            foregroundColor: Colors.white,
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}

// ==================== 2. API SERVICES (BACKEND LOGIC) ====================

class SecurityResult {
  bool isSafe;
  String threatLevel;
  String domain;
  String registrar;
  String creationDate;
  String protocol;
  int maliciousCount;
  String source;

  SecurityResult({
    required this.isSafe,
    required this.threatLevel,
    required this.domain,
    required this.registrar,
    required this.creationDate,
    required this.protocol,
    required this.maliciousCount,
    required this.source,
  });
}

class ApiService {
  // --- API KEYS ---
  static const String vtApiKey = 'b7c20280876a144a8482c4a91b3da5ce1899b14ff055a3ec715836f79f25095c';
  static const String googleApiKey = 'AIzaSyCmNRZTzD5nHzk48q8il6ut9x9sGVppOIQ';

  // --- 1. SCAN URL (VirusTotal) ---
  static Future<Map<String, dynamic>> scanVirusTotalUrl(String url) async {
    String urlId = base64Url.encode(utf8.encode(url)).replaceAll('=', '');
    try {
      final response = await http.get(
        Uri.parse('https://www.virustotal.com/api/v3/urls/$urlId'),
        headers: {'x-apikey': vtApiKey},
      );
      if (response.statusCode == 200) return jsonDecode(response.body);
    } catch (e) {
      debugPrint("VT URL Error: $e");
    }
    return {};
  }

  // --- 2. FETCH DOMAIN DETAILS (VirusTotal) ---
  static Future<Map<String, dynamic>> fetchDomainDetails(String domain) async {
    try {
      final response = await http.get(
        Uri.parse('https://www.virustotal.com/api/v3/domains/$domain'),
        headers: {'x-apikey': vtApiKey},
      );
      if (response.statusCode == 200) return jsonDecode(response.body);
    } catch (e) {
      debugPrint("VT Domain Error: $e");
    }
    return {};
  }

  // --- 3. SCAN URL (Google Safe Browsing) ---
  static Future<bool> scanGoogle(String url) async {
    try {
      final response = await http.post(
        Uri.parse("https://safebrowsing.googleapis.com/v4/threatMatches:find?key=$googleApiKey"),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "client": {"clientId": "phishing_app", "clientVersion": "1.0"},
          "threatInfo": {
            "threatTypes": ["MALWARE", "SOCIAL_ENGINEERING", "UNWANTED_SOFTWARE"],
            "platformTypes": ["ANY_PLATFORM"],
            "threatEntryTypes": ["URL"],
            "threatEntries": [{"url": url}]
          }
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return !data.containsKey('matches');
      }
    } catch (e) {
      debugPrint("Google API Error: $e");
    }
    return true; // Default safe if Google fails
  }

  // --- MAIN FUNCTION: COMBINES ALL 3 CALLS ---
  static Future<SecurityResult> performFullScan(String url) async {
    Uri? uri = Uri.tryParse(url);
    String domain = uri?.host ?? "";
    if (domain.isEmpty) domain = url.split('/')[0]; 

    final vtUrlFuture = scanVirusTotalUrl(url);
    final vtDomainFuture = fetchDomainDetails(domain);
    final googleFuture = scanGoogle(url);

    final List<dynamic> results = await Future.wait([vtUrlFuture, googleFuture, vtDomainFuture]);
    
    final vtUrlData = results[0] as Map<String, dynamic>;
    final bool googleIsSafe = results[1] as bool;
    final vtDomainData = results[2] as Map<String, dynamic>;

    // --- Process Data ---
    String protocol = uri?.scheme.toUpperCase() ?? "HTTP";
    String registrar = "Unknown / Private";
    String creationDate = "Unknown";
    int maliciousCount = 0;
    bool vtIsSafe = true;

    // 1. Analyze Threats (URL Report)
    if (vtUrlData.isNotEmpty && vtUrlData.containsKey('data')) {
      final stats = vtUrlData['data']['attributes']['last_analysis_stats'];
      maliciousCount = stats['malicious'] ?? 0;
      vtIsSafe = maliciousCount == 0;
    }

    // 2. Get Age & Registrar (Domain Report)
    if (vtDomainData.isNotEmpty && vtDomainData.containsKey('data')) {
      final attributes = vtDomainData['data']['attributes'];
      
      if (attributes.containsKey('registrar')) {
        registrar = attributes['registrar'];
      }
      
      int dateTs = attributes['creation_date'] ?? 0;
      if (dateTs > 0) {
        DateTime date = DateTime.fromMillisecondsSinceEpoch(dateTs * 1000);
        int ageYears = DateTime.now().year - date.year;
        creationDate = ageYears > 0 ? "$ageYears years ago" : DateFormat('dd MMM yyyy').format(date);
      }
    }

    // Final Safety Decision
    bool finalIsSafe = vtIsSafe && googleIsSafe;
    String threatLevel = finalIsSafe ? "Low" : (maliciousCount > 5 ? "Critical" : "High");

    return SecurityResult(
      isSafe: finalIsSafe,
      threatLevel: threatLevel,
      domain: domain.isNotEmpty ? domain : url,
      registrar: registrar,
      creationDate: creationDate,
      protocol: protocol,
      maliciousCount: maliciousCount,
      source: "Dual-Engine (VirusTotal + Google)",
    );
  }
}

// ==================== 3. HOME SCREEN ====================
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _urlController = TextEditingController();

  void _startScan() {
    String url = _urlController.text.trim();
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please enter a URL first.")));
      return;
    }
    if (!url.startsWith("http")) {
      url = "https://$url"; 
    }
    FocusScope.of(context).unfocus();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ResultScreen(url: url)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFE1F5FE), Color(0xFFF0F4F8)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Header Icon
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: Colors.blue.withValues(alpha: 0.2), blurRadius: 20, offset: const Offset(0, 10))
                    ],
                  ),
                  child: const Icon(Icons.shield_outlined, size: 80, color: Color(0xFF1E88E5)),
                ),
                const SizedBox(height: 30),
                
                // Title
                const Text(
                  "Phishing Detector",
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1565C0),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  "Verify links before you click.\nSecure your digital life.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.blueGrey.shade700),
                ),
                const SizedBox(height: 50),
                
                // Input Field
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 15, offset: const Offset(0, 5))
                    ],
                  ),
                  child: TextField(
                    controller: _urlController,
                    decoration: InputDecoration(
                      hintText: "Paste website URL here...",
                      hintStyle: TextStyle(color: Colors.grey.shade400),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                      prefixIcon: const Icon(Icons.link, color: Color(0xFF1E88E5)),
                      contentPadding: const EdgeInsets.all(20),
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                
                // SCAN Button
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton(
                    onPressed: _startScan,
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.radar),
                        SizedBox(width: 10),
                        Text("SCAN FOR PHISHING"),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 30),
                
                // Footer
                Text(
                  "Powered by VirusTotal & Google Safe Browsing", 
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 11)
                ),
                const SizedBox(height: 8),
                const Text(
                  "Managed by Amit Kushwaha",
                  style: TextStyle(
                    color: Colors.blueGrey, 
                    fontSize: 14,
                    fontWeight: FontWeight.bold, 
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ==================== 4. RESULT SCREEN (WITH SHARE) ====================
class ResultScreen extends StatefulWidget {
  final String url;
  const ResultScreen({super.key, required this.url});

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  SecurityResult? result;
  bool isLoading = true;
  bool isSharing = false; // To show loading during share capture

  // Controller for capturing screenshot
  final ScreenshotController _screenshotController = ScreenshotController();

  @override
  void initState() {
    super.initState();
    _runAnalysis();
  }

  Future<void> _runAnalysis() async {
    final data = await ApiService.performFullScan(widget.url);
    if (mounted) {
      setState(() {
        result = data;
        isLoading = false;
      });
    }
  }

  // --- NEW: SHARE SCREENSHOT FUNCTION ---
  Future<void> _shareScreenshot() async {
    setState(() {
      isSharing = true; // Start loading indicator
    });

    try {
      // 1. Capture the widget image
      final imageBytes = await _screenshotController.capture();

      if (imageBytes != null) {
        // 2. Get temporary directory to save the image
        final directory = await getTemporaryDirectory();
        final imagePath = await File('${directory.path}/security_report.png').create();
        
        // 3. Write image bytes to the file
        await imagePath.writeAsBytes(imageBytes);

        // 4. Share the file using Share Plus
        // Using XFile for cross-platform compatibility (newer share_plus versions)
        await Share.shareXFiles([XFile(imagePath.path)], text: 'Check out this security analysis report for ${widget.url}');
      }
    } catch (e) {
      debugPrint("Share Error: $e");
       if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(content: Text("Failed to create screenshot.")));
      }
    } finally {
       if (mounted) {
        setState(() {
          isSharing = false; // Stop loading indicator
        });
      }
    }
  }

  Future<void> _launchURL(String urlString) async {
    final Uri url = Uri.parse(urlString);
    try {
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        throw 'Could not launch';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(content: Text("Could not open link")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: Color(0xFF1E88E5)),
              const SizedBox(height: 20),
              Text("Scanning Domain & URL...", style: TextStyle(color: Colors.blueGrey.shade700)),
            ],
          ),
        ),
      );
    }

    final bool isSafe = result!.isSafe;
    final Color statusColor = isSafe ? const Color(0xFF00C853) : const Color(0xFFD50000);
    final String statusText = isSafe ? "Safe" : "Phishing Detected";
    final IconData statusIcon = isSafe ? Icons.gpp_good_rounded : Icons.gpp_bad_rounded;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: const Text("Analysis Report"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        // Hide Share button on AppBar while sharing to avoid capturing it
        actions: isSharing ? [] : [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _shareScreenshot,
            tooltip: "Share Report",
          )
        ],
      ),
      body: SingleChildScrollView(
        // WRAP CONTENT WITH SCREENSHOT WIDGET
        child: Screenshot(
          controller: _screenshotController,
          child: Container(
            color: const Color(0xFFF0F4F8), // Ensure background color is captured
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                const SizedBox(height: 10),
                
                // Status Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 30),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20, offset: const Offset(0, 10))
                    ],
                  ),
                  child: Column(
                    children: [
                      Icon(statusIcon, size: 80, color: statusColor),
                      const SizedBox(height: 15),
                      Text(
                        statusText,
                        style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            color: statusColor),
                      ),
                      const SizedBox(height: 5),
                      if (!isSafe)
                         Text("Malicious Flags: ${result!.maliciousCount}",
                             style: TextStyle(color: Colors.red.shade300, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),

                const SizedBox(height: 30),

                // Details List
                Container(
                  padding: const EdgeInsets.all(25),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(25),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20, offset: const Offset(0, 5))
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("URL INTELLIGENCE",
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade400,
                              letterSpacing: 1.2)),
                      const SizedBox(height: 25),
                      
                      _buildInfoRow("URL", widget.url, isLink: true, onTap: () => _launchURL(widget.url)),
                      _buildDivider(),
                      _buildInfoRow("Domain", result!.domain),
                      _buildDivider(),
                      _buildInfoRow("Domain Age", result!.creationDate),
                      _buildDivider(),
                      _buildInfoRow("Registrar", result!.registrar),
                      _buildDivider(),
                      _buildInfoRow("Protocol", result!.protocol),
                      _buildDivider(),
                      _buildInfoRow("Threat Level", result!.threatLevel, valueColor: statusColor, isBold: true),
                    ],
                  ),
                ),
                const SizedBox(height: 30),

                // --- NEW SHARE BUTTON ---
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton.icon(
                    onPressed: isSharing ? null : _shareScreenshot, // Disable if already sharing
                    icon: isSharing 
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                        : const Icon(Icons.share),
                    label: Text(isSharing ? "Generating Image..." : "Share Screenshot"),
                  ),
                ),
                const SizedBox(height: 20),
                 const Text(
                  "Managed by Amit Kushwaha",
                  style: TextStyle(color: Colors.blueGrey, fontWeight: FontWeight.bold),
                ),
                 const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String title, String value,
      {Color valueColor = Colors.black87, bool isBold = false, bool isLink = false, VoidCallback? onTap}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(
                  color: Colors.blueGrey.shade400, fontWeight: FontWeight.w600, fontSize: 14)),
          const SizedBox(width: 20),
          Expanded(
            child: GestureDetector(
              onTap: isLink ? onTap : null,
              child: Text(
                value,
                textAlign: TextAlign.end,
                style: TextStyle(
                  color: isLink ? Colors.blue : valueColor,
                  fontWeight: isBold ? FontWeight.w800 : FontWeight.w500,
                  fontSize: 15,
                  decoration: isLink ? TextDecoration.underline : TextDecoration.none,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(height: 1, color: Colors.grey.shade100);
  }
}