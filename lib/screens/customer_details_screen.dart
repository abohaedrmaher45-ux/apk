// lib/screens/customer_details_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/storage_service.dart';
import '../models/customer.dart';
import '../models/transaction.dart';
import '../utils/app_constants.dart';
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
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => isLoading = true);
    try {
      final customers = await storage.getCustomers();
      customer = storage.getCustomerById(customers, widget.customerId);
      transactions = await storage.getTransactionsByCustomer(widget.customerId);
      remainingMaterials = await storage.getCustomerRemainingMaterials(widget.customerId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في تحميل البيانات: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _deleteTransaction(Transaction transaction) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف معاملة'),
        content: Text('هل أنت متأكد من حذف هذه ${transaction.type.name}؟'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف', style: TextStyle(color: AppConstants.dangerColor)),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      setState(() => isLoading = true);
      await storage.deleteTransaction(transaction.id);
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ تم الحذف')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('تفاصيل العميل')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    
    if (customer == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('تفاصيل العميل')),
        body: const Center(child: Text('العميل غير موجود')),
      );
    }
    
    return Scaffold(
      appBar: AppBar(title: Text(customer!.name)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // بطاقة معلومات العميل
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.person, size: 28, color: AppConstants.primaryColor),
                        const SizedBox(width: 12),
                        Text(
                          customer!.name,
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    if (customer!.phone != null) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(Icons.phone, size: 20, color: Colors.grey),
                          const SizedBox(width: 8),
                          Text(customer!.phone!),
                        ],
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.calendar_today, size: 20, color: Colors.grey),
                        const SizedBox(width: 8),
                        Text('تاريخ التسجيل: ${customer!.createdAt}'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // الكميات المتبقية
            if (remainingMaterials.isNotEmpty)
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.inventory, color: AppConstants.accentColor),
                          SizedBox(width: 8),
                          Text('الكميات المتبقية', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const Divider(height: 24),
                      ...remainingMaterials.map((item) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(item['materialName'], style: const TextStyle(fontSize: 16)),
                            Text(
                              '${(item['remaining'] as double).toStringAsFixed(2)} ${AppConstants.getUnit(item['materialName'])}',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppConstants.accentColor),
                            ),
                          ],
                        ),
                      )),
                    ],
                  ),
                ),
              ),
            
            const SizedBox(height: 16),
            
            // سجل المعاملات
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.history, color: AppConstants.primaryColor),
                        SizedBox(width: 8),
                        Text('سجل المعاملات', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const Divider(height: 24),
                    if (transactions.isEmpty)
                      const Center(child: Text('لا توجد معاملات', style: TextStyle(color: Colors.grey))),
                    ...transactions.map((t) => _buildTransactionItem(t)),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // أزرار الإجراءات
            ElevatedButton.icon(
              onPressed: () => Navigator.pushNamed(context, '/return_invoice', arguments: widget.customerId).then((_) => _loadData()),
              icon: const Icon(Icons.receipt),
              label: const Text('فاتورة إرجاع جديدة', style: TextStyle(fontSize: 16)),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
            
            const SizedBox(height: 12),
            
            OutlinedButton.icon(
              onPressed: () async => PdfGenerator.generateCustomerReport(
                customer: customer!,
                transactions: transactions,
                remainingMaterials: remainingMaterials,
              ),
              icon: const Icon(Icons.picture_as_pdf),
              label: const Text('تصدير تقرير PDF', style: TextStyle(fontSize: 16)),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionItem(Transaction t) {
    final unit = AppConstants.getUnit(t.materialName);
    final icon = t.type == TransactionType.withdrawal ? Icons.arrow_upward : Icons.arrow_downward;
    final iconColor = t.type == TransactionType.withdrawal ? AppConstants.dangerColor : AppConstants.successColor;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: iconColor.withAlpha(26),
          child: Icon(icon, color: iconColor),
        ),
        title: Text(
          '${t.type.name} - ${t.materialName}',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('الكمية: ${t.quantity.toStringAsFixed(2)} $unit'),
            Text('التاريخ: ${t.date}'),
            if (t.returnDate != null && t.type == TransactionType.withdrawal)
              Text('تاريخ العودة: ${t.returnDate}', style: const TextStyle(color: AppConstants.secondaryColor)),
            if (t.note != null)
              Text('ملاحظة: ${t.note}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.blue),
              onPressed: () => Navigator.pushNamed(context, '/edit_transaction', arguments: t.id).then((_) => _loadData()),
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: AppConstants.dangerColor),
              onPressed: () => _deleteTransaction(t),
            ),
          ],
        ),
      ),
    );
  }
}