// lib/screens/customer_details_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/storage_service.dart';
import '../models/customer.dart';
import '../models/transaction.dart';
import '../utils/app_constants.dart';

class CustomerDetailsScreen extends StatefulWidget {
  final int customerId;
  const CustomerDetailsScreen({super.key, required this.customerId});

  @override
  State<CustomerDetailsScreen> createState() => _CustomerDetailsScreenState();
}

class _CustomerDetailsScreenState extends State<CustomerDetailsScreen> {
  final StorageService storage = StorageService.instance;
  
  Customer? _customer;
  List<Transaction> _withdrawals = [];
  Map<int, double> _returnedQuantities = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    final customers = await storage.getCustomers();
    _customer = storage.getCustomerById(customers, widget.customerId);
    
    // جلب جميع عمليات السحب لهذا العميل
    _withdrawals = await storage.getWithdrawalsByCustomer(widget.customerId);
    
    // حساب الكمية المرتجعة لكل عملية سحب
    final allTransactions = await storage.getTransactionsByCustomer(widget.customerId);
    final returns = allTransactions.where((t) => t.type == TransactionType.return_).toList();
    
    for (var withdrawal in _withdrawals) {
      double returned = 0;
      for (var returnT in returns) {
        if (returnT.linkedWithdrawalId == withdrawal.id) {
          returned += returnT.quantity;
        }
      }
      _returnedQuantities[withdrawal.id] = returned;
    }
    
    setState(() => _isLoading = false);
  }

  double getRemainingForWithdrawal(Transaction withdrawal) {
    final returned = _returnedQuantities[withdrawal.id] ?? 0;
    return withdrawal.quantity - returned;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text(_customer?.name ?? 'تفاصيل العميل'),
        backgroundColor: AppConstants.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _customer == null
              ? const Center(child: Text('العميل غير موجود'))
              : _withdrawals.isEmpty
                  ? const Center(child: Text('لا توجد عمليات سحب لهذا العميل'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _withdrawals.length,
                      itemBuilder: (context, index) {
                        final w = _withdrawals[index];
                        final remaining = getRemainingForWithdrawal(w);
                        return _buildWithdrawalCard(w, remaining);
                      },
                    ),
    );
  }

  Widget _buildWithdrawalCard(Transaction withdrawal, double remaining) {
    final isCompleted = remaining <= 0;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // رأس البطاقة
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isCompleted ? Colors.green.withAlpha(26) : AppConstants.primaryColor.withAlpha(26),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isCompleted ? Icons.check_circle : Icons.inventory,
                    color: isCompleted ? Colors.green : AppConstants.primaryColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        withdrawal.materialName,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'تاريخ السحب: ${withdrawal.date}',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                if (isCompleted)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withAlpha(26),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'مكتمل',
                      style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),
            
            // التفاصيل
            _buildDetailRow('الكمية المسحوبة:', '${withdrawal.quantity.toStringAsFixed(2)}'),
            _buildDetailRow('الكمية المرتجعة:', '${(withdrawal.quantity - remaining).toStringAsFixed(2)}'),
            _buildDetailRow('الكمية المتبقية:', '${remaining.toStringAsFixed(2)}', isRemaining: true),
            _buildDetailRow('سعر الفرد:', '${withdrawal.pricePerUnit.toStringAsFixed(2)} ${AppConstants.currencySymbol}'),
            _buildDetailRow('تاريخ العودة المتوقع:', withdrawal.returnDate ?? 'غير محدد'),
            if (withdrawal.note != null) _buildDetailRow('ملاحظة:', withdrawal.note!),
            
            const SizedBox(height: 12),
            
            // زر الإرجاع (إذا لم تكتمل الكمية)
            if (!isCompleted)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pushNamed(
                    context,
                    '/return_invoice',
                    arguments: {
                      'customerId': withdrawal.customerId,
                      'withdrawalId': withdrawal.id,
                      'materialName': withdrawal.materialName,
                      'remainingQuantity': remaining,
                    },
                  ).then((_) => _loadData()),
                  icon: const Icon(Icons.receipt, size: 18),
                  label: const Text('إرجاع جزء من هذه المادة'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isRemaining = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade600)),
          Text(
            value,
            style: TextStyle(
              fontWeight: isRemaining ? FontWeight.bold : FontWeight.normal,
              color: isRemaining && double.tryParse(value.split(' ')[0]) != 0
                  ? Colors.amber
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}