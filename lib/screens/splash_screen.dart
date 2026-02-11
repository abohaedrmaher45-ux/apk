import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../core/security/license_validator.dart';
import 'login_screen.dart';
import 'license_error_screen.dart';

/// 🎬 شاشة البداية - تتحقق من الترخيص
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkLicense();
  }

  Future<void> _checkLicense() async {
    // انتظر قليلاً لشاشة البداية
    await Future.delayed(const Duration(milliseconds: 1500));
    
    // التحقق من الترخيص
    final result = await LicenseValidator.validateLicense();
    
    if (!mounted) return;
    
    if (result.isValid) {
      // ✅ مرخص - اذهب لشاشة الدخول
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    } else {
      // ❌ غير مرخص - اذهب لشاشة الخطأ
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => LicenseErrorScreen(
            errorMessage: result.errorMessage ?? 'خطأ في الترخيص',
            errorCode: result.errorCode?.toString() ?? 'UNKNOWN',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.teal.shade800,
              Colors.teal.shade600,
              Colors.teal.shade400,
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 🏢 شعار الشركة
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(50),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.shopping_cart,
                  size: 60,
                  color: Colors.teal,
                ),
              ),
              const SizedBox(height: 24),
              
              // 📱 اسم التطبيق
              const Text(
                'Al Hal Market',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 8),
              
              // 🔒 نسخة محمية
              const Text(
                'نسخة محمية © 2025',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 48),
              
              // ⏳ مؤشر تحميل
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}