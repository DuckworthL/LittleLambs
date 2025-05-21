class Child {
  final int? id;
  final String name;
  final int age;
  final String? notes;
  final String groupName;

  Child({
    this.id,
    required this.name,
    required this.age,
    this.notes,
    required this.groupName,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'age': age,
      'notes': notes,
      'groupName': groupName,
    };
  }

  factory Child.fromMap(Map<String, dynamic> map) {
    return Child(
      id: map['id'],
      name: map['name'],
      age: map['age'],
      notes: map['notes'],
      groupName: map['groupName'],
    );
  }
}
