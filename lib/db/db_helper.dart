import 'package:sas_akount_login/models/purchase.dart';
import 'package:sas_akount_login/models/sales.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/user_model.dart';
import '../models/dashboard_model.dart';
import 'dart:async';

class DBHelper {
  static final DBHelper _instance = DBHelper._internal();
  static Database? _database;

  factory DBHelper() {
    return _instance;
  }

  DBHelper._internal();

  // Method to get the database instance
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  // Initialize database with new tables (while keeping the previous 'users' table intact)
  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'sas_akount.db');
    return await openDatabase(
      path,
      version: 1, // Incremented version to handle new tables
      onCreate: (db, version) async {
        // Create 'users' table for login/register process
        await db.execute(
          "CREATE TABLE users(id INTEGER PRIMARY KEY, phoneNumber TEXT, password TEXT, email TEXT)",
        );

        // Create other necessary tables for sales, purchases, inventory, customers, vendors, and outstanding
        await db.execute(
          "CREATE TABLE sales(id INTEGER PRIMARY KEY, customerId INTEGER, totalAmount REAL, date TEXT)",
        );

        await db.execute(
          "CREATE TABLE purchases(id INTEGER PRIMARY KEY, vendorId INTEGER, totalAmount REAL, date TEXT)",
        );

        await db.execute(
          "CREATE TABLE inventory(id INTEGER PRIMARY KEY, itemName TEXT, quantity INTEGER, price REAL)",
        );

        await db.execute(
          "CREATE TABLE customers(id INTEGER PRIMARY KEY, name TEXT, phone TEXT, email TEXT)",
        );

        await db.execute(
          "CREATE TABLE vendors(id INTEGER PRIMARY KEY, name TEXT, phone TEXT, email TEXT)",
        );

        await db.execute(
          "CREATE TABLE outstanding(id INTEGER PRIMARY KEY, customerId INTEGER, vendorId INTEGER, outstandingAmount REAL, type TEXT, date TEXT)",
        );
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        // Handle table creation on upgrading the database
        if (oldVersion < 2) {
          await db.execute(
            "CREATE TABLE sales(id INTEGER PRIMARY KEY, customerId INTEGER, totalAmount REAL, date TEXT)",
          );
          await db.execute(
            "CREATE TABLE purchases(id INTEGER PRIMARY KEY, vendorId INTEGER, totalAmount REAL, date TEXT)",
          );
          await db.execute(
            "CREATE TABLE inventory(id INTEGER PRIMARY KEY, itemName TEXT, quantity INTEGER, price REAL)",
          );
          await db.execute(
            "CREATE TABLE customers(id INTEGER PRIMARY KEY, name TEXT, phone TEXT, email TEXT)",
          );
          await db.execute(
            "CREATE TABLE vendors(id INTEGER PRIMARY KEY, name TEXT, phone TEXT, email TEXT)",
          );
          await db.execute(
            "CREATE TABLE outstanding(id INTEGER PRIMARY KEY, customerId INTEGER, vendorId INTEGER, outstandingAmount REAL, type TEXT, date TEXT)",
          );
        }
      },
    );
  }

  // Existing Auth (User Login/Register) functions remain intact
  Future<void> insertUser(User user) async {
    final db = await database;
    await db.insert('users', user.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<bool> login(String phoneNumber, String password) async {
    final db = await database;
    final result = await db.query(
      'users',
      where: 'phoneNumber = ? AND password = ?',
      whereArgs: [phoneNumber, password],
    );
    return result.isNotEmpty;
  }

  // Additional functions for sales, purchases, inventory, customers, vendors, and outstanding

  Future<void> insertSale(Sales sale) async {
    final db = await database;
    await db.insert('sales', sale.toJson(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // Future<void> insertPurchase(purchases purchase) async {
  //   final db = await database;
  //   await db.insert('purchases', purchase.toJson(),
  //       conflictAlgorithm: ConflictAlgorithm.replace);
  // }

  Future<void> insertPurchase(Purchase purchase) async {
    final db = await database;
    await db.insert(
      'purchases',
      purchase.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> insertInventory(Inventory inventory) async {
    final db = await database;
    await db.insert('inventory', inventory.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> insertCustomer(Customer customer) async {
    final db = await database;
    await db.insert('customers', customer.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> insertVendor(Vendor vendor) async {
    final db = await database;
    await db.insert('vendors', vendor.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> insertOutstanding(Outstanding outstanding) async {
    final db = await database;
    await db.insert('outstanding', outstanding.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }
}
