import 'package:flutter/material.dart';
import 'package:contacts_service/contacts_service.dart';
import 'package:url_launcher/url_launcher.dart' as url_launcher;

class ContactDetailsScreen extends StatelessWidget {
  final Contact contact;

  const ContactDetailsScreen({
    Key? key,
    required this.contact,
  }) : super(key: key);

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

  Future<void> _openMap(PostalAddress address) async {
    final query = Uri.encodeComponent(
      '${address.street}, ${address.city}, ${address.region} ${address.postcode}, ${address.country}'
    );
    final uri = Uri.parse('https://maps.google.com/?q=$query');
    if (await url_launcher.canLaunchUrl(uri)) {
      await url_launcher.launchUrl(uri);
    }
  }

  Widget _buildContactInfo() {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        Card(
          child: ListTile(
            leading: const Icon(Icons.person),
            title: Text(contact.displayName ?? 'Unknown'),
            subtitle: contact.company != null ? Text(contact.company!) : null,
          ),
        ),
        if (contact.phones?.isNotEmpty ?? false) ...[
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
                  itemCount: contact.phones?.length ?? 0,
                  itemBuilder: (context, index) {
                    final phone = contact.phones![index];
                    return ListTile(
                      leading: const Icon(Icons.phone),
                      title: Text(phone.value ?? ''),
                      subtitle: Text(phone.label ?? ''),
                      trailing: IconButton(
                        icon: const Icon(Icons.call),
                        onPressed: () => _makePhoneCall(phone.value!),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
        if (contact.emails?.isNotEmpty ?? false) ...[
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
                  itemCount: contact.emails?.length ?? 0,
                  itemBuilder: (context, index) {
                    final email = contact.emails![index];
                    return ListTile(
                      leading: const Icon(Icons.email),
                      title: Text(email.value ?? ''),
                      subtitle: Text(email.label ?? ''),
                      trailing: IconButton(
                        icon: const Icon(Icons.send),
                        onPressed: () => _sendEmail(email.value!),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
        if (contact.postalAddresses?.isNotEmpty ?? false) ...[
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
                  itemCount: contact.postalAddresses?.length ?? 0,
                  itemBuilder: (context, index) {
                    final address = contact.postalAddresses![index];
                    final addressText = [
                      address.street,
                      address.city,
                      address.region,
                      address.postcode,
                      address.country,
                    ].where((s) => s != null && s.isNotEmpty).join(', ');
                    
                    return ListTile(
                      leading: const Icon(Icons.location_on),
                      title: Text(addressText),
                      subtitle: Text(address.label ?? ''),
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
      body: _buildContactInfo(),
    );
  }
} 