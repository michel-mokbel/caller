import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:contacts_service/contacts_service.dart';
import '../models/contact_task.dart';
import '../models/secure_contact.dart';
import 'package:flutter/foundation.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('contacts.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 4,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE secure_contacts(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        encrypted_data TEXT NOT NULL,
        is_favorite INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE favorite_contacts(
        contact_id TEXT PRIMARY KEY,
        display_name TEXT NOT NULL,
        timestamp INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE contact_tasks(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        contact_id TEXT NOT NULL,
        title TEXT NOT NULL,
        description TEXT,
        due_date TEXT NOT NULL,
        is_completed INTEGER DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        ALTER TABLE secure_contacts
        ADD COLUMN is_favorite INTEGER DEFAULT 0
      ''');
    }
    
    if (oldVersion < 3) {
      try {
        await db.execute('''
          CREATE TABLE favorite_contacts(
            contact_id TEXT PRIMARY KEY,
            display_name TEXT NOT NULL,
            timestamp INTEGER NOT NULL
          )
        ''');
      } catch (e) {
        debugPrint('Error creating favorite_contacts table: $e');
      }
    }

    if (oldVersion < 4) {
      try {
        // Add created_at and updated_at columns to secure_contacts
        await db.execute('''
          ALTER TABLE secure_contacts
          ADD COLUMN created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
        ''');
        await db.execute('''
          ALTER TABLE secure_contacts
          ADD COLUMN updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
        ''');
      } catch (e) {
        debugPrint('Error adding timestamp columns to secure_contacts: $e');
      }
    }
  }

  Future<bool> isContactFavorite(String contactId) async {
    final db = await instance.database;
    final result = await db.query(
      'favorite_contacts',
      where: 'contact_id = ?',
      whereArgs: [contactId],
    );
    return result.isNotEmpty;
  }

  Future<void> toggleFavoriteContact(Contact contact) async {
    final db = await instance.database;
    final isFavorite = await isContactFavorite(contact.identifier!);

    if (isFavorite) {
      await db.delete(
        'favorite_contacts',
        where: 'contact_id = ?',
        whereArgs: [contact.identifier],
      );
    } else {
      await db.insert('favorite_contacts', {
        'contact_id': contact.identifier,
        'display_name': contact.displayName ?? 'Unknown',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
    }
  }

  // Tasks CRUD operations
  Future<ContactTask> createTask(ContactTask task) async {
    final db = await database;
    final id = await db.insert('contact_tasks', task.toMap());
    return task.copyWith(id: id);
  }

  Future<List<ContactTask>> getTasksForContact(String contactId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'contact_tasks',
      where: 'contact_id = ?',
      whereArgs: [contactId],
      orderBy: 'due_date ASC',
    );
    return List.generate(maps.length, (i) => ContactTask.fromMap(maps[i]));
  }

  Future<int> updateTask(ContactTask task) async {
    final db = await database;
    return db.update(
      'contact_tasks',
      task.toMap(),
      where: 'id = ?',
      whereArgs: [task.id],
    );
  }

  Future<int> deleteTask(int id) async {
    final db = await database;
    return await db.delete(
      'contact_tasks',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Secure Contacts CRUD operations
  Future<SecureContact> createSecureContact(SecureContact contact) async {
    final db = await database;
    final id = await db.insert('secure_contacts', contact.toMap());
    return contact.copyWith(id: id);
  }

  Future<List<SecureContact>> getAllSecureContacts() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('secure_contacts');
    return List.generate(maps.length, (i) => SecureContact.fromMap(maps[i]));
  }

  Future<int> updateSecureContact(SecureContact contact) async {
    final db = await database;
    return db.update(
      'secure_contacts',
      contact.toMap(),
      where: 'id = ?',
      whereArgs: [contact.id],
    );
  }

  Future<int> deleteSecureContact(int id) async {
    final db = await database;
    return await db.delete(
      'secure_contacts',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> close() async {
    final db = await instance.database;
    db.close();
  }
} 