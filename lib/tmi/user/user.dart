class User {
  String login;
  String displayName;
  String color;
  String id;
  String? avatarUrl;

  User({
    required this.login,
    required this.displayName,
    required this.id,
    this.color = '#777777',
    this.avatarUrl,
  }) {
    if (color.isEmpty) color = '#777777';
  }
}
