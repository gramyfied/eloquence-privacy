class User {
  final String id;
  final String? email;
  final String? name;
  final String? avatarUrl;
  
  User({
    required this.id,
    this.email,
    this.name,
    this.avatarUrl,
  });
}
