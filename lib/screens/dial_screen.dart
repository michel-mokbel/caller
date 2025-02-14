import 'package:flutter/material.dart';

import 'package:url_launcher/url_launcher.dart';
import 'package:contacts_service/contacts_service.dart';

class DialScreen extends StatefulWidget {
  const DialScreen({super.key});

  @override
  State<DialScreen> createState() => _DialScreenState();
}

class _DialScreenState extends State<DialScreen> {
  final TextEditingController _numberController = TextEditingController();

  @override
  void dispose() {
    _numberController.dispose();
    super.dispose();
  }

  void _addNumber(String number) {
    _numberController.text = _numberController.text + number;
  }

  void _removeLastNumber() {
    if (_numberController.text.isNotEmpty) {
      _numberController.text = _numberController.text.substring(
        0,
        _numberController.text.length - 1,
      );
    }
  }

  Future<void> _makeCall() async {
    if (_numberController.text.isEmpty) return;

    // Format the phone number by removing any non-digit characters except +
    final Uri callUri = Uri(
        scheme: 'tel',
        path: _numberController.text,
      );

    try {
      if (await canLaunchUrl(callUri)) {
        await launchUrl(callUri);
        print('Calling ...');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not launch the call on this device')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error making the call')),
      );
    }
  }

  Future<void> _addToContacts() async {
    if (_numberController.text.isEmpty) return;
    
    try {
      final newContact = Contact();
      newContact.phones = [Item(value: _numberController.text)];
      await ContactsService.addContact(newContact);
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Contact added successfully')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to add contact')),
      );
    }
  }

  Future<void> _sendSMS() async {
    if (_numberController.text.isEmpty) return;
    
    String formattedNumber = _numberController.text.replaceAll(RegExp(r'[^\d+]'), '');
    final Uri smsUri = Uri(
      scheme: 'sms',
      path: formattedNumber,
    );

    try {
      if (await canLaunchUrl(smsUri)) {
        await launchUrl(smsUri);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not launch SMS')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error launching SMS')),
      );
    }
  }

  Widget _buildDialButton(String number, [String? letters]) {
    return Expanded(
      child: TextButton(
        onPressed: () => _addNumber(number),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              number,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            if (letters != null)
              Text(
                letters,
                style: const TextStyle(fontSize: 12),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dial'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _numberController,
              style: const TextStyle(fontSize: 32),
              textAlign: TextAlign.center,
              decoration: const InputDecoration(
                border: InputBorder.none,
              ),
              readOnly: true,
            ),
          ),
          const Spacer(),
          Row(
            children: [
              _buildDialButton('1', ''),
              _buildDialButton('2', 'ABC'),
              _buildDialButton('3', 'DEF'),
            ],
          ),
          Row(
            children: [
              _buildDialButton('4', 'GHI'),
              _buildDialButton('5', 'JKL'),
              _buildDialButton('6', 'MNO'),
            ],
          ),
          Row(
            children: [
              _buildDialButton('7', 'PQRS'),
              _buildDialButton('8', 'TUV'),
              _buildDialButton('9', 'WXYZ'),
            ],
          ),
          Row(
            children: [
              _buildDialButton('*'),
              _buildDialButton('0', '+'),
              _buildDialButton('#'),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                onPressed: _removeLastNumber,
                icon: const Icon(Icons.backspace),
              ),
              FloatingActionButton(
                onPressed: _makeCall,
                backgroundColor: Colors.green,
                child: const Icon(Icons.call, color: Colors.white),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                onSelected: (value) {
                  switch (value) {
                    case 'add':
                      _addToContacts();
                      break;
                    case 'sms':
                      _sendSMS();
                      break;
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'add',
                    child: Row(
                      children: [
                        Icon(Icons.person_add),
                        SizedBox(width: 8),
                        Text('Add to Contacts'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'sms',
                    child: Row(
                      children: [
                        Icon(Icons.message),
                        SizedBox(width: 8),
                        Text('Send SMS'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
} 