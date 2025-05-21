import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/attendance_provider.dart';
import '../providers/children_provider.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';
import 'monthly_report_screen.dart';


class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  bool _showArchive = false;
  final int _maxFutureMonths = 12; // Show up to 12 months in the future
  bool _isLoadingAttendance = true;
  Map<int, int> _attendanceData = {};

  @override
  void initState() {
    super.initState();
    _loadAttendanceData();
  }

  Future<void> _loadAttendanceData() async {
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

      setState(() {
        _attendanceData = data;
        _isLoadingAttendance = false;
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error loading attendance data: $e');
      }
      setState(() => _isLoadingAttendance = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final currentYear = now.year;
    final currentMonth = now.month;

    final childrenProvider = Provider.of<ChildrenProvider>(context);
    final children = childrenProvider.children;

    // Create list of future months
    List<Widget> futureMonths = [];
    for (int i = 0; i < _maxFutureMonths; i++) {
      final futureMonth = (currentMonth + i) % 12;
      final futureYear = currentYear + ((currentMonth + i) ~/ 12);
      final actualMonth = futureMonth == 0 ? 12 : futureMonth;

      futureMonths.add(
        _MonthCard(
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
          _MonthCard(
            year: archiveYear,
            month: archiveMonth,
          ),
        );
      }
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // App bar
          SliverAppBar(
            expandedHeight: 130.0,
            pinned: true,
            backgroundColor: AppColors.primary,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: AppColors.primaryGradient,
                ),
                child: const SafeArea(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(20, 60, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Attendance Reports',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8),
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
              title: const Padding(
                padding: EdgeInsets.only(left: 16.0),
                child: Text(
                  'Attendance Reports',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
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
                    'Monthly Reports',
                    style: AppTextStyles.heading3,
                  ),
                ],
              ),
            ),
          ),

          // Future months list
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                if (index >= futureMonths.length) return null;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: futureMonths[index],
                );
              },
              childCount: futureMonths.length,
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

  const _MonthCard({
    required this.year,
    required this.month,
    this.isCurrentMonth = false,
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
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
        child: Material(
          color: Colors.transparent,
          child: InkWell(
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
                          : Colors.grey.shade100,
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
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
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

                            final data = snapshot.data as Map<String, int>;
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
                  // Arrow
                  const Icon(
                    Icons.chevron_right,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
