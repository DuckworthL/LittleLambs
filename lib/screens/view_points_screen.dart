import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/children_provider.dart';
import '../providers/points_provider.dart';
import '../models/child.dart';

class ViewPointsScreen extends StatefulWidget {
  const ViewPointsScreen({super.key});

  @override
  State<ViewPointsScreen> createState() => _ViewPointsScreenState();
}

class _ViewPointsScreenState extends State<ViewPointsScreen> {
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadData();
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
    final pointsProvider = Provider.of<PointsProvider>(context);

    // Sort children by points (highest to lowest)
    final children = List<Child>.from(childrenProvider.children);
    children.sort((a, b) {
      final pointsA = pointsProvider.getChildTotalPoints(a.id!);
      final pointsB = pointsProvider.getChildTotalPoints(b.id!);
      return pointsB.compareTo(pointsA); // Descending order
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Points Leaderboard'),
      ),
      body: children.isEmpty
          ? const Center(
              child: Text('No children added yet'),
            )
          : ListView.builder(
              itemCount: children.length,
              itemBuilder: (context, index) {
                final child = children[index];
                final points = pointsProvider.getChildTotalPoints(child.id!);

                return Card(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: _getPositionColor(index),
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                    title: Text(
                      child.name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text('${child.groupName} • Age: ${child.age}'),
                    trailing: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$points pts',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    onTap: () => _showPointsHistory(context, child),
                  ),
                );
              },
            ),
    );
  }

  Color _getPositionColor(int position) {
    if (position == 0) return Colors.amber; // Gold
    if (position == 1) return Colors.grey.shade400; // Silver
    if (position == 2) return Colors.brown.shade300; // Bronze
    return Colors.blue; // Everyone else
  }

  void _showPointsHistory(BuildContext context, Child child) async {
    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    // Load points data for this child
    try {
      final pointsProvider =
          Provider.of<PointsProvider>(context, listen: false);
      await pointsProvider.loadPointsForChild(child.id!);

      // Dismiss loading dialog
      if (context.mounted) Navigator.of(context).pop();

      // Show history dialog
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text('${child.name}\'s Points History'),
            content: SizedBox(
              width: double.maxFinite,
              height: 300, // Set a fixed height to avoid overflow
              child: _buildPointsHistoryList(context, child.id!),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      // Dismiss loading dialog on error
      if (context.mounted) Navigator.of(context).pop();

      // Show error message
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading points: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildPointsHistoryList(BuildContext context, int childId) {
    final pointsProvider = Provider.of<PointsProvider>(context);
    final pointsList = pointsProvider.pointsData[childId] ?? [];

    if (pointsList.isEmpty) {
      return const Center(
        child: Text('No points history yet'),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      itemCount: pointsList.length,
      itemBuilder: (context, index) {
        final point = pointsList[index];
        final date =
            DateFormat('MMM d, yyyy').format(DateTime.parse(point.date));

        return ListTile(
          leading: CircleAvatar(
            backgroundColor: Colors.green,
            child: Text(
              '+${point.amount}',
              style: const TextStyle(color: Colors.white),
            ),
          ),
          title: Text(point.reason ?? 'Points added'),
          subtitle: Text(date),
        );
      },
    );
  }
}
