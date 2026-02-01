import 'package:flutter/material.dart';
import 'core/security/license_validator.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 🔐 التحقق من الترخيص قبل بدء التطبيق
  final validationResult = await LicenseValidator.validateLicense();
  
  runApp(MyApp(validationResult: validationResult));
}

class MyApp extends StatelessWidget {
  final LicenseValidationResult validationResult;
  
  const MyApp({super.key, required this.validationResult});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Maherkh App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: validationResult.isValid 
          ? const MyHomePage() 
          : LicenseErrorScreen(validationResult: validationResult),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;
  Map<String, dynamic>? _licenseStatus;

  @override
  void initState() {
    super.initState();
    _loadLicenseStatus();
  }

  Future<void> _loadLicenseStatus() async {
    final status = await LicenseValidator.getLicenseStatus();
    setState(() {
      _licenseStatus = status;
    });
  }

  void _incrementCounter() {
    setState(() {
      _counter++;
    });
  }
  
  void _showLicenseInfo() {
    if (_licenseStatus == null) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.shield_outlined, color: Colors.green),
            SizedBox(width: 8),
            Text('معلومات الترخيص'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildInfoRow('معرف الترخيص:', 
                '${(_licenseStatus!['license_id'] as String).substring(0, 20)}...'),
              const Divider(),
              _buildInfoRow('حالة التفعيل:', 
                _licenseStatus!['is_activated'] ? '✅ مُفعّل' : '❌ غير مُفعّل'),
              _buildInfoRow('تاريخ التفعيل:', _licenseStatus!['activation_date']),
              _buildInfoRow('عدد مرات التشغيل:', 
                _licenseStatus!['total_launches'].toString()),
              const Divider(),
              _buildInfoRow('إصدار التطبيق:', _licenseStatus!['app_version']),
              const Divider(),
              const Text(
                'معلومات الجهاز:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
              ...(_licenseStatus!['device_info'] as Map<String, String>)
                  .entries
                  .map((e) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text('${e.key}: ${e.value}', 
                      style: const TextStyle(fontSize: 12)),
                  )),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }
  
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, 
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(value, 
              style: const TextStyle(fontSize: 13),
              textAlign: TextAlign.left),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Maherkh App - نسخة محمية'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: _showLicenseInfo,
            tooltip: 'معلومات الترخيص',
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.verified_user, color: Colors.green, size: 20),
                    SizedBox(width: 8),
                    Text(
                      '✅ التطبيق مرخص ومحمي',
                      style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24.0),
                child: Text(
                  'لقد قمت بالضغط على الزر:',
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
              const SizedBox(height: 40),
              if (_licenseStatus != null)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'مرات التشغيل: ${_licenseStatus!['total_launches']}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'تاريخ التفعيل: ${(_licenseStatus!['activation_date'] as String).split('T')[0]}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
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

/// شاشة خطأ الترخيص
class LicenseErrorScreen extends StatelessWidget {
  final LicenseValidationResult validationResult;
  
  const LicenseErrorScreen({super.key, required this.validationResult});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 80,
                  color: Colors.red.shade400,
                ),
                const SizedBox(height: 24),
                Text(
                  'خطأ في الترخيص',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade700,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Text(
                    _getErrorMessage(),
                    style: const TextStyle(fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 32),
                const Text(
                  'هذا التطبيق مرخص لجهاز محدد ولا يمكن نسخه أو مشاركته.',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'للحصول على نسخة مرخصة، يرجى التواصل مع المطور.',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  String _getErrorMessage() {
    switch (validationResult.errorCode) {
      case LicenseErrorCode.deviceMismatch:
        return '⚠️ هذا التطبيق مرخص لجهاز آخر\n\nلا يمكن تشغيل هذه النسخة على هذا الجهاز';
      case LicenseErrorCode.invalidLicense:
        return '❌ معرف الترخيص غير صالح\n\nيرجى التواصل مع المطور';
      case LicenseErrorCode.deviceError:
        return '🔧 خطأ في التحقق من الجهاز\n\nتأكد من أذونات التطبيق';
      default:
        return '❓ حدث خطأ غير متوقع\n\n${validationResult.errorMessage ?? "خطأ غير معروف"}';
    }
  }
}
