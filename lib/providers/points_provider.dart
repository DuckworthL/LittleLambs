import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../models/point.dart';
import '../helpers/database_helper.dart';

class PointsProvider with ChangeNotifier {
  final Map<int, List<Point>> _pointsData = {}; // childId -> list of points
  final Map<int, int> _totalPointsCache = {}; // childId -> total points

  Map<int, List<Point>> get pointsData => _pointsData;
  Map<int, int> get totalPointsCache => _totalPointsCache;

  String get todayFormatted {
    return DateFormat('yyyy-MM-dd').format(DateTime.now());
  }

  Future<void> loadPointsForChild(int childId) async {
    final pointsData =
        await DatabaseHelper.instance.queryPointsByChild(childId);
    _pointsData[childId] =
        pointsData.map((item) => Point.fromMap(item)).toList();

    // Update total points cache
    _totalPointsCache[childId] =
        await DatabaseHelper.instance.getTotalPointsByChild(childId);

    notifyListeners();
  }

  Future<void> addPoints(int childId, int amount, {String? reason}) async {
    final point = Point(
      childId: childId,
      date: todayFormatted,
      amount: amount,
      reason: reason,
    );

    final id = await DatabaseHelper.instance.addPoints(point.toMap());

    // Update local data
    if (_pointsData.containsKey(childId)) {
      _pointsData[childId]!.insert(
          0,
          Point(
            id: id,
            childId: childId,
            date: todayFormatted,
            amount: amount,
            reason: reason,
          ));
    }

    // Update cached total
    _totalPointsCache[childId] = (_totalPointsCache[childId] ?? 0) + amount;

    notifyListeners();
  }

  Future<void> loadAllChildrenTotalPoints(List<int> childIds) async {
    for (var childId in childIds) {
      _totalPointsCache[childId] =
          await DatabaseHelper.instance.getTotalPointsByChild(childId);
    }
    notifyListeners();
  }

  int getChildTotalPoints(int childId) {
    return _totalPointsCache[childId] ?? 0;
  }
}
