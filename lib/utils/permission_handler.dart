import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/services.dart';

class PermissionUtils {
  static final List<Permission> _permissions = [
    Permission.contacts,
    Permission.microphone,
    Permission.notification,
    if (!Platform.isIOS) Permission.phone,
  ];

  static Future<bool> checkAndRequestPermissions(BuildContext context) async {
    // Request each permission directly using system prompts
    Map<Permission, PermissionStatus> statuses = {};
    bool allGranted = true;
    
    for (var permission in _permissions) {
      final status = await permission.request();
      statuses[permission] = status;
      
      // Check if this permission is not granted
      if (!status.isGranted) {
        debugPrint('Permission ${permission.toString()} status: ${status.toString()}');
        allGranted = false;
      }
    }

    // If all permissions are granted, return true
    if (allGranted) {
      return true;
    }

    // Only show settings dialog if permissions are actually denied
    if (context.mounted) {
      _showSettingsDialog(context);
    }
    return false;
  }

  static void _showSettingsDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Permissions Required'),
        content: const Text(
          'Some permissions are required for the app to work properly. Please enable them in Settings.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              SystemNavigator.pop();
            },
            child: const Text('Exit App'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }
} 