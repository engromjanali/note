import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

class DBHelper {
  DBHelper._();
  static final DBHelper getInstance = DBHelper._();

  Database? myDB;
  static final tableName = "note";
  static final noteTitle = "title";
  static final noteDesc = "desc";
  static final noteNo = "ls_no";
  static final noteTime = "entry_time";
  static final noteHash = "data_hash"; // For integrity verification

  // 🔑 Generate encryption password (use secure storage in production)
  String _getEncryptionKey() {
    // ⚠️ IMPORTANT: In production, use flutter_secure_storage
    // This is just an example - don't hardcode keys!
    return "your_secure_encryption_password_here_change_this";
  }

  // 📊 Generate hash for data integrity
  String _generateHash(String title, String desc) {
    final data = "$title|$desc";
    final bytes = utf8.encode(data);
    final hash = sha256.convert(bytes);
    return hash.toString();
  }

  // 🔓 Open encrypted database
  Future<Database> getDB() async {
    myDB ??= await openDB();
    return myDB!;
  }

  Future<Database> openDB() async {
    Directory appDir = await getApplicationDocumentsDirectory();
    String dbPath = join(appDir.path, "noteDB_encrypted.db");
    
    return await openDatabase(
      dbPath,
      password: _getEncryptionKey(), // 🔐 Encryption password
      onCreate: (db, version) {
        db.execute(
          "CREATE TABLE $tableName ("
          "$noteNo INTEGER PRIMARY KEY AUTOINCREMENT, "
          "$noteTitle TEXT, "
          "$noteDesc TEXT, "
          "$noteHash TEXT, " // Hash for integrity check
          "$noteTime TEXT DEFAULT CURRENT_TIMESTAMP"
          ");"
        );
      },
      version: 1,
    );
  }

  // ✅ Insert with integrity hash
  Future<bool> addNote({required String title, required String desc}) async {
    var db = await getDB();
    String hash = _generateHash(title, desc);
    
    int effectedRow = await db.insert(
      tableName,
      {
        noteTitle: title,
        noteDesc: desc,
        noteHash: hash,
      },
    );
    
    return effectedRow > 0;
  }

  // 🔍 Fetch all notes with integrity verification
  Future<List<Map<String, dynamic>>> getAllNote() async {
    var db = await getDB();
    List<Map<String, dynamic>> allData = await db.query(tableName);
    
    // Verify data integrity
    List<Map<String, dynamic>> verifiedData = [];
    for (var note in allData) {
      String storedHash = note[noteHash] ?? '';
      String calculatedHash = _generateHash(
        note[noteTitle] ?? '',
        note[noteDesc] ?? '',
      );
      
      if (storedHash == calculatedHash) {
        verifiedData.add(note);
      } else {
        print("⚠️ Data integrity compromised for note #${note[noteNo]}");
        // You can handle tampered data here (delete, flag, etc.)
      }
    }
    
    return verifiedData;
  }

  // 🔄 Update with new hash
  Future<bool> updateNote({
    required String title,
    required String desc,
    required int slNo,
  }) async {
    var db = await getDB();
    String hash = _generateHash(title, desc);
    
    int effectedRow = await db.update(
      tableName,
      {
        noteTitle: title,
        noteDesc: desc,
        noteHash: hash,
      },
      where: "$noteNo = ?",
      whereArgs: [slNo],
    );
    
    return effectedRow > 0;
  }

  // 🗑️ Delete note
  Future<bool> deleteNote({required int slNo}) async {
    var db = await getDB();
    
    int effectedRow = await db.delete(
      tableName,
      where: "$noteNo = ?",
      whereArgs: [slNo],
    );
    
    return effectedRow > 0;
  }

  // 🔒 Close database
  Future<void> closeDB() async {
    if (myDB != null) {
      await myDB!.close();
      myDB = null;
    }
  }
}


class KeyManager {
  AndroidOptions _getAndroidOptions() => const AndroidOptions(
        encryptedSharedPreferences: true,
      );
  final iOptions =
      IOSOptions(accessibility: KeychainAccessibility.first_unlock);
  late final FlutterSecureStorage storage = FlutterSecureStorage(
    aOptions: _getAndroidOptions(),
    iOptions: iOptions,
  );

  Future<String> getOrCreateKey() async {
    String? key = await storage.read(key: 'db_encryption_key');
    if (key == null) {
      key = "_generateSecureRandomKey()"; // Generate random key
      await storage.write(key: 'db_encryption_key', value: key);
    }
    return key;
  }
}
