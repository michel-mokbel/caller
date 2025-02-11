import 'package:flutter/material.dart';
import 'package:contacts_service/contacts_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import 'contact_tasks_screen.dart';
import 'regular_contact_details_screen.dart';
import '../utils/database_helper.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  List<Contact> _contacts = [];
  List<Contact> _filteredContacts = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String _selectedLetter = '#';
  final Map<String, List<Contact>> _groupedContacts = {};
  Set<String> _blockedNumbers = {};

  @override
  void initState() {
    super.initState();
    _loadContacts();
    _loadBlockedNumbers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadContacts() async {
    final permission = await Permission.contacts.request();
    if (permission.isGranted) {
      final contacts = await ContactsService.getContacts();
      setState(() {
        _contacts = contacts.toList()
          ..sort((a, b) => (a.displayName ?? '')
              .compareTo(b.displayName ?? ''));
        _filteredContacts = _contacts;
        _groupContacts();
        _isLoading = false;
      });
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Contacts permission denied')),
      );
    }
  }

  Future<void> _loadBlockedNumbers() async {
    final numbers = await DatabaseHelper.instance.getBlockedNumbersSet();
    setState(() {
      _blockedNumbers = numbers;
    });
  }

  bool _isNumberBlocked(Contact contact) {
    if (contact.phones == null || contact.phones!.isEmpty) return false;
    
    String normalizeNumber(String number) {
      return number.replaceAll(RegExp(r'[^\d+]'), '');
    }

    return contact.phones!.any((phone) {
      final normalizedPhone = normalizeNumber(phone.value ?? '');
      return _blockedNumbers.any((blocked) => normalizeNumber(blocked) == normalizedPhone);
    });
  }

  void _groupContacts() {
    _groupedContacts.clear();
    for (var contact in _filteredContacts) {
      String letter = (contact.displayName?.isNotEmpty ?? false)
          ? contact.displayName![0].toUpperCase()
          : '#';
      if (!RegExp(r'[A-Z]').hasMatch(letter)) letter = '#';
      
      _groupedContacts.putIfAbsent(letter, () => []);
      _groupedContacts[letter]!.add(contact);
    }
  }

  void _filterContacts(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredContacts = _contacts;
      } else {
        _filteredContacts = _contacts.where((contact) {
          final name = contact.displayName?.toLowerCase() ?? '';
          final phone = contact.phones?.firstOrNull?.value?.toLowerCase() ?? '';
          final company = contact.company?.toLowerCase() ?? '';
          final searchQuery = query.toLowerCase();
          
          return name.contains(searchQuery) ||
              phone.contains(searchQuery) ||
              company.contains(searchQuery);
        }).toList();
      }
      _groupContacts();
    });
  }

  void _scrollToLetter(String letter) {
    if (!_groupedContacts.containsKey(letter)) return;
    
    int index = 0;
    for (var entry in _groupedContacts.entries) {
      if (entry.key == letter) break;
      index += entry.value.length + 1; // +1 for the header
    }
    
    _scrollController.animateTo(
      index * 72.0, // Approximate height of each item
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
    
    setState(() => _selectedLetter = letter);
  }

  Future<void> _makeCall(String phoneNumber) async {
    final uri = Uri.parse('tel:$phoneNumber');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not launch the call on this device')),
      );
    }
  }

  Future<void> _sendSMS(String phoneNumber) async {
    final uri = Uri.parse('sms:$phoneNumber');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _showAddTaskDialog(String contactId) {
    final contact = _contacts.firstWhere(
      (c) => c.identifier == contactId,
      orElse: () => Contact(),
    );
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ContactTasksScreen(contact: contact),
      ),
    );
  }

  Widget _buildContactItem(Contact contact) {
    final isBlocked = _isNumberBlocked(contact);
    
    return Dismissible(
      key: Key(contact.identifier ?? ''),
      direction: DismissDirection.horizontal,
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.endToStart) {
          // Delete confirmation
          return await showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: const Text('Delete Contact'),
                content: Text('Are you sure you want to delete ${contact.displayName}?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.red,
                    ),
                    child: const Text('Delete'),
                  ),
                ],
              );
            },
          );
        } else {
          // Block/Unblock confirmation
          if (contact.phones?.isEmpty ?? true) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('This contact has no phone number to block')),
            );
            return false;
          }

          final phoneNumber = contact.phones!.first.value;
          final isCurrentlyBlocked = _isNumberBlocked(contact);

          if (isCurrentlyBlocked) {
            // Unblock confirmation
            final shouldUnblock = await showDialog<bool>(
              context: context,
              builder: (BuildContext context) {
                return AlertDialog(
                  title: const Text('Unblock Contact'),
                  content: Text('Are you sure you want to unblock ${contact.displayName}?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text('Unblock'),
                    ),
                  ],
                );
              },
            );

            if (shouldUnblock == true) {
              await DatabaseHelper.instance.unblockNumber(phoneNumber!);
              _loadBlockedNumbers();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('${contact.displayName} has been unblocked')),
              );
            }
            return false;
          } else {
            // Block confirmation
            final reason = await showDialog<String>(
              context: context,
              builder: (BuildContext context) {
                final reasonController = TextEditingController();
                return AlertDialog(
                  title: const Text('Block Contact'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Are you sure you want to block ${contact.displayName}?'),
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
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.of(context).pop(reasonController.text),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.red,
                      ),
                      child: const Text('Block'),
                    ),
                  ],
                );
              },
            );

            if (reason != null) {
              await DatabaseHelper.instance.blockNumber(
                phoneNumber!,
                contactName: contact.displayName,
                reason: reason.isNotEmpty ? reason : null,
              );
              _loadBlockedNumbers();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('${contact.displayName} has been blocked')),
              );
            }
            return false;
          }
        }
      },
      onDismissed: (direction) async {
        if (direction == DismissDirection.endToStart) {
          try {
            await ContactsService.deleteContact(contact);
            _loadContacts();
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${contact.displayName} deleted'),
                action: SnackBarAction(
                  label: 'Undo',
                  onPressed: () async {
                    await ContactsService.addContact(contact);
                    _loadContacts();
                  },
                ),
              ),
            );
          } catch (e) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Failed to delete contact')),
            );
            _loadContacts(); // Refresh the list to restore the contact
          }
        }
      },
      background: Container(
        color: Colors.red.shade100,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 16.0),
        child: const Icon(
          Icons.block,
          color: Colors.red,
        ),
      ),
      secondaryBackground: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16.0),
        child: const Icon(
          Icons.delete,
          color: Colors.white,
        ),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => RegularContactDetailsScreen(contact: contact),
            ),
          ).then((_) {
            _loadContacts();
            _loadBlockedNumbers();
          });
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: isBlocked ? Colors.red : Theme.of(context).primaryColor,
                child: Text(
                  contact.displayName?.characters.first.toUpperCase() ?? '?',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      contact.displayName ?? 'Unknown',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: isBlocked ? Colors.red : null,
                      ),
                    ),
                    if (contact.phones?.isNotEmpty ?? false)
                      Text(
                        contact.phones!.first.value ?? '',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: isBlocked ? Colors.red.shade700 : Colors.grey[600],
                        ),
                      ),
                    if (isBlocked)
                      Text(
                        'Blocked Contact',
                        style: TextStyle(
                          color: Colors.red.shade700,
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (contact.phones?.isNotEmpty ?? false) ...[
                    IconButton(
                      icon: Icon(
                        Icons.phone,
                        color: isBlocked ? Colors.red : Colors.grey[600],
                        size: 20,
                      ),
                      onPressed: () => _makeCall(contact.phones!.first.value!),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.message,
                        color: isBlocked ? Colors.red : Colors.grey[600],
                        size: 20,
                      ),
                      onPressed: () => _sendSMS(contact.phones!.first.value!),
                    ),
                  ],
                  IconButton(
                    icon: Icon(
                      Icons.task,
                      color: isBlocked ? Colors.red : Colors.grey[600],
                      size: 20,
                    ),
                    onPressed: () => _showAddTaskDialog(contact.identifier!),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContactList() {
    final letters = _groupedContacts.keys.toList()..sort();
    
    return ListView.builder(
      controller: _scrollController,
      itemCount: letters.length * 2 - 1, // Account for separators
      itemBuilder: (context, index) {
        // If index is odd, it's a separator
        if (index.isOdd) {
          return const Divider();
        }
        
        final letterIndex = index ~/ 2;
        final letter = letters[letterIndex];
        final contactsForLetter = _groupedContacts[letter]!;
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Text(
                letter,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
            ),
            ...contactsForLetter.map((contact) => _buildContactItem(contact)).toList(),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Contacts'),
      ),
      body: Row(
        children: [
          Expanded(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search name, phone, or company',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                    ),
                    onChanged: _filterContacts,
                  ),
                ),
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _buildContactList(),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 32,
            child: ListView.builder(
              itemCount: 27, // A-Z + #
              itemBuilder: (context, index) {
                final letter = index < 26
                    ? String.fromCharCode(65 + index)
                    : '#';
                return GestureDetector(
                  onTap: () => _scrollToLetter(letter),
                  child: Container(
                    height: 20,
                    alignment: Alignment.center,
                    child: Text(
                      letter,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: _selectedLetter == letter
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: _selectedLetter == letter
                            ? Theme.of(context).primaryColor
                            : Colors.grey,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final nameController = TextEditingController();
          final phoneController = TextEditingController();
          
          final result = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('New Contact'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Name'),
                    autofocus: true,
                  ),
                  TextField(
                    controller: phoneController,
                    decoration: const InputDecoration(labelText: 'Phone'),
                    keyboardType: TextInputType.phone,
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
                  child: const Text('Create'),
                ),
              ],
            ),
          );

          if (result == true && mounted && nameController.text.isNotEmpty) {
            try {
              // Create a new contact with basic info
              final newContact = Contact();
              newContact.givenName = nameController.text;
              newContact.familyName = '';
              newContact.displayName = nameController.text;
              
              if (phoneController.text.isNotEmpty) {
                newContact.phones = [Item(label: 'mobile', value: phoneController.text)];
              }

              // Add the contact
              await ContactsService.addContact(newContact);
              
              if (!mounted) return;
              
              // Refresh the contacts list
              await _loadContacts();
              
              // Show success message
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Contact created successfully')),
              );
            } catch (e) {
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Failed to add contact: ${e.toString()}')),
              );
            }
          }
        },
        child: const Icon(Icons.person_add),
      ),
    );
  }
} 