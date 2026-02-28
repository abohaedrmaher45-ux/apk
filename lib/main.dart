import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'screens/login_screen.dart';
import 'security/activation_screen.dart';
import 'services/app_state_manager.dart';
import 'services/time_security_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

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
      home: FutureBuilder<Map<String, dynamic>>(
        future: _getAppStatusWithTime(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildSplashScreen();
          }

          if (snapshot.hasError) {
            return const _TrialTimerWrapper(child: LoginScreen());
          }

          Map<String, dynamic> data = snapshot.data ?? {
            'status': 'expired',
            'remainingSeconds': 0,
          };
          
          String status = data['status'];
          int remainingSeconds = data['remainingSeconds'];
          
          // ✅ التعديل الوحيد: تغليف MaterialApp بالكامل
          if (status == 'activated') {
            return _TrialTimerWrapper(
              remainingSeconds: remainingSeconds,
              child: MaterialApp(
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
                home: const LoginScreen(),
              ),
            );
          } else {
            return _TrialTimerWrapper(
              remainingSeconds: remainingSeconds,
              child: MaterialApp(
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
                home: const ActivationScreen(),
              ),
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
        String? firstLaunchStr = await storage.read(key: 'first_launch_date_secure');
        
        if (firstLaunchStr != null) {
          DateTime firstLaunch = DateTime.parse(firstLaunchStr);
          final timeService = TimeSecurityService();
          DateTime? secureTime = await timeService.getSecureTime();
          
          if (secureTime != null) {
            const trialMinutes = 15;
            const trialSeconds = trialMinutes * 60;
            int elapsedSeconds = secureTime.difference(firstLaunch).inSeconds;
            remainingSeconds = trialSeconds - elapsedSeconds;
            if (remainingSeconds < 0) remainingSeconds = 0;
          }
        }
      }
      
      return {
        'status': status,
        'remainingSeconds': remainingSeconds,
      };
    } catch (e) {
      return {
        'status': 'error',
        'remainingSeconds': 0,
      };
    }
  }

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
              Icon(Icons.shopping_cart, size: 100, color: Colors.white),
              const SizedBox(height: 20),
              const Text('Al Hal Market', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 10),
              const Text('محاسب سوق الهال', style: TextStyle(fontSize: 18, color: Colors.white)),
              const SizedBox(height: 30),
              const CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
              const SizedBox(height: 20),
              const Text('جاري تحميل التطبيق...', style: TextStyle(color: Colors.white)),
            ],
          ),
        ),
      ),
    );
  }
}

// ✅ موقت التوقيت - بدون تغيير
class _TrialTimerWrapper extends StatefulWidget {
  final Widget child;
  final int remainingSeconds;

  const _TrialTimerWrapper({
    required this.child,
    this.remainingSeconds = 0,
  });

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
    
    if (_remainingSeconds > 0) {
      _startTimer();
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() {
          _remainingSeconds--;
        });
      } else {
        _timer?.cancel();
      }
    });
  }

  @override
  void didUpdateWidget(_TrialTimerWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.remainingSeconds != oldWidget.remainingSeconds) {
      _remainingSeconds = widget.remainingSeconds;
      if (_remainingSeconds > 0) {
        _startTimer();
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatTime(int seconds) {
    int hours = seconds ~/ 3600;
    int minutes = (seconds % 3600) ~/ 60;
    int secs = seconds % 60;
    
    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    } else {
      return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_remainingSeconds <= 0) {
      return widget.child;
    }

    return Stack(
      children: [
        widget.child, // MaterialApp بأكمله
        Positioned(
          top: 40,
          right: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _remainingSeconds < 300 ? Colors.red : Colors.orange,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.timer, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Text(
                  _formatTime(_remainingSeconds),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
