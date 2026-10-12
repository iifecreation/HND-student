// Handles runtime microphone permission requests and checks using permission_handler.

import 'package:permission_handler/permission_handler.dart';

/// Helper class for inspecting and requesting microphone permissions on device.
class VoicePermissions {
  /// Returns true if microphone recording permission is currently granted.
  static Future<bool> hasMicrophonePermission() async {
    final status = await Permission.microphone.status;
    return status.isGranted;
  }

  /// Prompts the user for microphone recording permission.
  /// Returns true if granted, false otherwise.
  static Future<bool> requestMicrophonePermission() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  /// Checks if microphone permission has been permanently denied by the user.
  static Future<bool> isPermanentlyDenied() async {
    final status = await Permission.microphone.status;
    return status.isPermanentlyDenied;
  }

  /// Opens the device system settings page for PrinterDoc if permission is permanently denied.
  static Future<bool> openAppSettingsPage() async {
    return await openAppSettings();
  }
}
