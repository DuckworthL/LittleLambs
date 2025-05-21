import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../models/point.dart';
import '../helpers/database_helper.dart';
import '../utils/logger.dart';

class PointsProvider with ChangeNotifier {
  List<Point> _points = [];
  final Map<int, int> _childTotalPoints = {};

  List<Point> get points => _points;
  Map<int, int> get childTotalPoints => _childTotalPoints;

  Future<void> fetchPoints() async {
    try {
      final pointsData = await DatabaseHelper.instance.queryAllPoints();
      _points = pointsData.map((item) {
        return Point(
          id: item['id'] as int,
          childId: item['childId'] as int,
          childName: item['childName'] as String,
          groupName: item['groupName'] as String,
          date: item['date'] as String,
          amount: item['amount'] as int,
          reason: item['reason'] as String?,
        );
      }).toList();

      // Also load total points
      await loadAllChildrenTotalPoints();

      notifyListeners();
    } catch (e) {
      Logger.error('Error fetching points', e);
      rethrow;
    }
  }

  Future<void> loadAllChildrenTotalPoints() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final result = await db.rawQuery('''
        SELECT childId, SUM(amount) as total 
        FROM points 
        GROUP BY childId
      ''');

      _childTotalPoints.clear();
      for (var item in result) {
        final childId = item['childId'] as int;
        final total = item['total'] as int? ?? 0;
        _childTotalPoints[childId] = total;
      }

      notifyListeners();
    } catch (e) {
      Logger.error('Error loading total points', e);
    }
  }

  int getChildTotalPoints(int childId) {
    return _childTotalPoints[childId] ?? 0;
  }

  Future<void> addPoints(int childId, int amount, String? reason) async {
    try {
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

      final pointData = {
        'childId': childId,
        'date': today,
        'amount': amount,
        'reason': reason,
      };

      // We're not using the ID directly, so no need to store it in a variable
      await DatabaseHelper.instance.insertPoints(pointData);

      // Fetch updated points list to get the child name
      await fetchPoints();

      notifyListeners();
    } catch (e) {
      Logger.error('Error adding points', e);
      rethrow;
    }
  }

  Future<void> updatePoints(int id, int amount, String? reason) async {
    try {
      final pointData = {
        'amount': amount,
        'reason': reason,
      };

      await DatabaseHelper.instance.updatePoints(id, pointData);
      await fetchPoints();

      notifyListeners();
    } catch (e) {
      Logger.error('Error updating points', e);
      rethrow;
    }
  }

  Future<void> deletePoints(int id) async {
    try {
      await DatabaseHelper.instance.deletePoints(id);

      // Remove from local state
      _points.removeWhere((point) => point.id == id);

      // Update total points
      await loadAllChildrenTotalPoints();

      notifyListeners();
    } catch (e) {
      Logger.error('Error deleting points', e);
      rethrow;
    }
  }

  Future<int> getTotalPointsByChild(int childId) async {
    try {
      return await DatabaseHelper.instance.getTotalPointsByChild(childId);
    } catch (e) {
      Logger.error('Error getting total points', e);
      return 0;
    }
  }

  List<Point> getPointsByChild(int childId) {
    return _points.where((point) => point.childId == childId).toList();
  }
}
