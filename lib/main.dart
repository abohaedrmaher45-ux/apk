// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'daily_movement_screen.dart';
import 'security/activation_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));
  
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'نظام المبيعات',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.teal,
        fontFamily: 'Cairo',
        textTheme: const TextTheme(bodyMedium: TextStyle(fontSize: 16)),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
      home: const SplashScreen(),
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: child!,
      ),
    );
  }
}

// شاشة البداية مع المؤقت المدمج
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  int _trialSeconds = 0;
  bool _isChecking = true;
  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _fadeAnimation = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );
    
    _controller.forward();
    _checkTrialStatus();
  }

  Future<void> _checkTrialStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final trialEndTime = prefs.getInt('trial_end_time') ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    
    // فترة تجريبية 3 أيام = 259200 ثانية
    const trialDuration = 259200;
    
    int remaining;
    if (trialEndTime == 0) {
      final endTime = now + trialDuration;
      await prefs.setInt('trial_end_time', endTime);
      remaining = trialDuration;
    } else {
      remaining = (trialEndTime - now).clamp(0, trialDuration);
    }
    
    if (!mounted) return;
    
    setState(() {
      _trialSeconds = remaining;
      _isChecking = false;
    });
    
    // الانتقال بعد 2 ثواني
    await Future.delayed(const Duration(seconds: 2));
    
    if (mounted && !_hasNavigated) {
      _hasNavigated = true;
      if (_trialSeconds > 0) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => DateSelectionScreen(
              storeType: 'متجر افتراضي',
              storeName: 'المتجر الرئيسي',
              sellerName: 'المندوب',
            ),
          ),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const ActivationScreen()),
        );
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF4DB6AC), Color(0xFF26A69A), Color(0xFF00897B)],
          ),
        ),
        child: SafeArea(
          child: _isChecking
              ? const Center(child: CircularProgressIndicator(color: Colors.white))
              : FadeTransition(
                  opacity: _fadeAnimation,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.storefront,
                          size: 60,
                          color: Color(0xFF00897B),
                        ),
                      ),
                      const SizedBox(height: 40),
                      
                      const Text(
                        'نظام إدارة المبيعات اليومية',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          shadows: [Shadow(offset: Offset(1, 1), blurRadius: 4, color: Colors.black54)],
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      
                      Text(
                        _trialSeconds > 0 
                            ? 'الفترة التجريبية متبقي: ${_formatTime(_trialSeconds)}'
                            : 'انتهت الفترة التجريبية',
                        style: TextStyle(
                          fontSize: 16,
                          color: _trialSeconds > 0 ? Colors.white70 : Colors.red[100],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      
                      const SizedBox(height: 60),
                      
                      SizedBox(
                        width: 200,
                        height: 4,
                        child: LinearProgressIndicator(
                          value: _trialSeconds > 0 ? (_trialSeconds / 259200) : 0,
                          valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                          backgroundColor: Colors.white24,
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  String _formatTime(int seconds) {
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    final hours = (seconds ~/ 3600);
    final days = hours ~/ 24;
    
    if (days > 0) return '${days}ي ${hours % 24}س';
    return '${minutes}:${secs}';
  }
}

// دالة مساعدة للتحقق من المؤقت في أي صفحة
Future<bool> checkTrialStatus(BuildContext context) async {
  final prefs = await SharedPreferences.getInstance();
  final trialEndTime = prefs.getInt('trial_end_time') ?? 0;
  final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  final remaining = (trialEndTime - now).clamp(0, 259200);
  
  if (remaining <= 0 && context.mounted) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const ActivationScreen()),
      (route) => false,
    );
    return false;
  }
  return true;
}

// دالة لعرض المؤقت في AppBar
Widget buildTrialTimer() {
  return FutureBuilder<int>(
    future: _getRemainingSeconds(),
    builder: (context, snapshot) {
      if (!snapshot.hasData) return const SizedBox.shrink();
      
      final seconds = snapshot.data!;
      if (seconds <= 0) return const SizedBox.shrink();
      
      final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
      final secs = (seconds % 60).toString().padLeft(2, '0');
      
      return Padding(
        padding: const EdgeInsets.only(right: 16.0),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.red.shade600, Colors.orange.shade600],
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.timer, color: Colors.white, size: 16),
              const SizedBox(width: 6),
              Text(
                '$minutes:$secs',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

Future<int> _getRemainingSeconds() async {
  final prefs = await SharedPreferences.getInstance();
  final trialEndTime = prefs.getInt('trial_end_time') ?? 0;
  final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  return (trialEndTime - now).clamp(0, 259200);
}