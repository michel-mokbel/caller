import 'package:flutter/material.dart';
import 'package:contacts_service/contacts_service.dart';
import 'package:permission_handler/permission_handler.dart';
import '../utils/database_helper.dart';
import 'regular_contact_details_screen.dart';
import 'package:url_launcher/url_launcher.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  List<Contact> _favorites = [];
  bool _isLoading = true;
  String? _errorMessage;
  final Map<String, List<Contact>> _groupedFavorites = {};

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  void _groupContacts() {
    _groupedFavorites.clear();
    for (var contact in _favorites) {
      String letter = (contact.displayName?.isNotEmpty ?? false)
          ? contact.displayName![0].toUpperCase()
          : '#';
      if (!RegExp(r'[A-Z]').hasMatch(letter)) letter = '#';
      
      _groupedFavorites.putIfAbsent(letter, () => []);
      _groupedFavorites[letter]!.add(contact);
    }
  }

  Future<void> _loadFavorites() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final permission = await Permission.contacts.request();
      if (!permission.isGranted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Contacts permission denied';
        });
        return;
      }

      // Get all contacts
      final allContacts = await ContactsService.getContacts(
        withThumbnails: false,
        photoHighResolution: false,
      );

      // Get favorite contact IDs from database
      final db = await DatabaseHelper.instance.database;
      final favoriteRecords = await db.query('favorite_contacts');
      final favoriteIds = favoriteRecords.map((r) => r['contact_id'] as String).toSet();

      // Filter contacts that are in favorites and sort them
      final favoriteContacts = allContacts
        .where((contact) => contact.identifier != null && favoriteIds.contains(contact.identifier))
        .toList()
        ..sort((a, b) => (a.displayName ?? '').compareTo(b.displayName ?? ''));

      setState(() {
        _favorites = favoriteContacts;
        _groupContacts();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error loading favorites: $e';
      });
    }
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

  Widget _buildContactItem(Contact contact) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => RegularContactDetailsScreen(contact: contact),
            ),
          ).then((_) => _loadFavorites()); // Reload after returning from details
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFavoritesList() {
    final letters = _groupedFavorites.keys.toList()..sort();
    
    return ListView.builder(
      itemCount: letters.length * 2 - 1, // Account for separators
      itemBuilder: (context, index) {
        // If index is odd, it's a separator
        if (index.isOdd) {
          return const Divider();
        }
        
        final letterIndex = index ~/ 2;
        final letter = letters[letterIndex];
        final contactsForLetter = _groupedFavorites[letter]!;
        
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
        title: const Text('Favorites'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: Colors.red),
                        const SizedBox(height: 16),
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ],
                    ),
                  ),
                )
              : _favorites.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.star_border,
                            size: 64,
                            color: Colors.grey,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No favorites yet',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Add contacts to favorites to see them here',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadFavorites,
                      child: _buildFavoritesList(),
                    ),
    );
  }
} 