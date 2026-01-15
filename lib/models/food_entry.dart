class FoodEntry {
  final String? id; // Firestore Doc ID
  final String petId;
  final String petName;
  final String foodType;
  final int amountGrams;
  final DateTime time;

  FoodEntry({
    this.id,
    required this.petId,
    required this.petName,
    required this.foodType,
    required this.amountGrams,
    required this.time,
  });

  Map<String, dynamic> toMap() {
    return {
      'petId': petId,
      'petName': petName,
      'foodType': foodType,
      'amountGrams': amountGrams,
      'time': time.toIso8601String(),
    };
  }

  Map<String, dynamic> toJson() => toMap();

  factory FoodEntry.fromMap(Map<String, dynamic> map, String documentId) {
    return FoodEntry(
      id: documentId,
      petId: map['petId'] ?? '',
      petName: map['petName'] ?? '',
      foodType: map['foodType'] ?? '',
      amountGrams: map['amountGrams'] ?? 0,
      time: map['time'] != null ? DateTime.parse(map['time']) : DateTime.now(),
    );
  }

  factory FoodEntry.fromJson(Map<String, dynamic> json) {
    return FoodEntry(
      petId: json['petId'] ?? '',
      petName: json['petName'] ?? '',
      foodType: json['foodType'] ?? '',
      amountGrams: json['amountGrams'] ?? 0,
      time: json['time'] != null ? DateTime.parse(json['time']) : DateTime.now(),
    );
  }
}


