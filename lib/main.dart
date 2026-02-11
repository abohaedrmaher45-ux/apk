import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'core/security/license_validator.dart';
import 'screens/login_screen.dart';
import 'screens/license_error_screen.dart';
import 'screens/splash_screen.dart'; // سننشئه بعد قليل

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 🔒 قفل اتجاه الشاشة
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  
  // ✅ تشغيل التطبيق بدون انتظار التحقق
  // (سنعمل التحقق في شاشة البداية)
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ال حل ماركت',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.teal,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        fontFamily: 'Arial',
      ),
      // نبدأ بشاشة البداية التي تتحقق من الترخيص
      home: const SplashScreen(),
    );
  }
}