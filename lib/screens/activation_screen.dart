// lib/screens/activation_screen.dart
import 'package:flutter/material.dart';
import '../services/app_state_manager.dart';

class ActivationScreen extends StatefulWidget {
  @override
  _ActivationScreenState createState() => _ActivationScreenState();
}

class _ActivationScreenState extends State<ActivationScreen> {
  final TextEditingController _idController = TextEditingController();
  final AppStateManager _manager = AppStateManager();
  bool _isLoading = false;
  String? _errorMessage;

  void _tryActivate() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    bool success = await _manager.activateApp(_idController.text.trim(), "User");

    setState(() {
      _isLoading = false;
      if (success) {
        // إذا نجح التفعيل، نعيد بناء الواجهة في main.dart
        // طريقة بسيطة: نستبدل الشاشة الحالية بالشاشة الرئيسية
        Navigator.pushReplacementNamed(context, '/home');
      } else {
        _errorMessage = "كود التفعيل غير صحيح أو غير مطابق لجهازك";
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("تفعيل التطبيق")),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text("انتهت الفترة التجريبية. الرجاء إدخال كود التفعيل:", 
                 style: TextStyle(fontSize: 16),
                 textAlign: TextAlign.center),
            SizedBox(height: 20),
            TextField(
              controller: _idController,
              decoration: InputDecoration(
                labelText: "كود التفعيل (ID)",
                border: OutlineInputBorder(),
              ),
            ),
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(_errorMessage!, style: TextStyle(color: Colors.red)),
              ),
            SizedBox(height: 20),
            _isLoading
                ? CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: _tryActivate,
                    child: Text("تفعيل الآن"),
                    style: ElevatedButton.styleFrom(
                      minimumSize: Size(double.infinity, 50)
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}