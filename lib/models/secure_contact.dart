import 'package:contacts_service/contacts_service.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:flutter/foundation.dart';
import 'dart:convert';

class SecureContact {
  final int? id;
  final String encryptedData;
  final bool isFavorite;
  final DateTime createdAt;
  final DateTime updatedAt;

  SecureContact({
    this.id,
    required this.encryptedData,
    this.isFavorite = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    try {
      return {
        'id': id,
        'encrypted_data': encryptedData,
        'is_favorite': isFavorite ? 1 : 0,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };
    } catch (e) {
      debugPrint('Error converting SecureContact to map: $e');
      rethrow;
    }
  }

  static SecureContact fromMap(Map<String, dynamic> map) {
    try {
      return SecureContact(
        id: map['id'] as int?,
        encryptedData: map['encrypted_data'] as String,
        isFavorite: (map['is_favorite'] as int?) == 1,
        createdAt: DateTime.parse(map['created_at'] as String),
        updatedAt: DateTime.parse(map['updated_at'] as String),
      );
    } catch (e) {
      debugPrint('Error creating SecureContact from map: $e');
      rethrow;
    }
  }

  static String encryptContact(Contact contact, encrypt.Key key, encrypt.IV iv) {
    try {
      final encrypter = encrypt.Encrypter(encrypt.AES(key));
      
      debugPrint('Converting contact to map...');
      // Convert contact to JSON string
      final contactData = {
        'displayName': contact.displayName,
        'phones': contact.phones?.map((phone) => {
          'label': phone.label,
          'value': phone.value,
        }).toList(),
        'emails': contact.emails?.map((email) => {
          'label': email.label,
          'value': email.value,
        }).toList(),
        'company': contact.company,
        'addresses': contact.postalAddresses?.map((addr) => {
          'label': addr.label,
          'street': addr.street,
          'city': addr.city,
          'region': addr.region,
          'postcode': addr.postcode,
          'country': addr.country,
        }).toList(),
      };

      debugPrint('Contact data: $contactData');

      final jsonString = jsonEncode(contactData);
      debugPrint('JSON string created successfully');

      final encrypted = encrypter.encrypt(jsonString, iv: iv);
      debugPrint('Contact encrypted successfully');
      
      return encrypted.base64;
    } catch (e) {
      debugPrint('Error encrypting contact: $e');
      rethrow;
    }
  }

  static Map<String, dynamic> decryptContact(String encryptedData, encrypt.Key key, encrypt.IV iv) {
    try {
      debugPrint('Attempting to decrypt contact...');
      final encrypter = encrypt.Encrypter(encrypt.AES(key));
      
      debugPrint('Decrypting base64 data...');
      final decrypted = encrypter.decrypt64(encryptedData, iv: iv);
      debugPrint('Decrypted data: $decrypted');

      debugPrint('Parsing JSON data...');
      final Map<String, dynamic> contactData = jsonDecode(decrypted);
      debugPrint('Contact data parsed successfully: $contactData');
      
      return contactData;
    } catch (e) {
      debugPrint('Error decrypting contact: $e');
      return {
        'displayName': 'Error decrypting contact',
        'phones': [],
        'emails': [],
        'company': '',
      };
    }
  }

  SecureContact copyWith({
    int? id,
    String? encryptedData,
    bool? isFavorite,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    try {
      return SecureContact(
        id: id ?? this.id,
        encryptedData: encryptedData ?? this.encryptedData,
        isFavorite: isFavorite ?? this.isFavorite,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
    } catch (e) {
      debugPrint('Error copying SecureContact: $e');
      rethrow;
    }
  }
} 