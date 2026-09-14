import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/product.dart';

class SQLiteHelper {
  static final SQLiteHelper instance = SQLiteHelper._init();
  static Database? _database;

  SQLiteHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('villageshop_local.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
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
        udhaar REAL DEFAULT 0.0,
        lastTx TEXT
      )
    ''');
  }

  Future<void> ensureTablesExist() async {
    final db = await instance.database;
    await _createDB(db, 1);
  }

  Future<void> saveProducts(List<Product> products) async {
    final db = await instance.database;
    final batch = db.batch();
    for (var product in products) {
      batch.insert('products', product.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<void> saveProductRecord(Map<String, dynamic> p) async {
    final db = await instance.database;
    await db.insert('products', {
      'name': p['name'],
      'category': p['category'] ?? 'General',
      'unit': p['unit'] ?? 'pcs',
      'purchasePrice': (p['price'] as num?)?.toDouble() ?? 0.0,
      'sellingPrice': (p['price'] as num?)?.toDouble() ?? 0.0,
      'mrp': (p['price'] as num?)?.toDouble() ?? 0.0,
      'currentStock': (p['stock'] as num?)?.toDouble() ?? 0.0,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deductProductStock(String productName, double quantity) async {
    final db = await instance.database;
    await ensureTablesExist();
    await db.rawUpdate(
      'UPDATE products SET currentStock = CASE WHEN currentStock - ? < 0 THEN 0 ELSE currentStock - ? END WHERE name = ?',
      [quantity, quantity, productName],
    );
  }

  Future<List<Product>> getProducts() async {
    final db = await instance.database;
    await ensureTablesExist();
    final result = await db.query('products');
    return result.map((map) => Product.fromMap(map)).toList();
  }

  Future<void> saveCustomer(Map<String, dynamic> customer) async {
    final db = await instance.database;
    await ensureTablesExist();
    await db.insert('customers', customer, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> getCustomers() async {
    final db = await instance.database;
    await ensureTablesExist();
    return await db.query('customers');
  }

  Future<void> updateCustomerUdhaar(String name, double newUdhaar) async {
    final db = await instance.database;
    await ensureTablesExist();
    await db.update(
      'customers',
      {'udhaar': newUdhaar, 'lastTx': 'Payment Received'},
      where: 'name = ?',
      whereArgs: [name],
    );
  }

  Future<void> addToSyncQueue(String clientTxId, String entityName, String payloadJson) async {
    final db = await instance.database;
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
  }

  Future<List<Map<String, dynamic>>> getPendingSyncItems() async {
    final db = await instance.database;
    await ensureTablesExist();
    return await db.query('sync_queue', where: 'syncStatus = ?', whereArgs: ['PENDING']);
  }

  Future<void> markSynced(String clientTxId) async {
    final db = await instance.database;
    await db.update(
      'sync_queue',
      {'syncStatus': 'SUCCESS'},
      where: 'clientTransactionId = ?',
      whereArgs: [clientTxId],
    );
  }
}
