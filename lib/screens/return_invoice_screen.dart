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
  const ReturnInvoiceScreen({super.key, required this.customerId});

  @override
  State<ReturnInvoiceScreen> createState() => _ReturnInvoiceScreenState();
}

class _ReturnInvoiceScreenState extends State<ReturnInvoiceScreen> {
  final StorageService storage = StorageService.instance;
  final _formKey = GlobalKey<FormState>();
  
  Customer? _customer;
  List<Map<String, dynamic>> _remainingMaterials = [];
  String? _selectedMaterial;
  double _remainingQuantity = 0;
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
    _remainingMaterials = await storage.getCustomerRemainingMaterials(widget.customerId);
    
    if (_remainingMaterials.isNotEmpty) {
      _selectedMaterial = _remainingMaterials.first['materialName'];
      _remainingQuantity = _remainingMaterials.first['remaining'];
    }
    
    setState(() => _isLoading = false);
  }

  Future<void> _updateRemainingQuantity(String material) async {
    final materialData = _remainingMaterials.firstWhere(
      (m) => m['materialName'] == material,
      orElse: () => {'remaining': 0.0},
    );
    setState(() {
      _remainingQuantity = materialData['remaining'];
    });
  }

  Future<void> _saveReturn() async {
    if (!_formKey.currentState!.validate()) return;
    if (_customer == null) return;
    if (_selectedMaterial == null) return;
    
    if (_returnQuantity > _remainingQuantity) {
      _showToast('⚠️ الكمية المرتجعة أكبر من المتوفرة (${_remainingQuantity.toStringAsFixed(2)})');
      return;
    }
    
    setState(() => _isSaving = true);
    
    try {
      int transactionId = await storage.getNextTransactionId();
      Transaction transaction = Transaction(
        id: transactionId,
        customerId: widget.customerId,
        materialName: _selectedMaterial!,
        type: TransactionType.return_,
        quantity: _returnQuantity,
        pricePerUnit: 0,
        discountPercent: 0,
        date: DateFormat('yyyy-MM-dd').format(DateTime.now()),
        returnDate: null,
        actualReturnDate: DateFormat('yyyy-MM-dd').format(DateTime.now()),
        note: _note.isEmpty ? null : _note,
        linkedWithdrawalId: null,
      );
      
      await storage.addTransaction(transaction);
      _showToast('✅ تم تسجيل الإرجاع بنجاح');
      
      // تحديث البيانات والعودة
      await _loadData();
      _returnQuantity = 0;
      _note = '';
      _formKey.currentState?.reset();
      
      // إذا أصبحت الكمية المتبقية صفر، نغلق الشاشة
      if (_remainingMaterials.isEmpty) {
        Navigator.pop(context);
      }
      
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
        title: const Text('فاتورة إرجاع مواد'),
        backgroundColor: AppConstants.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _customer == null
              ? const Center(child: Text('العميل غير موجود'))
              : _remainingMaterials.isEmpty
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
            'لا توجد مواد متبقية',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'جميع المواد المسحوبة تم إرجاعها',
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
                          Text('التاريخ: ${DateFormat('yyyy-MM-dd').format(DateTime.now())}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // المواد المتبقية
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('المواد المتبقية', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    ..._remainingMaterials.map((m) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(m['materialName']),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.amber.withAlpha(26),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${(m['remaining'] as double).toStringAsFixed(2)} ${AppConstants.getUnit(m['materialName'])}',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.amber),
                            ),
                          ),
                        ],
                      ),
                    )),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // نموذج الإرجاع
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('بيانات الإرجاع', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    
                    // اختيار المادة
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'المادة المرتجعة',
                        border: OutlineInputBorder(),
                      ),
                      value: _selectedMaterial,
                      items: _remainingMaterials.map<DropdownMenuItem<String>>((m) {
                        return DropdownMenuItem<String>(
                          value: m['materialName'],
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(m['materialName']),
                              Text('متبقي: ${(m['remaining'] as double).toStringAsFixed(2)}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedMaterial = value;
                          _updateRemainingQuantity(value!);
                        });
                      },
                      validator: (value) => value == null ? 'الرجاء اختيار المادة' : null,
                    ),
                    const SizedBox(height: 16),
                    
                    // الكمية المرتجعة
                    TextFormField(
                      decoration: InputDecoration(
                        labelText: 'الكمية المرتجعة',
                        suffixText: AppConstants.getUnit(_selectedMaterial ?? ''),
                        border: const OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (v) => _returnQuantity = double.tryParse(v) ?? 0,
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'الرجاء إدخال الكمية';
                        double val = double.tryParse(v) ?? 0;
                        if (val <= 0) return 'الكمية يجب أن تكون أكبر من 0';
                        if (val > _remainingQuantity) return 'الكمية أكبر من المتوفرة (${_remainingQuantity.toStringAsFixed(2)})';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    // ملاحظة
                    TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'ملاحظة',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
                      onChanged: (v) => _note = v,
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // تذكير
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, color: Colors.blue),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'سيتم خصم هذه الكمية من رصيد العميل تلقائياً',
                              style: TextStyle(color: Colors.blue.shade700, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
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
}