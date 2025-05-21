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

      // Make sure children data is loaded
      await childrenProvider.fetchAndSetChildren();

      // Combine data from both providers
      final attendanceData = attendanceProvider.attendanceData[dateStr] ?? {};
      final List<Map<String, dynamic>> records = [];

      for (var child in childrenProvider.children) {
        final isPresent = attendanceData[child.id ?? 0] ?? false;
        records.add({
          'child': child,
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

  @override
  Widget build(BuildContext context) {
    // Sort records by present then alphabetically
    _attendanceRecords.sort((a, b) {
      // Sort by attendance status first (present before absent)
      if (a['isPresent'] && !b['isPresent']) return -1;
      if (!a['isPresent'] && b['isPresent']) return 1;

      // Then sort by name
      final childA = a['child'] as Child;
      final childB = b['child'] as Child;
      return childA.name.compareTo(childB.name);
    });

    // Count present children
    final presentCount =
        _attendanceRecords.where((record) => record['isPresent']).length;
    final totalChildren = _attendanceRecords.length;

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
          ? const Center(child: CircularProgressIndicator())
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
              : CustomScrollView(
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
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
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
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Text(
                                    '$presentCount / $totalChildren',
                                    style: const TextStyle(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            // Wrap LinearProgressIndicator in ClipRRect for rounded corners
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: totalChildren > 0
                                    ? presentCount / totalChildren
                                    : 0,
                                backgroundColor: Colors.grey.shade200,
                                color: AppColors.primary,
                                minHeight: 8,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Attendance: ${totalChildren > 0 ? (presentCount / totalChildren * 100).round() : 0}%',
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
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

                    // Present children list
                    if (presentCount > 0)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                          child: Text(
                            'Present ($presentCount)',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: AppColors.success,
                            ),
                          ),
                        ),
                      ),

                    // Present children list items
                    if (presentCount > 0)
                      SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final records = _attendanceRecords
                                .where((r) => r['isPresent'])
                                .toList();
                            if (index >= records.length) return null;

                            final record = records[index];
                            final child = record['child'] as Child;

                            return Container(
                              margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: AppColors.success.withOpacity(0.3),
                                  width: 1,
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Row(
                                  children: [
                                    // Avatar
                                    CircleAvatar(
                                      backgroundColor:
                                          AppColors.success.withOpacity(0.1),
                                      child: Text(
                                        child.name.isNotEmpty
                                            ? child.name[0].toUpperCase()
                                            : '?',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.success,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),

                                    // Child details
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            child.name,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w500,
                                              fontSize: 16,
                                            ),
                                          ),
                                          Text(
                                            '${child.groupName} • Age: ${child.age}',
                                            style: const TextStyle(
                                              fontSize: 14,
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    // Present indicator
                                    const Icon(
                                      Icons.check_circle,
                                      color: AppColors.success,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                          childCount: _attendanceRecords
                              .where((r) => r['isPresent'])
                              .length,
                        ),
                      ),

                    // Absent children header
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Text(
                          'Absent (${totalChildren - presentCount})',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppColors.error,
                          ),
                        ),
                      ),
                    ),

                    // Absent children list
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final records = _attendanceRecords
                              .where((r) => !r['isPresent'])
                              .toList();
                          if (index >= records.length) return null;

                          final record = records[index];
                          final child = record['child'] as Child;

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
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  // Avatar
                                  CircleAvatar(
                                    backgroundColor: Colors.grey.shade100,
                                    child: Text(
                                      child.name.isNotEmpty
                                          ? child.name[0].toUpperCase()
                                          : '?',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),

                                  // Child details
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          child.name,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w500,
                                            fontSize: 16,
                                            color: Colors.grey.shade800,
                                          ),
                                        ),
                                        Text(
                                          '${child.groupName} • Age: ${child.age}',
                                          style: const TextStyle(
                                            fontSize: 14,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Mark Present button - for upcoming services
                                  if (DateTime.now()
                                          .difference(widget.date)
                                          .inDays <=
                                      0)
                                    IconButton(
                                      icon: const Icon(
                                          Icons.check_circle_outline),
                                      color: Colors.grey.shade400,
                                      onPressed: () async {
                                        final dateStr = DateFormat('yyyy-MM-dd')
                                            .format(widget.date);
                                        final attendanceProvider =
                                            Provider.of<AttendanceProvider>(
                                                context,
                                                listen: false);
                                        final isContextMounted =
                                            context.mounted;
                                        final scaffoldMsgr =
                                            ScaffoldMessenger.of(context);

                                        try {
                                          await attendanceProvider
                                              .setAttendance(
                                            childId: child.id ?? 0,
                                            date: dateStr,
                                            isPresent: true,
                                          );

                                          if (isContextMounted && mounted) {
                                            _loadAttendanceData();
                                          }
                                        } catch (e) {
                                          // Show error
                                          if (isContextMounted && mounted) {
                                            scaffoldMsgr.showSnackBar(
                                              SnackBar(
                                                content: Text('Error: $e'),
                                                backgroundColor: Colors.red,
                                              ),
                                            );
                                          }
                                        }
                                      },
                                    )
                                  // Absent indicator for past services
                                  else
                                    Icon(
                                      Icons.remove_circle,
                                      color: Colors.grey.shade400,
                                    ),
                                ],
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
    );
  }
}
