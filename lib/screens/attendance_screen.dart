import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/children_provider.dart';
import '../providers/attendance_provider.dart';
import '../models/child.dart';
import '../constants/app_colors.dart';

class AttendanceScreen extends StatefulWidget {
  final String date;

  const AttendanceScreen({
    super.key,
    required this.date,
  });

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen>
    with TickerProviderStateMixin {
  TabController? _tabController;
  bool _isLoading = true;
  String _selectedDate = '';

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.date;
    _loadData();
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final childrenProvider =
        Provider.of<ChildrenProvider>(context, listen: false);
    final attendanceProvider =
        Provider.of<AttendanceProvider>(context, listen: false);

    await childrenProvider.fetchAndSetChildren();
    await attendanceProvider.fetchAttendanceForDate(_selectedDate);

    _tabController?.dispose();

    if (childrenProvider.groups.isNotEmpty) {
      _tabController = TabController(
        length: childrenProvider.groups.length,
        vsync: this,
      );
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    bool isWeekendDay(DateTime date) =>
        date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _getNextServiceDay(DateTime.now()),
      firstDate: DateTime(2020),
      lastDate: DateTime(2050),
      selectableDayPredicate: isWeekendDay,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: AppColors.surface,
              onSurface: AppColors.textPrimary,
            ),
            datePickerTheme: DatePickerThemeData(
              dayStyle: const TextStyle(fontSize: 13),
              yearStyle: const TextStyle(fontSize: 13),
              headerBackgroundColor: AppColors.primary,
              headerForegroundColor: Colors.white,
              backgroundColor: AppColors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedDate = DateFormat('yyyy-MM-dd').format(picked);
        _loadData();
      });
    }
  }

  DateTime _getNextServiceDay(DateTime date) {
    if (date.weekday == DateTime.saturday || date.weekday == DateTime.sunday) {
      return date;
    }

    final daysToSaturday = (DateTime.saturday - date.weekday) % 7;
    final daysToSunday = (DateTime.sunday - date.weekday) % 7;

    final daysToClosestService =
        daysToSaturday < daysToSunday ? daysToSaturday : daysToSunday;

    return date.add(Duration(days: daysToClosestService));
  }

  @override
  Widget build(BuildContext context) {
    final childrenProvider = Provider.of<ChildrenProvider>(context);
    final attendanceProvider = Provider.of<AttendanceProvider>(context);

    final selectedDateTime = DateTime.parse(_selectedDate);
    final weekday = DateFormat('EEEE').format(selectedDateTime);
    final formattedDate = DateFormat('MMMM d, yyyy').format(selectedDateTime);

    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Loading...'),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        body: const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Attendance'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(120),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Date display
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            weekday,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            weekday == "Saturday"
                                ? Icons.weekend
                                : Icons.church,
                            color: Colors.white,
                            size: 16,
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => _selectDate(context),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.calendar_month,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  formattedDate,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),

                // Group tabs
                if (childrenProvider.groups.isNotEmpty &&
                    _tabController != null)
                  Container(
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      isScrollable: true,
                      indicatorSize: TabBarIndicatorSize.tab,
                      indicator: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      labelColor: AppColors.primary,
                      unselectedLabelColor: Colors.white,
                      labelStyle: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                      unselectedLabelStyle: const TextStyle(
                        fontWeight: FontWeight.normal,
                        fontSize: 12,
                      ),
                      tabs: childrenProvider.groups
                          .map((group) => Tab(text: group))
                          .toList(),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      body: childrenProvider.groups.isEmpty
          ? const _EmptyState(
              message: 'No groups defined yet. Add children first.')
          : _tabController == null
              ? const _EmptyState(message: 'Error initializing tabs')
              : Column(
                  children: [
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: childrenProvider.groups.map((group) {
                          final children =
                              childrenProvider.getChildrenByGroup(group);
                          return AttendanceList(
                            children: children,
                            date: _selectedDate,
                          );
                        }).toList(),
                      ),
                    ),
                    // Stats footer
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            offset: const Offset(0, -3),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.people_alt,
                                color: AppColors.primary,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Present: ${attendanceProvider.getPresentCountForDate(_selectedDate)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(context),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                            ),
                            child: const Text('Done'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String message;

  const _EmptyState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.people_outline,
              size: 60,
              color: AppColors.textLight,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: const TextStyle(
                fontSize: 16,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class AttendanceList extends StatelessWidget {
  final List<Child> children;
  final String date;

  const AttendanceList({
    super.key,
    required this.children,
    required this.date,
  });

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) {
      return const _EmptyState(message: 'No children in this group');
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: children.length,
      itemBuilder: (context, index) {
        return AttendanceListItem(
          child: children[index],
          date: date,
        );
      },
    );
  }
}

class AttendanceListItem extends StatelessWidget {
  final Child child;
  final String date;

  const AttendanceListItem({
    super.key,
    required this.child,
    required this.date,
  });

  @override
  Widget build(BuildContext context) {
    final attendanceProvider = Provider.of<AttendanceProvider>(context);
    final isPresent = attendanceProvider.isChildPresent(child.id!, date);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () {
          attendanceProvider.markAttendance(child.id!, date, !isPresent);
        },
        borderRadius: BorderRadius.circular(12),
        splashColor: AppColors.primary.withOpacity(0.1),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 24,
                backgroundColor:
                    isPresent ? AppColors.success : Colors.grey.shade300,
                child: Icon(
                  isPresent ? Icons.check : Icons.person,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              // Child info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      child.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      'Age: ${child.age}',
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              // Attendance switch
              Switch(
                value: isPresent,
                activeColor: AppColors.success,
                onChanged: (newValue) {
                  attendanceProvider.markAttendance(child.id!, date, newValue);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
