class Point {
  final int? id;
  final int childId;
  final String date; // Store as YYYY-MM-DD
  final int amount;
  final String? reason;

  Point({
    this.id,
    required this.childId,
    required this.date,
    required this.amount,
    this.reason,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'childId': childId,
      'date': date,
      'amount': amount,
      'reason': reason,
    };
  }

  factory Point.fromMap(Map<String, dynamic> map) {
    return Point(
      id: map['id'],
      childId: map['childId'],
      date: map['date'],
      amount: map['amount'],
      reason: map['reason'],
    );
  }
}
