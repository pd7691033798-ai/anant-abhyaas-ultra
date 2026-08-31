---
name: Flutter Android validation
description: Workspace limitation affecting Flutter APK verification.
---

This workspace provides Flutter and Dart but does not provide an Android SDK, so `flutter build apk` cannot run here.

**Why:** The Flutter client can still be validated through the web preview, `flutter analyze`, and `flutter test`; APK compilation requires an Android SDK-enabled environment.

**How to apply:** Do not treat a missing Android SDK as a Dart or app-code failure. Report the limitation clearly and use the available Flutter checks for Replit validation.