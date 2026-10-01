/// Mirrors `User` in frontend/src/lib/types.ts.
class User {
  final String id;
  final String email;
  final String firstName;
  final String lastName;
  final bool isVerified;
  final String riskProfile;
  final List<String> alertChannels;
  final String? defaultExchange;
  final String createdAt;

  const User({
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.isVerified,
    required this.riskProfile,
    required this.alertChannels,
    required this.defaultExchange,
    required this.createdAt,
  });

  String get fullName => '$firstName $lastName'.trim();

  String get initials {
    final first = firstName.isNotEmpty ? firstName[0] : '';
    final last = lastName.isNotEmpty ? lastName[0] : '';
    return (first + last).toUpperCase();
  }

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['id'].toString(),
        email: json['email'] as String,
        firstName: json['first_name'] as String? ?? '',
        lastName: json['last_name'] as String? ?? '',
        isVerified: json['is_verified'] as bool? ?? false,
        riskProfile: json['risk_profile'] as String? ?? 'moderate',
        alertChannels: (json['alert_channels'] as List<dynamic>? ?? const ['in_app']).cast<String>(),
        defaultExchange: json['default_exchange'] as String?,
        createdAt: json['created_at'] as String? ?? '',
      );
}
