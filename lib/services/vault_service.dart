import 'package:shared_preferences/shared_preferences.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';

class VaultService {
  static const String _keyPrefix = 'vault_';
  static const String _saltKey = '${_keyPrefix}salt';
  static const String _hashedPasswordKey = '${_keyPrefix}hashed_password';
  static const String _ivKey = '${_keyPrefix}iv';
  
  SharedPreferences? _prefs;
  encrypt.Key? _encryptionKey;
  encrypt.IV? _iv;
  bool _isInitialized = false;

  // Singleton pattern
  static final VaultService instance = VaultService._internal();
  
  VaultService._internal();

  Future<void> initialize() async {
    if (_isInitialized) {
      debugPrint('VaultService already initialized');
      return;
    }

    try {
      _prefs = await SharedPreferences.getInstance();
      _isInitialized = true;
      debugPrint('VaultService initialized successfully');
      
      // Try to restore vault state if it was previously unlocked
      if (isVaultSetup) {
        _tryRestoreVaultState();
      }
    } catch (e) {
      debugPrint('Error initializing VaultService: $e');
      rethrow;
    }
  }

  Future<void> _tryRestoreVaultState() async {
    try {
      final saltString = _prefs?.getString(_saltKey);
      final ivString = _prefs?.getString(_ivKey);

      if (saltString != null && ivString != null) {
        _iv = encrypt.IV(base64.decode(ivString));
        debugPrint('Restored vault state');
      }
    } catch (e) {
      debugPrint('Error restoring vault state: $e');
    }
  }

  bool get isVaultSetup {
    try {
      final hasKey = _prefs?.containsKey(_hashedPasswordKey) ?? false;
      debugPrint('Checking vault setup: $hasKey');
      return hasKey;
    } catch (e) {
      debugPrint('Error checking vault setup: $e');
      return false;
    }
  }

  Future<bool> setupVault(String password) async {
    try {
      if (isVaultSetup) {
        debugPrint('Vault is already set up');
        return false;
      }

      if (_prefs == null) {
        debugPrint('SharedPreferences not initialized');
        return false;
      }

      // Generate a random salt
      final salt = _generateRandomBytes(16);
      final hashedPassword = _hashPassword(password, salt);
      
      // Generate encryption key from password
      _encryptionKey = _generateKey(password, salt);
      
      // Generate and save IV
      _iv = encrypt.IV.fromSecureRandom(16);

      debugPrint('Generated vault components successfully');

      // Save salt, hashed password, and IV
      await _prefs!.setString(_saltKey, base64.encode(salt));
      await _prefs!.setString(_hashedPasswordKey, base64.encode(hashedPassword));
      await _prefs!.setString(_ivKey, base64.encode(_iv!.bytes));

      debugPrint('Saved vault components successfully');
      return true;
    } catch (e) {
      debugPrint('Error setting up vault: $e');
      return false;
    }
  }

  Future<bool> unlockVault(String password) async {
    try {
      if (!isVaultSetup) {
        debugPrint('Cannot unlock: Vault is not set up');
        return false;
      }

      final saltString = _prefs?.getString(_saltKey);
      final hashedString = _prefs?.getString(_hashedPasswordKey);
      final ivString = _prefs?.getString(_ivKey);

      if (saltString == null || hashedString == null || ivString == null) {
        debugPrint('Missing vault components');
        return false;
      }

      final salt = base64.decode(saltString);
      final storedHash = base64.decode(hashedString);
      final hashedPassword = _hashPassword(password, salt);

      if (!_compareBytes(hashedPassword, storedHash)) {
        debugPrint('Password verification failed');
        return false;
      }

      // Set up encryption key and IV for the session
      _encryptionKey = _generateKey(password, salt);
      _iv = encrypt.IV(base64.decode(ivString));

      debugPrint('Vault unlocked successfully');
      return true;
    } catch (e) {
      debugPrint('Error unlocking vault: $e');
      return false;
    }
  }

  Future<bool> changePassword(String oldPassword, String newPassword) async {
    try {
      if (!await unlockVault(oldPassword)) {
        debugPrint('Cannot change password: old password verification failed');
        return false;
      }

      if (_prefs == null) {
        debugPrint('SharedPreferences not initialized');
        return false;
      }

      // Generate new salt and hash for the new password
      final newSalt = _generateRandomBytes(16);
      final newHashedPassword = _hashPassword(newPassword, newSalt);
      
      // Generate new encryption key and IV
      final newKey = _generateKey(newPassword, newSalt);
      final newIV = encrypt.IV.fromSecureRandom(16);

      // Save new values
      await _prefs!.setString(_saltKey, base64.encode(newSalt));
      await _prefs!.setString(_hashedPasswordKey, base64.encode(newHashedPassword));
      await _prefs!.setString(_ivKey, base64.encode(newIV.bytes));

      _encryptionKey = newKey;
      _iv = newIV;

      debugPrint('Password changed successfully');
      return true;
    } catch (e) {
      debugPrint('Error changing password: $e');
      return false;
    }
  }

  void lockVault() {
    try {
      _encryptionKey = null;
      _iv = null;
      debugPrint('Vault locked successfully');
    } catch (e) {
      debugPrint('Error locking vault: $e');
    }
  }

  bool get isUnlocked => _encryptionKey != null && _iv != null;

  encrypt.Key? get encryptionKey => _encryptionKey;
  encrypt.IV? get iv => _iv;

  List<int> _generateRandomBytes(int length) {
    try {
      final key = encrypt.Key.fromSecureRandom(length);
      return key.bytes;
    } catch (e) {
      debugPrint('Error generating random bytes: $e');
      rethrow;
    }
  }

  List<int> _hashPassword(String password, List<int> salt) {
    try {
      final codec = utf8.encoder;
      final key = codec.convert(password);
      final saltedKey = [...key, ...salt];
      return sha256.convert(saltedKey).bytes;
    } catch (e) {
      debugPrint('Error hashing password: $e');
      rethrow;
    }
  }

  encrypt.Key _generateKey(String password, List<int> salt) {
    try {
      final codec = utf8.encoder;
      final key = codec.convert(password);
      final saltedKey = [...key, ...salt];
      final hash = sha256.convert(saltedKey).bytes;
      return encrypt.Key(Uint8List.fromList(hash));
    } catch (e) {
      debugPrint('Error generating key: $e');
      rethrow;
    }
  }

  bool _compareBytes(List<int> a, List<int> b) {
    try {
      if (a.length != b.length) return false;
      for (int i = 0; i < a.length; i++) {
        if (a[i] != b[i]) return false;
      }
      return true;
    } catch (e) {
      debugPrint('Error comparing bytes: $e');
      return false;
    }
  }
} 