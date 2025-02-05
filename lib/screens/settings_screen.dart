import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'secure_contacts_screen.dart';
import 'blocked_numbers_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {

  void showPrivacyPolicy(BuildContext context) async {
    String htmlFilePath = 'lib/assets/html/privacy_policy_en.html';
    String htmlData = await rootBundle.loadString(htmlFilePath);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Privacy Policy'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Html(data: htmlData),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _checkPermissions() async {
    final contacts = await Permission.contacts.status;

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permissions Status'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPermissionStatus('Contacts', contacts),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
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

  Future<void> _shareApp() async {
    const String appURL = 'https://apps.apple.com/us/app/vault-book/id6741470168';



    try {
      final box = context.findRenderObject() as RenderBox?;

      await Share.share(appURL,
        sharePositionOrigin: box!.localToGlobal(Offset.zero) & box.size,
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to share: ${e.toString()}'),
          duration: const Duration(seconds: 3),
          action: SnackBarAction(
            label: 'Retry',
            onPressed: _shareApp,
          ),
        ),
      );
    }
  }

  Widget _buildPermissionStatus(String name, PermissionStatus status) {
    final icon = status.isGranted
        ? const Icon(Icons.check_circle, color: Colors.green)
        : const Icon(Icons.error, color: Colors.red);

    return Row(
      children: [
        icon,
        const SizedBox(width: 8),
        Text('$name: ${status.name}'),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          const ListTile(
            title: Text(
              'General',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.share),
            title: const Text('Share App'),
            subtitle: const Text('Tell your friends about this app'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: _shareApp,
          ),
          // SwitchListTile(
          //   value: _showContactPhoto,
          //   onChanged: (value) {
          //     setState(() => _showContactPhoto = value);
          //   },
          //   title: const Text('Show Contact Photos'),
          //   subtitle: const Text('Display contact photos in lists'),
          // ),
          ListTile(
            leading: const Icon(Icons.security),
            title: const Text('Privacy Policy'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              showPrivacyPolicy(context);
            },
          ),
          const Divider(),
          const ListTile(
            title: Text(
              'Security',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.security),
            title: const Text('Secure Contacts Vault'),
            subtitle: const Text('Manage encrypted contacts'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SecureContactsScreen(),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.key),
            title: const Text('App Permissions'),
            subtitle: const Text('Manage app permissions'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: _checkPermissions,
          ),
          ListTile(
            leading: const Icon(Icons.block),
            title: const Text('Blocked Numbers'),
            subtitle: const Text('Manage blocked contacts and numbers'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const BlockedNumbersScreen(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
