# share_app_latest

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Reducing app size

Release builds use **minification** and **resource shrinking** (Android). For the smallest output:

- **Android APK (per device, smaller):**
  ```bash
  flutter build apk --release --split-per-abi --obfuscate --split-debug-info=./debug-info/
  ```
- **Android App Bundle (for Play Store, recommended):**
  ```bash
  flutter build appbundle --release --obfuscate --split-debug-info=./debug-info/
  ```
- **iOS:** Release builds strip symbols by default.
