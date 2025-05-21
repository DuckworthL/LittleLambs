import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('little_lambs.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 2,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Create tables
    await db.execute('''
      CREATE TABLE children(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        age INTEGER NOT NULL,
        groupName TEXT NOT NULL,
        notes TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE attendance(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        childId INTEGER NOT NULL,
        date TEXT NOT NULL,
        isPresent INTEGER NOT NULL,
        UNIQUE(childId, date),
        FOREIGN KEY (childId) REFERENCES children (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE points(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        childId INTEGER NOT NULL,
        date TEXT NOT NULL,
        amount INTEGER NOT NULL,
        reason TEXT,
        FOREIGN KEY (childId) REFERENCES children (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE archived_months (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        year INTEGER NOT NULL,
        month INTEGER NOT NULL,
        archived_date TEXT NOT NULL
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add the archived_months table if upgrading from version 1
      await db.execute('''
        CREATE TABLE IF NOT EXISTS archived_months (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          year INTEGER NOT NULL,
          month INTEGER NOT NULL,
          archived_date TEXT NOT NULL
        )
      ''');
    }
  }

  // CHILDREN CRUD OPERATIONS
  Future<int> insertChild(Map<String, dynamic> childData) async {
    final db = await database;
    return await db.insert('children', childData);
  }

  Future<List<Map<String, dynamic>>> queryAllChildren() async {
    final db = await database;
    return await db.query('children', orderBy: 'name');
  }

  Future<int> updateChild(int id, Map<String, dynamic> childData) async {
    final db = await database;
    return await db.update(
      'children',
      childData,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteChild(int id) async {
    final db = await database;

    // Delete associated attendance records first
    await db.delete(
      'attendance',
      where: 'childId = ?',
      whereArgs: [id],
    );

    // Delete associated points records
    await db.delete(
      'points',
      where: 'childId = ?',
      whereArgs: [id],
    );

    // Delete the child
    return await db.delete(
      'children',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ATTENDANCE OPERATIONS
  Future<int> insertOrUpdateAttendance(Map<String, dynamic> data) async {
    final db = await database;

    try {
      // Try to insert first
      return await db.insert(
        'attendance',
        data,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error during attendance insert: $e');
      }

      // If error, try to update
      return await db.update(
        'attendance',
        data,
        where: 'childId = ? AND date = ?',
        whereArgs: [data['childId'], data['date']],
      );
    }
  }

  Future<List<Map<String, dynamic>>> queryAttendanceForDate(String date) async {
    final db = await database;
    return await db.query(
      'attendance',
      where: 'date = ?',
      whereArgs: [date],
    );
  }

  Future<List<Map<String, dynamic>>> queryAttendanceByMonth(
      String yearMonth) async {
    final db = await database;
    return await db.query(
      'attendance',
      where: 'date LIKE ?',
      whereArgs: ['$yearMonth%'],
    );
  }

  // POINTS OPERATIONS
  Future<int> insertPoints(Map<String, dynamic> data) async {
    final db = await database;
    return await db.insert('points', data);
  }

  Future<List<Map<String, dynamic>>> queryAllPoints() async {
    final db = await database;
    return await db.rawQuery('''
      SELECT points.*, children.name as childName, children.groupName 
      FROM points 
      JOIN children ON points.childId = children.id
      ORDER BY points.date DESC
    ''');
  }

  Future<int> updatePoints(int id, Map<String, dynamic> data) async {
    final db = await database;
    return await db.update(
      'points',
      data,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deletePoints(int id) async {
    final db = await database;
    return await db.delete(
      'points',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Map<String, dynamic>>> queryPointsByChild(int childId) async {
    final db = await database;
    return await db.query(
      'points',
      where: 'childId = ?',
      whereArgs: [childId],
      orderBy: 'date DESC',
    );
  }

  Future<int> getTotalPointsByChild(int childId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT SUM(amount) as total FROM points WHERE childId = ?',
      [childId],
    );

    return result.first['total'] == null ? 0 : result.first['total'] as int;
  }

  // GROUP OPERATIONS
  Future<List<String>> queryAllGroups() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT DISTINCT groupName FROM children ORDER BY groupName',
    );

    return result.map((row) => row['groupName'] as String).toList();
  }

  Future<int> updateGroup(String oldName, String newName) async {
    final db = await database;
    return await db.update(
      'children',
      {'groupName': newName},
      where: 'groupName = ?',
      whereArgs: [oldName],
    );
  }

  Future<int> deleteGroup(String groupName) async {
    final db = await database;
    // This will delete all children in the group, and cascading will delete their attendance and points
    return await db.delete(
      'children',
      where: 'groupName = ?',
      whereArgs: [groupName],
    );
  }

  // Count children in a group
  Future<int> countChildrenInGroup(String groupName) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM children WHERE groupName = ?',
      [groupName],
    );

    return result.first['count'] as int;
  }
}
