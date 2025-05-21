import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';
import '../models/attendance.dart';
import '../helpers/database_helper.dart';

class AttendanceProvider with ChangeNotifier {
  final Map<String, Map<int, bool>> _attendanceData = {};

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
      if (kDebugMode) {
        print('Error getting monthly attendance: $e');
      }
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
      if (kDebugMode) {
        print('Error getting attendance count by child: $e');
      }
      return {};
    }
  }
}
