import 'package:flutter/material.dart';
import '../models/secure_contact.dart';
import '../services/vault_service.dart';
import 'package:url_launcher/url_launcher.dart' as url_launcher;

class SecureContactDetailsScreen extends StatefulWidget {
  final SecureContact contact;

  const SecureContactDetailsScreen({
    Key? key,
    required this.contact,
  }) : super(key: key);

  @override
  State<SecureContactDetailsScreen> createState() => _SecureContactDetailsScreenState();
}

class _SecureContactDetailsScreenState extends State<SecureContactDetailsScreen> {
  late Map<String, dynamic> _contactData;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadContactData();
  }

  Future<void> _loadContactData() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      _contactData = SecureContact.decryptContact(
        widget.contact.encryptedData,
        VaultService.instance.encryptionKey!,
        VaultService.instance.iv!,
      );

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error loading contact details: $e';
      });
    }
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final uri = Uri.parse('tel:$phoneNumber');
    if (await url_launcher.canLaunchUrl(uri)) {
      await url_launcher.launchUrl(uri);
    }
  }

  Future<void> _sendEmail(String email) async {
    final uri = Uri.parse('mailto:$email');
    if (await url_launcher.canLaunchUrl(uri)) {
      await url_launcher.launchUrl(uri);
    }
  }

  Future<void> _openMap(Map<String, dynamic> address) async {
    final query = Uri.encodeComponent(
      '${address['street']}, ${address['city']}, ${address['region']} ${address['postcode']}, ${address['country']}'
    );
    final uri = Uri.parse('https://maps.google.com/?q=$query');
    if (await url_launcher.canLaunchUrl(uri)) {
      await url_launcher.launchUrl(uri);
    }
  }

  Widget _buildContactInfo() {
    final phones = _contactData['phones'] as List<dynamic>? ?? [];
    final emails = _contactData['emails'] as List<dynamic>? ?? [];
    final addresses = _contactData['addresses'] as List<dynamic>? ?? [];

    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        Card(
          child: ListTile(
            leading: const Icon(Icons.person),
            title: Text(_contactData['displayName'] as String? ?? 'Unknown'),
            subtitle: _contactData['company'] != null
                ? Text(_contactData['company'] as String)
                : null,
          ),
        ),
        if (phones.isNotEmpty) ...[
          const SizedBox(height: 16),
          Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'Phone Numbers',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: phones.length,
                  itemBuilder: (context, index) {
                    final phone = phones[index] as Map<String, dynamic>;
                    return ListTile(
                      leading: const Icon(Icons.phone),
                      title: Text(phone['value'] as String),
                      subtitle: Text(phone['label'] as String),
                      trailing: IconButton(
                        icon: const Icon(Icons.call),
                        onPressed: () => _makePhoneCall(phone['value'] as String),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
        if (emails.isNotEmpty) ...[
          const SizedBox(height: 16),
          Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'Email Addresses',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: emails.length,
                  itemBuilder: (context, index) {
                    final email = emails[index] as Map<String, dynamic>;
                    return ListTile(
                      leading: const Icon(Icons.email),
                      title: Text(email['value'] as String),
                      subtitle: Text(email['label'] as String),
                      trailing: IconButton(
                        icon: const Icon(Icons.send),
                        onPressed: () => _sendEmail(email['value'] as String),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
        if (addresses.isNotEmpty) ...[
          const SizedBox(height: 16),
          Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'Addresses',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: addresses.length,
                  itemBuilder: (context, index) {
                    final address = addresses[index] as Map<String, dynamic>;
                    final addressText = [
                      address['street'],
                      address['city'],
                      address['region'],
                      address['postcode'],
                      address['country'],
                    ].where((s) => s != null).join(', ');
                    
                    return ListTile(
                      leading: const Icon(Icons.location_on),
                      title: Text(addressText),
                      subtitle: Text(address['label'] as String),
                      trailing: IconButton(
                        icon: const Icon(Icons.map),
                        onPressed: () => _openMap(address),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Contact Details'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                )
              : _buildContactInfo(),
    );
  }
} 