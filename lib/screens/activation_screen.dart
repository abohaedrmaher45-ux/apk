import 'package:flutter/material.dart';
import '../license_service.dart';
import '../main.dart';

class ActivationScreen extends StatefulWidget {
  const ActivationScreen({super.key});

  @override
  State<ActivationScreen> createState() => _ActivationScreenState();
}

class _ActivationScreenState extends State<ActivationScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _idController = TextEditingController();
  final LicenseService _licenseService = LicenseService();
  
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _usernameController.dispose();
    _idController.dispose();
    super.dispose();
  }

  Future<void> _tryActivate() async {
    // التحقق من صحة المدخلات
    if (_usernameController.text.trim().isEmpty) {
      setState(() {
        _errorMessage = 'الرجاء إدخال اسم المستخدم';
      });
      return;
    }

    if (_idController.text.trim().isEmpty) {
      setState(() {
        _errorMessage = 'الرجاء إدخال كود التفعيل (ID)';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // محاولة التفعيل
    bool success = await _licenseService.activateApp(
      _idController.text.trim(),
      _usernameController.text.trim(),
    );

    setState(() {
      _isLoading = false;
    });

    if (success) {
      // التفعيل نجح - الانتقال للشاشة الرئيسية
      if (!mounted) return;
      
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text(
            '✅ تم التفعيل بنجاح!',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.verified_user, size: 80, color: Colors.green),
              const SizedBox(height: 16),
              Text(
                'مرحباً، ${_usernameController.text.trim()}!',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'تم تفعيل التطبيق بنجاح. استمتع بجميع المميزات!',
                style: TextStyle(fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const MyHomePage()),
                  (route) => false,
                );
              },
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 45),
                backgroundColor: Colors.green,
              ),
              child: const Text(
                'ابدأ الآن',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
          ],
        ),
      );
    } else {
      // التفعيل فشل
      setState(() {
        _errorMessage = 'كود التفعيل غير صحيح أو غير مطابق لجهازك';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تفعيل التطبيق'),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              
              // أيقونة التفعيل
              const Icon(
                Icons.lock_clock,
                size: 80,
                color: Colors.red,
              ),
              const SizedBox(height: 24),
              
              // العنوان
              const Text(
                'انتهت الفترة التجريبية',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              
              // الوصف
              const Text(
                'للاستمرار في استخدام التطبيق، يرجى إدخال بيانات التفعيل',
                style: TextStyle(fontSize: 16, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              
              // حقل اسم المستخدم
              TextField(
                controller: _usernameController,
                decoration: InputDecoration(
                  labelText: 'اسم المستخدم',
                  prefixIcon: const Icon(Icons.person),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
                textAlign: TextAlign.right,
              ),
              const SizedBox(height: 20),
              
              // حقل كود التفعيل (ID)
              TextField(
                controller: _idController,
                decoration: InputDecoration(
                  labelText: 'كود التفعيل (ID)',
                  prefixIcon: const Icon(Icons.vpn_key),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
                textAlign: TextAlign.right,
              ),
              const SizedBox(height: 20),
              
              // رسالة الخطأ
              if (_errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red, width: 1),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error, color: Colors.red, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 30),
              
              // زر التفعيل
              _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(),
                    )
                  : ElevatedButton(
                      onPressed: _tryActivate,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 55),
                        backgroundColor: Colors.blue,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'تفعيل الآن',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
              const SizedBox(height: 20),
              
              // ملاحظة
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue, width: 1),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.info, color: Colors.blue, size: 30),
                    SizedBox(height: 8),
                    Text(
                      'كود التفعيل مرتبط بجهازك',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 4),
                    Text(
                      'تأكد من إدخال الكود الصحيح المقدم لك من المطور',
                      style: TextStyle(
                        color: Colors.blue,
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
