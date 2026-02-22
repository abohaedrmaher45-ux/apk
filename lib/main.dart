import 'package:flutter/material.dart';
import 'license_service.dart';
import 'screens/activation_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'تطبيقي المحمي',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const LicenseCheckScreen(),
    );
  }
}

/// شاشة فحص الترخيص الأولية
class LicenseCheckScreen extends StatefulWidget {
  const LicenseCheckScreen({super.key});

  @override
  State<LicenseCheckScreen> createState() => _LicenseCheckScreenState();
}

class _LicenseCheckScreenState extends State<LicenseCheckScreen> {
  final LicenseService _licenseService = LicenseService();
  bool _isChecking = true;
  String _status = '';

  @override
  void initState() {
    super.initState();
    _checkLicenseStatus();
  }

  Future<void> _checkLicenseStatus() async {
    setState(() {
      _isChecking = true;
    });

    final status = await _licenseService.checkAppStatus();

    setState(() {
      _status = status;
      _isChecking = false;
    });

    // التنقل حسب الحالة
    if (status == 'activated') {
      _navigateToMainApp();
    } else if (status == 'trial') {
      _showTrialWelcome();
    } else if (status == 'expired') {
      _navigateToActivation();
    }
  }

  void _navigateToMainApp() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const MyHomePage()),
    );
  }

  void _navigateToActivation() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const ActivationScreen()),
    );
  }

  void _showTrialWelcome() async {
    final remainingHours = await _licenseService.getRemainingTrialHours();
    
    if (!mounted) return;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text(
          '🎉 مرحباً بك!',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.timer, size: 60, color: Colors.blue),
            const SizedBox(height: 16),
            Text(
              'لديك فترة تجريبية مجانية',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'الوقت المتبقي: $remainingHours ساعة',
              style: TextStyle(fontSize: 16, color: Colors.blue[700]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            const Text(
              'استمتع بجميع المميزات خلال هذه الفترة!',
              style: TextStyle(fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _navigateToMainApp();
            },
            child: const Text('ابدأ الآن', style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: _isChecking
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 24),
                    Text(
                      'جارٍ فحص الترخيص...',
                      style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                    ),
                  ],
                )
              : const SizedBox.shrink(),
        ),
      ),
    );
  }
}

/// الشاشة الرئيسية للتطبيق (بعد التفعيل أو خلال الفترة التجريبية)
class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final LicenseService _licenseService = LicenseService();
  int _counter = 0;
  String? _username;
  String _licenseStatus = '';
  int _remainingHours = 0;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    final username = await _licenseService.getUsername();
    final status = await _licenseService.checkAppStatus();
    final remaining = await _licenseService.getRemainingTrialHours();

    setState(() {
      _username = username;
      _licenseStatus = status;
      _remainingHours = remaining;
    });
  }

  void _incrementCounter() {
    setState(() {
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('التطبيق المحمي'),
        centerTitle: true,
        actions: [
          if (_licenseStatus == 'trial')
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '⏱ $_remainingHours ساعة',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              if (_username != null) ...[
                const Icon(Icons.verified_user, size: 60, color: Colors.green),
                const SizedBox(height: 16),
                Text(
                  'مرحباً، $_username',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.green, width: 2),
                  ),
                  child: const Text(
                    '✅ التطبيق مُفعّل',
                    style: TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
              ] else if (_licenseStatus == 'trial') ...[
                const Icon(Icons.timer, size: 60, color: Colors.orange),
                const SizedBox(height: 16),
                const Text(
                  'الفترة التجريبية',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.orange, width: 2),
                  ),
                  child: Text(
                    '⏱ الوقت المتبقي: $_remainingHours ساعة',
                    style: const TextStyle(
                      color: Colors.orange,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24.0),
                child: Text(
                  'لقد ضغطت على الزر هذا العدد من المرات:',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                '$_counter',
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'زيادة',
        child: const Icon(Icons.add),
      ),
    );
  }
}
