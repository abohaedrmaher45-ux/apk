// lib/screens/return_invoice_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../services/storage_service.dart';
import '../models/customer.dart';
import '../models/transaction.dart';
import '../utils/app_constants.dart';
import '../widgets/pdf_generator.dart';

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
    }
    
    setState(() => _isLoading = false);
  }

  double get _maxQuantity {
    final material = _remainingMaterials.firstWhere(
      (m) => m['materialName'] == _selectedMaterial,
      orElse: () => {'remaining': 0.0},
    );
    return (material['remaining'] as double?) ?? 0.0;
  }

  Future<void> _saveReturn() async {
    if (!_formKey.currentState!.validate()) return;
    if (_customer == null) return;
    if (_selectedMaterial == null) return;
    
    if (_returnQuantity > _maxQuantity) {
      _showToast('⚠️ الكمية المرتجعة أكبر من المتوفرة (${_maxQuantity.toStringAsFixed(2)})');
      return;
    }
    
    setState(() => _isSaving = true);
    
    try {
      final transactionId = await storage.getNextTransactionId();
      final transaction = Transaction(
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
      await PdfGenerator.generateReturnInvoice(customer: _customer!, transaction: transaction);
      
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
        title: const Text('فاتورة إرجاع مواد'),
        backgroundColor: AppConstants.primaryColor,
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
          const Icon(Icons.inventory, size: 80, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            'لا توجد مواد متبقية لهذا العميل',
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
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            _buildCustomerCard(),
            const SizedBox(height: 20),
            _buildRemainingMaterialsCard(),
            const SizedBox(height: 20),
            _buildReturnFormCard(),
            const SizedBox(height: 30),
            _buildSaveButton(),
          ],
        ),
      ),
    );
  }
  
  Widget _buildCustomerCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(13),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppConstants.primaryColor.withAlpha(26),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.person, size: 28, color: AppConstants.primaryColor),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _customer!.name,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                if (_customer!.phone != null)
                  Text(
                    _customer!.phone!,
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                const SizedBox(height: 4),
                Text(
                  'تاريخ الفاتورة: ${DateFormat('yyyy-MM-dd').format(DateTime.now())}',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildRemainingMaterialsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(13),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.inventory, color: Colors.amber),
              SizedBox(width: 8),
              Text('المواد المتبقية', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          const Divider(height: 24),
          ..._remainingMaterials.map((material) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  material['materialName'],
                  style: const TextStyle(fontSize: 16),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.amber.withAlpha(26),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${(material['remaining'] as double).toStringAsFixed(2)} ${AppConstants.getUnit(material['materialName'])}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.amber,
                    ),
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }
  
  Widget _buildReturnFormCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(13),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.receipt, color: Colors.green),
              SizedBox(width: 8),
              Text('بيانات الإرجاع', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          const Divider(height: 24),
          
          // اختيار المادة - تم التصحيح هنا
          DropdownButtonFormField<String>(
            decoration: _inputDecoration('المادة المرتجعة *', Icons.category),
            value: _selectedMaterial,
            items: _remainingMaterials.map<DropdownMenuItem<String>>((m) {
              return DropdownMenuItem<String>(
                value: m['materialName'],
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(m['materialName']),
                    const SizedBox(width: 8),
                    Text(
                      'متبقي: ${(m['remaining'] as double).toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              );
            }).toList(),
            onChanged: (value) => setState(() => _selectedMaterial = value),
            validator: (value) => value == null ? 'الرجاء اختيار المادة' : null,
          ),
          const SizedBox(height: 16),
          
          // الكمية المرتجعة
          TextFormField(
            decoration: _inputDecoration(
              'الكمية المرتجعة *',
              Icons.numbers,
              suffix: AppConstants.getUnit(_selectedMaterial ?? ''),
            ),
            keyboardType: TextInputType.number,
            onChanged: (v) => _returnQuantity = double.tryParse(v) ?? 0,
            validator: (v) {
              if (v == null || v.isEmpty) return 'الرجاء إدخال الكمية';
              final val = double.tryParse(v);
              if (val == null) return 'الرجاء إدخال رقم صحيح';
              if (val <= 0) return 'الكمية يجب أن تكون أكبر من 0';
              if (val > _maxQuantity) return 'الكمية المرتجعة أكبر من المتوفرة (${_maxQuantity.toStringAsFixed(2)})';
              return null;
            },
          ),
          const SizedBox(height: 16),
          
          // ملاحظة
          TextFormField(
            decoration: _inputDecoration('ملاحظة (اختياري)', Icons.note_add),
            maxLines: 2,
            onChanged: (v) => _note = v,
          ),
          const SizedBox(height: 16),
          
          // تذكير
          _buildReminderCard(),
        ],
      ),
    );
  }
  
  Widget _buildReminderCard() {
    return Container(
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
    );
  }
  
  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton(
        onPressed: _isSaving ? null : _saveReturn,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: _isSaving
            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.receipt),
                  SizedBox(width: 8),
                  Text('تسجيل الإرجاع وطباعة الفاتورة', style: TextStyle(fontSize: 16)),
                ],
              ),
      ),
    );
  }
  
  InputDecoration _inputDecoration(String label, IconData icon, {String? suffix}) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: AppConstants.primaryColor),
      suffixText: suffix,
      filled: true,
      fillColor: Colors.grey.shade50,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey.shade200)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppConstants.primaryColor, width: 2),
      ),
    );
  }
}