import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';
import '../models/attendance.dart';
import '../helpers/database_helper.dart';
import '../utils/logger.dart';

class AttendanceProvider with ChangeNotifier {
  final Map<String, Map<int, bool>> _attendanceData = {};

  // Track archived months
  final List<Map<String, dynamic>> _archivedMonths = [];

  // Getter for archived months
  List<Map<String, dynamic>> get archivedMonths => _archivedMonths;

  Map<String, Map<int, bool>> get attendanceData => _attendanceData;

  String get todayFormatted {
    return DateFormat('yyyy-MM-dd').format(DateTime.now());
  }

  // Get nearest service day (Saturday or Sunday)
  String get currentServiceDate {
    final now = DateTime.now();

    // If today is Saturday or Sunday, return today's date
    if (now.weekday == DateTime.saturday || now.weekday == DateTime.sunday) {
      return DateFormat('yyyy-MM-dd').format(now);
    }

    // Calculate days to Saturday and Sunday
    final daysToSaturday = (DateTime.saturday - now.weekday) % 7;
    final daysToSunday = (DateTime.sunday - now.weekday) % 7;

    // Return the closest upcoming service date
    final daysToClosestService =
        daysToSaturday < daysToSunday ? daysToSaturday : daysToSunday;

    final nextServiceDay = now.add(Duration(days: daysToClosestService));
    return DateFormat('yyyy-MM-dd').format(nextServiceDay);
  }

  Future<void> fetchAttendanceForDate(String date) async {
    final attendanceData =
        await DatabaseHelper.instance.queryAttendanceForDate(date);
    Map<int, bool> childAttendance = {};

    for (var item in attendanceData) {
      childAttendance[item['childId'] as int] = item['isPresent'] == 1;
    }

    _attendanceData[date] = childAttendance;
    notifyListeners();
  }

  Future<void> markAttendance(int childId, String date, bool isPresent) async {
    final attendance = Attendance(
      childId: childId,
      date: date,
      isPresent: isPresent,
    );

    await DatabaseHelper.instance.insertOrUpdateAttendance(attendance.toMap());

    // Update local state
    if (_attendanceData.containsKey(date)) {
      _attendanceData[date]![childId] = isPresent;
    } else {
      _attendanceData[date] = {childId: isPresent};
    }

    notifyListeners();
  }

  // Add setAttendance method to match what's used in the Detail Screen
  Future<void> setAttendance({
    required int childId,
    required String date,
    required bool isPresent,
  }) async {
    try {
      // This is just a wrapper around the existing markAttendance method
      await markAttendance(childId, date, isPresent);
    } catch (e) {
      Logger.error('Error setting attendance', e);
      rethrow;
    }
  }

  bool isChildPresent(int childId, String date) {
    if (_attendanceData.containsKey(date) &&
        _attendanceData[date]!.containsKey(childId)) {
      return _attendanceData[date]![childId]!;
    }
    return false;
  }

  // Get count of present children for a specific date
  int getPresentCountForDate(String date) {
    if (!_attendanceData.containsKey(date)) {
      return 0;
    }

    int count = 0;
    _attendanceData[date]!.forEach((_, isPresent) {
      if (isPresent) count++;
    });

    return count;
  }

  Future<Map<String, int>> getMonthlyAttendanceCount(
      int year, int month) async {
    try {
      final yearMonth = DateFormat('yyyy-MM').format(DateTime(year, month));
      final data =
          await DatabaseHelper.instance.queryAttendanceByMonth(yearMonth);

      Map<String, int> dateCountMap = {};

      for (var item in data) {
        final date = item['date'] as String;
        final isPresent = item['isPresent'] as int;

        if (isPresent == 1) {
          if (dateCountMap.containsKey(date)) {
            dateCountMap[date] = dateCountMap[date]! + 1;
          } else {
            dateCountMap[date] = 1;
          }
        }
      }

      return dateCountMap;
    } catch (e) {
      Logger.error('Error getting monthly attendance', e);
      return {};
    }
  }

  Future<Map<int, int>> getAttendanceCountByChild(
      List<int> childrenIds, String startDate, String endDate) async {
    try {
      Database db = await DatabaseHelper.instance.database;
      Map<int, int> result = {};

      for (var childId in childrenIds) {
        var count = await db.rawQuery('''
          SELECT COUNT(*) as count
          FROM attendance
          WHERE childId = ?
          AND date BETWEEN ? AND ?
          AND isPresent = 1
        ''', [childId, startDate, endDate]);

        result[childId] = count.first['count'] as int;
      }

      return result;
    } catch (e) {
      Logger.error('Error getting attendance count by child', e);
      return {};
    }
  }

  // Method to check if a month is archived
  bool isMonthArchived(int year, int month) {
    final monthKey = '$year-${month.toString().padLeft(2, '0')}';
    return _archivedMonths.any((m) => m['key'] == monthKey);
  }

  // Method to load archived months from database
  Future<void> loadArchivedMonths() async {
    try {
      Database db = await DatabaseHelper.instance.database;

      // Check if archived_months table exists, if not create it
      await db.execute('''
        CREATE TABLE IF NOT EXISTS archived_months (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          year INTEGER NOT NULL,
          month INTEGER NOT NULL,
          archived_date TEXT NOT NULL
        )
      ''');

      final List<Map<String, dynamic>> archivedData =
          await db.query('archived_months');

      _archivedMonths.clear();
      for (var item in archivedData) {
        final year = item['year'] as int;
        final month = item['month'] as int;

        _archivedMonths.add({
          'year': year,
          'month': month,
          'key': '$year-${month.toString().padLeft(2, '0')}',
          'archived_date': item['archived_date'],
        });
      }

      notifyListeners();
    } catch (e) {
      Logger.error('Error loading archived months', e);
    }
  }

  // Method to archive a month's reports
  Future<void> archiveMonthReport(int year, int month) async {
    try {
      if (isMonthArchived(year, month)) {
        // Already archived
        return;
      }

      Database db = await DatabaseHelper.instance.database;
      final now = DateTime.now();
      final archivedDate = DateFormat('yyyy-MM-dd').format(now);

      // Insert into archived_months table
      await db.insert('archived_months', {
        'year': year,
        'month': month,
        'archived_date': archivedDate,
      });

      // Update local state
      _archivedMonths.add({
        'year': year,
        'month': month,
        'key': '$year-${month.toString().padLeft(2, '0')}',
        'archived_date': archivedDate,
      });

      Logger.log('Archived report for $month/$year');
      notifyListeners();
    } catch (e) {
      Logger.error('Error archiving month report', e);
      throw Exception('Failed to archive report: $e');
    }
  }

  // Method to restore a month's reports from archive
  Future<void> restoreMonthReport(int year, int month) async {
    try {
      if (!isMonthArchived(year, month)) {
        // Not archived
        return;
      }

      Database db = await DatabaseHelper.instance.database;

      // Remove from archived_months table
      await db.delete('archived_months',
          where: 'year = ? AND month = ?', whereArgs: [year, month]);

      // Update local state
      final monthKey = '$year-${month.toString().padLeft(2, '0')}';
      _archivedMonths.removeWhere((m) => m['key'] == monthKey);

      Logger.log('Restored report for $month/$year');
      notifyListeners();
    } catch (e) {
      Logger.error('Error restoring month report', e);
      throw Exception('Failed to restore report: $e');
    }
  }

  // Method to delete a month's reports
  Future<void> deleteMonthReport(int year, int month) async {
    try {
      Database db = await DatabaseHelper.instance.database;
      final yearMonth = DateFormat('yyyy-MM').format(DateTime(year, month));

      // Delete attendance records for this month
      await db.delete('attendance', where: "date LIKE '$yearMonth%'");

      // If it was archived, also remove from archived_months
      if (isMonthArchived(year, month)) {
        await db.delete('archived_months',
            where: 'year = ? AND month = ?', whereArgs: [year, month]);

        // Update local state for archived months
        final monthKey = '$year-${month.toString().padLeft(2, '0')}';
        _archivedMonths.removeWhere((m) => m['key'] == monthKey);
      }

      // Clear local state for this month if any
      final pattern = RegExp('^$yearMonth');
      _attendanceData.removeWhere((key, _) => pattern.hasMatch(key));

      Logger.log('Deleted report for $month/$year');
      notifyListeners();
    } catch (e) {
      Logger.error('Error deleting month report', e);
      throw Exception('Failed to delete report: $e');
    }
  }
}