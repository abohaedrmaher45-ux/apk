import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/login_screen.dart';
import 'security/activation_screen.dart';
import 'services/app_state_manager.dart'; // استيراد مدير حالة التطبيق

void main() async {
  // التأكد من تهيئة Flutter
  WidgetsFlutterBinding.ensureInitialized();

  // قفل اتجاه التطبيق
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  // ✅ تعديل مهم: لا ننتظر حالة التطبيق هنا
  // نمرر null أو قيمة افتراضية
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  final AppStateManager _appStateManager = AppStateManager();

  MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Al Hal Market',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.teal,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        fontFamily: 'Arial',
      ),
      home: FutureBuilder<String>(
        // ✅ مهم: نبدأ بقيمة مخزنة محلياً أولاً
        future: _getInitialStatusLocally(),
        builder: (context, snapshot) {
          // 1. حالة الانتظار - نعرض شاشة ترحيب فورية
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildSplashScreen(); // ✅ شاشة ترحيب فورية
          }
          
          // 2. حالة وجود خطأ
          if (snapshot.hasError) {
            print('خطأ: ${snapshot.error}');
            // ✅ في حالة الخطأ، نظهر شاشة الدخول كحل بديل
            return const LoginScreen();
          }

          // 3. حالة وجود البيانات
          String status = snapshot.data ?? 'activated';

          // ✅ نتحقق من الحالة ولكن بدون تعليق التطبيق
          if (status == 'trial' || status == 'expired') {
            return const ActivationScreen();
          } else {
            return const LoginScreen();
          }
        },
      ),
    );
  }

  // ✅ دالة جديدة: تحصل على الحالة المحلية أولاً (بدون إنترنت)
  Future<String> _getInitialStatusLocally() async {
    try {
      // نحاول الحصول من الذاكرة المحلية أولاً
      final prefs = await SharedPreferences.getInstance();
      String localStatus = prefs.getString('app_status') ?? 'activated';
      
      // ✅ في الخلفية، نحاول التحديث من الإنترنت (لا يمنع ظهور الصفحة)
      _updateStatusInBackground();
      
      return localStatus;
    } catch (e) {
      // إذا فشل، نرجع قيمة افتراضية
      return 'activated';
    }
  }

  // ✅ دالة تعمل في الخلفية لتحديث الحالة
  Future<void> _updateStatusInBackground() async {
    try {
      final status = await _appStateManager.getAppStatus();
      // حفظ الحالة الجديدة محلياً للمستقبل
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('app_status', status);
    } catch (e) {
      // تجاهل أخطاء الشبكة - التطبيق سيستمر بالحالة المحلية
      print('تحديث الحالة في الخلفية فشل: $e');
    }
  }

  // ✅ شاشة ترحيب جميلة تظهر فوراً
  Widget _buildSplashScreen() {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.teal.shade800, Colors.teal.shade500],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // شعار التطبيق
              Icon(
                Icons.shopping_cart,
                size: 100,
                color: Colors.white,
              ),
              SizedBox(height: 20),
              Text(
                'Al Hal Market',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 10),
              Text(
                'محاسب سوق الهال',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.white.withOpacity(0.9),
                ),
              ),
              SizedBox(height: 30),
              
              // ✅ مؤشر تحميل أنيق
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
              
              SizedBox(height: 20),
              Text(
                'جاري تحميل التطبيق...',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}