import 'package:flutter/material.dart';
import 'package:contacts_service/contacts_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import 'contact_tasks_screen.dart';
import 'regular_contact_details_screen.dart';

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

  @override
  void initState() {
    super.initState();
    _loadContacts();
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
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => RegularContactDetailsScreen(contact: contact),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: Theme.of(context).primaryColor,
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
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (contact.phones?.isNotEmpty ?? false)
                    Text(
                      contact.phones!.first.value ?? '',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[600],
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
                    icon: Icon(Icons.phone, color: Colors.grey[600], size: 20),
                    onPressed: () => _makeCall(contact.phones!.first.value!),
                  ),
                  IconButton(
                    icon: Icon(Icons.message, color: Colors.grey[600], size: 20),
                    onPressed: () => _sendSMS(contact.phones!.first.value!),
                  ),
                ],
                IconButton(
                  icon: Icon(Icons.task, color: Colors.grey[600], size: 20),
                  onPressed: () => _showAddTaskDialog(contact.identifier!),
                ),
              ],
            ),
          ],
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
        onPressed: () {
          // TODO: Implement add contact functionality
        },
        child: const Icon(Icons.person_add),
      ),
    );
  }
} 