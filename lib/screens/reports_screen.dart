import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/attendance_provider.dart';
import '../providers/children_provider.dart';
import 'monthly_report_screen.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  bool _showArchive = false;
  final int _maxFutureMonths = 12; // Show up to 12 months in the future

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final currentYear = now.year;
    final currentMonth = now.month;

    // Create list of future months
    List<Widget> futureMonths = [];
    for (int i = 0; i < _maxFutureMonths; i++) {
      final futureMonth = (currentMonth + i) % 12;
      final futureYear = currentYear + ((currentMonth + i) ~/ 12);
      final actualMonth = futureMonth == 0 ? 12 : futureMonth;

      futureMonths.add(
        ReportMonthCard(
          year: futureYear,
          month: actualMonth,
          isCurrentMonth: i == 0,
        ),
      );
    }

    // Create list of archived months
    List<Widget> archivedMonths = [];
    if (_showArchive) {
      // Add 24 previous months to archive
      for (int i = 1; i <= 24; i++) {
        int archiveMonth = currentMonth - i;
        int archiveYear = currentYear;

        while (archiveMonth <= 0) {
          archiveMonth += 12;
          archiveYear -= 1;
        }

        archivedMonths.add(
          ReportMonthCard(
            year: archiveYear,
            month: archiveMonth,
          ),
        );
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance Reports'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Monthly Reports',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),

            // Future months
            ...futureMonths,

            // Archive section
            const SizedBox(height: 20),
            GestureDetector(
              onTap: () {
                setState(() {
                  _showArchive = !_showArchive;
                });
              },
              child: Row(
                children: [
                  Icon(
                    _showArchive ? Icons.arrow_drop_down : Icons.arrow_right,
                    size: 28,
                  ),
                  const Text(
                    'Archive',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            if (_showArchive) ...archivedMonths,

            const SizedBox(height: 20),

            // Child attendance section
            const Text(
              'Children Attendance',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            const ChildrenReportList(),
          ],
        ),
      ),
    );
  }
}

class ReportMonthCard extends StatelessWidget {
  final int year;
  final int month;
  final bool isCurrentMonth;

  const ReportMonthCard({
    super.key,
    required this.year,
    required this.month,
    this.isCurrentMonth = false,
  });

  @override
  Widget build(BuildContext context) {
    final monthName = DateFormat('MMMM').format(DateTime(year, month));

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isCurrentMonth ? Colors.blue : Colors.grey,
          child: Text(
            month.toString(),
            style: const TextStyle(color: Colors.white),
          ),
        ),
        title: Text('$monthName $year'),
        subtitle: FutureBuilder(
          future: Provider.of<AttendanceProvider>(context, listen: false)
              .getMonthlyAttendanceCount(year, month),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Text('Loading...');
            }

            if (snapshot.hasError) {
              return const Text('Error loading data');
            }

            final data = snapshot.data as Map<String, int>;
            final serviceCount = data.length;

            // Show different text based on whether it's a past or future month
            final now = DateTime.now();
            final isPastOrPresent =
                (year < now.year) || (year == now.year && month <= now.month);

            if (isPastOrPresent) {
              return serviceCount > 0
                  ? Text('$serviceCount services recorded')
                  : const Text('No services recorded');
            } else {
              // Future month
              return const Text('Upcoming month');
            }
          },
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => MonthlyReportScreen(
                year: year,
                month: month,
              ),
            ),
          );
        },
      ),
    );
  }
}

class ChildrenReportList extends StatelessWidget {
  const ChildrenReportList({super.key});

  @override
  Widget build(BuildContext context) {
    final childrenProvider = Provider.of<ChildrenProvider>(context);
    final attendanceProvider = Provider.of<AttendanceProvider>(context);

    final children = childrenProvider.children;
    if (children.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text('No children added yet'),
        ),
      );
    }

    // Get first day of current month
    final now = DateTime.now();
    final firstDayOfMonth = DateTime(now.year, now.month, 1);
    final startDate = DateFormat('yyyy-MM-dd').format(firstDayOfMonth);
    final endDate = DateFormat('yyyy-MM-dd').format(now);

    return FutureBuilder(
      future: attendanceProvider.getAttendanceCountByChild(
        children.map((c) => c.id!).toList(),
        startDate,
        endDate,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            padding: const EdgeInsets.all(16),
            child: const Center(
              child: Column(
                children: [
                  SizedBox(
                    width: 30,
                    height: 30,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(height: 8),
                  Text('Loading attendance data...'),
                ],
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 40),
                  const SizedBox(height: 8),
                  Text('Error loading data: ${snapshot.error}'),
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
            ),
          );
        }

        final attendanceData = snapshot.data ?? <int, int>{};

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: children.length,
          itemBuilder: (context, index) {
            final child = children[index];
            final attendanceCount = attendanceData[child.id!] ?? 0;

            return Card(
              child: ListTile(
                title: Text(child.name),
                subtitle: Text('${child.groupName} • Age: ${child.age}'),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '$attendanceCount',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Text('days'),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
