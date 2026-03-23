# 🛡️ Phishing-App-Detector

<div align="center">

![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white)
![Android](https://img.shields.io/badge/Android-3DDC84?style=for-the-badge&logo=android&logoColor=white)
![iOS](https://img.shields.io/badge/iOS-000000?style=for-the-badge&logo=ios&logoColor=white)
![Windows](https://img.shields.io/badge/Windows-0078D6?style=for-the-badge&logo=windows&logoColor=white)

**A professional, cross-platform phishing detection app built with Flutter.**  
Powered by VirusTotal & Google Safe Browsing APIs to keep users safe online.

*Managed by Amit Kushwaha*

</div>

---

## 📖 Table of Contents

1. [Project Description](#-project-description)
2. [Features](#-features)
3. [How the API Integration Works](#-how-the-api-integration-works)
4. [Tech Stack](#-tech-stack)
5. [Flutter Project Structure (A–Z)](#-flutter-project-structure-a-to-z)
6. [Prerequisites](#-prerequisites)
7. [Installation & Setup](#-installation--setup)
8. [Running the Application](#-running-the-application)
9. [Building for Production](#-building-for-production)
10. [API Keys Configuration](#-api-keys-configuration)
11. [App Screens Overview](#-app-screens-overview)
12. [Dependencies](#-dependencies)
13. [Known Issues & Limitations](#-known-issues--limitations)
14. [Contributing](#-contributing)
15. [License](#-license)

---

## 📱 Project Description

**Phishing-App-Detector** (internally named *Phishing Guard* / *Cyber Raksha App*) is a cross-platform mobile and desktop application that helps users verify whether a website URL is safe or a phishing/malicious link — before they click on it.

In an era where phishing attacks are the #1 entry point for cybercrime, this app provides a fast, intelligent, dual-engine security check using two of the most trusted threat intelligence platforms in the world:

- **VirusTotal** — Scans URLs and domains against 70+ antivirus engines simultaneously and fetches domain WHOIS data (registrar, domain age).
- **Google Safe Browsing** — Checks URLs against Google's continuously updated database of malware, social engineering, and unwanted software.

The app combines results from both engines to deliver a confident, reliable verdict: **Safe** or **Phishing Detected**.

Users can also **share a screenshot** of the full security analysis report directly from within the app, making it easy to warn friends and family about dangerous links.

---

## ✨ Features

| Feature | Description |
|---|---|
| 🔍 **Dual-Engine Scanning** | Combines VirusTotal + Google Safe Browsing for maximum accuracy |
| 🌐 **Domain Intelligence** | Fetches domain age, registrar, and protocol (HTTP/HTTPS) |
| 📊 **Threat Level Rating** | Classifies threats as Low / High / Critical based on malicious flag count |
| 📸 **Share Screenshot** | Captures and shares the full analysis report as an image |
| 🔗 **Clickable URL** | Tap the scanned URL in the result to open it in a browser |
| 🎨 **Professional UI** | Clean Material Design 3 interface with gradient backgrounds |
| 📱 **Cross-Platform** | Runs on Android, iOS, Windows, macOS, and Linux |
| ⚡ **Fast Scanning** | Parallel API calls using `Future.wait()` for speed |
| 🔒 **HTTPS Auto-Prefix** | Automatically prepends `https://` if the user omits it |

---

## 🔌 How the API Integration Works

This is the core of the application. The `ApiService` class in `lib/main.dart` orchestrates **three concurrent API calls** and merges their results into a single `SecurityResult` object.

### Architecture Diagram

```
User inputs URL
      │
      ▼
 ApiService.performFullScan(url)
      │
      ├──────────────────────────────────────────┐
      │                                          │
      ▼                                          ▼
scanVirusTotalUrl(url)              scanGoogle(url)
  [VirusTotal /urls endpoint]    [Google Safe Browsing API]
      │                                          │
      ▼                                          │
fetchDomainDetails(domain)                       │
  [VirusTotal /domains endpoint]                 │
      │                                          │
      └──────────────┬───────────────────────────┘
                     │
              Future.wait([...])   ← All 3 run in PARALLEL
                     │
                     ▼
            Merge & Process Results
                     │
                     ▼
            SecurityResult object
                     │
                     ▼
            ResultScreen (UI)
```

### API Call 1 — VirusTotal URL Scan

**Endpoint:** `GET https://www.virustotal.com/api/v3/urls/{urlId}`

The URL is encoded to Base64 (URL-safe, without padding `=`) to create a unique ID. This ID is used to query VirusTotal's analysis database.

```dart
String urlId = base64Url.encode(utf8.encode(url)).replaceAll('=', '');
final response = await http.get(
  Uri.parse('https://www.virustotal.com/api/v3/urls/$urlId'),
  headers: {'x-apikey': vtApiKey},
);
```

**What it returns:** A JSON object containing `last_analysis_stats` with counts like `malicious`, `harmless`, `suspicious`, and `undetected` from all 70+ engines.

**How we use it:** We read `stats['malicious']` to get the count of engines that flagged the URL as dangerous.

---

### API Call 2 — VirusTotal Domain Details

**Endpoint:** `GET https://www.virustotal.com/api/v3/domains/{domain}`

The domain is extracted from the URL using `Uri.parse()`. This separate call fetches WHOIS-style intelligence about the domain itself.

```dart
final response = await http.get(
  Uri.parse('https://www.virustotal.com/api/v3/domains/$domain'),
  headers: {'x-apikey': vtApiKey},
);
```

**What it returns:** Domain attributes including `registrar` (e.g., "GoDaddy"), `creation_date` (Unix timestamp), and domain-level analysis stats.

**How we use it:** We convert `creation_date` to a human-readable "domain age" (e.g., "5 years ago") and display the registrar name.

---

### API Call 3 — Google Safe Browsing

**Endpoint:** `POST https://safebrowsing.googleapis.com/v4/threatMatches:find?key={apiKey}`

This is a POST request that sends a JSON payload describing which threats to check against.

```dart
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
```

**What it returns:** If the URL is dangerous, the response body contains a `matches` key with threat details. If safe, the body is an empty JSON object `{}`.

**How we use it:** `!data.containsKey('matches')` → `true` means the URL is safe according to Google.

---

### Combining Results — Final Verdict Logic

```dart
// All 3 calls run simultaneously
final List<dynamic> results = await Future.wait([
  vtUrlFuture,      // VirusTotal URL report
  googleFuture,     // Google Safe Browsing verdict
  vtDomainFuture,   // VirusTotal domain details
]);

// Final safety decision: BOTH engines must agree it's safe
bool finalIsSafe = vtIsSafe && googleIsSafe;

// Threat level classification
String threatLevel = finalIsSafe
    ? "Low"
    : (maliciousCount > 5 ? "Critical" : "High");
```

This conservative AND logic ensures that if **either** engine flags the URL, the app warns the user. The app defaults to "safe" only if Google's API call fails (network error), preventing false positives due to network issues.

---

## 🛠️ Tech Stack

| Technology | Version | Purpose |
|---|---|---|
| Flutter SDK | ≥ 3.35.0 | Cross-platform UI framework |
| Dart SDK | ≥ 3.9.0, < 4.0.0 | Programming language |
| `http` | ^1.2.0 | Making REST API calls |
| `intl` | ^0.19.0 | Date formatting (domain age) |
| `url_launcher` | ^6.2.5 | Opening URLs in browser |
| `screenshot` | ^3.0.0 | Capturing widget as image |
| `share_plus` | ^9.0.0 | Sharing files across platforms |
| `path_provider` | ^2.1.3 | Temporary directory for screenshots |
| `cupertino_icons` | ^1.0.6 | iOS-style icons |

---

## 📁 Flutter Project Structure (A to Z)

Below is a complete explanation of every folder and file in this Flutter project.

```
flutter_application_1/
│
├── android/                        # Android platform code
│   ├── app/
│   │   ├── src/
│   │   │   ├── main/
│   │   │   │   ├── AndroidManifest.xml   # App permissions, activity, app name
│   │   │   │   ├── kotlin/               # Kotlin entry point (MainActivity)
│   │   │   │   └── res/                  # Android resources (icons, splash)
│   │   │   ├── debug/AndroidManifest.xml # Extra permissions for debug builds
│   │   │   └── profile/AndroidManifest.xml
│   │   └── build.gradle.kts             # App-level Gradle build config
│   ├── build.gradle.kts                 # Project-level Gradle config
│   ├── settings.gradle.kts              # Gradle plugin management
│   └── gradle.properties                # JVM args, AndroidX flag
│
├── ios/                            # iOS platform code
│   ├── Runner/
│   │   ├── AppDelegate.swift            # iOS app entry point
│   │   ├── Info.plist                   # App display name, permissions, orientations
│   │   ├── Assets.xcassets/             # App icons and launch images
│   │   └── Base.lproj/
│   │       ├── Main.storyboard          # Flutter view controller storyboard
│   │       └── LaunchScreen.storyboard  # Splash screen layout
│   ├── RunnerTests/
│   │   └── RunnerTests.swift            # iOS unit tests
│   ├── Runner.xcodeproj/                # Xcode project file (build settings)
│   └── Runner.xcworkspace/              # Xcode workspace (includes CocoaPods)
│
├── macos/                          # macOS desktop platform code
│   ├── Runner/
│   │   ├── AppDelegate.swift            # macOS app delegate
│   │   ├── MainFlutterWindow.swift      # Main window setup
│   │   ├── Info.plist                   # Bundle info for macOS
│   │   ├── DebugProfile.entitlements    # Sandbox + network permissions (dev)
│   │   ├── Release.entitlements         # Sandbox permissions (production)
│   │   └── Configs/
│   │       ├── AppInfo.xcconfig         # App name, bundle ID, copyright
│   │       ├── Debug.xcconfig           # Debug build config
│   │       ├── Release.xcconfig         # Release build config
│   │       └── Warnings.xcconfig        # Compiler warning flags
│   └── Flutter/
│       ├── Flutter-Debug.xcconfig       # Flutter-generated debug config
│       ├── Flutter-Release.xcconfig     # Flutter-generated release config
│       └── GeneratedPluginRegistrant.swift  # Auto-generated plugin registration
│
├── windows/                        # Windows desktop platform code
│   ├── runner/
│   │   ├── main.cpp                     # Windows app entry point (WinMain)
│   │   ├── flutter_window.cpp/.h        # Hosts Flutter engine in Win32 window
│   │   ├── win32_window.cpp/.h          # Win32 window abstraction (DPI aware)
│   │   ├── utils.cpp/.h                 # UTF-16 to UTF-8 conversion utils
│   │   ├── resource.h                   # Resource IDs (app icon)
│   │   ├── Runner.rc                    # Windows resource script (version info)
│   │   └── runner.exe.manifest          # DPI awareness, Windows version compat
│   ├── flutter/
│   │   ├── generated_plugin_registrant.cc/.h  # Auto-generated plugin registration
│   │   └── generated_plugins.cmake      # Plugin build rules
│   └── CMakeLists.txt                   # Top-level CMake build config
│
├── linux/                          # Linux desktop platform code
│   ├── runner/
│   │   ├── main.cc                      # Linux app entry point
│   │   ├── my_application.cc/.h         # GTK+ application wrapper
│   │   └── CMakeLists.txt               # Linux runner build config
│   ├── flutter/
│   │   ├── generated_plugin_registrant.cc/.h
│   │   └── generated_plugins.cmake
│   └── CMakeLists.txt                   # Linux top-level CMake config
│
├── web/                            # Web platform support
│   ├── index.html                       # Web app HTML shell
│   ├── manifest.json                    # PWA manifest (name, icons, theme)
│   └── icons/                          # PWA icon assets
│
├── lib/                            # ⭐ DART SOURCE CODE (main business logic)
│   ├── main.dart                        # App entry point + all core screens
│   │   ├── main()                       # Runs the Flutter app
│   │   ├── MyApp                        # Root MaterialApp widget + theming
│   │   ├── SecurityResult               # Data model for scan results
│   │   ├── ApiService                   # All API calls (VT + Google)
│   │   ├── HomeScreen                   # URL input screen
│   │   └── ResultScreen                 # Analysis results + share screen
│   │
│   └── phishing.dart                    # Secondary phishing check screen
│       └── PhishingLink                 # Simple local URL heuristic checker
│       └── checkWebsiteStatus()        # Offline rule-based URL analysis
│
├── test/                           # Automated tests
│   └── widget_test.dart                 # Basic smoke test (title, field, button)
│
├── pubspec.yaml                    # ⭐ Project manifest: dependencies, metadata
├── pubspec.lock                    # Locked dependency versions (commit this!)
├── analysis_options.yaml           # Dart static analysis / linting rules
├── .metadata                       # Flutter tool metadata (migration tracking)
├── .gitignore                      # Files excluded from Git
└── README.md                       # This file
```

### Key Files Explained in Depth

#### `lib/main.dart` — The Heart of the App

This single file contains the entire application logic, organized into 4 major sections:

| Section | Class | Responsibility |
|---|---|---|
| App Configuration | `MyApp` | Theme, colors, routing, app title |
| Data Model | `SecurityResult` | Holds all scan result fields |
| API Service | `ApiService` | 3 static methods calling external APIs |
| Home Screen | `HomeScreen` | URL input field and Scan button |
| Result Screen | `ResultScreen` | Displays result, handles share screenshot |

#### `pubspec.yaml` — Dependency Manifest

This is the equivalent of `package.json` in Node.js. It defines the project name, description, SDK version constraints, and all third-party packages. Running `flutter pub get` reads this file and downloads all packages listed under `dependencies`.

#### `android/app/src/main/AndroidManifest.xml` — Android Permissions

This file declares the app's permissions. This project requires:
- `INTERNET` — For API calls to VirusTotal and Google
- `ACCESS_NETWORK_STATE` — To check network connectivity
- `ACCESS_WIFI_STATE` — Additional network state info

The app label is set to **"Cyber Raksha App"** here.

#### `pubspec.lock` — Version Lock File

Auto-generated by `flutter pub get`. Always commit this file to Git — it ensures every developer and CI system installs the exact same package versions, preventing "works on my machine" bugs.

---

## ✅ Prerequisites

Before you begin, ensure you have the following installed:

| Tool | Minimum Version | Download |
|---|---|---|
| Flutter SDK | 3.35.0 | [flutter.dev](https://flutter.dev/docs/get-started/install) |
| Dart SDK | 3.9.0 (bundled with Flutter) | Included with Flutter |
| Android Studio | Latest stable | [developer.android.com](https://developer.android.com/studio) |
| Xcode (macOS only) | 14.0+ | Mac App Store |
| Git | Any | [git-scm.com](https://git-scm.com) |

Verify your setup by running:

```bash
flutter doctor
```

All items should show a green checkmark ✅. Resolve any issues before proceeding.

---

## ⚙️ Installation & Setup

### Step 1: Clone the Repository

```bash
git clone https://github.com/YOUR_USERNAME/Phishing-App-Detector.git
cd Phishing-App-Detector
```

### Step 2: Navigate to the Flutter Project

```bash
cd flutter_application_1
```

### Step 3: Install Dependencies

```bash
flutter pub get
```

This command reads `pubspec.yaml` and downloads all required packages into your local `.pub-cache`.

### Step 4: Configure API Keys

Open `lib/main.dart` and locate the `ApiService` class. Replace the placeholder keys with your own:

```dart
class ApiService {
  static const String vtApiKey = 'YOUR_VIRUSTOTAL_API_KEY_HERE';
  static const String googleApiKey = 'YOUR_GOOGLE_SAFE_BROWSING_API_KEY_HERE';
```

See the [API Keys Configuration](#-api-keys-configuration) section below for how to obtain these keys.

### Step 5: Verify Setup

```bash
flutter analyze
flutter test
```

---

## ▶️ Running the Application

### On Android (Physical Device or Emulator)

```bash
# List available devices
flutter devices

# Run on a specific device
flutter run -d <device-id>

# Run on the first available device
flutter run
```

> **Tip:** Enable USB Debugging on your Android device under Developer Options.

### On iOS (macOS required)

```bash
# Open iOS Simulator
open -a Simulator

# Run on simulator
flutter run -d iPhone

# Run on physical device (requires Apple Developer account)
flutter run -d <your-device-udid>
```

### On Windows

```bash
flutter run -d windows
```

### On macOS

```bash
flutter run -d macos
```

### On Linux

```bash
flutter run -d linux
```

### On Web (Chrome)

```bash
flutter run -d chrome
```

---

## 📦 Building for Production

### Android APK (for direct installation)

```bash
flutter build apk --release
```

Output: `build/app/outputs/flutter-apk/app-release.apk`

### Android App Bundle (for Google Play)

```bash
flutter build appbundle --release
```

Output: `build/app/outputs/bundle/release/app-release.aab`

### iOS (macOS required)

```bash
flutter build ios --release
```

Then open Xcode and archive the build for App Store submission.

### Windows Executable

```bash
flutter build windows --release
```

Output: `build/windows/x64/runner/Release/`

### macOS Application

```bash
flutter build macos --release
```

---

## 🔑 API Keys Configuration

### VirusTotal API Key (Free)

1. Go to [https://www.virustotal.com](https://www.virustotal.com)
2. Create a free account
3. Navigate to your **Profile → API Key**
4. Copy the key — the free tier allows **4 requests/minute** and **500 requests/day**

### Google Safe Browsing API Key (Free)

1. Go to [Google Cloud Console](https://console.cloud.google.com)
2. Create a new project (or select an existing one)
3. Navigate to **APIs & Services → Enable APIs**
4. Search for and enable the **Safe Browsing API**
5. Go to **APIs & Services → Credentials → Create Credentials → API Key**
6. Copy the generated key

> ⚠️ **Security Warning:** Never commit real API keys to a public GitHub repository. For production apps, use environment variables, `--dart-define`, or a secure secrets management solution. Consider restricting your Google API key to specific IP addresses or Android/iOS apps in the Google Cloud Console.

---

## 📲 App Screens Overview

### Screen 1: Home Screen

- Large shield icon header with blue gradient background
- Clean text input field for pasting URLs
- "SCAN FOR PHISHING" button that navigates to the Result Screen
- Auto-prepends `https://` if missing
- Footer credits
  ## 📸 Screenshots

<p align="center">
  <img src="https://github.com/user-attachments/assets/69913def-5f49-4e2b-b2ff-ed389a65ef27" width="300"/>
</p>

### Screen 2: Result Screen (Analysis Report)

- Full-screen loading indicator while APIs are called in parallel
- **Status Card** — Large icon + "Safe" (green) or "Phishing Detected" (red)
- **URL Intelligence Panel** showing:
  - Full URL (clickable, opens in browser)
  - Extracted domain
  - Domain age (e.g., "5 years ago")
  - Registrar name
  - Protocol (HTTP or HTTPS)
  - Threat Level (Low / High / Critical)
- **Share Screenshot** button — captures the result card and shares as a PNG image
## 📸 Screenshots

<p align="center">
  <img src="![Screenshot_20260323_204144](https://github.com/user-attachments/assets/08a9d4c7-1942-4bcd-9395-ef83dd353a5e)"
 width="300"/>
</p>

---

## 📚 Dependencies

Full list of packages used:

```yaml
dependencies:
  http: ^1.2.0           # REST API calls to VirusTotal & Google
  intl: ^0.19.0           # Formatting domain creation dates
  url_launcher: ^6.2.5    # Opens URLs in the device browser
  screenshot: ^3.0.0      # Captures Flutter widgets as PNG images
  share_plus: ^9.0.0      # Native share sheet for files
  path_provider: ^2.1.3   # Gets temp directory to save screenshot PNG
  cupertino_icons: ^1.0.6 # iOS-style icons in icon font
```

---

## ⚠️ Known Issues & Limitations

| Issue | Details |
|---|---|
| **Free API Rate Limits** | VirusTotal free tier: 4 req/min, 500 req/day. Heavy usage will hit this limit. |
| **VirusTotal First-Time URLs** | URLs never scanned before return empty results. A submission step would be needed for 100% coverage. |
| **Web Platform Share** | `share_plus` uses the Web Share API, which may not be supported in all browsers. |
| **Screenshot on Web** | The `screenshot` package may have limitations on the web platform. |
| **API Keys in Source** | Current implementation has keys hardcoded. Move to secure environment variables for production. |
| **No Offline Mode** | The app requires internet connectivity for all scanning functionality. |

---

## 🤝 Contributing

Contributions are welcome! Here's how to get started:

1. **Fork** the repository on GitHub
2. **Clone** your fork: `git clone https://github.com/YOUR_USERNAME/Phishing-App-Detector.git`
3. **Create a branch**: `git checkout -b feature/your-feature-name`
4. **Make your changes** and run `flutter test` to ensure nothing is broken
5. **Commit**: `git commit -m "Add: your feature description"`
6. **Push**: `git push origin feature/your-feature-name`
7. **Open a Pull Request** on the original repository

### Suggested Improvements

- Add URL submission to VirusTotal for first-time scans
- Implement scan history using local database (`sqflite`)
- Add QR code scanner to check links from images
- Move API keys to environment variables using `--dart-define`
- Add dark mode support
- Implement rate limit error handling with user-friendly messages

---

## 📄 License

This project is open source. Please check the repository for license details.

---

<div align="center">

**Built with ❤️ using Flutter**

*Managed by Amit Kushwaha*

⭐ If this project helped you, consider giving it a star on GitHub!

</div>
