class Appointment {
  final String? id;
  final String petId;
  final String title;
  final String? description;
  final DateTime dateTime;
  final String category;
  final String? location;
  final double? cost;
  final bool isDone;

  Appointment({
    this.id,
    required this.petId,
    required this.title,
    this.description,
    required this.dateTime,
    required this.category,
    this.location,
    this.cost,
    this.isDone = false,
  });

  Appointment copyWith({
    String? id,
    String? petId,
    String? title,
    String? description,
    DateTime? dateTime,
    String? category,
    String? location,
    double? cost,
    bool? isDone,
  }) {
    return Appointment(
      id: id ?? this.id,
      petId: petId ?? this.petId,
      title: title ?? this.title,
      description: description ?? this.description,
      dateTime: dateTime ?? this.dateTime,
      category: category ?? this.category,
      location: location ?? this.location,
      cost: cost ?? this.cost,
      isDone: isDone ?? this.isDone,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'petId': petId,
      'title': title,
      'description': description,
      'dateTime': dateTime.toIso8601String(),
      'category': category,
      'location': location,
      'cost': cost,
      'isDone': isDone,
    };
  }

  factory Appointment.fromMap(Map<String, dynamic> map, String documentId) {
    return Appointment(
      id: documentId,
      petId: map['petId'] ?? '',
      title: map['title'] ?? '',
      description: map['description'],
      dateTime: map['dateTime'] != null ? DateTime.parse(map['dateTime']) : DateTime.now(),
      category: map['category'] ?? 'Diğer',
      location: map['location'],
      cost: map['cost']?.toDouble(),
      isDone: map['isDone'] ?? false,
    );
  }
}
