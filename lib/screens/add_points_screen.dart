import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/children_provider.dart';
import '../providers/points_provider.dart';
import '../models/child.dart';

class AddPointsScreen extends StatefulWidget {
  const AddPointsScreen({super.key});

  @override
  State<AddPointsScreen> createState() => _AddPointsScreenState();
}

class _AddPointsScreenState extends State<AddPointsScreen>
    with TickerProviderStateMixin {
  // Changed from SingleTickerProviderStateMixin
  TabController? _tabController; // Make nullable
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _tabController?.dispose(); // Dispose controller when done
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final childrenProvider =
          Provider.of<ChildrenProvider>(context, listen: false);
      final pointsProvider =
          Provider.of<PointsProvider>(context, listen: false);

      await childrenProvider.fetchAndSetChildren();

      // Load total points for all children
      final childIds = childrenProvider.children.map((c) => c.id!).toList();

      try {
        await pointsProvider.loadAllChildrenTotalPoints(childIds);
      } catch (e) {
        if (kDebugMode) {
          print('Error loading points: $e');
        }
        // Continue even if points loading fails
      }

      // Dispose previous controller if it exists
      _tabController?.dispose();

      // Only create controller if we have groups
      if (childrenProvider.groups.isNotEmpty) {
        _tabController = TabController(
          length: childrenProvider.groups.length,
          vsync: this,
        );
      }

      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = 'Error loading data: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Loading...'),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_hasError) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Error'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 60, color: Colors.red),
              const SizedBox(height: 16),
              Text(_errorMessage),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadData,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final childrenProvider = Provider.of<ChildrenProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Points'),
        bottom: childrenProvider.groups.isNotEmpty && _tabController != null
            ? TabBar(
                controller: _tabController,
                tabs: childrenProvider.groups
                    .map((group) => Tab(text: group))
                    .toList(),
                isScrollable: true,
              )
            : null,
      ),
      body: childrenProvider.groups.isEmpty
          ? const Center(
              child: Text('No groups defined yet. Add children first.'),
            )
          : _tabController == null
              ? const Center(child: Text('Error initializing tabs'))
              : TabBarView(
                  controller: _tabController,
                  children: childrenProvider.groups.map((group) {
                    final children = childrenProvider.getChildrenByGroup(group);
                    return PointsChildList(
                      children: children,
                    );
                  }).toList(),
                ),
    );
  }
}

class PointsChildList extends StatelessWidget {
  final List<Child> children;

  const PointsChildList({
    super.key,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) {
      return const Center(
        child: Text('No children in this group'),
      );
    }

    return ListView.builder(
      itemCount: children.length,
      itemBuilder: (context, index) {
        return PointsChildListItem(
          child: children[index],
        );
      },
    );
  }
}

class PointsChildListItem extends StatelessWidget {
  final Child child;

  const PointsChildListItem({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final pointsProvider = Provider.of<PointsProvider>(context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: Column(
        children: [
          ListTile(
            leading: CircleAvatar(
              child: Text(
                child.name.isNotEmpty
                    ? child.name.substring(0, 1).toUpperCase()
                    : 'C',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            title: Text(
              child.name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text('Age: ${child.age} • Group: ${child.groupName}'),
            trailing: Text(
              'Total: ${pointsProvider.getChildTotalPoints(child.id!)}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildPointButton(context, 5, child.id!),
                _buildPointButton(context, 10, child.id!),
                _buildPointButton(context, 15, child.id!),
                _buildPointButton(context, 20, child.id!),
                _buildPointButton(context, 30, child.id!),
                IconButton(
                  icon: const Icon(Icons.add_circle),
                  color: Colors.purple,
                  onPressed: () => _showCustomPointsDialog(context, child.id!),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPointButton(BuildContext context, int points, int childId) {
    return ElevatedButton(
      onPressed: () {
        Provider.of<PointsProvider>(context, listen: false)
            .addPoints(childId, points);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Added $points points'),
            duration: const Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        minimumSize: const Size(40, 36),
      ),
      child: Text('+$points'),
    );
  }

  void _showCustomPointsDialog(BuildContext context, int childId) {
    final controller = TextEditingController();
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Custom Points'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Points',
              ),
            ),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason (optional)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
            },
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                final points = int.tryParse(controller.text) ?? 0;
                final reason = reasonController.text.isEmpty
                    ? null
                    : reasonController.text;
                if (points > 0) {
                  Provider.of<PointsProvider>(context, listen: false)
                      .addPoints(childId, points, reason: reason);
                  Navigator.of(ctx).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Added $points points'),
                      duration: const Duration(seconds: 1),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}
