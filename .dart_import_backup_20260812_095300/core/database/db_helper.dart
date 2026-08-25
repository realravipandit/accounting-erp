import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../../models/auth/user_model.dart';
import '../../models/purchase/purchase.dart';
import '../../models/sales/sales.dart';
import '../../models/inventory/inventory.dart';
import '../../models/ledger/customer.dart';
import '../../models/purchase/vendor.dart';
import '../../models/receivable/outstanding.dart';

class DBHelper {
  static final DBHelper _instance = DBHelper._internal();
  static Database? _database;

  factory DBHelper() {
    return _instance;
  }

  DBHelper._internal();

  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final String path = join(
      await getDatabasesPath(),
      'sas_akount.db',
    );
    return openDatabase(
      path,
      version: 2,
      onCreate: (Database db, int version) async {
        await _createTables(db);
      },
      onUpgrade: (Database db, int oldVersion, int newVersion) async {
        if (oldVersion < 2) {
          await _createTables(db);
        }
      },
    );
  }

  Future<void> _createTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS users (
        id INTEGER PRIMARY KEY,
        phoneNumber TEXT,
        password TEXT,
        email TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sales (
        id INTEGER PRIMARY KEY,
        customerId INTEGER,
        totalAmount REAL,
        date TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS purchases (
        id INTEGER PRIMARY KEY,
        vendorId INTEGER,
        totalAmount REAL,
        date TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS inventory (
        id INTEGER PRIMARY KEY,
        itemName TEXT,
        quantity INTEGER,
        price REAL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS customers (
        id INTEGER PRIMARY KEY,
        name TEXT,
        phone TEXT,
        email TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS vendors (
        id INTEGER PRIMARY KEY,
        name TEXT,
        phone TEXT,
        email TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS outstanding (
        id INTEGER PRIMARY KEY,
        customerId INTEGER,
        vendorId INTEGER,
        outstandingAmount REAL,
        type TEXT,
        date TEXT
      )
    ''');
  }

  // USERS
  Future<void> insertUser(User user) async {
    final db = await database;
    await db.insert(
      'users',
      user.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<bool> login(
    String phoneNumber,
    String password,
  ) async {
    final db = await database;
    final List<Map<String, dynamic>> result = await db.query(
      'users',
      where: 'phoneNumber = ? AND password = ?',
      whereArgs: [phoneNumber, password],
    );
    return result.isNotEmpty;
  }

  // SALES
  Future<void> insertSale(Sales sale) async {
    final db = await database;
    await db.insert(
      'sales',
      sale.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // PURCHASES
  Future<void> insertPurchase(Purchase purchase) async {
    final db = await database;
    await db.insert(
      'purchases',
      purchase.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // INVENTORY
  Future<void> insertInventory(Inventory inventory) async {
    final db = await database;
    await db.insert(
      'inventory',
      inventory.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // CUSTOMERS
  Future<void> insertCustomer(Customer customer) async {
    final db = await database;
    await db.insert(
      'customers',
      customer.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // VENDORS
  Future<void> insertVendor(Vendor vendor) async {
    final db = await database;
    await db.insert(
      'vendors',
      vendor.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // OUTSTANDING
  Future<void> insertOutstanding(
    Outstanding outstanding,
  ) async {
    final db = await database;
    await db.insert(
      'outstanding',
      outstanding.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}