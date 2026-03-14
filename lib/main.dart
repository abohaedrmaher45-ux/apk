import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'screens/login_screen.dart';
import 'security/activation_screen.dart'; // استيراد شاشة التفعيل

void main() async {
  // التأكد من تهيئة Flutter
  WidgetsFlutterBinding.ensureInitialized();

  // قفل اتجاه التطبيق
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  runApp(MyApp());
}

// ✅ التحقق من الوقت (واتساب ستايل)
class _TimeValidator {
  static Future<bool> isTimeValid() async {
    final prefs = await SharedPreferences.getInstance();
    final lastTime = prefs.getInt('last_valid_time');
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    
    if (lastTime == null) {
      await prefs.setInt('last_valid_time', now);
      return true;
    }
    
    if (now < lastTime || now > lastTime + 300) return false;
    
    await prefs.setInt('last_valid_time', now);
    return true;
  }
}

// ✅ مؤقت منفصل يمكن استخدامه في أي شاشة
class TrialTimer extends StatefulWidget {
  final int remainingSeconds;
  final VoidCallback? onTimerExpired;
  
  const TrialTimer({
    Key? key,
    required this.remainingSeconds,
    this.onTimerExpired,
  }) : super(key: key);

  @override
  _TrialTimerState createState() => _TrialTimerState();
}

class _TrialTimerState extends State<TrialTimer> {
  late int _remainingSeconds;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _remainingSeconds = widget.remainingSeconds;
    if (_remainingSeconds > 0) _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() => _remainingSeconds--);
        if (_remainingSeconds == 0 && widget.onTimerExpired != null) {
          widget.onTimerExpired!();
        }
      } else {
        _timer?.cancel();
      }
    });
  }

  String _formatTime(int seconds) {
    int minutes = seconds ~/ 60;
    int secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_remainingSeconds <= 0) return const SizedBox.shrink();
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.timer, color: Colors.teal, size: 18),
          const SizedBox(width: 8),
          Text(
            _formatTime(_remainingSeconds),
            style: const TextStyle(
              color: Colors.teal,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

// ✅ مزود المؤقت للتطبيق كله
class TrialTimerProvider extends InheritedWidget {
  final int remainingSeconds;
  final VoidCallback onTimerExpired;
  final Timer? timer;

  const TrialTimerProvider({
    Key? key,
    required this.remainingSeconds,
    required this.onTimerExpired,
    required this.timer,
    required Widget child,
  }) : super(key: key, child: child);

  @override
  bool updateShouldNotify(TrialTimerProvider oldWidget) {
    return remainingSeconds != oldWidget.remainingSeconds;
  }

  static TrialTimerProvider? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<TrialTimerProvider>();
  }
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
      home: FutureBuilder<Map<String, dynamic>>(
        future: () async {
          // التحقق من حالة التفعيل المخزنة
          final prefs = await SharedPreferences.getInstance();
          final String activationStatus = prefs.getString('activation_status') ?? '';

          bool isActivated = false;
          if (activationStatus.isNotEmpty) {
            try {
              // فك التشفير البسيط والتحقق من القيمة
              final decodedStatus = utf8.decode(base64.decode(activationStatus));
              if (decodedStatus == 'activated_ok') {
                isActivated = true;
              }
            } catch (e) {
              // في حال وجود قيمة خاطئة أو قديمة
              isActivated = false;
            }
          }

          if (!isActivated) {
            return {'isActivated': false, 'remainingSeconds': 0};
          }

          if (!await _TimeValidator.isTimeValid()) {
            throw Exception('Invalid time');
          }
          return _getTrialStatus();
        }(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildSplashScreen();
          }

          bool isActivated = snapshot.data?['isActivated'] ?? false;
          int remainingSeconds = snapshot.data?['remainingSeconds'] ?? 0;
          
          return _TrialTimerWrapper(
            remainingSeconds: remainingSeconds,
            child: isActivated 
                ? _buildMainScreenWithTimer(remainingSeconds)
                : const ActivationScreen(),
          );
        },
      ),
    );
  }

  Widget _buildMainScreenWithTimer(int remainingSeconds) {
    return WillPopScope(
      onWillPop: () async => false, // منع الرجوع للخلف
      child: TrialTimerStatefulProvider(
        remainingSeconds: remainingSeconds,
        onTimerExpired: _handleTimerExpired,
        child: const LoginScreen(),
      ),
    );
  }

  void _handleTimerExpired() async {
    // حذف حالة التفعيل
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('activation_status');
    
    // حذف تاريخ أول تشغيل ليبدأ المؤقت من جديد
    const storage = FlutterSecureStorage();
    await storage.delete(key: 'first_launch_date');
  }

  Future<Map<String, dynamic>> _getTrialStatus() async {
    try {
      final storage = FlutterSecureStorage();
      String? firstLaunchStr = await storage.read(key: 'first_launch_date');
      
      if (firstLaunchStr == null) {
        String now = DateTime.now().toIso8601String();
        await storage.write(key: 'first_launch_date', value: now);
        return {'isActivated': true, 'remainingSeconds': 15 * 60};
      }
      
      DateTime firstLaunch = DateTime.parse(firstLaunchStr);
      DateTime now = DateTime.now();
      const trialSeconds = 15 * 60;
      int remaining = trialSeconds - now.difference(firstLaunch).inSeconds;
      
      return {'isActivated': true, 'remainingSeconds': remaining < 0 ? 0 : remaining};
    } catch (e) {
      return {'isActivated': true, 'remainingSeconds': 0};
    }
  }

  Widget _buildSplashScreen() {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.teal.shade800, Colors.teal.shade500],
          ),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.shopping_cart, size: 100, color: Colors.white),
              SizedBox(height: 20),
              Text('Al Hal Market', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),
              SizedBox(height: 10),
              Text('محاسب سوق الهال', style: TextStyle(fontSize: 18, color: Colors.white)),
              SizedBox(height: 30),
              CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
              SizedBox(height: 20),
              Text('جاري تحميل التطبيق...', style: TextStyle(color: Colors.white)),
            ],
          ),
        ),
      ),
    );
  }
}

// ✅ Stateful provider لإدارة المؤقت
class TrialTimerStatefulProvider extends StatefulWidget {
  final Widget child;
  final int remainingSeconds;
  final VoidCallback onTimerExpired;

  const TrialTimerStatefulProvider({
    Key? key,
    required this.child,
    required this.remainingSeconds,
    required this.onTimerExpired,
  }) : super(key: key);

  @override
  _TrialTimerStatefulProviderState createState() => _TrialTimerStatefulProviderState();
}

class _TrialTimerStatefulProviderState extends State<TrialTimerStatefulProvider> {
  late int _remainingSeconds;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _remainingSeconds = widget.remainingSeconds;
    if (_remainingSeconds > 0) _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() => _remainingSeconds--);
        if (_remainingSeconds == 0) {
          _timer?.cancel();
          widget.onTimerExpired();
          _redirectToActivationScreen();
        }
      } else {
        _timer?.cancel();
      }
    });
  }

  Future<void> _redirectToActivationScreen() async {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('انتهت الفترة التجريبية. يرجى إدخال رابط التفعيل مرة أخرى.'),
        duration: Duration(seconds: 3),
      ),
    );

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const ActivationScreen()),
      (route) => false,
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TrialTimerProvider(
      remainingSeconds: _remainingSeconds,
      onTimerExpired: widget.onTimerExpired,
      timer: _timer,
      child: widget.child,
    );
  }
}

// ✅ Wrapper
class _TrialTimerWrapper extends StatelessWidget {
  final Widget child;
  final int remainingSeconds;
  
  const _TrialTimerWrapper({
    required this.child,
    this.remainingSeconds = 0,
  });

  @override
  Widget build(BuildContext context) {
    return child;
  }
}