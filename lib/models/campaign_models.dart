class TopUser {
  final String id;
  final String firstName;
  final String imgUrl;
  final int orderCount;

  TopUser({
    required this.id,
    required this.firstName,
    required this.imgUrl,
    required this.orderCount,
  });

  factory TopUser.fromJson(Map<String, dynamic> json) {
    return TopUser(
      id: json['id'] ?? '',
      firstName: json['first_name'] ?? 'User',
      imgUrl: json['img_url'] ?? '',
      orderCount: json['order_count'] ?? 0,
    );
  }
}

class NewUser {
  final String id;
  final String firstName;
  final String imgUrl;

  NewUser({required this.id, required this.firstName, required this.imgUrl});

  factory NewUser.fromJson(Map<String, dynamic> json) {
    return NewUser(
      id: json['id'] ?? '',
      firstName: json['first_name'] ?? 'User',
      imgUrl: json['img_url'] ?? '',
    );
  }
}
