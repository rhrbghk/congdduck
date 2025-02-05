import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String id;
  final String name;
  final String email;
  final String imageUrl;
  final String gender;
  final String mbti;
  final List<String> preferredMbti;
  final List<String> hobbies;
  final GeoPoint? location;
  final DateTime createdAt;
  final bool profileCompleted;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.imageUrl,
    required this.gender,
    required this.mbti,
    required this.preferredMbti,
    required this.hobbies,
    this.location,
    required this.createdAt,
    required this.profileCompleted,
  });

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel(
      id: doc.id,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      imageUrl: data['imageUrl'] ?? '',
      gender: data['gender'] ?? '',
      mbti: data['mbti'] ?? '',
      preferredMbti: List<String>.from(data['preferredMbti'] ?? []),
      hobbies: List<String>.from(data['hobbies'] ?? []),
      location: data['location'] as GeoPoint?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      profileCompleted: data['profileCompleted'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'imageUrl': imageUrl,
      'gender': gender,
      'mbti': mbti,
      'preferredMbti': preferredMbti,
      'hobbies': hobbies,
      'location': location,
      'createdAt': createdAt,
      'profileCompleted': profileCompleted,
    };
  }

  UserModel copyWith({
    String? name,
    String? email,
    String? imageUrl,
    String? gender,
    String? mbti,
    List<String>? preferredMbti,
    List<String>? hobbies,
    GeoPoint? location,
    DateTime? createdAt,
    bool? profileCompleted,
  }) {
    return UserModel(
      id: id,
      name: name ?? this.name,
      email: email ?? this.email,
      imageUrl: imageUrl ?? this.imageUrl,
      gender: gender ?? this.gender,
      mbti: mbti ?? this.mbti,
      preferredMbti: preferredMbti ?? this.preferredMbti,
      hobbies: hobbies ?? this.hobbies,
      location: location ?? this.location,
      createdAt: createdAt ?? this.createdAt,
      profileCompleted: profileCompleted ?? this.profileCompleted,
    );
  }
}
