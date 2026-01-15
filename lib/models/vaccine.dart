class Vaccine {
  final String? id;
  final String petId;
  final String name;
  final DateTime date;
  final bool isDone;
  final String? note;
  final int? frequencyMonths;

  Vaccine({
    this.id,
    required this.petId,
    required this.name,
    required this.date,
    this.isDone = false,
    this.note,
    this.frequencyMonths,
  });

  Vaccine copyWith({
    String? id,
    String? petId,
    String? name,
    DateTime? date,
    bool? isDone,
    String? note,
    int? frequencyMonths,
  }) {
    return Vaccine(
      id: id ?? this.id,
      petId: petId ?? this.petId,
      name: name ?? this.name,
      date: date ?? this.date,
      isDone: isDone ?? this.isDone,
      note: note ?? this.note,
      frequencyMonths: frequencyMonths ?? this.frequencyMonths,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'petId': petId,
      'name': name,
      'date': date.toIso8601String(),
      'isDone': isDone,
      'note': note,
      'frequencyMonths': frequencyMonths,
    };
  }

  factory Vaccine.fromMap(Map<String, dynamic> map, String documentId) {
    return Vaccine(
      id: documentId,
      petId: map['petId'] ?? '',
      name: map['name'] ?? '',
      date: map['date'] != null ? DateTime.parse(map['date']) : DateTime.now(),
      isDone: map['isDone'] ?? false,
      note: map['note'],
      frequencyMonths: map['frequencyMonths'],
    );
  }
}
