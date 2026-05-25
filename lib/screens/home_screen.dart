// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../services/storage_service.dart';
import '../models/customer.dart';
import '../models/transaction.dart';
import '../utils/app_constants.dart';
import '../widgets/custom_toggle.dart';
import '../widgets/material_grid.dart';
import '../widgets/animated_summary.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final StorageService storage = StorageService.instance;
  final _formKey = GlobalKey<FormState>();

  List<Customer> _customers = [];
  int? _selectedCustomerId;
  bool _isNewCustomer = false;
  final TextEditingController _newNameController = TextEditingController();
  final TextEditingController _newPhoneController = TextEditingController();

  String _selectedMaterial = AppConstants.materialList[0];
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _discountController = TextEditingController(text: '0');
  final TextEditingController _noteController = TextEditingController();

  DateTime _startDate = DateTime.now();
  DateTime _returnDate = DateTime.now().add(const Duration(days: 30));

  bool _isLoading = false;
  bool _isLoadingCustomers = true;

  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  @override
  void dispose() {
    _newNameController.dispose();
    _newPhoneController.dispose();
    _quantityController.dispose();
    _priceController.dispose();
    _discountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadCustomers() async {
    setState(() => _isLoadingCustomers = true);
    final customers = await storage.getCustomers();
    setState(() {
      _customers = customers;
      _isLoadingCustomers = false;
    });
  }

  Future<void> _saveWithdrawal() async {
    if (!_formKey.currentState!.validate()) return;

    final confirmed = await _showConfirmationDialog();
    if (!confirmed) return;

    setState(() => _isLoading = true);

    try {
      int customerId = _selectedCustomerId ?? 0;

      if (_isNewCustomer) {
        String name = _newNameController.text.trim();
        if (name.isEmpty) {
          _showToast('الرجاء ادخال اسم العميل');
          setState(() => _isLoading = false);
          return;
        }

        int newId = await storage.getNextCustomerId();
        Customer newCustomer = Customer(
          id: newId,
          name: name,
          phone: _newPhoneController.text.trim().isEmpty
              ? null
              : _newPhoneController.text.trim(),
          createdAt: DateFormat('yyyy-MM-dd').format(DateTime.now()),
        );
        await storage.addCustomer(newCustomer);
        customerId = newId;
        await _loadCustomers();

        setState(() {
          _isNewCustomer = false;
          _newNameController.clear();
          _newPhoneController.clear();
          _selectedCustomerId = newId;
        });
      }

      if (customerId == 0) {
        _showToast('الرجاء اختيار عميل');
        setState(() => _isLoading = false);
        return;
      }

      double quantity = double.tryParse(_quantityController.text) ?? 0;
      double price = double.tryParse(_priceController.text) ?? 0;
      double discount = double.tryParse(_discountController.text) ?? 0;

      if (discount > 50) {
        _showToast('الخصم لا يمكن ان يتجاوز 50%');
        setState(() => _isLoading = false);
        return;
      }

      if (quantity <= 0) {
        _showToast('الرجاء ادخال كمية صحيحة');
        setState(() => _isLoading = false);
        return;
      }

      if (price <= 0) {
        _showToast('الرجاء ادخال سعر صحيح');
        setState(() => _isLoading = false);
        return;
      }

      if (quantity > 1000) {
        final confirmLarge = await _showLargeQuantityDialog(quantity);
        if (!confirmLarge) {
          setState(() => _isLoading = false);
          return;
        }
      }

      int transactionId = await storage.getNextTransactionId();
      Transaction transaction = Transaction(
        id: transactionId,
        customerId: customerId,
        materialName: _selectedMaterial,
        type: TransactionType.withdrawal,
        quantity: quantity,
        pricePerUnit: price,
        discountPercent: discount,
        date: DateFormat('yyyy-MM-dd').format(_startDate),
        returnDate: DateFormat('yyyy-MM-dd').format(_returnDate),
        actualReturnDate: null,
        note: _noteController.text.isEmpty ? null : _noteController.text,
        linkedWithdrawalId: null,
      );

      await storage.addTransaction(transaction);
      HapticFeedback.heavyImpact();
      _showToast('تم حفظ عملية السحب بنجاح');
      _resetForm();
    } catch (e) {
      _showToast('خطأ: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<bool> _showConfirmationDialog() async {
    final quantity = double.tryParse(_quantityController.text) ?? 0;
    final price = double.tryParse(_priceController.text) ?? 0;
    final discount = double.tryParse(_discountController.text) ?? 0;
    final total = quantity * price;
    final discountAmount = total * (discount / 100);
    final finalTotal = total - discountAmount;

    final customerName = _isNewCustomer
        ? _newNameController.text.trim()
        : _customers.firstWhere(
            (c) => c.id == _selectedCustomerId,
            orElse: () => Customer(id: 0, name: 'غير معروف', createdAt: ''),
          ).name;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Icon(Icons.receipt_long, color: AppConstants.primaryColor),
            const SizedBox(width: 8),
            const Text('تأكيد العملية'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildConfirmRow('العميل:', customerName),
            _buildConfirmRow('المادة:', _selectedMaterial),
            _buildConfirmRow('الكمية:', '$quantity ${AppConstants.getUnit(_selectedMaterial)}'),
            const Divider(height: 24),
            _buildConfirmRow('الاجمالي:', '${total.toStringAsFixed(2)} ${AppConstants.currencySymbol}'),
            if (discount > 0)
              _buildConfirmRow('الخصم:', '-${discountAmount.toStringAsFixed(2)} ${AppConstants.currencySymbol}', color: AppConstants.dangerColor),
            const Divider(height: 24),
            _buildConfirmRow('الصافي:', '${finalTotal.toStringAsFixed(2)} ${AppConstants.currencySymbol}', isBold: true, color: AppConstants.successColor),
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
              backgroundColor: AppConstants.primaryColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('تأكيد الحفظ'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<bool> _showLargeQuantityDialog(double quantity) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Icon(Icons.warning_amber, color: AppConstants.secondaryColor),
            const SizedBox(width: 8),
            const Text('كمية كبيرة'),
          ],
        ),
        content: Text('الكمية المدخلة ($quantity) اكبر من المتوسط. هل انت متأكد؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('تعديل'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppConstants.secondaryColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('نعم، متأكد'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Widget _buildConfirmRow(String label, String value, {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade600)),
          Text(
            value,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: color ?? Colors.black87,
              fontSize: isBold ? 16 : 14,
            ),
          ),
        ],
      ),
    );
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    setState(() {
      _isNewCustomer = false;
      _selectedCustomerId = null;
      _selectedMaterial = AppConstants.materialList[0];
      _startDate = DateTime.now();
      _returnDate = DateTime.now().add(const Duration(days: 30));
      _quantityController.clear();
      _priceController.clear();
      _discountController.text = '0';
      _noteController.clear();
    });
  }

  void _showToast(String msg) {
    Fluttertoast.showToast(msg: msg, gravity: ToastGravity.BOTTOM);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('سحب مواد'),
        backgroundColor: AppConstants.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.people),
            onPressed: () => Navigator.pushNamed(context, '/customers'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCustomerSection(),
              const SizedBox(height: 20),
              _buildMaterialSection(),
              const SizedBox(height: 20),
              _buildDatesSection(),
              const SizedBox(height: 20),
              _buildNoteSection(),
              const SizedBox(height: 20),
              _buildSummarySection(),
              const SizedBox(height: 30),
              _buildSaveButton(),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCustomerSection() {
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
                Icon(Icons.person_outline, color: AppConstants.primaryColor, size: 22),
                const SizedBox(width: 8),
                const Text(
                  'معلومات العميل',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 20),
            CustomToggle(
              isNewCustomer: _isNewCustomer,
              onToggle: (value) => setState(() => _isNewCustomer = value),
            ),
            const SizedBox(height: 20),
            if (!_isNewCustomer)
              _isLoadingCustomers
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : DropdownButtonFormField<int>(
                      decoration: InputDecoration(
                        labelText: 'اختر العميل',
                        prefixIcon: const Icon(Icons.person_search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                      ),
                      value: _selectedCustomerId,
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('-- اختر عميل --', style: TextStyle(color: Colors.grey)),
                        ),
                        ..._customers.map((c) => DropdownMenuItem(
                          value: c.id,
                          child: Row(
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [AppConstants.primaryColor, Color(0xFF3A5F8F)],
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Center(
                                  child: Text(
                                    c.name.isNotEmpty ? c.name[0] : '?',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(c.name),
                            ],
                          ),
                        )),
                      ],
                      onChanged: (value) => setState(() => _selectedCustomerId = value),
                      validator: (value) => value == null ? 'الرجاء اختيار عميل' : null,
                    ),
            if (_isNewCustomer) ...[
              TextFormField(
                controller: _newNameController,
                decoration: InputDecoration(
                  labelText: 'اسم العميل *',
                  prefixIcon: const Icon(Icons.person_add),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
                validator: (value) => value?.trim().isEmpty == true ? 'الرجاء ادخال اسم العميل' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _newPhoneController,
                decoration: InputDecoration(
                  labelText: 'رقم الهاتف (اختياري)',
                  prefixIcon: const Icon(Icons.phone),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
                keyboardType: TextInputType.phone,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMaterialSection() {
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
                Icon(Icons.category_outlined, color: AppConstants.primaryColor, size: 22),
                const SizedBox(width: 8),
                const Text(
                  'اختيار المادة',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            MaterialGrid(
              selectedMaterial: _selectedMaterial,
              onMaterialSelected: (material) {
                setState(() => _selectedMaterial = material);
                HapticFeedback.selectionClick();
              },
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _quantityController,
                    decoration: InputDecoration(
                      labelText: 'الكمية *',
                      suffixText: AppConstants.getUnit(_selectedMaterial),
                      prefixIcon: const Icon(Icons.scale),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'الرجاء ادخال الكمية';
                      final q = double.tryParse(value);
                      if (q == null || q <= 0) return 'كمية غير صحيحة';
                      return null;
                    },
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _priceController,
                    decoration: InputDecoration(
                      labelText: 'سعر الفرد *',
                      suffixText: AppConstants.currencySymbol,
                      prefixIcon: const Icon(Icons.attach_money),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'الرجاء ادخال السعر';
                      final p = double.tryParse(value);
                      if (p == null || p <= 0) return 'سعر غير صحيح';
                      return null;
                    },
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _discountController,
              decoration: InputDecoration(
                labelText: 'الخصم (%) - الحد الاقصى 50%',
                prefixIcon: const Icon(Icons.local_offer),
                suffixText: '%',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                final d = double.tryParse(value ?? '0') ?? 0;
                if (d > 50) return 'الخصم لا يتجاوز 50%';
                return null;
              },
              onChanged: (_) => setState(() {}),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDatesSection() {
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
                Icon(Icons.date_range, color: AppConstants.primaryColor, size: 22),
                const SizedBox(width: 8),
                const Text(
                  'الفترة الزمنية',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      _buildDateNode(
                        date: _startDate,
                        label: 'تاريخ السحب',
                        icon: Icons.play_circle_outline,
                        color: AppConstants.successColor,
                        onTap: () async {
                          DateTime? picked = await showDatePicker(
                            context: context,
                            initialDate: _startDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2030),
                            builder: (context, child) {
                              return Theme(
                                data: Theme.of(context).copyWith(
                                  colorScheme: const ColorScheme.light(
                                    primary: AppConstants.primaryColor,
                                  ),
                                ),
                                child: child!,
                              );
                            },
                          );
                          if (picked != null) {
                            setState(() {
                              _startDate = picked;
                              if (_returnDate.isBefore(_startDate)) {
                                _returnDate = _startDate.add(const Duration(days: 30));
                              }
                            });
                          }
                        },
                      ),
                      Expanded(
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 8),
                          child: Column(
                            children: [
                              Text(
                                '${_returnDate.difference(_startDate).inDays} يوم',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade500,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                height: 3,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      AppConstants.successColor,
                                      AppConstants.secondaryColor,
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      _buildDateNode(
                        date: _returnDate,
                        label: 'تاريخ العودة',
                        icon: Icons.flag,
                        color: AppConstants.secondaryColor,
                        onTap: () async {
                          DateTime? picked = await showDatePicker(
                            context: context,
                            initialDate: _returnDate,
                            firstDate: _startDate,
                            lastDate: DateTime(2030),
                            builder: (context, child) {
                              return Theme(
                                data: Theme.of(context).copyWith(
                                  colorScheme: const ColorScheme.light(
                                    primary: AppConstants.primaryColor,
                                  ),
                                ),
                                child: child!,
                              );
                            },
                          );
                          if (picked != null) setState(() => _returnDate = picked);
                        },
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

  Widget _buildDateNode({
    required DateTime date,
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              DateFormat('yyyy-MM-dd').format(date),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoteSection() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: TextFormField(
          controller: _noteController,
          decoration: InputDecoration(
            labelText: 'ملاحظة (اختياري)',
            prefixIcon: const Icon(Icons.notes),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            filled: true,
            fillColor: Colors.grey.shade50,
          ),
          maxLines: 2,
        ),
      ),
    );
  }

  Widget _buildSummarySection() {
    final quantity = double.tryParse(_quantityController.text) ?? 0;
    final price = double.tryParse(_priceController.text) ?? 0;
    final discount = double.tryParse(_discountController.text) ?? 0;

    return AnimatedSummary(
      quantity: quantity,
      price: price,
      discount: discount,
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _saveWithdrawal,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppConstants.primaryColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 4,
          shadowColor: AppConstants.primaryColor.withOpacity(0.4),
        ),
        child: _isLoading
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
                  Text('جاري الحفظ...', style: TextStyle(fontSize: 16)),
                ],
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.save, size: 22),
                  SizedBox(width: 8),
                  Text(
                    'حفظ عملية السحب',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
      ),
    );
  }
}
