import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/children_provider.dart';
import '../providers/attendance_provider.dart';
import '../models/child.dart';

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
  // Changed from SingleTickerProviderStateMixin
  TabController? _tabController; // Make nullable
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
    _tabController?.dispose(); // Dispose when done
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

    // Dispose previous controller if it exists
    _tabController?.dispose();

    // Create new controller only if there are groups
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
    // Allow Saturday and Sunday to be selected
    bool isWeekendDay(DateTime date) =>
        date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;


    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _getNextServiceDay(DateTime.now()),
      firstDate: DateTime(2020),
      lastDate: DateTime(2050), // Extended to support far future dates
      selectableDayPredicate: isWeekendDay,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            datePickerTheme: const DatePickerThemeData(
              // More compact date picker to avoid overflow
              dayStyle: TextStyle(fontSize: 13),
              yearStyle: TextStyle(fontSize: 13),
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
    // If already on weekend, return current date
    if (date.weekday == DateTime.saturday || date.weekday == DateTime.sunday) {
      return date;
    }

    // Find closest weekend day
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
    final formattedDate =
        DateFormat('EEEE, MMMM d, yyyy').format(DateTime.parse(_selectedDate));

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Loading...'),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          children: [
            const Text('Attendance'),
            Text(
              formattedDate,
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month),
            onPressed: () => _selectDate(context),
          ),
        ],
        bottom: childrenProvider.groups.isNotEmpty && _tabController != null
            ? TabBar(
                controller: _tabController,
                tabs: childrenProvider.groups
                    .map((group) => Tab(text: group))
                    .toList(),
                isScrollable: true,
              )
            : null,
      ),
      body: childrenProvider.groups.isEmpty
          ? const Center(
              child: Text('No groups defined yet. Add children first.'),
            )
          : _tabController == null
              ? const Center(child: Text('Error initializing tabs'))
              : TabBarView(
                  controller: _tabController,
                  children: childrenProvider.groups.map((group) {
                    final children = childrenProvider.getChildrenByGroup(group);
                    return AttendanceList(
                      children: children,
                      date: _selectedDate,
                    );
                  }).toList(),
                ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Total Present: ${attendanceProvider.getPresentCountForDate(_selectedDate)}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Done'),
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
      return const Center(
        child: Text('No children in this group'),
      );
    }

    return ListView.builder(
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

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isPresent ? Colors.green : Colors.grey,
          child: Icon(
            isPresent ? Icons.check : Icons.person,
            color: Colors.white,
          ),
        ),
        title: Text(
          child.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text('Age: ${child.age}'),
        trailing: Switch(
          value: isPresent,
          activeColor: Colors.green,
          onChanged: (newValue) {
            attendanceProvider.markAttendance(child.id!, date, newValue);
          },
        ),
      ),
    );
  }
}
