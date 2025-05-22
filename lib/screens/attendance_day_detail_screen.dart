import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';
import '../providers/attendance_provider.dart';
import '../providers/children_provider.dart';
import '../utils/logger.dart';
import '../models/child.dart';

class AttendanceDayDetailScreen extends StatefulWidget {
  final DateTime date;
  final String formattedDate;
  final int attendanceCount;

  const AttendanceDayDetailScreen({
    super.key,
    required this.date,
    required this.formattedDate,
    required this.attendanceCount,
  });

  @override
  State<AttendanceDayDetailScreen> createState() =>
      _AttendanceDayDetailScreenState();
}

class _AttendanceDayDetailScreenState extends State<AttendanceDayDetailScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _attendanceRecords = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadAttendanceData();
  }

  Future<void> _loadAttendanceData() async {
    setState(() => _isLoading = true);

    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(widget.date);
      final attendanceProvider =
          Provider.of<AttendanceProvider>(context, listen: false);
      final childrenProvider =
          Provider.of<ChildrenProvider>(context, listen: false);

      // Load attendance data for this date
      await attendanceProvider.fetchAttendanceForDate(dateStr);

      // Make sure students data is loaded
      await childrenProvider.fetchAndSetChildren();

      // Combine data from both providers
      final attendanceData = attendanceProvider.attendanceData[dateStr] ?? {};
      final List<Map<String, dynamic>> records = [];

      for (var student in childrenProvider.children) {
        final isPresent = attendanceData[student.id ?? 0] ?? false;
        records.add({
          'student': student,
          'isPresent': isPresent,
        });
      }

      if (mounted) {
        setState(() {
          _attendanceRecords = records;
          _isLoading = false;
        });
      }
    } catch (e) {
      Logger.error('Error loading attendance data for date', e);

      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load attendance data: $e';
          _isLoading = false;
        });
      }
    }
  }

  // Toggle student attendance status
  Future<void> _toggleAttendance(Child student, bool currentStatus) async {
    final dateStr = DateFormat('yyyy-MM-dd').format(widget.date);
    final attendanceProvider =
        Provider.of<AttendanceProvider>(context, listen: false);
    final scaffoldMsgr = ScaffoldMessenger.of(context);
    final isContextMounted = context.mounted;

    try {
      // Toggle the attendance status
      await attendanceProvider.setAttendance(
        childId: student.id ?? 0,
        date: dateStr,
        isPresent: !currentStatus, // Toggle current value
      );

      if (isContextMounted && mounted) {
        _loadAttendanceData(); // Refresh the data

        // Show a confirmation message
        scaffoldMsgr.showSnackBar(
          SnackBar(
            content: Text(!currentStatus
                ? '${student.name} marked as present'
                : '${student.name} marked as absent'),
            backgroundColor:
                !currentStatus ? AppColors.success : Colors.grey.shade700,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 1),
            margin: const EdgeInsets.only(bottom: 16, right: 16, left: 16),
          ),
        );
      }
    } catch (e) {
      if (isContextMounted && mounted) {
        scaffoldMsgr.showSnackBar(
          SnackBar(
            content: Text('Error updating attendance: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Sort records by present then alphabetically
    _attendanceRecords.sort((a, b) {
      // Sort by attendance status first (present before absent)
      if (a['isPresent'] && !b['isPresent']) return -1;
      if (!a['isPresent'] && b['isPresent']) return 1;

      // Then sort by name
      final studentA = a['student'] as Child;
      final studentB = b['student'] as Child;
      return studentA.name.compareTo(studentB.name);
    });

    // Count present students
    final presentCount =
        _attendanceRecords.where((record) => record['isPresent']).length;
    final totalStudents = _attendanceRecords.length;

    // Calculate attendance percentage safely
    final attendancePercentage =
        totalStudents > 0 ? (presentCount / totalStudents * 100).round() : 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(DateFormat('MMM d, yyyy').format(widget.date)),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _loadAttendanceData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            )
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: AppColors.error,
                          size: 48,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppColors.error),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _loadAttendanceData,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadAttendanceData,
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      // Summary section
                      SliverToBoxAdapter(
                        child: Container(
                          margin: const EdgeInsets.all(16),
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
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
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Service Summary',
                                        style: AppTextStyles.heading3,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        widget.formattedDate,
                                        style: const TextStyle(
                                          color: AppColors.textSecondary,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                  // Attendance Badge
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _getAttendanceColor(
                                              attendancePercentage)
                                          .withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          _getAttendanceIcon(
                                              attendancePercentage),
                                          size: 16,
                                          color: _getAttendanceColor(
                                              attendancePercentage),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          '$presentCount / $totalStudents',
                                          style: TextStyle(
                                            color: _getAttendanceColor(
                                                attendancePercentage),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),

                              // Attendance progress bar
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        'Attendance Rate',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                      Text(
                                        '$attendancePercentage%',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: _getAttendanceColor(
                                              attendancePercentage),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  // Wrap LinearProgressIndicator in ClipRRect for rounded corners
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: totalStudents > 0
                                          ? presentCount / totalStudents
                                          : 0,
                                      backgroundColor: Colors.grey.shade200,
                                      color: _getAttendanceColor(
                                          attendancePercentage),
                                      minHeight: 8,
                                    ),
                                  ),
                                ],
                              ),

                              // Quick info row
                              const SizedBox(height: 20),
                              Row(
                                children: [
                                  // Students by group
                                  Expanded(
                                    child: _buildQuickInfoItem(
                                      icon: Icons.people,
                                      title: 'Present',
                                      value: '$presentCount',
                                      color: AppColors.success,
                                    ),
                                  ),
                                  const SizedBox(width: 12),

                                  // Absent count
                                  Expanded(
                                    child: _buildQuickInfoItem(
                                      icon: Icons.person_off,
                                      title: 'Absent',
                                      value: '${totalStudents - presentCount}',
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Attendance list header
                      const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(16, 8, 16, 12),
                          child: Row(
                            children: [
                              Icon(
                                Icons.people,
                                size: 16,
                                color: AppColors.textSecondary,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Attendance List',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: Divider(),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Tab header sections for Present/Absent
                      SliverPersistentHeader(
                        pinned: true,
                        delegate: _SliverAppBarDelegate(
                          minHeight: 60,
                          maxHeight: 60,
                          child: Container(
                            color: AppColors.background,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            child: Row(
                              children: [
                                // Present Tab
                                Expanded(
                                  child: InkWell(
                                    onTap: () {
                                      // You could add tab switching logic here if needed
                                    },
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 10),
                                      decoration: BoxDecoration(
                                        color:
                                            AppColors.success.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: AppColors.success
                                              .withOpacity(0.3),
                                          width: 1,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          const Icon(
                                            Icons.check_circle,
                                            color: AppColors.success,
                                            size: 18,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Present ($presentCount)',
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.success,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),

                                // Absent Tab
                                Expanded(
                                  child: InkWell(
                                    onTap: () {
                                      // You could add tab switching logic here if needed
                                    },
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 10),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade200,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: Colors.grey.shade300,
                                          width: 1,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.cancel,
                                            color: Colors.grey.shade700,
                                            size: 18,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Absent (${totalStudents - presentCount})',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.grey.shade700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Present students list items
                      if (presentCount > 0)
                        SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final records = _attendanceRecords
                                  .where((r) => r['isPresent'])
                                  .toList();
                              if (index >= records.length) return null;

                              final record = records[index];
                              final student = record['student'] as Child;
                              final bool isPresent = record['isPresent'];

                              return Container(
                                margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: AppColors.success.withOpacity(0.3),
                                    width: 1,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.03),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: InkWell(
                                  // Add onTap to toggle attendance status
                                  onTap: () =>
                                      _toggleAttendance(student, isPresent),
                                  borderRadius: BorderRadius.circular(12),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Row(
                                      children: [
                                        // Avatar with enhanced styling
                                        Container(
                                          width: 46,
                                          height: 46,
                                          decoration: const BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [
                                                AppColors.primary,
                                                AppColors.primaryLight
                                              ],
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                            ),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Center(
                                            child: Text(
                                              student.name.isNotEmpty
                                                  ? student.name[0]
                                                      .toUpperCase()
                                                  : '?',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                                fontSize: 20,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 16),

                                        // Student details with enhanced styling
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                student.name,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 16,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Row(
                                                children: [
                                                  Container(
                                                    padding: const EdgeInsets
                                                            .symmetric(
                                                        horizontal: 8,
                                                        vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: Colors.blue
                                                          .withOpacity(0.1),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              12),
                                                    ),
                                                    child: Text(
                                                      student.groupName,
                                                      style: const TextStyle(
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                        color: Colors.blue,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    'Age: ${student.age}',
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                      color: AppColors
                                                          .textSecondary,
                                                    ),
                                                  ),
                                                  if (student.notes != null &&
                                                      student.notes!.isNotEmpty)
                                                    Icon(
                                                      Icons.info_outline,
                                                      size: 14,
                                                      color: Colors
                                                          .orange.shade700,
                                                    ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),

                                        // Checkbox for attendance
                                        Transform.scale(
                                          scale: 1.2,
                                          child: Checkbox(
                                            value: isPresent,
                                            activeColor: AppColors.success,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            onChanged: (newValue) {
                                              if (newValue != null) {
                                                _toggleAttendance(
                                                    student, isPresent);
                                              }
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                            childCount: _attendanceRecords
                                .where((r) => r['isPresent'])
                                .length,
                          ),
                        ),

                      // Absent students list
                      SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final records = _attendanceRecords
                                .where((r) => !r['isPresent'])
                                .toList();
                            if (index >= records.length) return null;

                            final record = records[index];
                            final student = record['student'] as Child;
                            final bool isPresent = record['isPresent'];

                            return Container(
                              margin: EdgeInsets.fromLTRB(16, 0, 16,
                                  index == records.length - 1 ? 24 : 8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.grey.shade300,
                                  width: 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.02),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: InkWell(
                                // Add onTap to toggle attendance status
                                onTap: () =>
                                    _toggleAttendance(student, isPresent),
                                borderRadius: BorderRadius.circular(12),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Row(
                                    children: [
                                      // Avatar
                                      Container(
                                        width: 46,
                                        height: 46,
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade200,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Center(
                                          child: Text(
                                            student.name.isNotEmpty
                                                ? student.name[0].toUpperCase()
                                                : '?',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Colors.grey.shade700,
                                              fontSize: 20,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 16),

                                      // Student details
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              student.name,
                                              style: TextStyle(
                                                fontWeight: FontWeight.w500,
                                                fontSize: 16,
                                                color: Colors.grey.shade800,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Row(
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets
                                                          .symmetric(
                                                      horizontal: 8,
                                                      vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: Colors.grey.shade100,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12),
                                                  ),
                                                  child: Text(
                                                    student.groupName,
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                      color:
                                                          Colors.grey.shade700,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  'Age: ${student.age}',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.grey.shade600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),

                                      // Mark Present button
                                      Transform.scale(
                                        scale: 1.2,
                                        child: Checkbox(
                                          value: isPresent,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(4),
                                          ),
                                          onChanged: (newValue) {
                                            if (newValue != null) {
                                              _toggleAttendance(
                                                  student, isPresent);
                                            }
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                          childCount: _attendanceRecords
                              .where((r) => !r['isPresent'])
                              .length,
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  // Helper method to build quick info cards
  Widget _buildQuickInfoItem({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: color,
            size: 20,
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  color: color.withOpacity(0.8),
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Helper method to get color based on attendance percentage
  Color _getAttendanceColor(int percentage) {
    if (percentage >= 75) return AppColors.success;
    if (percentage >= 50) return Colors.orange;
    return AppColors.error;
  }

  // Helper method to get icon based on attendance percentage
  IconData _getAttendanceIcon(int percentage) {
    if (percentage >= 75) return Icons.check_circle;
    if (percentage >= 50) return Icons.info;
    return Icons.warning;
  }
}

// Sliver delegate for sticky headers
class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverAppBarDelegate({
    required this.minHeight,
    required this.maxHeight,
    required this.child,
  });

  final double minHeight;
  final double maxHeight;
  final Widget child;

  @override
  double get minExtent => minHeight;

  @override
  double get maxExtent => maxHeight;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return SizedBox.expand(child: child);
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return maxHeight != oldDelegate.maxHeight ||
        minHeight != oldDelegate.minHeight ||
        child != oldDelegate.child;
  }
}
