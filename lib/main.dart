import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'screens/login_screen.dart';
import 'security/activation_screen.dart';
import 'services/app_state_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  runApp(MyApp());
}

// ✅ كلاس التحقق من الوقت (واتساب ستايل) - فقط هذا مضاف
class _TimeValidator {
  static Future<bool> isTimeValid() async {
    final prefs = await SharedPreferences.getInstance();
    final lastTime = prefs.getInt('last_valid_time');
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    
    if (lastTime == null) {
      await prefs.setInt('last_valid_time', now);
      return true;
    }
    
    if (now < lastTime || now > lastTime + 300) {
      return false;
    }
    
    await prefs.setInt('last_valid_time', now);
    return true;
  }
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
      home: FutureBuilder<Map<String, dynamic>>(
        future: () async {
          if (!await _TimeValidator.isTimeValid()) {
            throw Exception('Invalid time');
          }
          return _getAppStatusWithTime();
        }(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildSplashScreen();
          }

          if (snapshot.hasError) {
            return _buildTimeErrorScreen();
          }

          Map<String, dynamic> data = snapshot.data ?? {
            'status': 'expired',
            'remainingSeconds': 0,
          };
          
          String status = data['status'];
          int remainingSeconds = data['remainingSeconds'];
          
          if (status == 'activated') {
            return _TrialTimerWrapper(
              remainingSeconds: remainingSeconds,
              child: const LoginScreen(),
            );
          } else {
            return _TrialTimerWrapper(
              remainingSeconds: remainingSeconds,
              child: const ActivationScreen(),
            );
          }
        },
      ),
    );
  }

  Future<Map<String, dynamic>> _getAppStatusWithTime() async {
    try {
      String status = await _appStateManager.getAppStatus();
      int remainingSeconds = 0;
      
      if (status == 'trial') {
        final storage = FlutterSecureStorage();
        String? firstLaunchStr = await storage.read(key: 'first_launch_date');
        
        if (firstLaunchStr == null) {
          String now = DateTime.now().toIso8601String();
          await storage.write(key: 'first_launch_date', value: now);
          remainingSeconds = 15 * 60;
        } else {
          DateTime firstLaunch = DateTime.parse(firstLaunchStr);
          DateTime now = DateTime.now();
          const trialSeconds = 15 * 60;
          int elapsedSeconds = now.difference(firstLaunch).inSeconds;
          remainingSeconds = trialSeconds - elapsedSeconds;
          if (remainingSeconds < 0) remainingSeconds = 0;
        }
      }
      
      return {'status': status, 'remainingSeconds': remainingSeconds};
    } catch (e) {
      return {'status': 'error', 'remainingSeconds': 0};
    }
  }

  Widget _buildTimeErrorScreen() {
    return Scaffold(
      body: Container(
        color: Colors.red.shade900,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.access_time_filled, size: 100, color: Colors.white),
              const SizedBox(height: 30),
              const Text('الوقت غير صحيح', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 20),
              const Text('يرجى ضبط الوقت والتاريخ بشكل صحيح', style: TextStyle(fontSize: 18, color: Colors.white70)),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: () => SystemNavigator.pop(),
                child: const Text('إغلاق', style: TextStyle(fontSize: 18)),
              ),
            ],
          ),
        ),
      ),
    );
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
              SizedBox(height: 30),
              CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
            ],
          ),
        ),
      ),
    );
  }
}

// ✅ موقت التوقيت
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
