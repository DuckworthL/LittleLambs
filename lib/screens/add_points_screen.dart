import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_colors.dart';
import '../providers/children_provider.dart';
import '../providers/points_provider.dart';
import '../models/child.dart';
import '../utils/logger.dart';

class AddPointsScreen extends StatefulWidget {
  final int? selectedChildId;

  const AddPointsScreen({super.key, this.selectedChildId});

  @override
  State<AddPointsScreen> createState() => _AddPointsScreenState();
}

class _AddPointsScreenState extends State<AddPointsScreen> {
  final TextEditingController _pointsController =
      TextEditingController(text: '1');
  final TextEditingController _reasonController = TextEditingController();

  String? _selectedGroup;
  int? _selectedChildId;
  bool _isQuickMode = false;

  // Loading state
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedChildId = widget.selectedChildId;
    _loadData();
  }

  @override
  void dispose() {
    _pointsController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      // Load children & points data
      final childrenProvider =
          Provider.of<ChildrenProvider>(context, listen: false);
      final pointsProvider =
          Provider.of<PointsProvider>(context, listen: false);

      await childrenProvider.fetchAndSetChildren();
      await pointsProvider.fetchPoints();
      await pointsProvider.loadAllChildrenTotalPoints();

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      Logger.error('Error loading data', e);

      if (mounted) {
        setState(() => _isLoading = false);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final childrenProvider = Provider.of<ChildrenProvider>(context);
    final pointsProvider = Provider.of<PointsProvider>(context);

    final children = childrenProvider.children;
    final groups = childrenProvider.groups;

    // Filter children by selected group
    final filteredChildren = _selectedGroup != null
        ? children.where((child) => child.groupName == _selectedGroup).toList()
        : children;

    // Get selected child if any
    final selectedChild = _selectedChildId != null
        ? children.firstWhere((child) => child.id == _selectedChildId,
            orElse: () => Child(id: 0, name: '', age: 0, groupName: ''))
        : null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_isQuickMode ? 'Quick Add Points' : 'Add Points'),
        backgroundColor: AppColors.primary,
        elevation: 0,
        foregroundColor: Colors.white,
        actions: [
          // Toggle quick mode
          IconButton(
            icon: Icon(_isQuickMode ? Icons.edit : Icons.bolt),
            tooltip: _isQuickMode ? 'Regular Mode' : 'Quick Mode',
            onPressed: () {
              setState(() {
                _isQuickMode = !_isQuickMode;
              });
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _isQuickMode
              ? _buildQuickMode(filteredChildren, groups, pointsProvider)
              : _buildRegularMode(
                  filteredChildren, groups, selectedChild, pointsProvider),
    );
  }

  Widget _buildRegularMode(List<Child> filteredChildren, List<String> groups,
      Child? selectedChild, PointsProvider pointsProvider) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Group filter
          if (groups.isNotEmpty) ...[
            const Text(
              'Filter by Group',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedGroup,
                  isExpanded: true,
                  hint: const Text('All Groups'),
                  items: [
                    const DropdownMenuItem<String>(
                      value: null,
                      child: Text('All Groups'),
                    ),
                    for (final group in groups)
                      DropdownMenuItem<String>(
                        value: group,
                        child: Text(group),
                      ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedGroup = value;
                      // Clear selected child if changing groups
                      if (_selectedChildId != null) {
                        final childStillInGroup = filteredChildren
                            .any((c) => c.id == _selectedChildId);
                        if (!childStillInGroup) {
                          _selectedChildId = null;
                        }
                      }
                    });
                  },
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],

          // Child selection
          const Text(
            'Select Child',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),

          if (filteredChildren.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Icon(
                      Icons.people_outline,
                      size: 48,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _selectedGroup != null
                          ? 'No children in ${_selectedGroup!} group'
                          : 'No children added yet',
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          else
            Container(
              height: 120,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 4),
                scrollDirection: Axis.horizontal,
                itemCount: filteredChildren.length,
                itemBuilder: (ctx, index) {
                  final child = filteredChildren[index];
                  final isSelected = child.id == _selectedChildId;
                  final totalPoints =
                      pointsProvider.getChildTotalPoints(child.id!);

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedChildId = child.id;
                      });
                    },
                    child: Container(
                      width: 100,
                      margin: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primaryLight.withOpacity(0.2)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primary
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircleAvatar(
                            backgroundColor:
                                AppColors.primaryLight.withOpacity(0.2),
                            radius: 24,
                            child: Text(
                              child.name.isNotEmpty
                                  ? child.name[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                                fontSize: 20,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            child.name,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            '$totalPoints pts',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

          const SizedBox(height: 24),

          // Points and reason
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Points input
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Points',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: TextField(
                        controller: _pointsController,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          hintText: 'Points',
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),

              // Reason input
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Reason (Optional)',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: TextField(
                        controller: _reasonController,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          hintText: 'Reason for points',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 32),

          // Add button
          Center(
            child: ElevatedButton(
              onPressed: _selectedChildId == null
                  ? null
                  : () => _addPoints(pointsProvider),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                disabledBackgroundColor: Colors.grey.shade400,
              ),
              child: const Text(
                'Add Points',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickMode(List<Child> filteredChildren, List<String> groups,
      PointsProvider pointsProvider) {
    return Column(
      children: [
        // Top control bar
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.white,
          child: Row(
            children: [
              // Group filter
              if (groups.isNotEmpty)
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedGroup,
                        isExpanded: true,
                        hint: const Text('All Groups'),
                        items: [
                          const DropdownMenuItem<String>(
                            value: null,
                            child: Text('All Groups'),
                          ),
                          for (final group in groups)
                            DropdownMenuItem<String>(
                              value: group,
                              child: Text(group),
                            ),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _selectedGroup = value;
                          });
                        },
                      ),
                    ),
                  ),
                ),
              const SizedBox(width: 12),

              // Points & reason
              Container(
                width: 80,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: TextField(
                  controller: _pointsController,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Points',
                  ),
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 140,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: TextField(
                  controller: _reasonController,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Reason',
                  ),
                ),
              ),
            ],
          ),
        ),

        // Children grid
        Expanded(
          child: filteredChildren.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.people_outline,
                        size: 64,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _selectedGroup != null
                            ? 'No children in ${_selectedGroup!} group'
                            : 'No children added yet',
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 0.8,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: filteredChildren.length,
                  itemBuilder: (ctx, index) {
                    final child = filteredChildren[index];
                    final totalPoints =
                        pointsProvider.getChildTotalPoints(child.id!);

                    return InkWell(
                      onTap: () => _quickAddPoints(child.id!, pointsProvider),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircleAvatar(
                              backgroundColor:
                                  AppColors.primaryLight.withOpacity(0.2),
                              radius: 32,
                              child: Text(
                                child.name.isNotEmpty
                                    ? child.name[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                  fontSize: 24,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              child.name,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$totalPoints points',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Future<void> _addPoints(PointsProvider pointsProvider) async {
    if (_selectedChildId == null) return;

    // Validate points input
    final points = int.tryParse(_pointsController.text.trim());
    if (points == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid number of points'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Get reason if any
    final reason = _reasonController.text.trim();

    try {
      await pointsProvider.addPoints(
          _selectedChildId!, points, reason.isEmpty ? null : reason);

      if (!mounted) return;

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added $points points'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.success,
        ),
      );

      // Reset form
      _pointsController.text = '1';
      _reasonController.clear();
      setState(() {
        _selectedChildId = null;
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _quickAddPoints(
      int childId, PointsProvider pointsProvider) async {
    // Validate points input
    final points = int.tryParse(_pointsController.text.trim());
    if (points == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid number of points'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Get reason if any
    final reason = _reasonController.text.trim();

    try {
      await pointsProvider.addPoints(
          childId, points, reason.isEmpty ? null : reason);

      if (!mounted) return;

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added $points points'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
