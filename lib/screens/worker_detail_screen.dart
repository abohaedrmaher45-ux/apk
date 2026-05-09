import 'package:flutter/material.dart';
import '../services/worker_index_service.dart';
import '../services/attendance_storage_service.dart';
import '../services/payment_storage_service.dart';

class WorkerDetailScreen extends StatefulWidget {
  final WorkerData worker;
  final String selectedDate;

  const WorkerDetailScreen(
      {Key? key, required this.worker, required this.selectedDate})
      : super(key: key);

  @override
  _WorkerDetailScreenState createState() => _WorkerDetailScreenState();
}

class _WorkerDetailScreenState extends State<WorkerDetailScreen> {
  final AttendanceStorageService _attendanceService =
      AttendanceStorageService();
  final PaymentStorageService _paymentService = PaymentStorageService();

  bool _isLoading = true;
  int _totalPresent = 0;
  int _totalAbsent = 0;
  List<Map<String, String>> _payments = [];

  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    final selectedDate = _parseDate(widget.selectedDate);
    final firstDayOfMonth = DateTime(selectedDate.year, selectedDate.month, 1);

    int present = 0;
    int absent = 0;
    List<Map<String, String>> payments = [];

    for (int i = 0; i <= selectedDate.difference(firstDayOfMonth).inDays; i++) {
      final currentDate = firstDayOfMonth.add(Duration(days: i));
      final dateString =
          '${currentDate.year}/${currentDate.month}/${currentDate.day}';

      // حضور وغياب
      final attendanceDoc =
          await _attendanceService.loadAttendanceDocumentForDate(dateString);
      if (attendanceDoc != null) {
        for (var record in attendanceDoc.records) {
          if (record.workerName == widget.worker.name) {
            if (record.status == 'موجود') {
              present++;
            } else {
              absent++;
            }
          }
        }
      }

      // المدفوعات
      final paymentDoc =
          await _paymentService.loadPaymentDocumentForDate(dateString);
      if (paymentDoc != null) {
        for (var payment in paymentDoc.transactions) {
          if (payment.workerName == widget.worker.name &&
              payment.paymentValue.isNotEmpty) {
            payments.add({
              'date': dateString,
              'value': payment.paymentValue,
              'notes': payment.notes,
            });
          }
        }
      }
    }

    if (mounted) {
      setState(() {
        _totalPresent = present;
        _totalAbsent = absent;
        _payments = payments;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalPaid = _payments.fold(
        0.0, (sum, p) => sum + (double.tryParse(p['value'] ?? '0') ?? 0));

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.worker.name,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.orange[800],
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // بطاقة المعلومات الأساسية
                    Card(
                      elevation: 3,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            _buildInfoRow(
                                Icons.phone,
                                'الموبايل',
                                widget.worker.mobile.isEmpty
                                    ? '—'
                                    : widget.worker.mobile),
                            const Divider(),
                            _buildInfoRow(Icons.attach_money, 'الأجرة اليومية',
                                '${widget.worker.balance.toStringAsFixed(2).replaceAll(RegExp(r'\.00$'), '')} ${widget.worker.currency}'),
                            const Divider(),
                            _buildInfoRow(
                                Icons.monetization_on,
                                'العملة',
                                widget.worker.currency.isEmpty
                                    ? '—'
                                    : widget.worker.currency),
                            const Divider(),
                            _buildInfoRow(Icons.calendar_today, 'تاريخ البدء',
                                widget.worker.startDate),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // بطاقة الحضور والغياب
                    Row(
                      children: [
                        Expanded(
                          child: Card(
                            color: Colors.green[50],
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                children: [
                                  Icon(Icons.check_circle,
                                      color: Colors.green[700], size: 32),
                                  const SizedBox(height: 8),
                                  Text('$_totalPresent',
                                      style: TextStyle(
                                          fontSize: 28,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.green[700])),
                                  const Text('أيام الحضور',
                                      style: TextStyle(fontSize: 13)),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Card(
                            color: Colors.red[50],
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                children: [
                                  Icon(Icons.cancel,
                                      color: Colors.red[700], size: 32),
                                  const SizedBox(height: 8),
                                  Text('$_totalAbsent',
                                      style: TextStyle(
                                          fontSize: 28,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.red[700])),
                                  const Text('أيام الغياب',
                                      style: TextStyle(fontSize: 13)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // بطاقة المدفوعات
                    Card(
                      elevation: 3,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('مدفوعات الحساب',
                                    style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold)),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.blue[700],
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    'المجموع: ${totalPaid.toStringAsFixed(2).replaceAll(RegExp(r'\.00$'), '')} ${widget.worker.currency}',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            if (_payments.isEmpty)
                              const Center(
                                  child: Text('لا توجد مدفوعات مسجلة',
                                      style: TextStyle(color: Colors.grey)))
                            else
                              Table(
                                border: TableBorder.all(
                                    color: Colors.grey.shade300),
                                columnWidths: const {
                                  0: FlexColumnWidth(2),
                                  1: FlexColumnWidth(2),
                                  2: FlexColumnWidth(3),
                                },
                                children: [
                                  TableRow(
                                    decoration:
                                        BoxDecoration(color: Colors.grey[200]),
                                    children: const [
                                      Padding(
                                        padding: EdgeInsets.all(6),
                                        child: Text('التاريخ',
                                            style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12),
                                            textAlign: TextAlign.center),
                                      ),
                                      Padding(
                                        padding: EdgeInsets.all(6),
                                        child: Text('المبلغ',
                                            style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12),
                                            textAlign: TextAlign.center),
                                      ),
                                      Padding(
                                        padding: EdgeInsets.all(6),
                                        child: Text('البيان',
                                            style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12),
                                            textAlign: TextAlign.center),
                                      ),
                                    ],
                                  ),
                                  ..._payments.map((p) => TableRow(
                                        children: [
                                          Padding(
                                            padding: const EdgeInsets.all(6),
                                            child: Text(p['date'] ?? '',
                                                style: const TextStyle(
                                                    fontSize: 11),
                                                textAlign: TextAlign.center),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.all(6),
                                            child: Text(p['value'] ?? '',
                                                style: const TextStyle(
                                                    fontSize: 11,
                                                    fontWeight:
                                                        FontWeight.bold),
                                                textAlign: TextAlign.center),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.all(6),
                                            child: Text(p['notes'] ?? '',
                                                style: const TextStyle(
                                                    fontSize: 11),
                                                textAlign: TextAlign.center),
                                          ),
                                        ],
                                      )),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: Colors.orange[800], size: 20),
          const SizedBox(width: 10),
          Text('$label: ',
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          Expanded(
            child: Text(value,
                style: const TextStyle(fontSize: 14),
                textAlign: TextAlign.left),
          ),
        ],
      ),
    );
  }

  DateTime _parseDate(String dateStr) {
    final parts = dateStr.split('/');
    return DateTime(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
  }
}
