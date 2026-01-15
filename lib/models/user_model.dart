class UserModel {
  final String uid;
  final String email;
  final String displayName;
  final String? avatar;
  final DateTime createdAt;

  UserModel({
    required this.uid,
    required this.email,
    required this.displayName,
    this.avatar,
    required this.createdAt,
  });

  // Firebase'den gelen veriden model oluştur
  factory UserModel.fromFirebase(Map<String, dynamic> data, String uid) {
    return UserModel(
      uid: uid,
      email: data['email'] ?? '',
      displayName: data['displayName'] ?? '',
      avatar: data['avatar'],
      createdAt: data['createdAt'] != null 
          ? DateTime.parse(data['createdAt'])
          : DateTime.now(),
    );
  }

  // Firebase'e gönderilecek veri
  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'displayName': displayName,
      'avatar': avatar,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  UserModel copyWith({
    String? uid,
    String? email,
    String? displayName,
    String? avatar,
    DateTime? createdAt,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      avatar: avatar ?? this.avatar,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
