import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';
import '../providers/attendance_provider.dart';
import '../providers/children_provider.dart';
import '../widgets/menu_card.dart';
import 'monthly_report_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late String _formattedDate;
  late String _formattedTime;
  late Timer _timer;
  bool _isLoading = false;
  int _studentCount = 0;
  int _groupCount = 0;
  String? _nextServiceDate;
  Map<String, dynamic>? _quickStats;

  @override
  void initState() {
    super.initState();
    _updateTimeDate();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _updateTimeDate();
    });
    _loadData();
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  void _updateTimeDate() {
    final now = DateTime.now();
    setState(() {
      _formattedDate = DateFormat('EEEE, MMMM d, yyyy').format(now);
      _formattedTime = DateFormat('h:mm a').format(now);
    });
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final childrenProvider =
          Provider.of<ChildrenProvider>(context, listen: false);
      final attendanceProvider =
          Provider.of<AttendanceProvider>(context, listen: false);

      // Get next service date
      final nextServiceDate = attendanceProvider.currentServiceDate;

      // Fetch children data
      await childrenProvider.fetchAndSetChildren();

      // Get groups
      final groupNames = childrenProvider.children
          .map((child) => child.groupName)
          .toSet() // Get unique groups
          .toList();

      // Get quick stats - calculate for the past 30 days
      final now = DateTime.now();
      final thirtyDaysAgo = now.subtract(const Duration(days: 30));
      final startDate = DateFormat('yyyy-MM-dd').format(thirtyDaysAgo);
      final endDate = DateFormat('yyyy-MM-dd').format(now);

      // Get student IDs
      final studentIds = childrenProvider.children
          .map((child) => child.id)
          .whereType<int>() // Only include non-null IDs
          .toList();

      Map<int, int> attendanceCounts = {};
      if (studentIds.isNotEmpty) {
        attendanceCounts = await attendanceProvider.getAttendanceCountByChild(
            studentIds, startDate, endDate);
      }

      // Calculate average attendance
      int totalAttendances = 0;
      attendanceCounts.forEach((_, count) => totalAttendances += count);

      // Get the number of service days in the period
      final daysInPeriod = now.difference(thirtyDaysAgo).inDays;
      int serviceDays = 0;
      // Roughly 8 service days in 30 days (Saturdays and Sundays)
      serviceDays = (daysInPeriod / 7 * 2).round();

      final avgAttendance = studentIds.isNotEmpty && serviceDays > 0
          ? (totalAttendances / (studentIds.length * serviceDays) * 100).round()
          : 0;

      // Get the most recently attended service
      String? lastServiceDate;
      try {
        // This would need implementation in your AttendanceProvider
        // For now, just use a placeholder approach
        lastServiceDate = _getMostRecentAttendedService();
      } catch (e) {
        lastServiceDate = null;
      }

      if (mounted) {
        setState(() {
          _studentCount = childrenProvider.children.length;
          _groupCount = groupNames.length;
          _nextServiceDate = nextServiceDate;
          _quickStats = {
            'avgAttendance': avgAttendance,
            'lastServiceDate': lastServiceDate,
            'serviceDays': serviceDays,
            'totalAttendances': totalAttendances,
          };
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading data: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // This is a placeholder - you'd need to implement this in your provider
  String? _getMostRecentAttendedService() {
    final now = DateTime.now();
    // Find the most recent Sunday
    final daysToLastSunday = now.weekday == 7 ? 0 : 7 - now.weekday;
    final lastSunday = now.subtract(Duration(days: daysToLastSunday));
    return DateFormat('MMMM d').format(lastSunday);
  }

  // Show the points dialog
  void _showAddPointsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Points'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: InputDecoration(
                labelText: 'Student Name',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 16),
            TextField(
              decoration: InputDecoration(
                labelText: 'Points',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              // Add points logic would go here
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Points added successfully!'),
                  backgroundColor: AppColors.success,
                  behavior: SnackBarBehavior.floating,
                  margin: EdgeInsets.all(16),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
            ),
            child: const Text('Add Points'),
          ),
        ],
      ),
    );
  }

  // Show manage students dialog
  void _showManageStudentsDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Consumer<ChildrenProvider>(
        builder: (ctx, childrenProvider, _) {
          final children = childrenProvider.children;

          return Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(bottom: 16),
                  child: Text(
                    'Manage Students',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    ElevatedButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text('Add Student'),
                      onPressed: () {
                        Navigator.pop(ctx); // Close the bottom sheet
                        _showAddStudentDialog(
                            context); // Open the add student dialog
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.group),
                      label: const Text('Manage Groups'),
                      onPressed: () {
                        // Show manage groups dialog
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: children.isEmpty
                      ? const Center(child: Text('No students yet'))
                      : ListView.builder(
                          itemCount: children.length > 5
                              ? 5
                              : children.length, // Show at most 5 children
                          itemBuilder: (ctx, i) {
                            final child = children[i];
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: AppColors.primary,
                                child: Text(
                                  child.name.isNotEmpty
                                      ? child.name[0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                              title: Text(child.name),
                              subtitle: Text(
                                  '${child.groupName} • Age: ${child.age}'),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit, size: 20),
                                    onPressed: () {
                                      // Edit student logic
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete,
                                        size: 20, color: Colors.red),
                                    onPressed: () {
                                      // Delete student logic
                                    },
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
                if (children.length > 5)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Center(
                      child: TextButton.icon(
                        icon: const Icon(Icons.visibility),
                        label: Text('View All ${children.length} Students'),
                        onPressed: () {
                          // Navigate to full students list
                        },
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
    );
  }

  // Show add student dialog
  void _showAddStudentDialog(BuildContext context) {
    final nameController = TextEditingController();
    final ageController = TextEditingController();
    final groupController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add New Student'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Student Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: ageController,
                decoration: const InputDecoration(
                  labelText: 'Age',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: groupController,
                decoration: const InputDecoration(
                  labelText: 'Group',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              // Add student logic would go here
              if (nameController.text.isNotEmpty &&
                  ageController.text.isNotEmpty &&
                  groupController.text.isNotEmpty) {
                // Create and add the student

                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Student added successfully!'),
                    backgroundColor: AppColors.success,
                    behavior: SnackBarBehavior.floating,
                    margin: EdgeInsets.all(16),
                  ),
                );
              } else {
                // Show validation error
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please fill all fields'),
                    backgroundColor: Colors.red,
                    behavior: SnackBarBehavior.floating,
                    margin: EdgeInsets.all(16),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
            ),
            child: const Text('Add Student'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Determine if it's morning, afternoon, or evening for the greeting
    final hour = DateTime.now().hour;
    String greeting;
    if (hour < 12) {
      greeting = 'Good Morning';
    } else if (hour < 17) {
      greeting = 'Good Afternoon';
    } else {
      greeting = 'Good Evening';
    }

    // Get the current date to use for the reports screen
    final now = DateTime.now();
    final currentYear = now.year;
    final currentMonth = now.month;

    return Scaffold(
      backgroundColor: AppColors.background,
      // Make sure to set resizeToAvoidBottomInset to true to avoid keyboard issues
      resizeToAvoidBottomInset: true,
      // Set this to false to ensure system status bar stays visible
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text(
          'Little Lambs',
          style: TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
        systemOverlayStyle:
            SystemUiOverlayStyle.dark, // Ensure dark icons in status bar
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // Header with greeting, date and time
            SliverToBoxAdapter(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      greeting,
                      style: AppTextStyles.heading1.copyWith(
                        fontSize: 24,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Date display
                        Text(
                          _formattedDate,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        // Time display (now just for visual consistency since system clock is visible)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.access_time,
                                color: AppColors.primary,
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _formattedTime,
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Quick Stats Section
            SliverToBoxAdapter(
              child: _isLoading
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  : Column(
                      children: [
                        // Next Service Card
                        if (_nextServiceDate != null)
                          Container(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 10),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [AppColors.primary, Color(0xFF5C6BC0)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.event,
                                        color: Colors.white),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Next Service',
                                      style: AppTextStyles.heading3.copyWith(
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  DateFormat('EEEE, MMMM d').format(
                                      DateFormat('yyyy-MM-dd')
                                          .parse(_nextServiceDate!)),
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                ElevatedButton.icon(
                                  icon: const Icon(Icons.how_to_reg),
                                  label: const Text('View Attendance'),
                                  onPressed: () {
                                    // Navigate to the attendance screen for the next service
                                    final nextServiceDateTime =
                                        DateFormat('yyyy-MM-dd')
                                            .parse(_nextServiceDate!);
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            MonthlyReportScreen(
                                          year: nextServiceDateTime.year,
                                          month: nextServiceDateTime.month,
                                        ),
                                      ),
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: AppColors.primary,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 10,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // Statistics Row
                        Container(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 16),
                          child: Row(
                            children: [
                              // Students Count
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.all(16),
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Students',
                                        style: TextStyle(
                                          color: AppColors.textSecondary,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.person,
                                            color: Colors.orange.shade700,
                                            size: 20,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            '$_studentCount',
                                            style: const TextStyle(
                                              fontSize: 22,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),

                              // Groups Count
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.all(16),
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Groups',
                                        style: TextStyle(
                                          color: AppColors.textSecondary,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.groups,
                                            color: Colors.teal.shade700,
                                            size: 20,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            '$_groupCount',
                                            style: const TextStyle(
                                              fontSize: 22,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              const SizedBox(width: 12),

                              // Attendance Percentage
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.all(16),
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Avg. Attendance',
                                        style: TextStyle(
                                          color: AppColors.textSecondary,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.insert_chart,
                                            color: Colors.purple.shade700,
                                            size: 20,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            _quickStats != null
                                                ? '${_quickStats!['avgAttendance']}%'
                                                : '0%',
                                            style: const TextStyle(
                                              fontSize: 22,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
            ),

            // Menu Section Title
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, 10, 20, 16),
                child: Text(
                  'Quick Menu',
                  style: AppTextStyles.heading2,
                ),
              ),
            ),

            // Main Menu Grid
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 1.2,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                ),
                delegate: SliverChildListDelegate([
                  // View Current Month Reports
                  MenuCard(
                    title: 'Current Month',
                    icon: Icons.calendar_month,
                    color: const Color(0xFF4CAF50),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (ctx) => MonthlyReportScreen(
                          year: currentYear,
                          month: currentMonth,
                        ),
                      ),
                    ),
                  ),

                  // Manage Students - RESTORED
                  MenuCard(
                    title: 'Manage Students',
                    icon: Icons.people,
                    color: const Color(0xFF2196F3),
                    onTap: () => _showManageStudentsDialog(context),
                  ),

                  // Add Points
                  MenuCard(
                    title: 'Add Points',
                    icon: Icons.add_circle,
                    color: const Color(0xFFFF9800),
                    onTap: () => _showAddPointsDialog(context),
                  ),

                  // Help & Support
                  MenuCard(
                    title: 'Help & Support',
                    icon: Icons.help,
                    color: const Color(0xFF9C27B0),
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Help & Support'),
                          content: const Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Need assistance with the app?',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              SizedBox(height: 12),
                              Text('• View monthly attendance reports'),
                              Text('• Record student attendance'),
                              Text('• Track attendance trends'),
                              SizedBox(height: 12),
                              Text('Contact support@littlelambs.org for help'),
                            ],
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop(),
                              child: const Text('Close'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ]),
              ),
            ),

            // Footer space
            const SliverToBoxAdapter(
              child: SizedBox(height: 30),
            ),
          ],
        ),
      ),
    );
  }
}
