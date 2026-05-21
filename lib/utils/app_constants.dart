// lib/utils/app_constants.dart
import 'package:flutter/material.dart';

class AppConstants {
  // ==================== بيانات الشركة ====================
  static const String companyName = 'شركة العجاج للمقاولات';
  static const String managerName = 'إدارة ملحم العجاج ابو عويد';
  static const String contactPhone = '0930847972';
  static const String currencySymbol = 'ريال';
  static const String address = 'هجين - خلف المستوصف';  // ✅ تم إضافة هذا السطر
  
  // ==================== الألوان ====================
  static const Color primaryColor = Color(0xFF1E3A5F);
  static const Color secondaryColor = Color(0xFFF4A261);
  static const Color accentColor = Color(0xFF2A9D8F);
  static const Color dangerColor = Color(0xFFE76F51);
  static const Color successColor = Color(0xFF2A9D8F);
  static const Color backgroundColor = Color(0xFFF8F9FA);
  
  // ==================== المواد ووحداتها ====================
  static const List<String> materialList = [
    'حديد', 'اسمنت', 'رمل', 'طوب', 'بلاستيك', 
    'دهان', 'بلاط', 'سيراميك', 'خشب', 'مسامير', 'زجاج', 'المنيوم'
  ];
  
  static const Map<String, String> materialUnit = {
    'حديد': 'طن',
    'اسمنت': 'كيس',
    'رمل': 'متر مكعب',
    'طوب': 'ألف طوبة',
    'بلاستيك': 'متر',
    'دهان': 'علبة',
    'بلاط': 'متر مربع',
    'سيراميك': 'متر مربع',
    'خشب': 'متر',
    'مسامير': 'كيلو',
    'زجاج': 'متر مربع',
    'المنيوم': 'متر',
  };
  
  // ==================== إعدادات الأنيميشن ====================
  static const Duration animationDuration = Duration(milliseconds: 300);
  static const Curve animationCurve = Curves.easeInOut;
  
  // دالة مساعدة للحصول على وحدة المادة بأمان
  static String getUnit(String materialName) {
    return materialUnit[materialName] ?? 'قطعة';
  }
}