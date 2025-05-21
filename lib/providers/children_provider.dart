import 'package:flutter/foundation.dart';
import '../models/child.dart';
import '../helpers/database_helper.dart';

class ChildrenProvider with ChangeNotifier {
  List<Child> _children = [];
  List<String> _groups = [];

  List<Child> get children => _children;
  List<String> get groups => _groups;

  ChildrenProvider() {
    fetchAndSetChildren();
  }

  Future<void> fetchAndSetChildren() async {
    final childrenData = await DatabaseHelper.instance.queryAllChildren();
    _children = childrenData.map((item) => Child.fromMap(item)).toList();

    // Extract unique groups
    Set<String> groupSet = {};
    for (var child in _children) {
      groupSet.add(child.groupName);
    }
    _groups = groupSet.toList()..sort();

    notifyListeners();
  }

  Future<void> addChild(Child child) async {
    final id = await DatabaseHelper.instance.insertChild(child.toMap());
    final newChild = Child(
      id: id,
      name: child.name,
      age: child.age,
      notes: child.notes,
      groupName: child.groupName,
    );

    _children.add(newChild);

    // Update groups list if needed
    if (!_groups.contains(child.groupName)) {
      _groups.add(child.groupName);
      _groups.sort();
    }

    notifyListeners();
  }

  Future<void> updateChild(Child child) async {
    await DatabaseHelper.instance.updateChild(child.toMap());

    final childIndex = _children.indexWhere((c) => c.id == child.id);
    if (childIndex >= 0) {
      _children[childIndex] = child;
    }

    // Update groups list if needed
    if (!_groups.contains(child.groupName)) {
      _groups.add(child.groupName);
      _groups.sort();
    }

    notifyListeners();
  }

  Future<void> deleteChild(int id) async {
    await DatabaseHelper.instance.deleteChild(id);
    _children.removeWhere((child) => child.id == id);

    // Recalculate groups
    Set<String> groupSet = {};
    for (var child in _children) {
      groupSet.add(child.groupName);
    }
    _groups = groupSet.toList()..sort();

    notifyListeners();
  }

  List<Child> getChildrenByGroup(String groupName) {
    return _children.where((child) => child.groupName == groupName).toList();
  }
}
