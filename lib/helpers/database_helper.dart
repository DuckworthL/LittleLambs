import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';

class DatabaseHelper {
  static const _databaseName = "church_attendance.db";
  static const _databaseVersion = 2; // Incremented version number

  // Singleton pattern
  DatabaseHelper._privateConstructor();
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  _initDatabase() async {
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String path = join(documentsDirectory.path, _databaseName);
    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade, // Added upgrade handler
    );
  }

  Future _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE children(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        age INTEGER NOT NULL,
        notes TEXT,
        groupName TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE attendance(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        childId INTEGER NOT NULL,
        date TEXT NOT NULL,
        isPresent INTEGER NOT NULL,
        FOREIGN KEY (childId) REFERENCES children (id)
          ON DELETE CASCADE,
        UNIQUE(childId, date)
      )
    ''');

    await db.execute('''
      CREATE TABLE points(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        childId INTEGER NOT NULL,
        date TEXT NOT NULL,
        amount INTEGER NOT NULL,
        reason TEXT,
        FOREIGN KEY (childId) REFERENCES children (id)
          ON DELETE CASCADE
      )
    ''');
  }

  // Added upgrade handler
  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Create points table if upgrading from version 1
      await db.execute('''
        CREATE TABLE IF NOT EXISTS points(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          childId INTEGER NOT NULL,
          date TEXT NOT NULL,
          amount INTEGER NOT NULL,
          reason TEXT,
          FOREIGN KEY (childId) REFERENCES children (id)
            ON DELETE CASCADE
        )
      ''');
    }
  }

  // Children CRUD operations
  Future<int> insertChild(Map<String, dynamic> row) async {
    Database db = await instance.database;
    return await db.insert('children', row);
  }

  Future<List<Map<String, dynamic>>> queryAllChildren() async {
    Database db = await instance.database;
    return await db.query('children', orderBy: 'name');
  }

  Future<List<Map<String, dynamic>>> queryChildrenByGroup(
      String groupName) async {
    Database db = await instance.database;
    return await db.query('children',
        where: 'groupName = ?', whereArgs: [groupName], orderBy: 'name');
  }

  Future<int> updateChild(Map<String, dynamic> row) async {
    Database db = await instance.database;
    int id = row['id'];
    return await db.update('children', row, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteChild(int id) async {
    Database db = await instance.database;
    return await db.delete('children', where: 'id = ?', whereArgs: [id]);
  }

  // Attendance CRUD operations
  Future<int> insertOrUpdateAttendance(Map<String, dynamic> row) async {
    Database db = await instance.database;
    try {
      return await db.insert('attendance', row,
          conflictAlgorithm: ConflictAlgorithm.replace);
    } catch (e) {
      return await db.update('attendance', row,
          where: 'childId = ? AND date = ?',
          whereArgs: [row['childId'], row['date']]);
    }
  }

  Future<List<Map<String, dynamic>>> queryAttendanceForDate(String date) async {
    Database db = await instance.database;
    return await db.query('attendance', where: 'date = ?', whereArgs: [date]);
  }

  Future<List<Map<String, dynamic>>> queryAttendanceByChild(int childId) async {
    Database db = await instance.database;
    return await db.query('attendance',
        where: 'childId = ?', whereArgs: [childId], orderBy: 'date DESC');
  }

  Future<List<Map<String, dynamic>>> queryAttendanceByMonth(
      String yearMonth) async {
    Database db = await instance.database;
    return await db.query('attendance',
        where: 'date LIKE ?', whereArgs: ['$yearMonth%'], orderBy: 'date');
  }

  Future<Map<String, dynamic>> getAttendanceStats() async {
    Database db = await instance.database;

    var totalResult = await db.rawQuery(
        'SELECT COUNT(DISTINCT date) as totalServices FROM attendance');
    int totalServices = totalResult.first['totalServices'] as int;

    var childrenResult =
        await db.rawQuery('SELECT COUNT(*) as totalChildren FROM children');
    int totalChildren = childrenResult.first['totalChildren'] as int;

    return {
      'totalServices': totalServices,
      'totalChildren': totalChildren,
    };
  }

  // Points CRUD operations
  Future<int> addPoints(Map<String, dynamic> row) async {
    Database db = await instance.database;
    try {
      return await db.insert('points', row);
    } catch (e) {
      if (kDebugMode) {
        print('Error adding points: $e');
      }
      // Create table if it doesn't exist and try again
      await db.execute('''
        CREATE TABLE IF NOT EXISTS points(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          childId INTEGER NOT NULL,
          date TEXT NOT NULL,
          amount INTEGER NOT NULL,
          reason TEXT,
          FOREIGN KEY (childId) REFERENCES children (id)
            ON DELETE CASCADE
        )
      ''');
      return await db.insert('points', row);
    }
  }

  Future<List<Map<String, dynamic>>> queryPointsByChild(int childId) async {
    Database db = await instance.database;
    try {
      return await db.query('points',
          where: 'childId = ?', whereArgs: [childId], orderBy: 'date DESC');
    } catch (e) {
      if (kDebugMode) {
        print('Error querying points: $e');
      }
      // If table doesn't exist yet, return empty list
      return [];
    }
  }

  Future<int> getTotalPointsByChild(int childId) async {
    Database db = await instance.database;
    try {
      var result = await db.rawQuery(
          'SELECT SUM(amount) as total FROM points WHERE childId = ?',
          [childId]);
      return result.first['total'] as int? ?? 0;
    } catch (e) {
      // Handle case where points table might not exist
      if (kDebugMode) {
        print('Error getting points: $e');
      }
      return 0;
    }
  }
}
