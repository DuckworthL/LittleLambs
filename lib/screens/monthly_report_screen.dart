import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/attendance_provider.dart';

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
      appBar: AppBar(
        title: Text('$monthName Report'),
      ),
      body: FutureBuilder(
        future: _loadReportData(context),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 60, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error: ${snapshot.error}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      // Force rebuild to retry
                      (context as Element).markNeedsBuild();
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final data = snapshot.data as Map<String, dynamic>;
          final serviceDates = data['serviceDates'] as List<DateTime>;
          final attendanceCounts = data['attendanceCounts'] as Map<String, int>;
          final isFutureMonth = data['isFutureMonth'] as bool;

          return Column(
            children: [
              // Month overview card
              Card(
                margin: const EdgeInsets.all(16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text(
                        monthName,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '${serviceDates.length} Services',
                        style: const TextStyle(fontSize: 18),
                      ),

                      // Future month indicator
                      if (isFutureMonth)
                        Container(
                          padding: const EdgeInsets.all(8),
                          margin: const EdgeInsets.only(top: 10),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.info_outline, color: Colors.blue),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'This is a future month. Attendance data will appear after services take place.',
                                  style: TextStyle(color: Colors.blue),
                                ),
                              ),
                            ],
                          ),
                        ),

                      const SizedBox(height: 15),

                      // Simple attendance graph
                      SizedBox(
                        height: 120,
                        child: Row(
                          children: serviceDates.map((date) {
                            final dateStr =
                                DateFormat('yyyy-MM-dd').format(date);
                            final count = attendanceCounts[dateStr] ?? 0;
                            const maxHeight = 100.0;
                            final height = count > 0
                                ? maxHeight * (0.3 + (count / 20))
                                : // Scale for visual appeal
                                10.0; // Minimum height if zero

                            return Expanded(
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 4),
                                child: Column(
                                  children: [
                                    Text(
                                      count.toString(),
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 5),
                                    Container(
                                      height: height,
                                      decoration: BoxDecoration(
                                        color: count > 0
                                            ? Colors.blue
                                            : Colors.grey[300],
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ),
                                    const SizedBox(height: 5),
                                    Text(
                                      DateFormat('d').format(date),
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Service list
              Expanded(
                child: ListView.builder(
                  itemCount: serviceDates.length,
                  itemBuilder: (context, index) {
                    final date = serviceDates[index];
                    final dateStr = DateFormat('yyyy-MM-dd').format(date);
                    final formattedDate =
                        DateFormat('EEEE, MMMM d, yyyy').format(date);
                    final count = attendanceCounts[dateStr] ?? 0;

                    // Determine if this date is in the future
                    final now = DateTime.now();
                    final isFutureDate = date.isAfter(now);

                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 4),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isFutureDate
                              ? Colors.grey.shade300
                              : (count > 0 ? Colors.blue : Colors.grey),
                          child: Text(
                            DateFormat('d').format(date),
                            style: TextStyle(
                              color:
                                  isFutureDate ? Colors.black54 : Colors.white,
                            ),
                          ),
                        ),
                        title: Text(formattedDate),
                        subtitle: Text(
                          isFutureDate
                              ? 'Upcoming service'
                              : (count > 0
                                  ? '$count children present'
                                  : 'No attendance recorded'),
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          // Navigate to daily detail view in the future
                          // (or show message that it's an upcoming service)
                          if (isFutureDate) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('This is an upcoming service'),
                                duration: Duration(seconds: 1),
                              ),
                            );
                          } else {
                            // Could navigate to a detailed attendance screen for this date
                          }
                        },
                      ),
                    );
                  },
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
