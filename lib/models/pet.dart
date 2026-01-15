class Pet {
  final String? id;
  final String name;
  final String type;
  final int age;
  final String weight;
  final String breed;
  final String? imagePath;
  final DateTime? birthDate;
  final String? gender;
  final bool? neutered;

  Pet({
    this.id,
    required this.name,
    required this.type,
    required this.age,
    required this.weight,
    required this.breed,
    this.imagePath,
    this.birthDate,
    this.gender,
    this.neutered,
  });

  Pet copyWith({
    String? id,
    String? name,
    String? type,
    int? age,
    String? weight,
    String? breed,
    String? imagePath,
    DateTime? birthDate,
    String? gender,
    bool? neutered,
  }) {
    return Pet(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      age: age ?? this.age,
      weight: weight ?? this.weight,
      breed: breed ?? this.breed,
      imagePath: imagePath ?? this.imagePath,
      birthDate: birthDate ?? this.birthDate,
      gender: gender ?? this.gender,
      neutered: neutered ?? this.neutered,
    );
  }

  // Firestore & General usage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'age': age,
      'weight': weight,
      'breed': breed,
      'imagePath': imagePath,
      'birthDate': birthDate?.toIso8601String(),
      'gender': gender,
      'neutered': neutered,
    };
  }

  // Helper also for JSON/Firebase
  Map<String, dynamic> toJson() => toMap();

  factory Pet.fromMap(Map<String, dynamic> data, String documentId) {
    return Pet(
      id: documentId,
      name: data['name'] ?? '',
      type: data['type'] ?? '',
      age: data['age'] ?? 0,
      weight: data['weight'] ?? '',
      breed: data['breed'] ?? '',
      imagePath: data['imagePath'],
      birthDate: data['birthDate'] != null ? DateTime.parse(data['birthDate']) : null,
      gender: data['gender'],
      neutered: data['neutered'],
    );
  }

  factory Pet.fromJson(Map<String, dynamic> json) {
    return Pet(
      id: json['id']?.toString(),
      name: json['name'],
      type: json['type'],
      age: json['age'],
      weight: json['weight'],
      breed: json['breed'],
      imagePath: json['imagePath'],
      birthDate: json['birthDate'] != null ? DateTime.parse(json['birthDate']) : null,
      gender: json['gender'],
      neutered: json['neutered'],
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Pet && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
