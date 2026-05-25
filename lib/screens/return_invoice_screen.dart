// lib/screens/return_invoice_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../services/storage_service.dart';
import '../models/customer.dart';
import '../models/transaction.dart';
import '../utils/app_constants.dart';
import '../widgets/quantity_slider.dart';

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
      _returnQuantity = 0;
    }

    setState(() => _isLoading = false);
  }

  void _updateRemainingQuantity(String material) {
    final materialData = _remainingMaterials.firstWhere(
      (m) => m['materialName'] == material,
      orElse: () => {'remaining': 0.0},
    );
    setState(() {
      _remainingQuantity = materialData['remaining'];
      _returnQuantity = 0;
    });
  }

  Future<void> _saveReturn() async {
    if (!_formKey.currentState!.validate()) return;
    if (_customer == null) return;
    if (_selectedMaterial == null) return;

    if (_returnQuantity > _remainingQuantity) {
      _showToast('الكمية المرتجعة اكبر من المتوفرة (${_remainingQuantity.toStringAsFixed(2)})');
      return;
    }

    if (_returnQuantity <= 0) {
      _showToast('الرجاء ادخال كمية صحيحة');
      return;
    }

    final confirmed = await _showReturnConfirmation();
    if (!confirmed) return;

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
      HapticFeedback.heavyImpact();
      _showToast('تم تسجيل الارجاع بنجاح');

      await _loadData();
      _returnQuantity = 0;
      _note = '';
      _formKey.currentState?.reset();

      if (_remainingMaterials.isEmpty) {
        if (mounted) {
          _showCompletionDialog();
        }
      }
    } catch (e) {
      _showToast('حدث خطأ: $e');
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Future<bool> _showReturnConfirmation() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Icon(Icons.assignment_return, color: AppConstants.successColor),
            const SizedBox(width: 8),
            const Text('تأكيد الارجاع'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildConfirmRow('العميل:', _customer!.name),
            _buildConfirmRow('المادة:', _selectedMaterial!),
            _buildConfirmRow('الكمية المرتجعة:', '${_returnQuantity.toStringAsFixed(2)} ${AppConstants.getUnit(_selectedMaterial!)}'),
            const Divider(height: 24),
            _buildConfirmRow('المتبقي بعد الارجاع:', '${(_remainingQuantity - _returnQuantity).toStringAsFixed(2)} ${AppConstants.getUnit(_selectedMaterial!)}', color: AppConstants.successColor),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('الغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppConstants.successColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('تأكيد الارجاع'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _showCompletionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppConstants.successColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle,
                color: AppConstants.successColor,
                size: 50,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'تم ارجاع جميع المواد!',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'لا توجد مواد متبقية لهذا العميل',
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppConstants.successColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('حسنا'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfirmRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade600)),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: color ?? Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  void _showToast(String msg) {
    Fluttertoast.showToast(msg: msg, gravity: ToastGravity.BOTTOM);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('فاتورة ارجاع مواد'),
        backgroundColor: AppConstants.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
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
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: AppConstants.successColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle_outline,
              size: 60,
              color: AppConstants.successColor,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'لا توجد مواد متبقية',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'جميع المواد المسحوبة تم ارجاعها',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back),
            label: const Text('العودة', style: TextStyle(fontSize: 16)),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
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
            _buildCustomerCard(),
            const SizedBox(height: 16),
            _buildRemainingMaterialsCard(),
            const SizedBox(height: 16),
            _buildReturnFormCard(),
            const SizedBox(height: 24),
            _buildSaveButton(),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerCard() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppConstants.primaryColor, Color(0xFF2A4A7A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppConstants.primaryColor.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  _customer!.name.isNotEmpty ? _customer!.name[0] : '?',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _customer!.name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  if (_customer!.phone != null) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.phone, size: 14, color: Colors.white70),
                        const SizedBox(width: 6),
                        Text(
                          _customer!.phone!,
                          style: const TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 14, color: Colors.white70),
                      const SizedBox(width: 6),
                      Text(
                        'التاريخ: ${DateFormat('yyyy-MM-dd').format(DateTime.now())}',
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRemainingMaterialsCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.inventory_2, color: AppConstants.accentColor, size: 22),
                const SizedBox(width: 8),
                const Text(
                  'المواد المتبقية',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Divider(height: 24),
            ..._remainingMaterials.map((m) => _buildMaterialProgressItem(m)),
          ],
        ),
      ),
    );
  }

  Widget _buildMaterialProgressItem(Map<String, dynamic> m) {
    final materialName = m['materialName'];
    final remaining = m['remaining'] as double;
    final unit = AppConstants.getUnit(materialName);
    final isSelected = materialName == _selectedMaterial;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedMaterial = materialName;
          _updateRemainingQuantity(materialName);
        });
        HapticFeedback.selectionClick();
      },
      child: AnimatedContainer(
        duration: AppConstants.animationDuration,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? AppConstants.accentColor.withOpacity(0.1) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppConstants.accentColor.withOpacity(0.5) : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppConstants.accentColor.withOpacity(0.2)
                            : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.construction,
                        color: isSelected ? AppConstants.accentColor : Colors.grey.shade500,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      materialName,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? AppConstants.accentColor : Colors.black87,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppConstants.accentColor.withOpacity(0.15)
                        : Colors.amber.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${remaining.toStringAsFixed(2)} $unit',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isSelected ? AppConstants.accentColor : Colors.amber.shade800,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: 1.0,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation<Color>(
                  isSelected ? AppConstants.accentColor : Colors.amber,
                ),
                minHeight: 6,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReturnFormCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.assignment_return, color: AppConstants.successColor, size: 22),
                const SizedBox(width: 8),
                const Text(
                  'بيانات الارجاع',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<String>(
              decoration: InputDecoration(
                labelText: 'المادة المرتجعة',
                prefixIcon: const Icon(Icons.category),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
              value: _selectedMaterial,
              items: _remainingMaterials.map<DropdownMenuItem<String>>((m) {
                return DropdownMenuItem<String>(
                  value: m['materialName'],
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(m['materialName']),
                      Text(
                        'متبقي: ${(m['remaining'] as double).toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
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
            const SizedBox(height: 20),
            if (_selectedMaterial != null)
              QuantitySlider(
                maxQuantity: _remainingQuantity,
                initialValue: _returnQuantity,
                unit: AppConstants.getUnit(_selectedMaterial!),
                onChanged: (value) {
                  setState(() => _returnQuantity = value);
                },
              ),
            const SizedBox(height: 20),
            TextFormField(
              decoration: InputDecoration(
                labelText: 'ملاحظة',
                prefixIcon: const Icon(Icons.notes),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
              maxLines: 2,
              onChanged: (v) => _note = v,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.blue.shade100),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue.shade600, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'سيتم خصم هذه الكمية من رصيد العميل تلقائياً',
                      style: TextStyle(
                        color: Colors.blue.shade700,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isSaving ? null : _saveReturn,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppConstants.successColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 4,
          shadowColor: AppConstants.successColor.withOpacity(0.4),
        ),
        child: _isSaving
            ? const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  ),
                  SizedBox(width: 12),
                  Text('جاري التسجيل...', style: TextStyle(fontSize: 16)),
                ],
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.assignment_return, size: 22),
                  SizedBox(width: 8),
                  Text(
                    'تسجيل الارجاع',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
      ),
    );
  }
}
