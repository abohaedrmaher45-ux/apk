import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/date_selection_screen.dart';
import 'security/activation_screen.dart';
import 'security/end_screen.dart'; // تأكد من المسار الصحيح لـ EndScreen
import 'services/time_security_service.dart'; // مسار خدمة الوقت

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // نستخدم TimeSecurityService للتحقق من صلاحية التجربة
  final timeService = TimeSecurityService();
  bool trialValid = await timeService.isTrialValid();
  bool isExpired = !trialValid;

  SharedPreferences prefs = await SharedPreferences.getInstance();
  
  // قراءة حالة التفعيل (الكود الموجود)
  String activationStatus = prefs.getString('activation_status') ?? '';
  bool isActivated = false;
  if (activationStatus.isNotEmpty) {
    try {
      String decodedStatus = utf8.decode(base64.decode(activationStatus));
      if (decodedStatus == 'activated_ok') {
        isActivated = true;
      }
    } catch (e) {
      isActivated = false;
    }
  }

  // إذا انتهت صلاحية التجربة (أو تم التلاعب)، نتأكد من تخزين trial_expired = true
  if (isExpired) {
    await timeService.terminateTrialDueToTampering(); // يخزن trial_expired=true ويمسح بيانات الوقت
    // نجبر isActivated على false حتى لا نذهب إلى أي شاشة أخرى
    isActivated = false;
  }

  runApp(MyApp(
    isActivated: isActivated,
    isExpired: isExpired,
  ));
}

class MyApp extends StatefulWidget {
  final bool isActivated;
  final bool isExpired;

  const MyApp({super.key, required this.isActivated, required this.isExpired});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  late bool _isActivated;
  late bool _isExpired;
  late final TimeSecurityService _timeService;

  @override
  void initState() {
    super.initState();
    _isActivated = widget.isActivated;
    _isExpired = widget.isExpired;
    _timeService = TimeSecurityService();
    // إضافة مراقب دورة الحياة
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// عند عودة التطبيق من الخلفية، نعيد التحقق من صلاحية التجربة
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _recheckAndRedirect();
    }
  }

  /// دالة إعادة التحقق والتوجيه إذا تغيرت الحالة
  Future<void> _recheckAndRedirect() async {
    // لا نريد إعادة التوجيه إذا كنا بالفعل في الشاشة النهائية أو شاشة التفعيل؟ 
    // لكن الأفضل التحقق دائماً.
    bool trialValid = await _timeService.isTrialValid();
    bool newExpired = !trialValid;

    // قراءة حالة التفعيل من SharedPreferences (قد تتغير من شاشة التفعيل)
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String activationStatus = prefs.getString('activation_status') ?? '';
    bool newActivated = false;
    if (activationStatus.isNotEmpty) {
      try {
        String decodedStatus = utf8.decode(base64.decode(activationStatus));
        if (decodedStatus == 'activated_ok') {
          newActivated = true;
        }
      } catch (e) {
        newActivated = false;
      }
    }

    // إذا انتهت التجربة، نوجه إلى EndScreen
    if (newExpired || await _timeService.wasTimeTampered()) {
      await _timeService.terminateTrialDueToTampering();
      _navigateToEndScreen();
      return;
    }

    // إذا لم تنتهِ التجربة
    // نتحقق من المطابقة مع الحالة الحالية للشاشة، ونوجه إذا لزم الأمر
    // لكننا سنقارن بالشاشة المعروضة حالياً
    final currentRoute = ModalRoute.of(context)?.settings.name;
    if (newActivated && !newExpired) {
      // يجب أن يكون في DateSelectionScreen أو شاشة رئيسية
      if (currentRoute != '/date_selection') {
        _navigateToDateScreen();
      }
    } else if (!newActivated && !newExpired) {
      // غير مفعل، يجب أن يكون في ActivationScreen
      if (currentRoute != '/activation') {
        _navigateToActivationScreen();
      }
    } else if (newExpired) {
      // انتهت التجربة – تمت معالجتها أعلاه
      return;
    }
  }

  void _navigateToEndScreen() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const EndScreen()),
      (route) => false,
    );
  }

  void _navigateToDateScreen() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => const DateSelectionScreen(
          storeType: '',
          storeName: '',
        ),
      ),
      (route) => false,
    );
  }

  void _navigateToActivationScreen() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const ActivationScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Worker Payments',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.teal,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        fontFamily: 'Arial',
      ),
      // تحديد الشاشة الابتدائية بناءً على الحالة المُمررة
      home: _getInitialScreen(),
      // إضافة named routes لدعم التنقل المتسق
      routes: {
        '/activation': (context) => const ActivationScreen(),
        '/date_selection': (context) => const DateSelectionScreen(storeType: '', storeName: ''),
        '/end': (context) => const EndScreen(),
      },
    );
  }

  Widget _getInitialScreen() {
    if (_isExpired) {
      return const EndScreen();
    }
    if (_isActivated) {
      return const DateSelectionScreen(storeType: '', storeName: '');
    } else {
      return const ActivationScreen();
    }
  }
}