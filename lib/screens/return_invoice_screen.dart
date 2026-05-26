// lib/screens/return_invoice_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../services/storage_service.dart';
import '../models/customer.dart';
import '../models/transaction.dart';
import '../utils/app_constants.dart';

class ReturnInvoiceScreen extends StatefulWidget {
  final int customerId;
  final int? withdrawalId;
  final String? materialName;
  final double? remainingQuantity;

  const ReturnInvoiceScreen({
    super.key,
    required this.customerId,
    this.withdrawalId,
    this.materialName,
    this.remainingQuantity,
  });

  @override
  State<ReturnInvoiceScreen> createState() => _ReturnInvoiceScreenState();
}

class _ReturnInvoiceScreenState extends State<ReturnInvoiceScreen> {
  final StorageService storage = StorageService.instance;
  final _formKey = GlobalKey<FormState>();
  
  Customer? _customer;
  List<Transaction> _withdrawals = [];
  Transaction? _selectedWithdrawal;
  double _maxReturnQuantity = 0;
  double _returnQuantity = 0;
  String _note = '';
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    final customers = await storage.getCustomers();
    _customer = storage.getCustomerById(customers, widget.customerId);
    
    // جلب عمليات السحب التي لم تكتمل
    final allWithdrawals = await storage.getWithdrawalsByCustomer(widget.customerId);
    _withdrawals = [];
    
    for (var w in allWithdrawals) {
      final remaining = await storage.getRemainingQuantity(w.customerId, w.materialName);
      if (remaining > 0) {
        _withdrawals.add(w);
      }
    }
    
    // إذا تم تمرير withdrawalId محدد
    if (widget.withdrawalId != null) {
      try {
        _selectedWithdrawal = _withdrawals.firstWhere(
          (w) => w.id == widget.withdrawalId,
        );
        if (_selectedWithdrawal != null) {
          _maxReturnQuantity = await storage.getRemainingQuantity(
            widget.customerId,
            _selectedWithdrawal!.materialName,
          );
        }
      } catch (e) {
        // إذا لم يتم العثور على withdrawalId، اختر الأول
        if (_withdrawals.isNotEmpty) {
          _selectedWithdrawal = _withdrawals.first;
          _maxReturnQuantity = await storage.getRemainingQuantity(
            widget.customerId,
            _selectedWithdrawal!.materialName,
          );
        }
      }
    } else if (_withdrawals.isNotEmpty) {
      // إذا لم يتم تمرير withdrawalId، اختر الأول
      _selectedWithdrawal = _withdrawals.first;
      _maxReturnQuantity = await storage.getRemainingQuantity(
        widget.customerId,
        _selectedWithdrawal!.materialName,
      );
    }
    
    setState(() => _isLoading = false);
  }

  Future<void> _updateSelectedWithdrawal(Transaction? withdrawal) async {
    setState(() {
      _selectedWithdrawal = withdrawal;
      _returnQuantity = 0;
    });
    
    if (withdrawal != null) {
      final remaining = await storage.getRemainingQuantity(
        widget.customerId,
        withdrawal.materialName,
      );
      setState(() => _maxReturnQuantity = remaining);
    }
  }

  Future<void> _saveReturn() async {
    if (!_formKey.currentState!.validate()) return;
    if (_customer == null) return;
    if (_selectedWithdrawal == null) {
      _showToast('الرجاء اختيار عملية السحب');
      return;
    }
    
    if (_returnQuantity <= 0) {
      _showToast('الرجاء إدخال كمية صحيحة');
      return;
    }
    
    if (_returnQuantity > _maxReturnQuantity) {
      _showToast('⚠️ الكمية المرتجعة أكبر من المتوفرة (${_maxReturnQuantity.toStringAsFixed(2)})');
      return;
    }
    
    setState(() => _isSaving = true);
    
    try {
      final transactionId = await storage.getNextTransactionId();
      final transaction = Transaction(
        id: transactionId,
        customerId: widget.customerId,
        materialName: _selectedWithdrawal!.materialName,
        type: TransactionType.return_,
        quantity: _returnQuantity,
        pricePerUnit: 0,
        discountPercent: 0,
        date: DateFormat('yyyy-MM-dd').format(DateTime.now()),
        returnDate: null,
        actualReturnDate: DateFormat('yyyy-MM-dd').format(DateTime.now()),
        note: _note.isEmpty ? null : _note,
        linkedWithdrawalId: _selectedWithdrawal!.id,
      );
      
      await storage.addTransaction(transaction);
      _showToast('✅ تم تسجيل الإرجاع بنجاح');
      
      if (mounted) Navigator.pop(context);
      
    } catch (e) {
      _showToast('❌ حدث خطأ: $e');
    } finally {
      setState(() => _isSaving = false);
    }
  }
  
  void _showToast(String msg) {
    Fluttertoast.showToast(msg: msg, gravity: ToastGravity.BOTTOM);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('إرجاع مواد'),
        backgroundColor: AppConstants.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _customer == null
              ? const Center(child: Text('العميل غير موجود'))
              : _withdrawals.isEmpty
                  ? _buildEmptyState()
                  : _buildReturnForm(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle, size: 80, color: Colors.green),
          const SizedBox(height: 16),
          const Text(
            'لا توجد مواد متبقية للإرجاع',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'جميع المواد تم إرجاعها',
            style: TextStyle(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back),
            label: const Text('العودة'),
          ),
        ],
      ),
    );
  }

  Widget _buildReturnForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            // معلومات العميل
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.person, size: 40, color: AppConstants.primaryColor),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_customer!.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          if (_customer!.phone != null) Text(_customer!.phone!),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // اختيار عملية السحب
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'اختر عملية السحب',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<Transaction>(
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                      ),
                      value: _selectedWithdrawal,
                      items: _withdrawals.map((w) {
                        return DropdownMenuItem<Transaction>(
                          value: w,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${w.materialName} - ${w.date}'),
                              Text(
                                'الكمية المتبقية: ${w.quantity.toStringAsFixed(2)}',
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: _updateSelectedWithdrawal,
                      validator: (value) => value == null ? 'الرجاء اختيار عملية السحب' : null,
                    ),
                    const SizedBox(height: 16),

                    if (_selectedWithdrawal != null) ...[
                      const Divider(),
                      const SizedBox(height: 8),
                      _buildDetailRow('المادة:', _selectedWithdrawal!.materialName),
                      _buildDetailRow('تاريخ السحب:', _selectedWithdrawal!.date),
                      _buildDetailRow('تاريخ العودة المتوقع:', _selectedWithdrawal!.returnDate ?? 'غير محدد'),
                      _buildDetailRow('الكمية المتبقية:', '${_maxReturnQuantity.toStringAsFixed(2)}', isRemaining: true),
                      const SizedBox(height: 16),

                      // الكمية المرتجعة
                      TextFormField(
                        decoration: InputDecoration(
                          labelText: 'الكمية المرتجعة',
                          border: const OutlineInputBorder(),
                          suffixText: 'وحدة',
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (v) => _returnQuantity = double.tryParse(v) ?? 0,
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'الرجاء إدخال الكمية';
                          final val = double.tryParse(v);
                          if (val == null) return 'الرجاء إدخال رقم صحيح';
                          if (val <= 0) return 'الكمية يجب أن تكون أكبر من 0';
                          if (val > _maxReturnQuantity) return 'الكمية أكبر من المتوفرة';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // ملاحظة
                      TextFormField(
                        decoration: const InputDecoration(
                          labelText: 'ملاحظة (اختياري)',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 2,
                        onChanged: (v) => _note = v,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // زر الحفظ
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveReturn,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: _isSaving
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('تسجيل الإرجاع', style: TextStyle(fontSize: 16)),
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
              color: isRemaining ? Colors.amber : null,
            ),
          ),
        ],
      ),
    );
  }
}