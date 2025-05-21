class Point {
  final int? id;
  final int childId;
  final String childName;
  final String groupName;
  final String date;
  final int amount;
  final String? reason;

  Point({
    this.id,
    required this.childId,
    required this.childName,
    required this.groupName,
    required this.date,
    required this.amount,
    this.reason,
  });
}
