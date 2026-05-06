class UserModel {
  final int id;
  final String email;
  final String name;
  final String? avatarUrl;

  const UserModel({
    required this.id,
    required this.email,
    required this.name,
    this.avatarUrl,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        id:        json['id'],
        email:     json['email'],
        name:      json['name'],
        avatarUrl: json['avatar_url'],
      );
}