import 'package:flutter/material.dart';
import 'worker_management_screen.dart';
import 'advance_payment_screen.dart';
import 'attendance_checklist_screen.dart';
import 'payroll_screen.dart';
import 'worker_list_screen.dart';

class MainMenuScreen extends StatelessWidget {
  final String selectedDate;

  const MainMenuScreen({super.key, required this.selectedDate});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('القائمة الرئيسية - $selectedDate'),
        backgroundColor: Colors.teal[700],
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildMenuButton(
                context: context,
                text: 'ادخال الاسماء',
                icon: Icons.person_add_alt_1,
                color: Colors.teal[600]!,
                onPressed: () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => WorkerManagementScreen(
                              selectedDate: selectedDate))); // أضف selectedDate
                },
              ),
              const SizedBox(height: 20),
              _buildMenuButton(
                context: context,
                text: 'جدول التفقد',
                icon: Icons.checklist_rtl,
                color: Colors.green[700]!, // لون جديد ومميز
                onPressed: () {
                  // الانتقال إلى الشاشة الجديدة
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => AttendanceChecklistScreen(
                              selectedDate: selectedDate)));
                },
              ),
              const SizedBox(height: 20),
              _buildMenuButton(
                context: context,
                text: 'دفعة على الحساب',
                icon: Icons.payment,
                color: Colors.blue[700]!, // لون شاشة الدفعات
                onPressed: () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => AdvancePaymentScreen(
                              selectedDate: selectedDate)));
                },
              ),
              const SizedBox(height: 20),
              _buildMenuButton(
                context: context,
                text: 'الاجرة المستحقة',
                icon: Icons.calculate,
                color: Colors.purple[700]!, // لون جديد ومميز
                onPressed: () {
                  // الانتقال إلى الشاشة الجديدة
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              PayrollScreen(selectedDate: selectedDate)));
                },
              ),
              const SizedBox(height: 20),
              _buildMenuButton(
                context: context,
                text: 'تفاصيل العمال',
                icon: Icons.person_search,
                color: Colors.orange[800]!,
                onPressed: () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              WorkerListScreen(selectedDate: selectedDate)));
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuButton({
    required BuildContext context,
    required String text,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 28),
      label: Text(text,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
      style: ElevatedButton.styleFrom(
        foregroundColor: Colors.white,
        backgroundColor: color,
        padding: const EdgeInsets.symmetric(vertical: 20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 5,
      ),
    );
  }
}
