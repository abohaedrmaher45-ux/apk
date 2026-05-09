import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/payroll_service.dart';

class PayrollScreen extends StatefulWidget {
  final String selectedDate;

  const PayrollScreen({Key? key, required this.selectedDate}) : super(key: key);

  @override
  _PayrollScreenState createState() => _PayrollScreenState();
}

class _PayrollScreenState extends State<PayrollScreen> {
  final PayrollService _payrollService = PayrollService();
  late Future<List<PayrollResult>> _payrollFuture;

  @override
  void initState() {
    super.initState();
    _payrollFuture = _payrollService.calculatePayroll(widget.selectedDate);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'احتساب الاجرة المستحقة\nلغاية تاريخ ${widget.selectedDate}',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16, height: 1.2),
        ),
        centerTitle: true,
        backgroundColor: Colors.purple[700],
        foregroundColor: Colors.white,
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: FutureBuilder<List<PayrollResult>>(
          future: _payrollFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('حدث خطأ: ${snapshot.error}'));
            }
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Center(child: Text('لا توجد بيانات لعرضها.'));
            }

            final results = snapshot.data!;

            return SingleChildScrollView(
              child: Table(
                border: TableBorder.all(color: Colors.grey.shade300),
                // هذا هو مفتاح الحل: توزيع المساحة بالتساوي على 5 أعمدة
                columnWidths: const <int, TableColumnWidth>{
                  0: FlexColumnWidth(), // العامل
                  1: FlexColumnWidth(), // مجموع الأجرة
                  2: FlexColumnWidth(), // أيام الغياب
                  3: FlexColumnWidth(), // دفعة من الحساب
                  4: FlexColumnWidth(), // الاستحقاق
                },
                children: [
                  // صف الرأس
                  TableRow(
                    decoration:
                        BoxDecoration(color: Colors.purple.withOpacity(0.1)),
                    children: [
                      _buildHeaderCell('العامل'),
                      _buildHeaderCell('أيام الحضور'),
                      _buildHeaderCell('أيام الغياب'),
                      _buildHeaderCell('دفعة على الحساب'),
                      _buildHeaderCell('الإستحقاق'),
                    ],
                  ),
                  // صفوف البيانات
                  ...results.map((result) {
                    // الاستحقاق: إزالة الأصفار الزائدة + إضافة الوحدة
                    final netDueFormatted = result.netDue
                        .toStringAsFixed(2)
                        .replaceAll(RegExp(r'\.00$'), '');

                    final netDueDisplay = result.currency.isNotEmpty
                        ? '$netDueFormatted ${result.currency}'
                        : netDueFormatted;

                    final advancesFormatted = result.advances
                        .toStringAsFixed(2)
                        .replaceAll(RegExp(r'\.00$'), '');

                    return TableRow(
                      children: [
                        _buildDataCell(result.workerName),
                        _buildDataCell(result.presentDays.toString()),
                        _buildDataCell(result.absentDays.toString()),
                        _buildDataCell(advancesFormatted),
                        GestureDetector(
                          onTap: () => _showCollectDialog(context, result),
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Center(
                              child: Text(
                                netDueDisplay,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                  decoration: TextDecoration.underline,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  }),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // دالة مساعدة لبناء خلية الرأس
  Widget _buildHeaderCell(String text) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Center(
        child: Text(
          text,
          style: const TextStyle(fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  // دالة مساعدة لبناء خلية البيانات
  Widget _buildDataCell(String text, {TextStyle? style}) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Center(
        child: Text(
          text,
          style: style,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Future<void> _showCollectDialog(
      BuildContext context, PayrollResult result) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'قبض العامل ${result.workerName} ؟',
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('لا',
                style: TextStyle(color: Colors.red, fontSize: 16)),
          ),
          const SizedBox(width: 40),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('نعم',
                style: TextStyle(color: Colors.green, fontSize: 16)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      // حفظ تاريخ القبض فقط - بدون أي حذف للسجلات
      await _payrollService.saveCollectionDate(
          result.workerName, widget.selectedDate);

      setState(() {
        _payrollFuture = _payrollService.calculatePayroll(widget.selectedDate);
      });
    }
  }
}
