import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/product.dart';

class SQLiteHelper {
  static final SQLiteHelper instance = SQLiteHelper._init();
  static Database? _database;

  SQLiteHelper._init();

  Future<Database?> get database async {
    if (kIsWeb) return null;
    if (_database != null) return _database!;
    try {
      _database = await _initDB('villageshop_local.db');
      return _database;
    } catch (_) {
      return null;
    }
  }

  Future<Database?> _initDB(String filePath) async {
    if (kIsWeb) return null;
    try {
      final dbPath = await getDatabasesPath();
      final path = join(dbPath, filePath);

      return await openDatabase(
        path,
        version: 1,
        onCreate: _createDB,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS products (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        productCode TEXT,
        name TEXT,
        category TEXT,
        unit TEXT,
        barcode TEXT,
        purchasePrice REAL,
        sellingPrice REAL,
        mrp REAL,
        currentStock REAL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS sync_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        clientTransactionId TEXT UNIQUE,
        entityName TEXT,
        payload TEXT,
        createdAt TEXT,
        syncStatus TEXT,
        retryCount INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS customers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT UNIQUE,
        phone TEXT,
        email TEXT,
        whatsapp TEXT,
        fatherName TEXT,
        address TEXT,
        village TEXT,
        po TEXT,
        ps TEXT,
        dist TEXT,
        pincode TEXT,
        udhaar REAL DEFAULT 0.0,
        lastTx TEXT
      )
    ''');
  }

  Future<void> ensureTablesExist() async {
    if (kIsWeb) return;
    try {
      final db = await instance.database;
      if (db == null) return;
      await _createDB(db, 1);
      
      // Auto-migrate missing columns for existing SQLite databases
      final List<String> newColumns = [
        'email', 'whatsapp', 'fatherName', 'address', 'village', 'po', 'ps', 'dist', 'pincode'
      ];
      for (var col in newColumns) {
        try {
          await db.execute('ALTER TABLE customers ADD COLUMN $col TEXT');
        } catch (_) {
          // Column already exists
        }
      }
    } catch (_) {}
  }

  Future<void> saveProducts(List<Product> products) async {
    if (kIsWeb) return;
    try {
      final db = await instance.database;
      if (db == null) return;
      final batch = db.batch();
      for (var product in products) {
        batch.insert('products', product.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);
    } catch (_) {}
  }

  Future<void> saveProductRecord(Map<String, dynamic> p) async {
    if (kIsWeb) return;
    try {
      final db = await instance.database;
      if (db == null) return;
      await db.insert('products', {
        'name': p['name'],
        'category': p['category'] ?? 'General',
        'unit': p['unit'] ?? 'pcs',
        'purchasePrice': (p['price'] as num?)?.toDouble() ?? 0.0,
        'sellingPrice': (p['price'] as num?)?.toDouble() ?? 0.0,
        'mrp': (p['price'] as num?)?.toDouble() ?? 0.0,
        'currentStock': (p['stock'] as num?)?.toDouble() ?? 0.0,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    } catch (_) {}
  }

  Future<void> deductProductStock(String productName, double quantity) async {
    if (kIsWeb) return;
    try {
      final db = await instance.database;
      if (db == null) return;
      await ensureTablesExist();
      await db.rawUpdate(
        'UPDATE products SET currentStock = CASE WHEN currentStock - ? < 0 THEN 0 ELSE currentStock - ? END WHERE name = ?',
        [quantity, quantity, productName],
      );
    } catch (_) {}
  }

  Future<List<Product>> getProducts() async {
    if (kIsWeb) return [];
    try {
      final db = await instance.database;
      if (db == null) return [];
      await ensureTablesExist();
      final result = await db.query('products');
      return result.map((map) => Product.fromMap(map)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveCustomer(Map<String, dynamic> customer) async {
    if (kIsWeb) return;
    try {
      final db = await instance.database;
      if (db == null) return;
      await ensureTablesExist();
      await db.insert('customers', customer, conflictAlgorithm: ConflictAlgorithm.replace);
    } catch (_) {}
  }

  Future<List<Map<String, dynamic>>> getCustomers() async {
    if (kIsWeb) return [];
    try {
      final db = await instance.database;
      if (db == null) return [];
      await ensureTablesExist();
      return await db.query('customers');
    } catch (_) {
      return [];
    }
  }

  Future<void> updateCustomerUdhaar(String name, double newUdhaar) async {
    if (kIsWeb) return;
    try {
      final db = await instance.database;
      if (db == null) return;
      await ensureTablesExist();
      await db.update(
        'customers',
        {'udhaar': newUdhaar, 'lastTx': 'Payment Received'},
        where: 'name = ?',
        whereArgs: [name],
      );
    } catch (_) {}
  }

  Future<void> updateCustomerRecord(String oldName, Map<String, dynamic> c) async {
    if (kIsWeb) return;
    try {
      final db = await instance.database;
      if (db == null) return;
      await ensureTablesExist();
      await db.update(
        'customers',
        c,
        where: 'name = ?',
        whereArgs: [oldName],
      );
    } catch (_) {}
  }

  Future<void> updateProductRecord(String oldName, Map<String, dynamic> p) async {
    if (kIsWeb) return;
    try {
      final db = await instance.database;
      if (db == null) return;
      await ensureTablesExist();
      await db.update(
        'products',
        p,
        where: 'name = ?',
        whereArgs: [oldName],
      );
    } catch (_) {}
  }

  Future<void> deleteCustomerRecord(String name) async {
    if (kIsWeb) return;
    try {
      final db = await instance.database;
      if (db == null) return;
      await db.delete('customers', where: 'name = ?', whereArgs: [name]);
    } catch (_) {}
  }

  Future<void> deleteProductRecord(String name) async {
    if (kIsWeb) return;
    try {
      final db = await instance.database;
      if (db == null) return;
      await db.delete('products', where: 'name = ?', whereArgs: [name]);
    } catch (_) {}
  }

  Future<void> deleteSaleRecord(String id) async {
    if (kIsWeb) return;
    try {
      final db = await instance.database;
      if (db == null) return;
      await db.delete('sales', where: 'id = ?', whereArgs: [id]);
    } catch (_) {}
  }

  Future<void> addToSyncQueue(String clientTxId, String entityName, String payloadJson) async {
    if (kIsWeb) return;
    try {
      final db = await instance.database;
      if (db == null) return;
      await ensureTablesExist();
      await db.insert(
        'sync_queue',
        {
          'clientTransactionId': clientTxId,
          'entityName': entityName,
          'payload': payloadJson,
          'createdAt': DateTime.now().toIso8601String(),
          'syncStatus': 'PENDING',
          'retryCount': 0,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (_) {}
  }

  Future<List<Map<String, dynamic>>> getPendingSyncItems() async {
    if (kIsWeb) return [];
    try {
      final db = await instance.database;
      if (db == null) return [];
      await ensureTablesExist();
      return await db.query('sync_queue', where: 'syncStatus = ?', whereArgs: ['PENDING']);
    } catch (_) {
      return [];
    }
  }

  Future<void> markSynced(String clientTxId) async {
    if (kIsWeb) return;
    try {
      final db = await instance.database;
      if (db == null) return;
      await db.update(
        'sync_queue',
        {'syncStatus': 'SUCCESS'},
        where: 'clientTransactionId = ?',
        whereArgs: [clientTxId],
      );
    } catch (_) {}
  }
}
