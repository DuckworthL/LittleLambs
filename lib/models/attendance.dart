class Attendance {
  final int? id;
  final int childId;
  final String date; // Store as YYYY-MM-DD
  final bool isPresent;

  Attendance({
    this.id,
    required this.childId,
    required this.date,
    required this.isPresent,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'childId': childId,
      'date': date,
      'isPresent': isPresent ? 1 : 0,
    };
  }

  factory Attendance.fromMap(Map<String, dynamic> map) {
    return Attendance(
      id: map['id'],
      childId: map['childId'],
      date: map['date'],
      isPresent: map['isPresent'] == 1,
    );
  }
}
