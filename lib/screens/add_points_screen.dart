import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/children_provider.dart';
import '../providers/points_provider.dart';
import '../models/child.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';

class AddPointsScreen extends StatefulWidget {
  const AddPointsScreen({super.key});

  @override
  State<AddPointsScreen> createState() => _AddPointsScreenState();
}

class _AddPointsScreenState extends State<AddPointsScreen> with TickerProviderStateMixin {
  TabController? _tabController;
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
    _tabController?.dispose();
    super.dispose();
  }
  
  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    try {
      final childrenProvider = Provider.of<ChildrenProvider>(context, listen: false);
      final pointsProvider = Provider.of<PointsProvider>(context, listen: false);
      
      await childrenProvider.fetchAndSetChildren();
      
      final childIds = childrenProvider.children.map((c) => c.id!).toList();
      
      try {
        await pointsProvider.loadAllChildrenTotalPoints(childIds);
      } catch (e) {
        if (kDebugMode) {
          print('Error loading points: $e');
        }
      }
      
      _tabController?.dispose();
      
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
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Loading...'),
          backgroundColor: AppColors.accent,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        body: const Center(
          child: CircularProgressIndicator(color: AppColors.accent),
        ),
      );
    }
    
    if (_hasError) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Error'),
          backgroundColor: AppColors.error,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 60, color: AppColors.error),
                const SizedBox(height: 16),
                Text(
                  _errorMessage,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyMedium,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _loadData,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    
    final childrenProvider = Provider.of<ChildrenProvider>(context);
    
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Add Points'),
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: childrenProvider.groups.isNotEmpty && _tabController != null
            ? PreferredSize(
                preferredSize: const Size.fromHeight(48),
                child: Container(
                  height: 40,
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    indicatorSize: TabBarIndicatorSize.tab,
                    indicator: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    labelColor: AppColors.accent,
                    unselectedLabelColor: Colors.white,
                    labelStyle: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                    unselectedLabelStyle: const TextStyle(
                      fontWeight: FontWeight.normal,
                      fontSize: 12,
                    ),
                    tabs: childrenProvider.groups
                        .map((group) => Tab(text: group))
                        .toList(),
                  ),
                ),
              )
            : null,
      ),
      body: childrenProvider.groups.isEmpty
          ? const _EmptyState(message: 'No groups defined yet. Add children first.')
          : _tabController == null
              ? const _EmptyState(message: 'Error initializing tabs')
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

class _EmptyState extends StatelessWidget {
  final String message;
  
  const _EmptyState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.stars_outlined,
              size: 60,
              color: AppColors.textLight,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: const TextStyle(
                fontSize: 16,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
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
      return const _EmptyState(message: 'No children in this group');
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
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
    final totalPoints = pointsProvider.getChildTotalPoints(child.id!);
    
        return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Child info header
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.primaryLight,
                  child: Text(
                    child.name.isNotEmpty ? child.name[0].toUpperCase() : 'C',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        child.name,
                        style: AppTextStyles.heading3.copyWith(fontSize: 18),
                      ),
                      Text(
                        'Age: ${child.age} • ${child.groupName}',
                        style: AppTextStyles.bodySmall,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.accentLight.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.emoji_events,
                        size: 16,
                        color: AppColors.accent,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$totalPoints pts',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: AppColors.accent,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Points buttons
          Container(
            height: 84,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
            ),
            child: Column(
              children: [
                const Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.add_circle,
                      size: 14,
                      color: AppColors.textSecondary,
                    ),
                    SizedBox(width: 4),
                    Text(
                      'Add Points:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildPointButton(context, 5, child.id!),
                    _buildPointButton(context, 10, child.id!),
                    _buildPointButton(context, 15, child.id!),
                    _buildPointButton(context, 20, child.id!),
                    _buildPointButton(context, 30, child.id!),
                    _buildCustomPointButton(context, child.id!),
                  ],
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

        _showPointsAddedSnackbar(context, points);
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: EdgeInsets.zero,
        minimumSize: const Size(42, 36),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: Text(
        '+$points',
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildCustomPointButton(BuildContext context, int childId) {
    return ElevatedButton(
      onPressed: () => _showCustomPointsDialog(context, childId),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.grey.shade200,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        padding: EdgeInsets.zero,
        minimumSize: const Size(42, 36),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: const Icon(
        Icons.add,
        size: 20,
      ),
    );
  }

  void _showCustomPointsDialog(BuildContext context, int childId) {
    final controller = TextEditingController();
    final reasonController = TextEditingController();
    bool isValid = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text(
              'Add Custom Points',
              style: AppTextStyles.heading3,
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Points',
                    hintText: 'Enter points',
                    floatingLabelStyle: const TextStyle(color: AppColors.accent),
                    focusedBorder: const UnderlineInputBorder(
                      borderSide: BorderSide(color: AppColors.accent),
                    ),
                    errorText: controller.text.isNotEmpty &&
                            (int.tryParse(controller.text) ?? 0) <= 0
                        ? 'Please enter a positive number'
                        : null,
                  ),
                  onChanged: (value) {
                    final points = int.tryParse(value) ?? 0;
                    setState(() {
                      isValid = points > 0;
                    });
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: reasonController,
                  decoration: const InputDecoration(
                    labelText: 'Reason (optional)',
                    hintText: 'Why are points being added?',
                    floatingLabelStyle: TextStyle(color: AppColors.accent),
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: AppColors.accent),
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                },
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
              ElevatedButton(
                onPressed: isValid
                    ? () {
                        final points = int.parse(controller.text);
                        final reason = reasonController.text.isEmpty
                            ? null
                            : reasonController.text;

                        Provider.of<PointsProvider>(context, listen: false)
                            .addPoints(childId, points, reason: reason);

                        Navigator.of(ctx).pop();
                        _showPointsAddedSnackbar(context, points);
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  disabledBackgroundColor: Colors.grey.shade300,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Add'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showPointsAddedSnackbar(BuildContext context, int points) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.check_circle,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Text('Added $points points'),
          ],
        ),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 1),
      ),
    );
  }
}
