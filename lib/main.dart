import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/login_screen.dart';
import 'security/activation_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
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
      home: FutureBuilder<bool>(
        future: _checkActivationStatus(),
        builder: (context, snapshot) {
          // حالة الانتظار - تظهر شاشة التحميل
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildSplashScreen();
          }

          // في حالة الخطأ، نعرض شاشة الدخول كحل آمن
          if (snapshot.hasError) {
            return const LoginScreen();
          }

          // إذا كان مفعلاً، نعرض شاشة الدخول، وإلا نعرض شاشة التفعيل
          bool isActivated = snapshot.data ?? false;
          
          if (isActivated) {
            return const LoginScreen();
          } else {
            return const ActivationScreen();
          }
        },
      ),
    );
  }

  // ✅ التحقق من حالة التفعيل محلياً فقط (بدون إنترنت)
  Future<bool> _checkActivationStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // قراءة حالة التفعيل من الذاكرة المحلية فقط
      bool isActivated = prefs.getBool('is_activated') ?? false;
      return isActivated;
    } catch (e) {
      // في حالة أي خطأ، نعيد false كقيمة افتراضية آمنة
      return false;
    }
  }

  // ✅ شاشة البداية (Splash Screen)
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
              const SizedBox(height: 20),
              const Text(
                'Al Hal Market',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'محاسب سوق الهال',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 30),
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
              const SizedBox(height: 20),
              const Text(
                'جاري تحميل التطبيق...',
                style: TextStyle(
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}