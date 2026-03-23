import 'package:flutter/material.dart';
// import 'phishing_detect.dart'; 

class PhishingLink extends StatefulWidget {
  const PhishingLink({super.key});

  @override
  State<PhishingLink> createState() => _PhishingLinkState();
}

class _PhishingLinkState extends State<PhishingLink> {
  String result = '';
  final TextEditingController titleController = TextEditingController();
  bool isLoading = false; // Added loading state for better UI

  @override
  void dispose() {
    titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Beware of Phishing'),
        backgroundColor: Colors.deepOrange,
      ),
      body: SingleChildScrollView( // Added ScrollView to prevent overflow
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  label: Text('Enter Link'),
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.link),
                ),
              ),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepOrange,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                setState(() {
                  isLoading = true;
                  result = "Checking...";
                });

                String url = titleController.text;
                
                
                String apiResult = await checkWebsiteStatus(url);
                
                setState(() {
                  result = apiResult;
                  isLoading = false;
                });
              },
              child: const Text('Check URL'),
            ),
            
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: isLoading 
                  ? const CircularProgressIndicator(color: Colors.deepOrange)
                  : Text(
                      result,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: result.contains("SAFE") ? Colors.green : Colors.deepOrange,
                      ),
                    ),
            ),
            
            const SizedBox(height: 30),
            
            const Padding(
              padding: EdgeInsets.only(top: 30),
              child: Divider(
                color: Colors.deepOrange,
                thickness: 2,
                indent: 20,
                endIndent: 20,
              ),
            ),
            
            const Padding(
              padding: EdgeInsets.all(12.0),
              child: Text(
                'Help us improve, Was this a phishing link?',
                style: TextStyle(color: Colors.white70),
              ),
            ),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton(
                  onPressed: () {}, 
                  child: const Text('Yes', style: TextStyle(color: Colors.deepOrange))
                ),
                TextButton(
                  onPressed: () {}, 
                  child: const Text('No', style: TextStyle(color: Colors.deepOrange))
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// --- LOGIC FUNCTION ADDED HERE ---

Future<String> checkWebsiteStatus(String url) async {
  
  // Fake loading delay
  await Future.delayed(const Duration(milliseconds: 1500));

  String lowerUrl = url.toLowerCase();

  if (url.isEmpty) {
    return "Please enter a URL first!";
  }

  if (url.length > 75) {
    return "⚠️ PHISHING DETECTED!\nReason: URL is suspiciously long.";
  } 
  else if (lowerUrl.contains("@") || lowerUrl.contains("-login") || lowerUrl.contains("update-bank")) {
    return "⚠️ PHISHING DETECTED!\nReason: URL contains suspicious keywords.";
  } 
  else if (!lowerUrl.startsWith("http")) {
    return "⚠️ INVALID URL\nPlease start with http:// or https://";
  }
  else {
    return "✅ WEBSITE IS SAFE\nYou can visit this link.";
  }
}