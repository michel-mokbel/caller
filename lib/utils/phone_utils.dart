import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

class PhoneUtils {
  static Future<bool> checkPhonePermission(BuildContext context) async {
    final hasPermission = await Permission.phone.request().isGranted;
    if (!hasPermission) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Phone permission denied')),
        );
      }
      return false;
    }
    return true;
  }

  static Future<void> makePhoneCall(String phoneNumber, BuildContext context) async {
    if (phoneNumber.isEmpty) return;

    if (!await checkPhonePermission(context)) return;

    final Uri launchUri = Uri(
      scheme: 'tel',
      path: phoneNumber,
    );

    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not launch phone app')),
        );
      }
    }
  }

  static Future<void> sendSMS(String phoneNumber, BuildContext context) async {
    if (phoneNumber.isEmpty) return;

    final Uri launchUri = Uri(
      scheme: 'sms',
      path: phoneNumber,
    );

    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not launch messaging app')),
        );
      }
    }
  }

  static String formatPhoneNumber(String phoneNumber) {
    // Remove any non-digit characters
    final digitsOnly = phoneNumber.replaceAll(RegExp(r'\D'), '');
    
    // Format based on length
    if (digitsOnly.length == 10) {
      return '(${digitsOnly.substring(0, 3)}) ${digitsOnly.substring(3, 6)}-${digitsOnly.substring(6)}';
    } else if (digitsOnly.length == 11) {
      return '+${digitsOnly[0]} (${digitsOnly.substring(1, 4)}) ${digitsOnly.substring(4, 7)}-${digitsOnly.substring(7)}';
    }
    
    // Return as is if we can't format it
    return phoneNumber;
  }
} 