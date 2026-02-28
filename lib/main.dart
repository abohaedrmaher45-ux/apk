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
          if (!await _TimeValidator.isTimeValid()) {
            throw Exception('Invalid time');
          }
          return _getTrialStatus();
        }(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildSplashScreen();
          }

          int remainingSeconds = snapshot.data?['remainingSeconds'] ?? 0;
          
          return _TrialTimerWrapper(
            remainingSeconds: remainingSeconds,
            child: FutureBuilder<bool>(
              future: _checkActivationStatus(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return _buildSplashScreen();
                }
                bool isActivated = snap.data ?? false;
                return isActivated ? const LoginScreen() : const ActivationScreen();
              },
            ),
          );
        },
      ),
    );
  }

  Future<Map<String, dynamic>> _getTrialStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      bool isActivated = prefs.getBool('is_activated') ?? false;
      
      if (isActivated) {
        return {'remainingSeconds': 0};
      }
      
      final storage = FlutterSecureStorage();
      String? firstLaunchStr = await storage.read(key: 'first_launch_date');
      
      if (firstLaunchStr == null) {
        String now = DateTime.now().toIso8601String();
        await storage.write(key: 'first_launch_date', value: now);
        return {'remainingSeconds': 15 * 60};
      }
      
      DateTime firstLaunch = DateTime.parse(firstLaunchStr);
      DateTime now = DateTime.now();
      const trialSeconds = 15 * 60;
      int remaining = trialSeconds - now.difference(firstLaunch).inSeconds;
      
      return {'remainingSeconds': remaining < 0 ? 0 : remaining};
    } catch (e) {
      return {'remainingSeconds': 0};
    }
  }

  Future<bool> _checkActivationStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('is_activated') ?? false;
    } catch (e) {
      return false;
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

class _TrialTimerWrapper extends StatefulWidget {
  final Widget child;
  final int remainingSeconds;
  const _TrialTimerWrapper({required this.child, this.remainingSeconds = 0});

  @override
  __TrialTimerWrapperState createState() => __TrialTimerWrapperState();
}

class __TrialTimerWrapperState extends State<_TrialTimerWrapper> {
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
      } else {
        _timer?.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatTime(int seconds) {
    int minutes = seconds ~/ 60;
    int secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_remainingSeconds > 0)
          Positioned(
            top: 40,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _remainingSeconds < 300 ? Colors.red : Colors.orange,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.timer, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Text(_formatTime(_remainingSeconds), 
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
