import 'package:flutter/material.dart';
import 'package:contacts_service/contacts_service.dart';
import 'package:url_launcher/url_launcher.dart' as url_launcher;
import '../utils/database_helper.dart';

class RegularContactDetailsScreen extends StatefulWidget {
  final Contact contact;

  const RegularContactDetailsScreen({
    Key? key,
    required this.contact,
  }) : super(key: key);

  @override
  State<RegularContactDetailsScreen> createState() => _RegularContactDetailsScreenState();
}

class _RegularContactDetailsScreenState extends State<RegularContactDetailsScreen> {
  late Contact _contact;
  bool _isEditing = false;
  bool _isFavorite = false;

  @override
  void initState() {
    super.initState();
    _contact = widget.contact;
    _checkFavoriteStatus();
  }

  Future<void> _checkFavoriteStatus() async {
    final isFavorite = await DatabaseHelper.instance.isContactFavorite(_contact.identifier!);
    setState(() {
      _isFavorite = isFavorite;
    });
  }

  Future<void> _toggleFavorite() async {
    await DatabaseHelper.instance.toggleFavoriteContact(_contact);
    await _checkFavoriteStatus();
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

  Future<void> _openMap(PostalAddress address) async {
    final query = Uri.encodeComponent(
      '${address.street}, ${address.city}, ${address.region} ${address.postcode}, ${address.country}'
    );
    final uri = Uri.parse('https://maps.google.com/?q=$query');
    if (await url_launcher.canLaunchUrl(uri)) {
      await url_launcher.launchUrl(uri);
    }
  }

  Future<void> _editBasicInfo() async {
    final nameController = TextEditingController(text: _contact.displayName);
    final companyController = TextEditingController(text: _contact.company);

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Basic Info'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: companyController,
              decoration: const InputDecoration(
                labelText: 'Company',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result == true) {
      setState(() {
        _contact.givenName = nameController.text;
        _contact.displayName = nameController.text;
        _contact.company = companyController.text;
      });
      await ContactsService.updateContact(_contact);
    }
  }

  Future<void> _addPhone() async {
    final controller = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Phone Number'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Phone Number',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.phone,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (result == true && controller.text.isNotEmpty) {
      setState(() {
        _contact.phones ??= [];
        _contact.phones!.add(Item(
          label: 'mobile',
          value: controller.text,
        ));
      });
      await ContactsService.updateContact(_contact);
    }
  }

  Future<void> _editPhone(Item phone, int index) async {
    final controller = TextEditingController(text: phone.value);
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Phone Number'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Phone Number',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.phone,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result == true && controller.text.isNotEmpty) {
      setState(() {
        _contact.phones![index] = Item(
          label: phone.label,
          value: controller.text,
        );
      });
      await ContactsService.updateContact(_contact);
    }
  }

  Future<void> _addEmail() async {
    final controller = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Email'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Email Address',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.emailAddress,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (result == true && controller.text.isNotEmpty) {
      setState(() {
        _contact.emails ??= [];
        _contact.emails!.add(Item(
          label: 'email',
          value: controller.text,
        ));
      });
      await ContactsService.updateContact(_contact);
    }
  }

  Future<void> _editEmail(Item email, int index) async {
    final controller = TextEditingController(text: email.value);
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Email'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Email Address',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.emailAddress,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result == true && controller.text.isNotEmpty) {
      setState(() {
        _contact.emails![index] = Item(
          label: email.label,
          value: controller.text,
        );
      });
      await ContactsService.updateContact(_contact);
    }
  }

  Widget _buildContactInfo() {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.person),
                title: Text(_contact.displayName ?? 'Unknown'),
                subtitle: _contact.company != null ? Text(_contact.company!) : null,
                trailing: IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: _editBasicInfo,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Phone Numbers',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add),
                      onPressed: _addPhone,
                    ),
                  ],
                ),
              ),
              if (_contact.phones?.isEmpty ?? true)
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('No phone numbers'),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _contact.phones?.length ?? 0,
                  itemBuilder: (context, index) {
                    final phone = _contact.phones![index];
                    return ListTile(
                      leading: const Icon(Icons.phone),
                      title: Text(phone.value ?? ''),
                      subtitle: Text(phone.label ?? ''),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: () => _editPhone(phone, index),
                          ),
                          IconButton(
                            icon: const Icon(Icons.call),
                            onPressed: () => _makePhoneCall(phone.value!),
                          ),
                        ],
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Email Addresses',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add),
                      onPressed: _addEmail,
                    ),
                  ],
                ),
              ),
              if (_contact.emails?.isEmpty ?? true)
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('No email addresses'),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _contact.emails?.length ?? 0,
                  itemBuilder: (context, index) {
                    final email = _contact.emails![index];
                    return ListTile(
                      leading: const Icon(Icons.email),
                      title: Text(email.value ?? ''),
                      subtitle: Text(email.label ?? ''),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: () => _editEmail(email, index),
                          ),
                          IconButton(
                            icon: const Icon(Icons.send),
                            onPressed: () => _sendEmail(email.value!),
                          ),
                        ],
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Contact Details'),
        actions: [
          IconButton(
            icon: Icon(
              _isFavorite ? Icons.star : Icons.star_border,
              color: _isFavorite ? Colors.yellow : null,
            ),
            onPressed: _toggleFavorite,
          ),
        ],
      ),
      body: _buildContactInfo(),
    );
  }
} 