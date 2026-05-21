import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/storage_service.dart';
import '../models/customer.dart';
import '../models/transaction.dart';
import '../utils/constants.dart';
import '../widgets/pdf_generator.dart';

class CustomerDetailsScreen extends StatefulWidget {
  final int customerId;
  const CustomerDetailsScreen({super.key, required this.customerId});

  @override
  State<CustomerDetailsScreen> createState() => _CustomerDetailsScreenState();
}

class _CustomerDetailsScreenState extends State<CustomerDetailsScreen> {
  final StorageService storage = StorageService.instance;
  Customer? customer;
  List<Transaction> transactions = [];
  List<Map<String, dynamic>> remainingMaterials = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final customers = await storage.getCustomers();
    customer = storage.getCustomerById(customers, widget.customerId);
    transactions = await storage.getTransactionsByCustomer(widget.customerId);
    remainingMaterials = await storage.getCustomerRemainingMaterials(widget.customerId);
    setState(() {});
  }

  Future<void> _deleteTransaction(Transaction transaction) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف معاملة'),
        content: Text('هل أنت متأكد من حذف هذه ${transaction.type.name}؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          TextButton(onPressed: () => Navigator.pop(context, true), style: TextButton.styleFrom(foregroundColor: Colors.red), child: const Text('حذف')),
        ],
      ),
    );
    if (confirmed == true) {
      await storage.deleteTransaction(transaction.id);
      await _loadData();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم الحذف')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (customer == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('تفاصيل العميل')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(customer!.name)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [const Icon(Icons.person, size: 28), const SizedBox(width: 8), Text(customer!.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold))]),
                    if (customer!.phone != null) ...[
                      const SizedBox(height: 8),
                      Row(children: [const Icon(Icons.phone, size: 20), const SizedBox(width: 8), Text(customer!.phone!)]),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (remainingMaterials.isNotEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('الكميات المتبقية', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const Divider(),
                      ...remainingMaterials.map((item) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(item['materialName'], style: const TextStyle(fontSize: 16)),
                            Text('${(item['remaining'] as double).toStringAsFixed(2)} ${materialUnit[item['materialName']]}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      )),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('سجل المعاملات', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const Divider(),
                    if (transactions.isEmpty) const Center(child: Text('لا توجد معاملات')),
                    ...transactions.map((t) => _buildTransactionItem(t)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => Navigator.pushNamed(context, '/return_invoice', arguments: widget.customerId).then((_) => _loadData()),
              icon: const Icon(Icons.receipt),
              label: const Text('فاتورة إرجاع جديدة'),
              style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () async => PdfGenerator.generateCustomerReport(customer: customer!, transactions: transactions, remainingMaterials: remainingMaterials),
              icon: const Icon(Icons.picture_as_pdf),
              label: const Text('تصدير تقرير PDF'),
              style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionItem(Transaction t) {
    final unit = materialUnit[t.materialName] ?? '';
    final icon = t.type == TransactionType.withdrawal ? Icons.arrow_upward : Icons.arrow_downward;
    final iconColor = t.type == TransactionType.withdrawal ? Colors.red : Colors.green;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: CircleAvatar(backgroundColor: iconColor.withAlpha(51), child: Icon(icon, color: iconColor)),
        title: Text('${t.type.name} - ${t.materialName}'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('الكمية: ${t.quantity.toStringAsFixed(2)} $unit'),
            Text('التاريخ: ${t.date}'),
            if (t.returnDate != null && t.type == TransactionType.withdrawal) Text('تاريخ العودة: ${t.returnDate}', style: const TextStyle(color: Colors.orange)),
            if (t.note != null) Text('ملاحظة: ${t.note}', style: const TextStyle(fontSize: 12)),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => Navigator.pushNamed(context, '/edit_transaction', arguments: t.id).then((_) => _loadData())),
            IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _deleteTransaction(t)),
          ],
        ),
      ),
    );
  }
}