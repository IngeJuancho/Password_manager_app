class PasswordEntry {
  String app;
  String? username;
  String password;
  String? packageId;
  DateTime createdAt;
  DateTime? lastModified;
  bool isFavorite;

  PasswordEntry({
    required this.app,
    this.username,
    required this.password,
    this.packageId,
    required this.createdAt,
    this.lastModified,
    this.isFavorite = false,
  });

  Map<String, dynamic> toJson() => {
        'app': app,
        'username': username,
        'password': password,
        'packageId': packageId,
        'createdAt': createdAt.toIso8601String(),
        'lastModified': lastModified?.toIso8601String(),
        'isFavorite': isFavorite,
      };

  factory PasswordEntry.fromJson(Map<String, dynamic> json) => PasswordEntry(
        app: json['app'],
        username: json['username'],
        password: json['password'],
        packageId: json['packageId'],
        createdAt: DateTime.parse(json['createdAt']),
        lastModified: json['lastModified'] != null
            ? DateTime.parse(json['lastModified'])
            : null,
        isFavorite: json['isFavorite'] ?? false,
      );
}
