import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
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

// ✅ مدير التفعيل - مسؤول عن حفظ واسترجاع رابط التفعيل
class ActivationManager {
  static final ActivationManager _instance = ActivationManager._internal();
  factory ActivationManager() => _instance;
  ActivationManager._internal();

  final FlutterSecureStorage secureStorage = const FlutterSecureStorage();
  final SharedPreferencesAsync asyncPrefs = SharedPreferencesAsync();
  
  static const String _activationLinkKey = 'activation_link';
  static const String _isActivatedKey = 'is_activated';
  static const String _lastValidTimeKey = 'last_valid_time';
  static const String _firstLaunchKey = 'first_launch_date';

  // ✅ حفظ رابط التفعيل
  Future<void> saveActivationLink(String link) async {
    await secureStorage.write(key: _activationLinkKey, value: link);
  }

  // ✅ استرجاع رابط التفعيل
  Future<String?> getActivationLink() async {
    return await secureStorage.read(key: _activationLinkKey);
  }

  // ✅ التحقق من وجود رابط مفعل
  Future<bool> hasValidActivationLink() async {
    final link = await getActivationLink();
    return link != null && link.isNotEmpty;
  }

  // ✅ حفظ حالة التفعيل
  Future<void> setActivated(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_isActivatedKey, value);
  }

  // ✅ التحقق من حالة التفعيل
  Future<bool> isActivated() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_isActivatedKey) ?? false;
  }

  // ✅ التحقق من الوقت
  Future<bool> isTimeValid() async {
    final prefs = await SharedPreferences.getInstance();
    final lastTime = prefs.getInt(_lastValidTimeKey);
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    
    if (lastTime == null) {
      await prefs.setInt(_lastValidTimeKey, now);
      return true;
    }
    
    if (now < lastTime || now > lastTime + 300) return false;
    
    await prefs.setInt(_lastValidTimeKey, now);
    return true;
  }

  // ✅ الحصول على حالة الفترة التجريبية
  Future<Map<String, dynamic>> getTrialStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      bool isActivated = prefs.getBool(_isActivatedKey) ?? false;
      
      String? firstLaunchStr = await secureStorage.read(key: _firstLaunchKey);
      
      if (firstLaunchStr == null) {
        String now = DateTime.now().toIso8601String();
        await secureStorage.write(key: _firstLaunchKey, value: now);
        return {'remainingSeconds': 15 * 60, 'isActivated': isActivated};
      }
      
      DateTime firstLaunch = DateTime.parse(firstLaunchStr);
      DateTime now = DateTime.now();
      const trialSeconds = 15 * 60;
      int remaining = trialSeconds - now.difference(firstLaunch).inSeconds;
      
      return {
        'remainingSeconds': remaining < 0 ? 0 : remaining,
        'isActivated': isActivated
      };
    } catch (e) {
      return {'remainingSeconds': 0, 'isActivated': false};
    }
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

class MyApp extends StatelessWidget {
  final ActivationManager _activationManager = ActivationManager();
  
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
          if (!await _activationManager.isTimeValid()) {
            throw Exception('Invalid time');
          }
          return _activationManager.getTrialStatus();
        }(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildSplashScreen();
          }

          int remainingSeconds = snapshot.data?['remainingSeconds'] ?? 0;
          bool isActivated = snapshot.data?['isActivated'] ?? false;
          
          return _TrialTimerWrapper(
            remainingSeconds: remainingSeconds,
            child: FutureBuilder<bool>(
              future: _activationManager.hasValidActivationLink(),
              builder: (context, linkSnapshot) {
                if (linkSnapshot.connectionState == ConnectionState.waiting) {
                  return _buildSplashScreen();
                }
                
                bool hasSavedLink = linkSnapshot.data ?? false;
                
                // تحديد الصفحة الرئيسية بناءً على حالة التفعيل والرابط المحفوظ
                if (isActivated) {
                  return _buildMainScreenWithTimer(remainingSeconds);
                } else {
                  // تمرير ActivationManager إلى شاشة التفعيل
                  return ActivationScreen(
                    activationManager: _activationManager,
                    hasSavedLink: hasSavedLink,
                  );
                }
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildMainScreenWithTimer(int remainingSeconds) {
    return WillPopScope(
      onWillPop: () async => false, // منع الرجوع للخلف
      child: TrialTimerProvider(
        remainingSeconds: remainingSeconds,
        onTimerExpired: _handleTimerExpired,
        child: LoginScreen(),
      ),
    );
  }

  void _handleTimerExpired() async {
    // حذف حالة التفعيل فقط - نحتفظ بالرابط المخزن
    await _activationManager.setActivated(false);
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

// ✅ مزود المؤقت للتطبيق كله
class TrialTimerProvider extends StatefulWidget {
  final Widget child;
  final int remainingSeconds;
  final VoidCallback onTimerExpired;

  const TrialTimerProvider({
    Key? key,
    required this.child,
    required this.remainingSeconds,
    required this.onTimerExpired,
  }) : super(key: key);

  @override
  _TrialTimerProviderState createState() => _TrialTimerProviderState();

  static _TrialTimerProviderState? of(BuildContext context) {
    return context.findAncestorStateOfType<_TrialTimerProviderState>();
  }
}

class _TrialTimerProviderState extends State<TrialTimerProvider> {
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
      MaterialPageRoute(builder: (_) => ActivationScreen(
        activationManager: ActivationManager(),
        hasSavedLink: false,
      )),
      (route) => false,
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  int get remainingSeconds => _remainingSeconds;

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

// ✅ Wrapper محدث مع دعم التنقل
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