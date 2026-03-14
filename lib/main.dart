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

// ✅ مدير التفعيل المحسن مع الحماية الكاملة
class ActivationManager {
  static final ActivationManager _instance = ActivationManager._internal();
  factory ActivationManager() => _instance;
  ActivationManager._internal();

  final FlutterSecureStorage secureStorage = const FlutterSecureStorage();
  
  static const String _activationLinkKey = 'activation_link';
  static const String _isActivatedKey = 'is_activated';
  static const String _lastValidTimeKey = 'last_valid_time';
  static const String _firstLaunchKey = 'first_launch_date';
  static const String _encryptedFirstLaunchKey = 'encrypted_first_launch';

  // ✅ حفظ رابط التفعيل
  Future<void> saveActivationLink(String link) async {
    await secureStorage.write(key: _activationLinkKey, value: link);
  }

  // ✅ استرجاع رابط التفعيل
  Future<String?> getActivationLink() async {
    return await secureStorage.read(key: _activationLinkKey);
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

  // ✅ حفظ تاريخ أول تشغيل بشكل آمن
  Future<void> saveFirstLaunchSecurely() async {
    try {
      final now = DateTime.now().toIso8601String();
      
      // 1️⃣ حفظ في الـ secure storage (مشفر)
      await secureStorage.write(key: _encryptedFirstLaunchKey, value: now);
      
      // 2️⃣ حفظ نسخة في SharedPreferences للمقارنة
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_firstLaunchKey, now);
      
      print('✅ First launch saved securely: $now');
    } catch (e) {
      print('❌ Error saving first launch: $e');
    }
  }

  // ✅ قراءة تاريخ أول تشغيل مع التحقق من التلاعب
  Future<DateTime?> getFirstLaunchSecurely() async {
    try {
      // 1️⃣ قراءة من التخزين المشفر (المصدر الرئيسي)
      final encryptedDate = await secureStorage.read(key: _encryptedFirstLaunchKey);
      
      // 2️⃣ قراءة من SharedPreferences (للمقارنة)
      final prefs = await SharedPreferences.getInstance();
      final prefsDate = prefs.getString(_firstLaunchKey);
      
      // 3️⃣ التحقق من التطابق (إذا اختلفا فهذا يعني تلاعب)
      if (encryptedDate != null && prefsDate != null && encryptedDate != prefsDate) {
        print('⚠️ Tampering detected! Dates do not match');
        return null;
      }
      
      // 4️⃣ التحقق من صحة التاريخ
      if (encryptedDate != null) {
        return DateTime.parse(encryptedDate);
      }
      
      return null;
    } catch (e) {
      print('❌ Error reading first launch: $e');
      return null;
    }
  }

  // ✅ التحقق من الوقت (واتساب ستايل)
  Future<bool> isTimeValid() async {
    final prefs = await SharedPreferences.getInstance();
    final lastTime = prefs.getInt(_lastValidTimeKey);
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    
    if (lastTime == null) {
      await prefs.setInt(_lastValidTimeKey, now);
      return true;
    }
    
    // منع الرجوع للخلف في الوقت
    if (now < lastTime) {
      print('⚠️ Time went backwards!');
      return false;
    }
    
    // منع التقدم الكبير في الوقت (أكثر من 5 دقائق)
    if (now > lastTime + 300) {
      print('⚠️ Time jumped forward too much!');
      return false;
    }
    
    await prefs.setInt(_lastValidTimeKey, now);
    return true;
  }

  // ✅ الحصول على حالة الفترة التجريبية بشكل آمن
  Future<Map<String, dynamic>> getTrialStatusSecurely() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      bool isActivated = prefs.getBool(_isActivatedKey) ?? false;
      
      // ✅ التحقق من الوقت أولاً
      bool timeValid = await isTimeValid();
      if (!timeValid) {
        print('⚠️ Time manipulation detected! Blocking access.');
        return {
          'remainingSeconds': 0,
          'isActivated': false,
          'timeManipulated': true
        };
      }
      
      // ✅ قراءة التاريخ من التخزين الآمن
      DateTime? firstLaunch = await getFirstLaunchSecurely();
      
      if (firstLaunch == null) {
        // أول مرة يتم فيها فتح التطبيق
        await saveFirstLaunchSecurely();
        print('🕒 First launch: 15 minutes remaining');
        return {
          'remainingSeconds': 15 * 60, // 15 دقيقة كاملة
          'isActivated': isActivated,
          'timeManipulated': false
        };
      }
      
      // حساب الوقت المتبقي
      DateTime now = DateTime.now();
      const trialSeconds = 15 * 60; // 15 دقيقة بالثواني
      
      int elapsedSeconds = now.difference(firstLaunch).inSeconds;
      
      // ✅ التحقق من أن الوقت لم يرجع للخلف
      if (elapsedSeconds < 0) {
        print('⚠️ Time went backwards! Resetting trial.');
        await saveFirstLaunchSecurely(); // إعادة تعيين التاريخ
        return {
          'remainingSeconds': 15 * 60,
          'isActivated': isActivated,
          'timeManipulated': true
        };
      }
      
      int remaining = trialSeconds - elapsedSeconds;
      
      print('🕒 First launch: $firstLaunch');
      print('🕒 Now: $now');
      print('🕒 Elapsed: ${elapsedSeconds ~/ 60} minutes');
      print('🕒 Remaining: ${remaining ~/ 60} minutes');
      
      return {
        'remainingSeconds': remaining < 0 ? 0 : remaining,
        'isActivated': isActivated,
        'timeManipulated': false
      };
      
    } catch (e) {
      print('❌ Error in getTrialStatusSecurely: $e');
      return {
        'remainingSeconds': 0,
        'isActivated': false,
        'timeManipulated': true
      };
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
    print('🕒 TrialTimer initialized with: $_remainingSeconds seconds');
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
        future: _activationManager.getTrialStatusSecurely(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildSplashScreen();
          }

          if (snapshot.hasError) {
            print('❌ Error: ${snapshot.error}');
            return _buildErrorScreen();
          }

          int remainingSeconds = snapshot.data?['remainingSeconds'] ?? 0;
          bool isActivated = snapshot.data?['isActivated'] ?? false;
          bool timeManipulated = snapshot.data?['timeManipulated'] ?? false;
          
          print('🕒 App starting with: $remainingSeconds seconds remaining');
          
          if (timeManipulated) {
            return _buildTamperingScreen();
          }
          
          return _TrialTimerWrapper(
            remainingSeconds: remainingSeconds,
            child: FutureBuilder<bool>(
              future: _activationManager.isActivated(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return _buildSplashScreen();
                }
                bool isActivated = snap.data ?? false;
                
                if (isActivated) {
                  return _buildMainScreenWithTimer(remainingSeconds);
                } else {
                  return const ActivationScreen();
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
      onWillPop: () async => false,
      child: TrialTimerProvider(
        remainingSeconds: remainingSeconds,
        onTimerExpired: _handleTimerExpired,
        child: const LoginScreen(),
      ),
    );
  }

  void _handleTimerExpired() async {
    print('🕒 Timer expired!');
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

  Widget _buildErrorScreen() {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.red.shade800, Colors.red.shade500],
          ),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 100, color: Colors.white),
              SizedBox(height: 20),
              Text('حدث خطأ في التطبيق', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
              SizedBox(height: 10),
              Text('يرجى إعادة تشغيل التطبيق', style: TextStyle(fontSize: 18, color: Colors.white)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTamperingScreen() {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.orange.shade800, Colors.orange.shade500],
          ),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.warning_amber_rounded, size: 100, color: Colors.white),
              SizedBox(height: 20),
              Text('تم اكتشاف تلاعب في النظام', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
              SizedBox(height: 10),
              Text('يرجى عدم العبث بوقت الجهاز', style: TextStyle(fontSize: 18, color: Colors.white)),
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
    print('🕒 TrialTimerProvider initialized with: $_remainingSeconds seconds');
    if (_remainingSeconds > 0) _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() {
          _remainingSeconds--;
        });
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