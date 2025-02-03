import 'package:flutter/material.dart';
import 'package:contacts_service/contacts_service.dart';
import '../services/vault_service.dart';
import '../models/secure_contact.dart';
import '../utils/database_helper.dart';
import 'dart:convert';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'secure_contact_details_screen.dart';

class SecureContactsScreen extends StatefulWidget {
  const SecureContactsScreen({Key? key}) : super(key: key);

  @override
  _SecureContactsScreenState createState() => _SecureContactsScreenState();
}

class _SecureContactsScreenState extends State<SecureContactsScreen> {
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = true;
  bool _isVaultSetup = false;
  bool _isVaultUnlocked = false;
  List<SecureContact> _secureContacts = [];
  String? _errorMessage;
  bool _showOnlyFavorites = false;

  @override
  void initState() {
    super.initState();
    _initializeVault();
  }

  Future<void> _initializeVault() async {
    try {
      await VaultService.instance.initialize();
      _checkVaultStatus();
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error initializing vault: $e';
      });
    }
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _checkVaultStatus() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final isSetup = VaultService.instance.isVaultSetup;
      setState(() {
        _isVaultSetup = isSetup;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error checking vault status: $e';
      });
    }
  }

  Future<void> _setupVault() async {
    if (_passwordController.text.isEmpty) {
      setState(() => _errorMessage = 'Please enter a password');
      return;
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      setState(() => _errorMessage = 'Passwords do not match');
      return;
    }

    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final success =
          await VaultService.instance.setupVault(_passwordController.text);

      if (success) {
        setState(() {
          _isVaultSetup = true;
          _isVaultUnlocked = true;
          _isLoading = false;
        });

        _passwordController.clear();
        _confirmPasswordController.clear();
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to set up vault';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error setting up vault: $e';
      });
    }
  }

  Future<void> _unlockVault() async {
    if (_passwordController.text.isEmpty) {
      setState(() => _errorMessage = 'Please enter your password');
      return;
    }

    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final success =
          await VaultService.instance.unlockVault(_passwordController.text);

      if (success) {
        await _loadSecureContacts();
        setState(() {
          _isVaultUnlocked = true;
          _isLoading = false;
        });
        _passwordController.clear();
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Incorrect password';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error unlocking vault: $e';
      });
    }
  }

  Future<void> _loadSecureContacts() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final contacts = await DatabaseHelper.instance.getAllSecureContacts();
      setState(() {
        _secureContacts = contacts;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error loading contacts: $e';
      });
    }
  }

  Future<void> _addContact() async {
    if (!VaultService.instance.isUnlocked) {
      setState(() => _errorMessage = 'Vault must be unlocked to add contacts');
      return;
    }

    try {
      final Contact? contact = await ContactsService.openDeviceContactPicker();
      if (contact != null) {
        setState(() {
          _isLoading = true;
          _errorMessage = null;
        });

        final encryptedData = SecureContact.encryptContact(
          contact,
          VaultService.instance.encryptionKey!,
          VaultService.instance.iv!,
        );

        final secureContact = SecureContact(encryptedData: encryptedData);
        await DatabaseHelper.instance.createSecureContact(secureContact);

        await _loadSecureContacts();
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error adding contact: $e';
      });
    }
  }

  Future<void> _createNewContact() async {
    if (!VaultService.instance.isUnlocked) {
      setState(() => _errorMessage = 'Vault must be unlocked to add contacts');
      return;
    }

    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final emailController = TextEditingController();
    final companyController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Create New Contact'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Name*',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: phoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
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
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (nameController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Name is required')),
                );
                return;
              }
              Navigator.of(context).pop(true);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (result == true) {
      try {
        setState(() {
          _isLoading = true;
          _errorMessage = null;
        });

        final contactData = {
          'displayName': nameController.text.trim(),
          'phones': phoneController.text.trim().isNotEmpty
              ? [
                  {
                    'label': 'mobile',
                    'value': phoneController.text.trim(),
                  }
                ]
              : [],
          'emails': emailController.text.trim().isNotEmpty
              ? [
                  {
                    'label': 'email',
                    'value': emailController.text.trim(),
                  }
                ]
              : [],
          'company': companyController.text.trim(),
        };

        final jsonString = jsonEncode(contactData);
        final encrypter = encrypt.Encrypter(
            encrypt.AES(VaultService.instance.encryptionKey!));
        final encryptedData =
            encrypter.encrypt(jsonString, iv: VaultService.instance.iv!).base64;

        final secureContact = SecureContact(encryptedData: encryptedData);
        await DatabaseHelper.instance.createSecureContact(secureContact);

        await _loadSecureContacts();
      } catch (e) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Error creating contact: $e';
        });
      }
    }

    nameController.dispose();
    phoneController.dispose();
    emailController.dispose();
    companyController.dispose();
  }

  Widget _buildErrorMessage() {
    if (_errorMessage == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Text(
        _errorMessage!,
        style: const TextStyle(color: Colors.red),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildSetupVaultForm() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Set up Secure Contacts Vault',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _passwordController,
            decoration: const InputDecoration(
              labelText: 'Enter Password',
              border: OutlineInputBorder(),
            ),
            obscureText: true,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _confirmPasswordController,
            decoration: const InputDecoration(
              labelText: 'Confirm Password',
              border: OutlineInputBorder(),
            ),
            obscureText: true,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _isLoading ? null : _setupVault,
            child: const Text('Set up Vault'),
          ),
        ],
      ),
    );
  }

  Widget _buildUnlockVaultForm() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 56),
          const Text(
            'Unlock Secure Contacts Vault',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _passwordController,
            decoration: const InputDecoration(
              labelText: 'Enter Password',
              border: OutlineInputBorder(),
            ),
            obscureText: true,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _isLoading ? null : _unlockVault,
            child: const Text('Unlock Vault'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Exit'),
          ),
        ],
      ),
    );
  }

  Widget _buildSecureContactsList() {
    return Column(
      children: [
        AppBar(
          title: const Text('Secure Contacts'),
          actions: [
            PopupMenuButton<String>(
              onSelected: (value) {
                switch (value) {
                  case 'create':
                    _createNewContact();
                    break;
                  case 'import':
                    _addContact();
                    break;
                  case 'favorites':
                    setState(() {
                      _showOnlyFavorites = !_showOnlyFavorites;
                    });
                    break;
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'create',
                  child: Row(
                    children: [
                      Icon(Icons.person_add),
                      SizedBox(width: 8),
                      Text('Create New Contact'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'import',
                  child: Row(
                    children: [
                      Icon(Icons.import_contacts),
                      SizedBox(width: 8),
                      Text('Import from Phone'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'favorites',
                  child: Row(
                    children: [
                      Icon(_showOnlyFavorites ? Icons.star : Icons.star_border),
                      const SizedBox(width: 8),
                      Text(_showOnlyFavorites ? 'Show All' : 'Show Favorites'),
                    ],
                  ),
                ),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.lock),
              onPressed: () {
                VaultService.instance.lockVault();
                setState(() {
                  _isVaultUnlocked = false;
                  _secureContacts.clear();
                });
              },
            ),
          ],
        ),
        Expanded(
          child: _secureContacts.isEmpty
              ? const Center(
                  child: Text('No secure contacts yet'),
                )
              : ListView.builder(
                  itemCount: _secureContacts.length,
                  itemBuilder: (context, index) {
                    final contact = _secureContacts[index];

                    if (_showOnlyFavorites && !contact.isFavorite) {
                      return const SizedBox.shrink();
                    }

                    Map<String, dynamic> contactData;
                    try {
                      contactData = SecureContact.decryptContact(
                        contact.encryptedData,
                        VaultService.instance.encryptionKey!,
                        VaultService.instance.iv!,
                      );
                    } catch (e) {
                      debugPrint('Error decrypting contact: $e');
                      return ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Colors.red,
                          child: Icon(Icons.error, color: Colors.white),
                        ),
                        title: const Text('Error: Could not decrypt contact'),
                        subtitle: Text('Contact ID: ${contact.id}'),
                      );
                    }

                    final phones = contactData['phones'] as List<dynamic>?;
                    final emails = contactData['emails'] as List<dynamic>?;

                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 8.0,
                      ),
                      child: InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => SecureContactDetailsScreen(contact: contact),
                            ),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            children: [
                              CircleAvatar(
                                child: Text(
                                  (contactData['displayName'] as String?)?.characters.first.toUpperCase() ?? '?',
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      contactData['displayName'] as String? ?? 'Unknown',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    if (phones?.isNotEmpty ?? false)
                                      Text(
                                        phones!.first['value'] as String? ?? 'No phone number',
                                        style: Theme.of(context).textTheme.bodyMedium,
                                      ),
                                    if (emails?.isNotEmpty ?? false)
                                      Text(
                                        emails!.first['value'] as String? ?? 'No email',
                                        style: Theme.of(context).textTheme.bodySmall,
                                      ),
                                  ],
                                ),
                              ),
                              if (contact.isFavorite)
                                const Icon(
                                  Icons.star,
                                  color: Colors.yellow,
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildErrorMessage(),
                Expanded(
                  child: !_isVaultSetup
                      ? _buildSetupVaultForm()
                      : !_isVaultUnlocked
                          ? _buildUnlockVaultForm()
                          : _buildSecureContactsList(),
                ),
              ],
            ),
    );
  }
}
