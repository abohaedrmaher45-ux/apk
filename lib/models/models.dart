// lib/models/models.dart
import 'package:flutter/material.dart';

class MattressType {
  String name;
  double price;
  MattressType({required this.name, required this.price});
  
  Map<String, dynamic> toJson() => {'name': name, 'price': price};
  factory MattressType.fromJson(Map<String, dynamic> json) => MattressType(name: json['name'], price: json['price']);
}

class SupportType {
  String name;
  double price;
  SupportType({required this.name, required this.price});
  
  Map<String, dynamic> toJson() => {'name': name, 'price': price};
  factory SupportType.fromJson(Map<String, dynamic> json) => SupportType(name: json['name'], price: json['price']);
}

class MattressFixedColumn {
  final String name;
  final double lengthCM;
  final double widthCM;
  MattressFixedColumn({required this.name, required this.lengthCM, required this.widthCM});
}

class SupportFixedColumn {
  final String name;
  final double lengthCM;
  final double thicknessCM;
  SupportFixedColumn({required this.name, required this.lengthCM, required this.thicknessCM});
}

class MattressColumnData {
  String name;
  double lengthCM;
  double widthCM;
  final TextEditingController heightController;
  final TextEditingController quantityController;
  final TextEditingController discountController;
  final bool isFixed;
  
  MattressColumnData({
    required this.name,
    required this.lengthCM,
    required this.widthCM,
    required this.heightController,
    required this.quantityController,
    required this.discountController,
    required this.isFixed,
  });
  
  void dispose() {
    heightController.dispose();
    quantityController.dispose();
    discountController.dispose();
  }
}

class SupportColumnData {
  String name;
  double lengthCM;
  double thicknessCM;
  final TextEditingController heightController;
  final TextEditingController quantityController;
  final TextEditingController discountController;
  final bool isFixed;
  
  SupportColumnData({
    required this.name,
    required this.lengthCM,
    required this.thicknessCM,
    required this.heightController,
    required this.quantityController,
    required this.discountController,
    required this.isFixed,
  });
  
  void dispose() {
    heightController.dispose();
    quantityController.dispose();
    discountController.dispose();
  }
}

// نموذج القالب المخصص
class CustomTemplate {
  String name;
  DateTime createdAt;
  List<MattressColumnTemplate> mattressColumns;
  List<SupportColumnTemplate> supportColumns;
  String? mattressTypeName;
  String? supportTypeName;
  
  CustomTemplate({
    required this.name,
    required this.createdAt,
    required this.mattressColumns,
    required this.supportColumns,
    this.mattressTypeName,
    this.supportTypeName,
  });
  
  Map<String, dynamic> toJson() => {
    'name': name,
    'createdAt': createdAt.toIso8601String(),
    'mattressColumns': mattressColumns.map((c) => c.toJson()).toList(),
    'supportColumns': supportColumns.map((c) => c.toJson()).toList(),
    'mattressTypeName': mattressTypeName,
    'supportTypeName': supportTypeName,
  };
  
  factory CustomTemplate.fromJson(Map<String, dynamic> json) => CustomTemplate(
    name: json['name'],
    createdAt: DateTime.parse(json['createdAt']),
    mattressColumns: (json['mattressColumns'] as List).map((c) => MattressColumnTemplate.fromJson(c)).toList(),
    supportColumns: (json['supportColumns'] as List).map((c) => SupportColumnTemplate.fromJson(c)).toList(),
    mattressTypeName: json['mattressTypeName'],
    supportTypeName: json['supportTypeName'],
  );
}

class MattressColumnTemplate {
  String name;
  double lengthCM;
  double widthCM;
  double height;
  double quantity;
  double discount;
  
  MattressColumnTemplate({
    required this.name,
    required this.lengthCM,
    required this.widthCM,
    required this.height,
    required this.quantity,
    required this.discount,
  });
  
  Map<String, dynamic> toJson() => {
    'name': name,
    'lengthCM': lengthCM,
    'widthCM': widthCM,
    'height': height,
    'quantity': quantity,
    'discount': discount,
  };
  
  factory MattressColumnTemplate.fromJson(Map<String, dynamic> json) => MattressColumnTemplate(
    name: json['name'],
    lengthCM: json['lengthCM'],
    widthCM: json['widthCM'],
    height: json['height'],
    quantity: json['quantity'],
    discount: json['discount'],
  );
}

class SupportColumnTemplate {
  String name;
  double lengthCM;
  double thicknessCM;
  double height;
  double quantity;
  double discount;
  
  SupportColumnTemplate({
    required this.name,
    required this.lengthCM,
    required this.thicknessCM,
    required this.height,
    required this.quantity,
    required this.discount,
  });
  
  Map<String, dynamic> toJson() => {
    'name': name,
    'lengthCM': lengthCM,
    'thicknessCM': thicknessCM,
    'height': height,
    'quantity': quantity,
    'discount': discount,
  };
  
  factory SupportColumnTemplate.fromJson(Map<String, dynamic> json) => SupportColumnTemplate(
    name: json['name'],
    lengthCM: json['lengthCM'],
    thicknessCM: json['thicknessCM'],
    height: json['height'],
    quantity: json['quantity'],
    discount: json['discount'],
  );
}