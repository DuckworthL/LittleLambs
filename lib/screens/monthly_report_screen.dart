import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/attendance_provider.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';

class MonthlyReportScreen extends StatelessWidget {
  final int year;
  final int month;
  
  const MonthlyReportScreen({
    super.key,
    required this.year,
    required this.month,
  });

  @override
  Widget build(BuildContext context) {
    final monthName = DateFormat('MMMM yyyy').format(DateTime(year, month));
    
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('$monthName Report'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: FutureBuilder(
        future: _loadReportData(context),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }
          
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 60, color: AppColors.error),
                    const SizedBox(height: 16),
                    Text(
                      'Error: ${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodyMedium,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () {
                        // Force rebuild to retry
                        (context as Element).markNeedsBuild();
                      },
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
            );
          }
          
          final data = snapshot.data as Map<String, dynamic>;
          final serviceDates = data['serviceDates'] as List<DateTime>;
          final attendanceCounts = data['attendanceCounts'] as Map<String, int>;
          final isFutureMonth = data['isFutureMonth'] as bool;
          
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
                                  monthName,
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
                                  isFutureMonth
                                      ? 'Upcoming month'
                                      : 'Historical data',
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
                            Expanded(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: serviceDates.map((date) {
                                  final dateStr = DateFormat('yyyy-MM-dd').format(date);
                                  final count = attendanceCounts[dateStr] ?? 0;
                                  final dayNumber = date.day;
                                  final weekday = DateFormat('E').format(date); // Mon, Tue, etc.
                                  
                                  const double barMaxHeight = 120.0;
                                  // Scale bar height relative to max attendance, minimum 10% height
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
                                          duration:
                                              const Duration(milliseconds: 500),
                                          height: barHeight,
                                          width: 25,
                                          decoration: BoxDecoration(
                                            borderRadius:
                                                BorderRadius.circular(6),
                                            gradient: LinearGradient(
                                              begin: Alignment.bottomCenter,
                                              end: Alignment.topCenter,
                                              colors: count > 0
                                                  ? [
                                                      AppColors.primary,
                                                      AppColors.primaryLight
                                                    ]
                                                  : [
                                                      Colors.grey.shade300,
                                                      Colors.grey.shade200
                                                    ],
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: (count > 0
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
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Services list header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.view_list,
                        size: 16,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Service Details',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Container(
                          height: 1,
                          color: Colors.grey.shade300,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Services list
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    if (index >= serviceDates.length) return null;

                    final date = serviceDates[index];
                    final dateStr = DateFormat('yyyy-MM-dd').format(date);
                    final formattedDate =
                        DateFormat('EEEE, MMMM d, yyyy').format(date);
                    final count = attendanceCounts[dateStr] ?? 0;

                    // Determine if this date is in the future
                    final now = DateTime.now();
                    final isFutureDate = date.isAfter(now);

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
                            onTap: () {
                              // Navigate to daily detail view in the future
                              // (or show message that it's an upcoming service)
                              if (isFutureDate) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: const Text(
                                        'This is an upcoming service'),
                                    backgroundColor: AppColors.info,
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    margin: const EdgeInsets.all(16),
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                              } else {
                                // Could navigate to a detailed attendance screen for this date
                              }
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
                                      color: isFutureDate
                                          ? Colors.grey.shade100
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
                                            color: isFutureDate
                                                ? AppColors.textSecondary
                                                : (count > 0
                                                    ? Colors.white
                                                    : AppColors.textSecondary),
                                          ),
                                        ),
                                        Text(
                                          DateFormat('E').format(date),
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: isFutureDate
                                                ? AppColors.textSecondary
                                                : (count > 0
                                                    ? Colors.white
                                                    : AppColors.textSecondary),
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
                                              isFutureDate
                                                  ? Icons
                                                      .event_available_outlined
                                                  : (count > 0
                                                      ? Icons.people
                                                      : Icons.people_outline),
                                              size: 14,
                                              color: isFutureDate
                                                  ? AppColors.info
                                                  : (count > 0
                                                      ? AppColors.success
                                                      : AppColors
                                                          .textSecondary),
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              isFutureDate
                                                  ? 'Upcoming service'
                                                  : (count > 0
                                                      ? '$count children present'
                                                      : 'No attendance recorded'),
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: isFutureDate
                                                    ? AppColors.info
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

                                  // Arrow
                                  const Icon(
                                    Icons.navigate_next,
                                    color: AppColors.textSecondary,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                  // We don't know exactly how many items, but this is a reasonable upper bound
                  childCount: serviceDates.length + 1,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<Map<String, dynamic>> _loadReportData(BuildContext context) async {
    final attendanceProvider =
        Provider.of<AttendanceProvider>(context, listen: false);

    // Get service dates (Sat & Sun) in the month
    final serviceDates = _getServiceDatesInMonth(year, month);

    // Check if this is a future month
    final now = DateTime.now();
    final isCurrentOrPastMonth =
        year < now.year || (year == now.year && month <= now.month);

    // Get attendance counts for past months only
    Map<String, int> attendanceCounts = {};

    if (isCurrentOrPastMonth) {
      attendanceCounts =
          await attendanceProvider.getMonthlyAttendanceCount(year, month);
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
      'isFutureMonth': !isCurrentOrPastMonth,
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
}
