class User {
  final int id;
  final String firstName;
  final String lastName;
  final String email;
  final bool isVerified;
  final String createdAt;

  User({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.isVerified,
    required this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['id'] as int,
        firstName: json['first_name'] as String,
        lastName: json['last_name'] as String,
        email: json['email'] as String,
        isVerified: json['is_verified'] as bool,
        createdAt: json['created_at'] as String,
      );
}
