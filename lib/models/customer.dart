class Customer {
  int id;
  String name;
  String? phone;
  String createdAt;

  Customer({
    required this.id,
    required this.name,
    this.phone,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'phone': phone,
    'createdAt': createdAt,
  };

  factory Customer.fromJson(Map<String, dynamic> json) {
    return Customer(
      id: json['id'],
      name: json['name'],
      phone: json['phone'],
      createdAt: json['createdAt'],
    );
  }
}