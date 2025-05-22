import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/attendance_provider.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';
import '../utils/logger.dart';
import 'attendance_day_detail_screen.dart';

class MonthlyReportScreen extends StatefulWidget {
  final int year;
  final int month;

  const MonthlyReportScreen({
    super.key,
    required this.year,
    required this.month,
  });

  @override
  State<MonthlyReportScreen> createState() => _MonthlyReportScreenState();
}

class _MonthlyReportScreenState extends State<MonthlyReportScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _reportData;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadReportData();
  }

  Future<void> _loadReportData() async {
    setState(() => _isLoading = true);

    try {
      final data = await _fetchReportData();

      if (mounted) {
        setState(() {
          _reportData = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      Logger.error('Error loading monthly report data', e);

      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<Map<String, dynamic>> _fetchReportData() async {
    final attendanceProvider =
        Provider.of<AttendanceProvider>(context, listen: false);

    // Get service dates (Sat & Sun) in the month
    final serviceDates = _getServiceDatesInMonth(widget.year, widget.month);

    // Get the current date for comparison
    final now = DateTime.now();

    // Is this month in the future? (not this month or earlier)
    final isFutureMonth = widget.year > now.year ||
        (widget.year == now.year && widget.month > now.month);

    // Get attendance counts
    Map<String, int> attendanceCounts = {};

    // Only load real attendance data for current or past months
    if (!isFutureMonth) {
      attendanceCounts = await attendanceProvider.getMonthlyAttendanceCount(
          widget.year, widget.month);

      // For dates in current month that haven't happened yet, ensure they have 0 attendance
      for (var date in serviceDates) {
        final dateStr = DateFormat('yyyy-MM-dd').format(date);
        if (date.isAfter(now) && !attendanceCounts.containsKey(dateStr)) {
          attendanceCounts[dateStr] = 0;
        }
      }
    } else {
      // For future months, initialize with empty data
      for (var date in serviceDates) {
        final dateStr = DateFormat('yyyy-MM-dd').format(date);
        attendanceCounts[dateStr] = 0;
      }
    }

    return {
      'serviceDates': serviceDates,
      'attendanceCounts': attendanceCounts,
      'isFutureMonth': isFutureMonth,
      'currentDate': now,
    };
  }

  List<DateTime> _getServiceDatesInMonth(int year, int month) {
    final List<DateTime> serviceDates = [];
    final DateTime firstDayOfMonth = DateTime(year, month, 1);
    final DateTime lastDayOfMonth = DateTime(year, month + 1, 0);

    // Start from first day of month
    DateTime currentDay = firstDayOfMonth;

    // Add all Saturdays and Sundays in the month
    while (
        currentDay.isBefore(lastDayOfMonth) || currentDay == lastDayOfMonth) {
      if (currentDay.weekday == DateTime.saturday ||
          currentDay.weekday == DateTime.sunday) {
        serviceDates.add(currentDay);
      }
      currentDay = currentDay.add(const Duration(days: 1));
    }

    return serviceDates;
  }

  @override
  Widget build(BuildContext context) {
    final monthName =
        DateFormat('MMMM yyyy').format(DateTime(widget.year, widget.month));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('$monthName Report'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          // Check if this month should be archived
          if (_shouldShowArchiveOption())
            IconButton(
              icon: const Icon(Icons.archive_outlined),
              tooltip: 'Archive Report',
              onPressed: () {
                _showArchiveConfirmation();
              },
            ),
          // Add refresh button
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Data',
            onPressed: _loadReportData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline,
                            size: 60, color: AppColors.error),
                        const SizedBox(height: 16),
                        Text(
                          'Error: $_errorMessage',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.bodyMedium,
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: _loadReportData,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
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
                )
              : _buildReportContent(),
    );
  }

  bool _shouldShowArchiveOption() {
    if (_reportData == null) return false;

    // Show archive option for past months that have attendance data
    final now = DateTime.now();
    final isPastMonth = widget.year < now.year ||
        (widget.year == now.year && widget.month < now.month);

    if (isPastMonth) {
      final attendanceCounts =
          _reportData!['attendanceCounts'] as Map<String, int>;
      final hasData = attendanceCounts.values.any((count) => count > 0);
      return hasData;
    }

    return false;
  }

  void _showArchiveConfirmation() {
    final monthName =
        DateFormat('MMMM yyyy').format(DateTime(widget.year, widget.month));

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Archive Report'),
        content: Text(
            'Archive the report for $monthName?\n\nYou can access archived reports from the Archive section.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              try {
                // Implement the actual archiving functionality
                final attendanceProvider =
                    Provider.of<AttendanceProvider>(context, listen: false);
                final navigatorContext = Navigator.of(ctx);
                final scaffoldMsgr = ScaffoldMessenger.of(context);
                final isMounted = context.mounted;

                await attendanceProvider.archiveMonthReport(
                    widget.year, widget.month);

                if (isMounted && context.mounted) {
                  navigatorContext.pop();
                  Navigator.of(context).pop(); // Return to reports screen

                  scaffoldMsgr.showSnackBar(
                    SnackBar(
                      content: Text('$monthName report has been archived'),
                      behavior: SnackBarBehavior.floating,
                      margin: const EdgeInsets.all(16),
                    ),
                  );
                }
              } catch (e) {
                Logger.error('Error archiving report', e);

                if (!context.mounted) return;

                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Failed to archive report: $e'),
                    backgroundColor: Colors.red,
                    behavior: SnackBarBehavior.floating,
                    margin: const EdgeInsets.all(16),
                  ),
                );
              }
            },
            child: const Text('Archive'),
          ),
        ],
      ),
    );
  }

  Widget _buildReportContent() {
    final serviceDates = _reportData!['serviceDates'] as List<DateTime>;
    final attendanceCounts =
        _reportData!['attendanceCounts'] as Map<String, int>;
    final isFutureMonth = _reportData!['isFutureMonth'] as bool;
    final currentDate = _reportData!['currentDate'] as DateTime;

    // Find max attendance for chart scaling
    int maxAttendance = 1; // Prevent division by zero
    attendanceCounts.forEach((_, count) {
      if (count > maxAttendance) maxAttendance = count;
    });

    return CustomScrollView(
      slivers: [
        // Month overview card
        SliverToBoxAdapter(
          child: Container(
            margin: const EdgeInsets.all(16),
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
              children: [
                // Header info
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            DateFormat('MMMM yyyy')
                                .format(DateTime(widget.year, widget.month)),
                            style: AppTextStyles.heading2,
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primaryLight.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              '${serviceDates.length} Services',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            isFutureMonth
                                ? Icons.event_available_outlined
                                : Icons.event_available,
                            size: 16,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            isFutureMonth ? 'Upcoming month' : 'Current month',
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Future month indicator
                if (isFutureMonth)
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.info.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: AppColors.info,
                          size: 20,
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'This is a future month. Attendance data will appear after services take place.',
                            style: TextStyle(
                              color: AppColors.info,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Attendance Chart
                Container(
                  height: 200,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.bar_chart,
                            size: 14,
                            color: AppColors.textSecondary,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Attendance Chart',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Added a container to prevent overflow
                      Expanded(
                        child: serviceDates.isEmpty
                            ? const Center(
                                child: Text(
                                  'No service dates in this month',
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              )
                            : serviceDates.length > 7
                                ? _buildScrollableChart(
                                    serviceDates,
                                    attendanceCounts,
                                    maxAttendance,
                                    currentDate)
                                : _buildFixedChart(
                                    serviceDates,
                                    attendanceCounts,
                                    maxAttendance,
                                    currentDate),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // Services list header
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Row(
              children: [
                Icon(
                  Icons.view_list,
                  size: 16,
                  color: AppColors.textSecondary,
                ),
                SizedBox(width: 8),
                Text(
                  'Service Details',
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

        // Services list
        serviceDates.isEmpty
            ? const SliverToBoxAdapter(
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(24.0),
                    child: Column(
                      children: [
                        Icon(
                          Icons.event_busy,
                          size: 48,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'No services in this month',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            : SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    if (index >= serviceDates.length) return null;

                    final date = serviceDates[index];
                    final dateStr = DateFormat('yyyy-MM-dd').format(date);
                    final formattedDate =
                        DateFormat('EEEE, MMMM d, yyyy').format(date);
                    final count = attendanceCounts[dateStr] ?? 0;

                    // KEY FIX: Don't block navigation to services in current month!
                    // Only check if this date is in a future month
                    bool isInFutureMonth = isFutureMonth;

                    // For current month, differentiate between past and upcoming services
                    bool isUpcomingService = date.isAfter(currentDate);

                    bool canAccess =
                        !isInFutureMonth; // Allow access to all dates in current or past months

                    return Container(
                      margin: EdgeInsets.fromLTRB(
                          16, 0, 16, index == serviceDates.length - 1 ? 16 : 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            // Fixed: Use the correct way to reference AttendanceDayDetailScreen
                            onTap: canAccess
                                ? () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            AttendanceDayDetailScreen(
                                          date: date,
                                          formattedDate: formattedDate,
                                          attendanceCount: count,
                                        ),
                                      ),
                                    ).then((_) => _loadReportData());
                                  }
                                : () {
                                    // Show message that it's a future month service
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: const Text(
                                            'Future month service details are not available yet'),
                                        backgroundColor: AppColors.info,
                                        behavior: SnackBarBehavior.floating,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        margin: const EdgeInsets.all(16),
                                        duration: const Duration(seconds: 2),
                                      ),
                                    );
                                  },
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Row(
                                children: [
                                  // Day display
                                  Container(
                                    width: 50,
                                    height: 50,
                                    decoration: BoxDecoration(
                                      color: isInFutureMonth
                                          ? Colors.grey.shade100
                                          : isUpcomingService
                                              ? Colors.amber
                                                  .shade100 // Upcoming services in current month
                                              : (count > 0
                                                  ? AppColors.primary
                                                  : Colors.grey.shade200),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          date.day.toString(),
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: isInFutureMonth
                                                ? AppColors.textSecondary
                                                : isUpcomingService
                                                    ? Colors.amber
                                                        .shade800 // Color for upcoming services
                                                    : (count > 0
                                                        ? Colors.white
                                                        : AppColors
                                                            .textSecondary),
                                          ),
                                        ),
                                        Text(
                                          DateFormat('E').format(date),
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: isInFutureMonth
                                                ? AppColors.textSecondary
                                                : isUpcomingService
                                                    ? Colors.amber.shade800
                                                    : (count > 0
                                                        ? Colors.white
                                                        : AppColors
                                                            .textSecondary),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 16),

                                  // Service details
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          formattedDate,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w500,
                                            fontSize: 14,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Icon(
                                              isInFutureMonth
                                                  ? Icons
                                                      .event_available_outlined
                                                  : isUpcomingService
                                                      ? Icons.upcoming
                                                      : (count > 0
                                                          ? Icons.people
                                                          : Icons
                                                              .people_outline),
                                              size: 14,
                                              color: isInFutureMonth
                                                  ? AppColors.info
                                                  : isUpcomingService
                                                      ? Colors.amber.shade800
                                                      : (count > 0
                                                          ? AppColors.success
                                                          : AppColors
                                                              .textSecondary),
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              isInFutureMonth
                                                  ? 'Future month service'
                                                  : isUpcomingService
                                                      ? 'Upcoming service (accessible)'
                                                      : (count > 0
                                                          ? '$count students present' // Changed from 'children' to 'students'
                                                          : 'No attendance recorded'),
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: isInFutureMonth
                                                    ? AppColors.info
                                                    : isUpcomingService
                                                        ? Colors.amber.shade800
                                                        : (count > 0
                                                            ? AppColors.success
                                                            : AppColors
                                                                .textSecondary),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Navigation icon
                                  Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: canAccess
                                          ? AppColors.primary.withOpacity(0.1)
                                          : Colors.grey.shade100,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Center(
                                      child: Icon(
                                        canAccess
                                            ? Icons.navigate_next
                                            : Icons.lock_clock,
                                        color: canAccess
                                            ? AppColors.primary
                                            : AppColors.textSecondary,
                                        size: 24,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                  childCount: serviceDates.length,
                ),
              ),
      ],
    );
  }

  // Fixed width chart for small number of dates
  Widget _buildFixedChart(
      List<DateTime> serviceDates,
      Map<String, int> attendanceCounts,
      int maxAttendance,
      DateTime currentDate) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: serviceDates.map((date) {
        final dateStr = DateFormat('yyyy-MM-dd').format(date);
        final count = attendanceCounts[dateStr] ?? 0;
        final dayNumber = date.day;
        final weekday = DateFormat('E').format(date);

        // Determine if this is a future date in the current month
        final isUpcomingDate = date.isAfter(currentDate);

        const double barMaxHeight = 120.0;
        final double barHeight = count > 0
            ? (count / maxAttendance) * barMaxHeight * 0.9 + barMaxHeight * 0.1
            : barMaxHeight * 0.1;

        return Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // Attendance count
              Text(
                count.toString(),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),

              // Bar
              AnimatedContainer(
                duration: const Duration(milliseconds: 500),
                height: barHeight,
                width: 25,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: isUpcomingDate
                        ? [Colors.amber.shade200, Colors.amber.shade100]
                        : count > 0
                            ? [AppColors.primary, AppColors.primaryLight]
                            : [Colors.grey.shade300, Colors.grey.shade200],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (isUpcomingDate
                              ? Colors.amber
                              : count > 0
                                  ? AppColors.primary
                                  : Colors.grey)
                          .withOpacity(0.2),
                      offset: const Offset(0, 3),
                      blurRadius: 4,
                      spreadRadius: 0,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // Weekday label
              Text(
                weekday,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),

              // Day number
              Text(
                dayNumber.toString(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isUpcomingDate ? Colors.amber.shade800 : Colors.black,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // Scrollable chart for many dates
  Widget _buildScrollableChart(
      List<DateTime> serviceDates,
      Map<String, int> attendanceCounts,
      int maxAttendance,
      DateTime currentDate) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: serviceDates.map((date) {
          final dateStr = DateFormat('yyyy-MM-dd').format(date);
          final count = attendanceCounts[dateStr] ?? 0;
          final dayNumber = date.day;
          final weekday = DateFormat('E').format(date);

          // Determine if this is a future date in the current month
          final isUpcomingDate = date.isAfter(currentDate);

          const double barMaxHeight = 120.0;
          final double barHeight = count > 0
              ? (count / maxAttendance) * barMaxHeight * 0.9 +
                  barMaxHeight * 0.1
              : barMaxHeight * 0.1;

          return Container(
            width: 50, // Fixed width for each bar
            margin: const EdgeInsets.symmetric(horizontal: 4),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Attendance count
                Text(
                  count.toString(),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),

                // Bar
                AnimatedContainer(
                  duration: const Duration(milliseconds: 500),
                  height: barHeight,
                  width: 25,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: isUpcomingDate
                          ? [Colors.amber.shade200, Colors.amber.shade100]
                          : count > 0
                              ? [AppColors.primary, AppColors.primaryLight]
                              : [Colors.grey.shade300, Colors.grey.shade200],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: (isUpcomingDate
                                ? Colors.amber
                                : count > 0
                                    ? AppColors.primary
                                    : Colors.grey)
                            .withOpacity(0.2),
                        offset: const Offset(0, 3),
                        blurRadius: 4,
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // Weekday label
                Text(
                  weekday,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),

                // Day number
                Text(
                  dayNumber.toString(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color:
                        isUpcomingDate ? Colors.amber.shade800 : Colors.black,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
