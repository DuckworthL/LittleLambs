import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/attendance_provider.dart';
import '../providers/children_provider.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';
import '../utils/logger.dart';
import 'monthly_report_screen.dart';
// New screen for service details

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  bool _showArchive = false;
  final int _maxFutureMonths = 1; // Only show current month plus 1 future month
  bool _isLoadingAttendance = true;
  Map<int, int> _attendanceData = {};

  @override
  void initState() {
    super.initState();
    _loadAttendanceData();
    _loadArchivedMonths();
  }

  Future<void> _loadArchivedMonths() async {
    try {
      final attendanceProvider =
          Provider.of<AttendanceProvider>(context, listen: false);
      await attendanceProvider.loadArchivedMonths();
    } catch (e) {
      Logger.error('Error loading archived months', e);
    }
  }

  Future<void> _loadAttendanceData() async {
    if (!mounted) return;

    setState(() => _isLoadingAttendance = true);

    try {
      final childrenProvider =
          Provider.of<ChildrenProvider>(context, listen: false);
      final attendanceProvider =
          Provider.of<AttendanceProvider>(context, listen: false);

      await childrenProvider.fetchAndSetChildren();

      // Get first day of current month
      final now = DateTime.now();
      final firstDayOfMonth = DateTime(now.year, now.month, 1);
      final startDate = DateFormat('yyyy-MM-dd').format(firstDayOfMonth);
      final endDate = DateFormat('yyyy-MM-dd').format(now);

      final childIds = childrenProvider.children.map((c) => c.id!).toList();
      final data = await attendanceProvider.getAttendanceCountByChild(
          childIds, startDate, endDate);

      if (!mounted) return;

      setState(() {
        _attendanceData = data;
        _isLoadingAttendance = false;
      });
    } catch (e) {
      Logger.error('Error loading attendance data', e);

      if (!mounted) return;

      setState(() => _isLoadingAttendance = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final currentYear = now.year;
    final currentMonth = now.month;

    final childrenProvider = Provider.of<ChildrenProvider>(context);
    final attendanceProvider = Provider.of<AttendanceProvider>(context);
    final children = childrenProvider.children;

    // Get archived months data
    List<Map<String, dynamic>> archivedMonthsData =
        attendanceProvider.archivedMonths;

    // Create list of accessible months (current month + 1 future month)
    List<Widget> accessibleMonths = [];
    for (int i = 0; i < _maxFutureMonths; i++) {
      final futureMonth = (currentMonth + i) % 12;
      final futureYear = currentYear + ((currentMonth + i) ~/ 12);
      final actualMonth = futureMonth == 0 ? 12 : futureMonth;

      accessibleMonths.add(
        _MonthCard(
          year: futureYear,
          month: actualMonth,
          isCurrentMonth: i == 0,
          isAccessible: true,
        ),
      );
    }

    // Create list of inaccessible future months (just visual, not accessible)
    List<Widget> inaccessibleMonths = [];
    for (int i = _maxFutureMonths; i < 11; i++) {
      final futureMonth = (currentMonth + i) % 12;
      final futureYear = currentYear + ((currentMonth + i) ~/ 12);
      final actualMonth = futureMonth == 0 ? 12 : futureMonth;

      inaccessibleMonths.add(
        _MonthCard(
          year: futureYear,
          month: actualMonth,
          isAccessible: false,
        ),
      );
    }

    // Create list of archived months
    List<Widget> archivedMonths = [];
    if (_showArchive) {
      if (archivedMonthsData.isEmpty) {
        // No archived months
        archivedMonths.add(
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Center(
              child: Text(
                'No archived reports found',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ),
        );
      } else {
        // Show archived months
        for (var monthData in archivedMonthsData) {
          archivedMonths.add(
            _MonthCard(
              year: monthData['year'],
              month: monthData['month'],
              isArchived: true,
              isAccessible: true,
            ),
          );
        }
      }
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // App bar - FIXED to remove duplicate title
          SliverAppBar(
            expandedHeight: 130.0,
            pinned: true,
            backgroundColor: AppColors.primary,
            title: const Text('Attendance Reports'),
            flexibleSpace: FlexibleSpaceBar(
              // Remove the title here to avoid duplication
              titlePadding: EdgeInsets.zero,
              background: Container(
                decoration: const BoxDecoration(
                  gradient: AppColors.primaryGradient,
                ),
                child: const Padding(
                  padding: EdgeInsets.fromLTRB(20, 80, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                          height: 24), // Space for the title in the app bar
                      Text(
                        'Track attendance trends and history',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w300,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Monthly reports section
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, 24, 20, 8),
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_month,
                    color: AppColors.primary,
                    size: 18,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Current & Upcoming Month',
                    style: AppTextStyles.heading3,
                  ),
                ],
              ),
            ),
          ),

          // Accessible months list
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                if (index >= accessibleMonths.length) return null;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: accessibleMonths[index],
                );
              },
              childCount: accessibleMonths.length,
            ),
          ),

          // Inaccessible future months section
          if (inaccessibleMonths.isNotEmpty)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, 24, 20, 8),
                child: Row(
                  children: [
                    Icon(
                      Icons.lock_clock,
                      color: AppColors.textSecondary,
                      size: 18,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Future Months (Not Yet Available)',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Inaccessible future months list
          if (inaccessibleMonths.isNotEmpty)
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  if (index >= inaccessibleMonths.length) return null;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: inaccessibleMonths[index],
                  );
                },
                childCount: inaccessibleMonths.length,
              ),
            ),

          // Archive section
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: InkWell(
                onTap: () {
                  setState(() {
                    _showArchive = !_showArchive;
                  });
                },
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Icon(
                        _showArchive
                            ? Icons.arrow_drop_down
                            : Icons.arrow_right,
                        size: 24,
                        color: AppColors.textSecondary,
                      ),
                      const Text(
                        'Archive',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Archived months list
          if (_showArchive)
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  if (index >= archivedMonths.length) return null;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: archivedMonths[index],
                  );
                },
                childCount: archivedMonths.length,
              ),
            ),

          // Children attendance section
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, 24, 20, 16),
              child: Row(
                children: [
                  Icon(
                    Icons.people,
                    color: AppColors.primary,
                    size: 18,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Children Attendance',
                    style: AppTextStyles.heading3,
                  ),
                ],
              ),
            ),
          ),

          // Children attendance data
          children.isEmpty
              ? const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Padding(
                    padding: EdgeInsets.all(20.0),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.people_outline,
                            size: 60,
                            color: AppColors.textLight,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'No children added yet',
                            style: TextStyle(
                              fontSize: 16,
                              color: AppColors.textSecondary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              : _isLoadingAttendance
                  ? const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(20.0),
                        child: Center(
                          child: Column(
                            children: [
                              CircularProgressIndicator(
                                  color: AppColors.primary),
                              SizedBox(height: 16),
                              Text('Loading attendance data...'),
                            ],
                          ),
                        ),
                      ),
                    )
                  : SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          if (index >= children.length) return null;

                          final child = children[index];
                          final attendanceCount =
                              _attendanceData[child.id!] ?? 0;

                          return Padding(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
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
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Row(
                                  children: [
                                    // Avatar
                                    CircleAvatar(
                                      backgroundColor: AppColors.primaryLight
                                          .withOpacity(0.2),
                                      child: Text(
                                        child.name.isNotEmpty
                                            ? child.name[0].toUpperCase()
                                            : 'C',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    // Child info
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            child.name,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
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
                                    // Attendance count
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.primaryLight
                                            .withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Column(
                                        children: [
                                          Text(
                                            '$attendanceCount',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 18,
                                              color: AppColors.primary,
                                            ),
                                          ),
                                          const Text(
                                            'days',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: AppColors.primary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                        childCount: children.length,
                      ),
                    ),

          const SliverPadding(padding: EdgeInsets.only(bottom: 20)),
        ],
      ),
    );
  }
}

class _MonthCard extends StatelessWidget {
  final int year;
  final int month;
  final bool isCurrentMonth;
  final bool isArchived;
  final bool isAccessible;

  const _MonthCard({
    required this.year,
    required this.month,
    this.isCurrentMonth = false,
    this.isArchived = false,
    this.isAccessible = true,
  });

  @override
  Widget build(BuildContext context) {
    final monthName = DateFormat('MMMM').format(DateTime(year, month));
    final now = DateTime.now();
    final isPastOrPresent =
        (year < now.year) || (year == now.year && month <= now.month);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isAccessible ? Colors.white : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isAccessible ? 0.05 : 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: isCurrentMonth
            ? Border.all(color: AppColors.primary, width: 2)
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(isCurrentMonth ? 10 : 12),
        child: Dismissible(
          key: Key('month_${year}_$month'),
          direction:
              isArchived ? DismissDirection.endToStart : DismissDirection.none,
          confirmDismiss: isArchived
              ? (direction) async {
                  return await showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Confirm Deletion'),
                      content: Text(
                          'Are you sure you want to delete the report for $monthName $year?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(false),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(true),
                          child: const Text('Delete',
                              style: TextStyle(color: Colors.red)),
                        ),
                      ],
                    ),
                  );
                }
              : null,
          background: Container(
            color: Colors.red,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 16.0),
            child: const Icon(
              Icons.delete,
              color: Colors.white,
            ),
          ),
          onDismissed: isArchived
              ? (direction) async {
                  // Store context-related objects before the async gap
                  final scaffoldMsgr = ScaffoldMessenger.of(context);
                  final attendanceProvider =
                      Provider.of<AttendanceProvider>(context, listen: false);
                  final isMounted = context.mounted;

                  try {
                    // Delete the month report
                    await attendanceProvider.deleteMonthReport(year, month);

                    // Check if widget is still mounted after the async operation
                    if (isMounted && context.mounted) {
                      scaffoldMsgr.showSnackBar(
                        SnackBar(
                          content: Text('Deleted report for $monthName $year'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  } catch (e) {
                    Logger.error('Error deleting report on dismiss', e);

                    // Check if widget is still mounted after the async operation
                    if (isMounted && context.mounted) {
                      scaffoldMsgr.showSnackBar(
                        SnackBar(
                          content: Text('Failed to delete: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                }
              : null,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: isAccessible
                  ? () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => MonthlyReportScreen(
                            year: year,
                            month: month,
                          ),
                        ),
                      );
                    }
                  : null,
              onLongPress: isArchived
                  ? () {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Report Actions'),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('$monthName $year'),
                              const SizedBox(height: 8),
                              ListTile(
                                leading: const Icon(Icons.restore),
                                title: const Text('Restore to Active'),
                                onTap: () async {
                                  // Store context-related objects before the async gap
                                  final scaffoldMsgr =
                                      ScaffoldMessenger.of(context);
                                  final navigationCtx = Navigator.of(ctx);
                                  final attendanceProvider =
                                      Provider.of<AttendanceProvider>(context,
                                          listen: false);
                                  final isMounted = context.mounted;

                                  try {
                                    await attendanceProvider.restoreMonthReport(
                                        year, month);

                                    // Check if widget is still mounted after the async operation
                                    if (isMounted && context.mounted) {
                                      navigationCtx.pop();
                                      scaffoldMsgr.showSnackBar(
                                        SnackBar(
                                          content: Text(
                                              'Restored $monthName $year to active reports'),
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    Logger.error('Error restoring report', e);

                                    // Check if widget is still mounted after the async operation
                                    if (isMounted && context.mounted) {
                                      navigationCtx.pop();
                                      scaffoldMsgr.showSnackBar(
                                        SnackBar(
                                          content:
                                              Text('Failed to restore: $e'),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    }
                                  }
                                },
                              ),
                              ListTile(
                                leading:
                                    const Icon(Icons.delete, color: Colors.red),
                                title: const Text('Delete',
                                    style: TextStyle(color: Colors.red)),
                                onTap: () {
                                  Navigator.pop(ctx);
                                  // Show delete confirmation
                                  showDialog(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: const Text('Confirm Deletion'),
                                      content: Text(
                                          'Are you sure you want to delete the report for $monthName $year?'),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.of(ctx).pop(),
                                          child: const Text('Cancel'),
                                        ),
                                        TextButton(
                                          onPressed: () async {
                                            // Store context-related objects before the async gap
                                            final scaffoldMsgr =
                                                ScaffoldMessenger.of(context);
                                            final navigationCtx =
                                                Navigator.of(ctx);
                                            final attendanceProvider =
                                                Provider.of<AttendanceProvider>(
                                                    context,
                                                    listen: false);
                                            final isMounted = context.mounted;

                                            try {
                                              await attendanceProvider
                                                  .deleteMonthReport(
                                                      year, month);

                                              // Check if widget is still mounted after the async operation
                                              if (isMounted &&
                                                  context.mounted) {
                                                navigationCtx.pop();
                                                scaffoldMsgr.showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                        'Deleted report for $monthName $year'),
                                                    backgroundColor: Colors.red,
                                                  ),
                                                );
                                              }
                                            } catch (e) {
                                              Logger.error(
                                                  'Error deleting report', e);

                                              // Check if widget is still mounted after the async operation
                                              if (isMounted &&
                                                  context.mounted) {
                                                navigationCtx.pop();
                                                scaffoldMsgr.showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                        'Failed to delete: $e'),
                                                    backgroundColor: Colors.red,
                                                  ),
                                                );
                                              }
                                            }
                                          },
                                          child: const Text('Delete',
                                              style:
                                                  TextStyle(color: Colors.red)),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                  : null,
              child: Opacity(
                opacity: isAccessible ? 1.0 : 0.5,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      // Month badge
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: isCurrentMonth
                              ? AppColors.primary
                              : (isArchived
                                  ? Colors.grey.shade300
                                  : Colors.grey.shade100),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                month.toString(),
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: isCurrentMonth
                                      ? Colors.white
                                      : AppColors.textPrimary,
                                ),
                              ),
                              Text(
                                year.toString(),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isCurrentMonth
                                      ? Colors.white.withOpacity(0.8)
                                      : AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Month info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$monthName $year',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: isAccessible
                                    ? AppColors.textPrimary
                                    : AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            if (!isAccessible)
                              const Row(
                                children: [
                                  Icon(Icons.lock_outline,
                                      size: 14, color: AppColors.textLight),
                                  SizedBox(width: 6),
                                  Text(
                                    'Not yet available',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: AppColors.textLight,
                                    ),
                                  ),
                                ],
                              )
                            else
                              FutureBuilder(
                                future: Provider.of<AttendanceProvider>(context,
                                        listen: false)
                                    .getMonthlyAttendanceCount(year, month),
                                builder: (context, snapshot) {
                                  if (snapshot.connectionState ==
                                      ConnectionState.waiting) {
                                    return const Row(
                                      children: [
                                        SizedBox(
                                          width: 10,
                                          height: 10,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: AppColors.textLight,
                                          ),
                                        ),
                                        SizedBox(width: 8),
                                        Text(
                                          'Loading...',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    );
                                  }

                                  if (snapshot.hasError) {
                                    return const Text(
                                      'Error loading data',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: AppColors.error,
                                      ),
                                    );
                                  }

                                  final data =
                                      snapshot.data as Map<String, int>;
                                  final serviceCount = data.length;

                                  if (isPastOrPresent) {
                                    return Row(
                                      children: [
                                        Icon(
                                          serviceCount > 0
                                              ? Icons.check_circle
                                              : Icons.calendar_month,
                                          size: 14,
                                          color: serviceCount > 0
                                              ? AppColors.success
                                              : AppColors.textSecondary,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          serviceCount > 0
                                              ? '$serviceCount services recorded'
                                              : 'No services recorded',
                                          style: const TextStyle(
                                            fontSize: 14,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    );
                                  } else {
                                    // Future month
                                    return const Row(
                                      children: [
                                        Icon(
                                          Icons.event_available_outlined,
                                          size: 14,
                                          color: AppColors.textSecondary,
                                        ),
                                        SizedBox(width: 6),
                                        Text(
                                          'Upcoming month',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    );
                                  }
                                },
                              ),
                          ],
                        ),
                      ),
                      // Arrow or lock icon
                      if (isAccessible)
                        Icon(
                          isArchived ? Icons.history : Icons.chevron_right,
                          color: AppColors.textSecondary,
                        )
                      else
                        const Icon(
                          Icons.lock_outline,
                          color: AppColors.textLight,
                          size: 18,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
