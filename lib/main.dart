import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/login_screen.dart';
import 'security/activation_screen.dart';
import 'services/app_state_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  // ✅ فقط هذا السطر تغير - نمرر دالة بدلاً من القيمة
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
        // ✅ نفس الكود الأصلي لكن بدون await في الـ main
        future: _appStateManager.getAppStatus(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          
          if (snapshot.hasError) {
            return Scaffold(
              body: Center(child: Text("خطأ في التحقق من الترخيص")),
            );
          }

          String status = snapshot.data ?? 'expired';

          if (status == 'trial' || status == 'expired' || status == 'error_network') {
            return const ActivationScreen();
          } else {
            return const LoginScreen();
          }
        },
      ),
    );
  }
}