import 'package:flutter/material.dart';
import 'license_service.dart'; // استدعاء ملف الخدمة الذي أنشأناه بالأعلى

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  // نقوم بإنشاء كائن من الخدمة
  final LicenseService _licenseService = LicenseService();

  @override
  Widget build(BuildContext context) {
    // المهم: MaterialApp يجب أن تكون الجذر، لأننا نحتاجها للتنقل والثيمات
    return MaterialApp(
      title: 'My Secure App',
      home: FutureBuilder<String>(
        future: _licenseService.checkAppStatus(),
        builder: (context, snapshot) {
          // 1. حالة الانتظار (جاري التحقق من الوقت/الترخيص)
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          
          // 2. حالة وجود خطأ
          if (snapshot.hasError) {
            return Scaffold(
              body: Center(child: Text("Error checking license")),
            );
          }

          // 3. حالة وجود البيانات (القرار)
          String status = snapshot.data ?? 'expired'; // Default to expired if null

          if (status == 'trial') {
            // وضع التجربة: عرض التطبيق مع شعار (تجريبي)
            return MainAppScreen(isTrial: true);
          } else if (status == 'expired') {
            // انتهت المدة: عرض شاشة التفعيل
            return ActivationScreen(licenseService: _licenseService);
          } else {
            // مفعل: عرض التطبيق الكامل
            return MainAppScreen(isTrial: false);
          }
        },
      ),
    );
  }
}

// واجهة التطبيق الرئيسية
class MainAppScreen extends StatelessWidget {
  final bool isTrial;
  MainAppScreen({required this.isTrial});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isTrial ? "التطبيق (نسخة تجريبية)" : "التطبيق"),
        actions: [
          if (isTrial) 
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Icon(Icons.timer, color: Colors.orange),
            )
        ],
      ),
      body: Center(
        child: Text("مرحباً بك في التطبيق، البيانات مشفرة وآمنة."),
      ),
    );
  }
}

// شاشة التفعيل (بعد انتهاء المدة)
class ActivationScreen extends StatelessWidget {
  final LicenseService licenseService;
  
  ActivationScreen({required this.licenseService});

  final TextEditingController _userController = TextEditingController();
  final TextEditingController _idController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text("انتهت الفترة التجريبية", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            SizedBox(height: 20),
            TextField(
              controller: _userController,
              decoration: InputDecoration(labelText: "اسم المستخدم", border: OutlineInputBorder()),
            ),
            SizedBox(height: 10),
            TextField(
              controller: _idController,
              decoration: InputDecoration(labelText: "رقم التفعيل (ID)", border: OutlineInputBorder()),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                // التحقق باستخدام الخوارزمية المحلية
                bool isValid = await licenseService.validateId(
                  _userController.text, 
                  _idController.text
                );
                
                if (isValid) {
                  // حفظ التفعيل
                  await licenseService.activateApp(
                    _idController.text, 
                    _userController.text
                  );
                  
                  // إعادة تحميل التطبيق (أو التنقل للشاشة الرئيسية)
                  Navigator.pushReplacement(
                    context, 
                    MaterialPageRoute(builder: (_) => MyApp())
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("معلومات التفعيل غير صحيحة"))
                  );
                }
              },
              child: Text("تفعيل الآن"),
            ),
            SizedBox(height: 10),
            Text("ملاحظة: التحقق يتم محلياً لضمان الخصوصية", style: TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}