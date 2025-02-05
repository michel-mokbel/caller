import 'package:flutter/material.dart';
import '../utils/database_helper.dart';
import 'package:intl/intl.dart';
import 'package:contacts_service/contacts_service.dart';
import 'package:permission_handler/permission_handler.dart';

class BlockedNumbersScreen extends StatefulWidget {
  const BlockedNumbersScreen({super.key});

  @override
  State<BlockedNumbersScreen> createState() => _BlockedNumbersScreenState();
}

class _BlockedNumbersScreenState extends State<BlockedNumbersScreen> {
  List<Map<String, dynamic>> _blockedNumbers = [];
  bool _isLoading = true;
  Set<String> _existingContactNumbers = {};

  @override
  void initState() {
    super.initState();
    _loadBlockedNumbers();
    _loadExistingContacts();
  }

  Future<void> _loadExistingContacts() async {
    try {
      final permission = await Permission.contacts.request();
      if (!permission.isGranted) return;

      final contacts = await ContactsService.getContacts();
      final numbers = contacts
          .expand((contact) => contact.phones ?? [])
          .map((phone) => phone.value ?? '')
          .where((number) => number.isNotEmpty)
          .toSet()
          .cast<String>();

      setState(() {
        _existingContactNumbers = numbers;
      });
    } catch (e) {
      debugPrint('Error loading contacts: $e');
    }
  }

  Future<void> _loadBlockedNumbers() async {
    setState(() => _isLoading = true);
    final numbers = await DatabaseHelper.instance.getBlockedNumbers();
    setState(() {
      _blockedNumbers = numbers;
      _isLoading = false;
    });
  }

  bool _isExistingContact(String phoneNumber) {
    // Normalize the phone number for comparison by removing non-digit characters except +
    String normalizeNumber(String number) {
      return number.replaceAll(RegExp(r'[^\d+]'), '');
    }
    
    final normalizedBlockedNumber = normalizeNumber(phoneNumber);
    return _existingContactNumbers.any(
      (number) => normalizeNumber(number) == normalizedBlockedNumber
    );
  }

  Future<void> _showBlockNumberDialog() async {
    final phoneController = TextEditingController();
    final reasonController = TextEditingController();

    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Block Number'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: phoneController,
                    decoration: const InputDecoration(
                      labelText: 'Phone Number',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.contacts),
                  onPressed: () async {
                    final contact = await _pickContact();
                    if (contact != null && contact.phones?.isNotEmpty == true) {
                      phoneController.text = contact.phones!.first.value ?? '';
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason (Optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (phoneController.text.isNotEmpty) {
                _blockNumber(
                  phoneController.text,
                  reason: reasonController.text.isNotEmpty ? reasonController.text : null,
                );
                Navigator.pop(context);
              }
            },
            child: const Text('Block'),
          ),
        ],
      ),
    );
  }

  Future<Contact?> _pickContact() async {
    try {
      final permission = await Permission.contacts.request();
      if (!permission.isGranted) {
        if (!mounted) return null;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Contacts permission denied')),
        );
        return null;
      }

      final Contact? contact = await ContactsService.openDeviceContactPicker();
      return contact;
    } catch (e) {
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking contact: $e')),
      );
      return null;
    }
  }

  Future<void> _blockNumber(String phoneNumber, {String? reason}) async {
    try {
      await DatabaseHelper.instance.blockNumber(
        phoneNumber,
        reason: reason,
      );
      _loadBlockedNumbers();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error blocking number: $e')),
      );
    }
  }

  Future<bool> _unblockNumber(String phoneNumber) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unblock Number'),
        content: Text('Are you sure you want to unblock $phoneNumber?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Unblock'),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      await DatabaseHelper.instance.unblockNumber(phoneNumber);
      _loadBlockedNumbers();
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Blocked Numbers'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _blockedNumbers.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.block,
                        size: 64,
                        color: Colors.grey,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No blocked numbers',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Numbers you block will appear here',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _blockedNumbers.length,
                  itemBuilder: (context, index) {
                    final number = _blockedNumbers[index];
                    final blockedDate = DateTime.fromMillisecondsSinceEpoch(
                      number['blocked_at'] as int,
                    );
                    final isExistingContact = _isExistingContact(number['phone_number']);
                    
                    return Dismissible(
                      key: Key(number['id'].toString()),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        color: Colors.red,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 16.0),
                        child: const Icon(
                          Icons.delete,
                          color: Colors.white,
                        ),
                      ),
                      confirmDismiss: (direction) async {
                        final result = await _unblockNumber(number['phone_number']);
                        return result;
                      },
                      child: ListTile(
                        leading: Icon(
                          Icons.block,
                          color: isExistingContact ? Colors.red : null,
                        ),
                        title: Text(
                          number['phone_number'],
                          style: TextStyle(
                            color: isExistingContact ? Colors.red : null,
                            fontWeight: isExistingContact ? FontWeight.bold : null,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (number['contact_name'] != null)
                              Text(
                                number['contact_name'],
                                style: TextStyle(
                                  color: isExistingContact ? Colors.red.shade700 : null,
                                ),
                              ),
                            if (number['reason'] != null)
                              Text(
                                'Reason: ${number['reason']}',
                                style: const TextStyle(
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            Text(
                              'Blocked on ${DateFormat('MMM d, y').format(blockedDate)}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            if (isExistingContact)
                              Text(
                                'Contact exists in address book',
                                style: TextStyle(
                                  color: Colors.red.shade700,
                                  fontSize: 12,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                          ],
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () => _unblockNumber(number['phone_number']),
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showBlockNumberDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
} 