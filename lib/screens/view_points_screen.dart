import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../constants/app_colors.dart';
import '../providers/points_provider.dart';
import '../providers/children_provider.dart';
import '../models/point.dart';
import '../utils/logger.dart';
import 'add_points_screen.dart';

class ViewPointsScreen extends StatefulWidget {
  const ViewPointsScreen({super.key});

  @override
  State<ViewPointsScreen> createState() => _ViewPointsScreenState();
}

class _ViewPointsScreenState extends State<ViewPointsScreen> {
  String? _selectedGroup;
  bool _isLoading = true;
  String _searchQuery = "";
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final pointsProvider =
          Provider.of<PointsProvider>(context, listen: false);
      final childrenProvider =
          Provider.of<ChildrenProvider>(context, listen: false);

      // Load both points and children data to ensure they're in sync
      await pointsProvider.fetchPoints();
      await childrenProvider.fetchAndSetChildren();
    } catch (e) {
      Logger.error('Error loading points data', e);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final pointsProvider = Provider.of<PointsProvider>(context);
    final childrenProvider = Provider.of<ChildrenProvider>(context);

    // Get points and filter them
    List<Point> allPoints = pointsProvider.points;
    final groups = childrenProvider.groups;

    // First filter by group if selected
    List<Point> filteredPoints = _selectedGroup == null
        ? allPoints
        : allPoints
            .where((point) => point.groupName == _selectedGroup)
            .toList();

    // Then filter by search query if any
    if (_searchQuery.isNotEmpty) {
      filteredPoints = filteredPoints.where((point) {
        return point.childName
                .toLowerCase()
                .contains(_searchQuery.toLowerCase()) ||
            (point.reason?.toLowerCase().contains(_searchQuery.toLowerCase()) ??
                false);
      }).toList();
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Manage Points'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _loadData,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddPointsScreen()),
          ).then((_) => _loadData());
        },
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Search and filter bar
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.white,
                  child: Column(
                    children: [
                      // Search bar
                      TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search by name or reason...',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    setState(() {
                                      _searchController.clear();
                                      _searchQuery = '';
                                    });
                                  },
                                )
                              : null,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              vertical: 8, horizontal: 16),
                        ),
                        onChanged: (value) {
                          setState(() {
                            _searchQuery = value;
                          });
                        },
                      ),

                      const SizedBox(height: 12),

                      // Group filter
                      if (groups.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.only(top: 4),
                          width: double.infinity,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                const Text(
                                  'Filter by: ',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w500,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // All groups option
                                FilterChip(
                                  label: const Text('All Groups'),
                                  selected: _selectedGroup == null,
                                  onSelected: (selected) {
                                    if (selected) {
                                      setState(() => _selectedGroup = null);
                                    }
                                  },
                                  backgroundColor: Colors.grey.shade100,
                                  selectedColor:
                                      AppColors.primary.withOpacity(0.2),
                                  checkmarkColor: AppColors.primary,
                                  labelStyle: TextStyle(
                                    color: _selectedGroup == null
                                        ? AppColors.primary
                                        : Colors.black,
                                    fontWeight: _selectedGroup == null
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                                const SizedBox(width: 8),

                                // Group filter chips
                                ...groups.map((group) {
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: FilterChip(
                                      label: Text(group),
                                      selected: _selectedGroup == group,
                                      onSelected: (selected) {
                                        setState(() => _selectedGroup =
                                            selected ? group : null);
                                      },
                                      backgroundColor: Colors.grey.shade100,
                                      selectedColor:
                                          AppColors.primary.withOpacity(0.2),
                                      checkmarkColor: AppColors.primary,
                                      labelStyle: TextStyle(
                                        color: _selectedGroup == group
                                            ? AppColors.primary
                                            : Colors.black,
                                        fontWeight: _selectedGroup == group
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                      ),
                                    ),
                                  );
                                }),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // Points list
                Expanded(
                  child: filteredPoints.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.star_border,
                                size: 64,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _searchQuery.isNotEmpty ||
                                        _selectedGroup != null
                                    ? 'No points match your search'
                                    : 'No points found',
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 8),
                              ElevatedButton.icon(
                                onPressed: () {
                                  // Clear filters if any
                                  if (_searchQuery.isNotEmpty ||
                                      _selectedGroup != null) {
                                    setState(() {
                                      _searchQuery = '';
                                      _searchController.clear();
                                      _selectedGroup = null;
                                    });
                                  } else {
                                    // Otherwise go to add points
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (context) =>
                                              const AddPointsScreen()),
                                    ).then((_) => _loadData());
                                  }
                                },
                                icon: Icon(_searchQuery.isNotEmpty ||
                                        _selectedGroup != null
                                    ? Icons.clear_all
                                    : Icons.add),
                                label: Text(_searchQuery.isNotEmpty ||
                                        _selectedGroup != null
                                    ? 'Clear Filters'
                                    : 'Add Points'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: filteredPoints.length,
                          itemBuilder: (ctx, index) {
                            final point = filteredPoints[index];
                            return _buildPointItem(context, point);
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildPointItem(BuildContext context, Point point) {
    final dateFormatted =
        DateFormat('MMM d, yyyy').format(DateTime.parse(point.date));

    return Dismissible(
      key: Key('point-${point.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(
          Icons.delete,
          color: Colors.white,
        ),
      ),
      confirmDismiss: (direction) async {
        return await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Confirm Deletion'),
            content:
                const Text('Are you sure you want to delete these points?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
        );
      },
      onDismissed: (direction) async {
        try {
          await Provider.of<PointsProvider>(context, listen: false)
              .deletePoints(point.id!);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${point.amount} points deleted'),
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 2),
              ),
            );
          }
        } catch (e) {
          Logger.error('Error deleting points', e);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error: $e'),
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 2),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      },
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: InkWell(
          onTap: () => _showPointDetails(context, point),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Child initial in avatar
                CircleAvatar(
                  backgroundColor: AppColors.primaryLight.withOpacity(0.2),
                  child: Text(
                    point.childName.isNotEmpty
                        ? point.childName[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Point details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        point.childName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        '${point.groupName} • $dateFormatted',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      if (point.reason != null && point.reason!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            point.reason!,
                            style: const TextStyle(
                              fontSize: 14,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
                ),
                // Points amount
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: point.amount > 0
                        ? AppColors.success.withOpacity(0.1)
                        : AppColors.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    point.amount.toString(),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: point.amount > 0
                          ? AppColors.success
                          : AppColors.error,
                    ),
                  ),
                ),
                // Edit button
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  color: Colors.grey.shade600,
                  onPressed: () => _editPoint(context, point),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showPointDetails(BuildContext context, Point point) {
    final dateFormatted =
        DateFormat('MMMM d, yyyy').format(DateTime.parse(point.date));

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.primaryLight.withOpacity(0.2),
                  radius: 24,
                  child: Text(
                    point.childName.isNotEmpty
                        ? point.childName[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                      fontSize: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        point.childName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
                      Text(
                        point.groupName,
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: point.amount > 0
                        ? AppColors.success.withOpacity(0.1)
                        : AppColors.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '${point.amount > 0 ? "+" : ""}${point.amount}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 22,
                      color: point.amount > 0
                          ? AppColors.success
                          : AppColors.error,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildDetailRow('Date', dateFormatted),
            if (point.reason != null && point.reason!.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'Reason',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                point.reason!,
                style: const TextStyle(fontSize: 16),
              ),
            ],
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _editPoint(context, point);
                  },
                  icon: const Icon(Icons.edit),
                  label: const Text('Edit'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _confirmDeletePoint(context, point);
                  },
                  icon: const Icon(Icons.delete),
                  label: const Text('Delete'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      children: [
        Text(
          '$label:',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(width: 16),
        Text(
          value,
          style: const TextStyle(fontSize: 16),
        ),
      ],
    );
  }

  // Fixed: Made async operation properly handle BuildContext
  void _editPoint(BuildContext context, Point point) {
    final pointsController =
        TextEditingController(text: point.amount.toString());
    final reasonController = TextEditingController(text: point.reason ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Points'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Child: ${point.childName}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: pointsController,
              decoration: const InputDecoration(
                labelText: 'Points',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason (Optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final amount = int.tryParse(pointsController.text) ?? 0;
              final reason = reasonController.text.trim();

              // Store context references before async gap
              final pointsProvider =
                  Provider.of<PointsProvider>(context, listen: false);
              final navigatorContext = Navigator.of(ctx);
              final scaffoldMsgr = ScaffoldMessenger.of(context);
              final isContextMounted = context.mounted;

              try {
                await pointsProvider.updatePoints(
                    point.id!, amount, reason.isEmpty ? null : reason);

                // Use stored references after async operation
                if (isContextMounted && context.mounted) {
                  navigatorContext.pop();
                  scaffoldMsgr.showSnackBar(
                    const SnackBar(
                      content: Text('Points updated successfully'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              } catch (e) {
                Logger.error('Error updating points', e);

                // Use stored references after async operation
                if (isContextMounted && context.mounted) {
                  navigatorContext.pop();
                  scaffoldMsgr.showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      behavior: SnackBarBehavior.floating,
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  // Fixed: Made async operation properly handle BuildContext
  void _confirmDeletePoint(BuildContext context, Point point) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Deletion'),
        content: const Text('Are you sure you want to delete these points?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              // Store context references before async gap
              final pointsProvider =
                  Provider.of<PointsProvider>(context, listen: false);
              final navigatorContext = Navigator.of(ctx);
              final scaffoldMsgr = ScaffoldMessenger.of(context);
              final isContextMounted = context.mounted;

              try {
                await pointsProvider.deletePoints(point.id!);

                // Use stored references after async operation
                if (isContextMounted && context.mounted) {
                  navigatorContext.pop();
                  scaffoldMsgr.showSnackBar(
                    SnackBar(
                      content: Text('${point.amount} points deleted'),
                      behavior: SnackBarBehavior.floating,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              } catch (e) {
                Logger.error('Error deleting points', e);

                // Use stored references after async operation
                if (isContextMounted && context.mounted) {
                  navigatorContext.pop();
                  scaffoldMsgr.showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      behavior: SnackBarBehavior.floating,
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}
