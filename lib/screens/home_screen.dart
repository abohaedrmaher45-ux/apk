// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../services/storage_service.dart';
import '../models/customer.dart';
import '../models/transaction.dart';
import '../utils/app_constants.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _formKey = GlobalKey<FormState>();
  final StorageService storage = StorageService.instance;
  
  // Controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _discountController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  
  // Variables
  int? _selectedCustomerId;
  String _selectedMaterial = AppConstants.materialList[0];
  DateTime _startDate = DateTime.now();
  DateTime _returnDate = DateTime.now().add(const Duration(days: 30));
  double _quantity = 0;
  double _price = 0;
  double _discount = 0;
  bool _isNewCustomer = false;
  bool _isLoading = false;
  
  List<Customer> _customers = [];
  bool _isLoadingCustomers = true;
  
  // متغيرات للكميات المتبقية
  double _remainingQuantity = 0;
  bool _showRemaining = false;

  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  Future<void> _loadCustomers() async {
    final customers = await storage.getCustomers();
    setState(() {
      _customers = customers;
      _isLoadingCustomers = false;
    });
  }

  Future<void> _loadRemainingQuantity() async {
    if (_selectedCustomerId != null) {
      final remaining = await storage.getRemainingQuantity(
        _selectedCustomerId!, 
        _selectedMaterial
      );
      setState(() {
        _remainingQuantity = remaining;
        _showRemaining = remaining > 0;
      });
    }
  }

  double get _totalBeforeDiscount => _quantity * _price;
  double get _discountAmount => _totalBeforeDiscount * (_discount / 100);
  double get _totalAfterDiscount => _totalBeforeDiscount - _discountAmount;

  Future<void> _saveTransaction() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    
    try {
      int customerId = _selectedCustomerId ?? 0;
      
      if (_isNewCustomer) {
        if (_nameController.text.trim().isEmpty) {
          _showToast('الرجاء إدخال اسم العميل');
          setState(() => _isLoading = false);
          return;
        }
        
        final newId = await storage.getNextCustomerId();
        final newCustomer = Customer(
          id: newId,
          name: _nameController.text.trim(),
          phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
          createdAt: DateFormat('yyyy-MM-dd').format(DateTime.now()),
        );
        await storage.addCustomer(newCustomer);
        customerId = newId;
        await _loadCustomers();
      }
      
      if (customerId == 0) {
        _showToast('الرجاء اختيار عميل');
        setState(() => _isLoading = false);
        return;
      }
      
      final transaction = Transaction(
        id: await storage.getNextTransactionId(),
        customerId: customerId,
        materialName: _selectedMaterial,
        type: TransactionType.withdrawal,
        quantity: _quantity,
        pricePerUnit: _price,
        discountPercent: _discount,
        date: DateFormat('yyyy-MM-dd').format(_startDate),
        returnDate: DateFormat('yyyy-MM-dd').format(_returnDate),
        actualReturnDate: null,
        note: _noteController.text.isEmpty ? null : _noteController.text,
        linkedWithdrawalId: null,
      );
      
      await storage.addTransaction(transaction);
      _showToast('✅ تم حفظ عملية السحب بنجاح');
      _resetForm();
      
    } catch (e) {
      _showToast('❌ حدث خطأ: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }
  
  void _resetForm() {
    _formKey.currentState?.reset();
    setState(() {
      _isNewCustomer = false;
      _selectedCustomerId = null;
      _selectedMaterial = AppConstants.materialList[0];
      _startDate = DateTime.now();
      _returnDate = DateTime.now().add(const Duration(days: 30));
      _quantity = 0;
      _price = 0;
      _discount = 0;
      _showRemaining = false;
      _remainingQuantity = 0;
      _quantityController.clear();
      _priceController.clear();
      _discountController.clear();
      _noteController.clear();
      _nameController.clear();
      _phoneController.clear();
    });
  }
  
  void _showToast(String msg) {
    Fluttertoast.showToast(msg: msg, gravity: ToastGravity.BOTTOM);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      _buildCustomerSection(),
                      const SizedBox(height: 20),
                      _buildMaterialSection(),
                      const SizedBox(height: 20),
                      if (_showRemaining) _buildRemainingQuantityCard(),
                      if (_quantity > 0 && _price > 0) _buildSummarySection(),
                      const SizedBox(height: 30),
                      _buildActionButtons(),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E3A5F), Color(0xFF2C4A7A)],
        ),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(30)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(13),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              // شعار الجك الحديدي
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(26),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.construction, color: Colors.white, size: 24),
                    SizedBox(width: 4),
                    Icon(Icons.hardware, color: Colors.white, size: 24),
                    SizedBox(width: 4),
                    Icon(Icons.apartment, color: Colors.white, size: 24),
                  ],
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'شركة العجاج للمقاولات',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'سحب و إرجاع المواد',
                      style: TextStyle(
                        color: Colors.white.withAlpha(179),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.people_outline, color: Colors.white),
                onPressed: () => Navigator.pushNamed(context, '/customers'),
              ),
              IconButton(
                icon: const Icon(Icons.settings, color: Colors.white),
                onPressed: () => Navigator.pushNamed(context, '/settings'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // جك حديدي زخرفي
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildIronBeam(),
              const SizedBox(width: 20),
              _buildIronBeam(),
              const SizedBox(width: 20),
              _buildIronBeam(),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildIronBeam() {
    return Container(
      width: 40,
      height: 8,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Colors.grey, Colors.white70, Colors.grey],
        ),
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(51),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
    );
  }
  
  Widget _buildRemainingQuantityCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.amber.withAlpha(26),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amber.withAlpha(102)),
      ),
      child: Row(
        children: [
          const Icon(Icons.inventory, color: Colors.amber, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'الكمية المتبقية',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  '${_remainingQuantity.toStringAsFixed(2)} ${AppConstants.getUnit(_selectedMaterial)}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.amber,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildCustomerSection() {
    return Container(
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
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppConstants.primaryColor.withAlpha(26),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.person, size: 20, color: AppConstants.primaryColor),
                ),
                const SizedBox(width: 12),
                const Text(
                  'معلومات العميل',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(40),
                  ),
                  child: Row(
                    children: [
                      _buildToggleButton('عميل موجود', !_isNewCustomer, () {
                        setState(() => _isNewCustomer = false);
                      }),
                      _buildToggleButton('عميل جديد', _isNewCustomer, () {
                        setState(() => _isNewCustomer = true);
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                
                if (!_isNewCustomer)
                  DropdownButtonFormField<int>(
                    decoration: _inputDecoration('اختر العميل *', Icons.people),
                    value: _selectedCustomerId,
                    items: [
                      const DropdownMenuItem(value: null, child: Text('اختر عميل...')),
                      ..._customers.map((c) => DropdownMenuItem(
                        value: c.id,
                        child: Text(c.name),
                      )),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedCustomerId = value;
                        _loadRemainingQuantity();
                      });
                    },
                    validator: (value) => value == null && !_isNewCustomer ? 'الرجاء اختيار عميل' : null,
                  ),
                
                if (_isNewCustomer) ...[
                  TextFormField(
                    controller: _nameController,
                    decoration: _inputDecoration('اسم العميل *', Icons.person),
                    validator: (value) => value?.trim().isEmpty == true ? 'الرجاء إدخال اسم العميل' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _phoneController,
                    decoration: _inputDecoration('رقم الهاتف (اختياري)', Icons.phone),
                    keyboardType: TextInputType.phone,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildToggleButton(String text, bool isSelected, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppConstants.primaryColor : Colors.transparent,
            borderRadius: BorderRadius.circular(36),
          ),
          child: Center(
            child: Text(
              text,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey.shade600,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildMaterialSection() {
    return Container(
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
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppConstants.primaryColor.withAlpha(26),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.inventory, size: 20, color: AppConstants.primaryColor),
                ),
                const SizedBox(width: 12),
                const Text(
                  'معلومات السحب',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                DropdownButtonFormField<String>(
                  decoration: _inputDecoration('نوع المادة *', Icons.category),
                  value: _selectedMaterial,
                  items: AppConstants.materialList.map((m) => DropdownMenuItem(
                    value: m,
                    child: Text(m),
                  )).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedMaterial = value!;
                      _loadRemainingQuantity();
                    });
                  },
                ),
                const SizedBox(height: 12),
                
                // الكمية والسعر
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _quantityController,
                        decoration: _inputDecoration(
                          'الكمية *',
                          Icons.numbers,
                          suffix: AppConstants.getUnit(_selectedMaterial),
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (v) => _quantity = double.tryParse(v) ?? 0,
                        validator: (v) => _validateNumber(v, 'الكمية'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _priceController,
                        decoration: _inputDecoration(
                          'سعر الفرد *',
                          Icons.attach_money,
                          suffix: AppConstants.currencySymbol,
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (v) => _price = double.tryParse(v) ?? 0,
                        validator: (v) => _validateNumber(v, 'السعر'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                
                // تاريخ البدء وتاريخ العودة
                Row(
                  children: [
                    Expanded(
                      child: _buildDatePicker('تاريخ البدء', _startDate, (date) {
                        setState(() => _startDate = date);
                      }),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildDatePicker('تاريخ العودة المتوقع', _returnDate, (date) {
                        setState(() => _returnDate = date);
                      }, isReturn: true),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                
                // الخصم والملاحظة
                TextFormField(
                  controller: _discountController,
                  decoration: _inputDecoration('الخصم (%)', Icons.percent),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => _discount = double.tryParse(v) ?? 0,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _noteController,
                  decoration: _inputDecoration('ملاحظة (اختياري)', Icons.note_add),
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildDatePicker(String label, DateTime date, Function(DateTime) onSelected, {bool isReturn = false}) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date,
          firstDate: DateTime(2020),
          lastDate: DateTime(2030),
          builder: (context, child) {
            return Theme(
              data: Theme.of(context).copyWith(
                colorScheme: const ColorScheme.light(primary: AppConstants.primaryColor),
              ),
              child: child!,
            );
          },
        );
        if (picked != null) onSelected(picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Icon(
              Icons.calendar_today,
              size: 18,
              color: isReturn ? AppConstants.dangerColor : AppConstants.primaryColor,
            ),
            const SizedBox(width: 12),
            Text(
              DateFormat('yyyy-MM-dd').format(date),
              style: TextStyle(
                color: isReturn ? AppConstants.dangerColor : Colors.black87,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSummarySection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppConstants.primaryColor.withAlpha(13),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppConstants.primaryColor.withAlpha(26)),
      ),
      child: Column(
        children: [
          const Row(
            children: [
              Icon(Icons.calculate, size: 20, color: AppConstants.primaryColor),
              SizedBox(width: 8),
              Text('ملخص الفاتورة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 12),
          _buildSummaryRow('الإجمالي قبل الخصم', '${_totalBeforeDiscount.toStringAsFixed(2)} ${AppConstants.currencySymbol}'),
          const SizedBox(height: 8),
          _buildSummaryRow('قيمة الخصم', '- ${_discountAmount.toStringAsFixed(2)} ${AppConstants.currencySymbol}', isNegative: true),
          const Divider(height: 24),
          _buildSummaryRow(
            'المطلوب دفعه',
            '${_totalAfterDiscount.toStringAsFixed(2)} ${AppConstants.currencySymbol}',
            isBold: true,
            isTotal: true,
          ),
        ],
      ),
    );
  }
  
  Widget _buildSummaryRow(String label, String value, {bool isNegative = false, bool isBold = false, bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
        Text(
          value,
          style: TextStyle(
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            fontSize: isTotal ? 16 : 14,
            color: isNegative ? AppConstants.dangerColor : (isTotal ? AppConstants.successColor : Colors.black87),
          ),
        ),
      ],
    );
  }
  
  Widget _buildActionButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 55,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _saveTransaction,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppConstants.primaryColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: _isLoading
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [Icon(Icons.save), SizedBox(width: 8), Text('تسجيل عملية السحب', style: TextStyle(fontSize: 16))],
                  ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 55,
          child: OutlinedButton(
            onPressed: () => Navigator.pushNamed(context, '/customers'),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppConstants.primaryColor),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [Icon(Icons.people, color: AppConstants.primaryColor), SizedBox(width: 8), Text('قائمة العملاء')],
            ),
          ),
        ),
      ],
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
  
  String? _validateNumber(String? value, String fieldName) {
    if (value == null || value.isEmpty) return 'الرجاء إدخال $fieldName';
    final num = double.tryParse(value);
    if (num == null) return 'الرجاء إدخال رقم صحيح';
    if (num <= 0) return '$fieldName يجب أن تكون أكبر من 0';
    return null;
  }
}