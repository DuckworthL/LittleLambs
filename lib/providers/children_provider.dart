import 'package:flutter/foundation.dart';
import '../models/child.dart';
import '../helpers/database_helper.dart';

class ChildrenProvider with ChangeNotifier {
  List<Child> _children = [];
  List<String> _groups = [];

  List<Child> get children => _children;
  List<String> get groups => _groups;

  Future<void> fetchAndSetChildren() async {
    try {
      final childrenData = await DatabaseHelper.instance.queryAllChildren();
      _children = childrenData.map((item) {
        return Child(
          id: item['id'] as int,
          name: item['name'] as String,
          age: item['age'] as int,
          groupName: item['groupName'] as String,
          notes: item['notes'] as String?,
        );
      }).toList();

      await _fetchGroups();

      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching children: $e');
      }
      rethrow;
    }
  }

  Future<void> _fetchGroups() async {
    try {
      _groups = await DatabaseHelper.instance.queryAllGroups();
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching groups: $e');
      }
      _groups = [];
    }
  }

  Future<void> addChild(
      String name, int age, String groupName, String? notes) async {
    try {
      final childData = {
        'name': name,
        'age': age,
        'groupName': groupName,
        'notes': notes,
      };

      final id = await DatabaseHelper.instance.insertChild(childData);

      final newChild = Child(
        id: id,
        name: name,
        age: age,
        groupName: groupName,
        notes: notes,
      );

      _children.add(newChild);

      // Update groups list if needed
      if (!_groups.contains(groupName)) {
        _groups.add(groupName);
        _groups.sort();
      }

      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('Error adding child: $e');
      }
      rethrow;
    }
  }

  Future<void> updateChild(
      int id, String name, int age, String groupName, String? notes) async {
    try {
      final childData = {
        'name': name,
        'age': age,
        'groupName': groupName,
        'notes': notes,
      };

      await DatabaseHelper.instance.updateChild(id, childData);

      final childIndex = _children.indexWhere((child) => child.id == id);
      if (childIndex >= 0) {
        _children[childIndex] = Child(
          id: id,
          name: name,
          age: age,
          groupName: groupName,
          notes: notes,
        );
      }

      // Update groups list if needed
      if (!_groups.contains(groupName)) {
        _groups.add(groupName);
        _groups.sort();
      }

      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('Error updating child: $e');
      }
      rethrow;
    }
  }

  Future<void> deleteChild(int id) async {
    try {
      await DatabaseHelper.instance.deleteChild(id);

      _children.removeWhere((child) => child.id == id);

      // Refresh groups in case the last child in a group was deleted
      await _fetchGroups();

      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('Error deleting child: $e');
      }
      rethrow;
    }
  }

  Future<void> addGroup(String groupName) async {
    if (_groups.contains(groupName)) {
      return;
    }

    _groups.add(groupName);
    _groups.sort();

    notifyListeners();
  }

  Future<void> updateGroup(String oldName, String newName) async {
    try {
      await DatabaseHelper.instance.updateGroup(oldName, newName);

      // Update local state
      final groupIndex = _groups.indexOf(oldName);
      if (groupIndex >= 0) {
        _groups[groupIndex] = newName;
        _groups.sort();
      }

      // Update children in this group
      for (int i = 0; i < _children.length; i++) {
        if (_children[i].groupName == oldName) {
          _children[i] = Child(
            id: _children[i].id,
            name: _children[i].name,
            age: _children[i].age,
            groupName: newName,
            notes: _children[i].notes,
          );
        }
      }

      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('Error updating group: $e');
      }
      rethrow;
    }
  }

  Future<bool> deleteGroup(String groupName) async {
    try {
      // Check if there are children in this group
      final childCount =
          await DatabaseHelper.instance.countChildrenInGroup(groupName);

      if (childCount > 0) {
        // Ask for confirmation before deleting
        return false;
      }

      await DatabaseHelper.instance.deleteGroup(groupName);

      // Remove the group and any children in it from local state
      _groups.remove(groupName);
      _children.removeWhere((child) => child.groupName == groupName);

      notifyListeners();
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error deleting group: $e');
      }
      return false;
    }
  }

  List<Child> getChildrenByGroup(String groupName) {
    return _children.where((child) => child.groupName == groupName).toList();
  }

  Child? getChildById(int id) {
    try {
      return _children.firstWhere((child) => child.id == id);
    } catch (e) {
      return null;
    }
  }
}
