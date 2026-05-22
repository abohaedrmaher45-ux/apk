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
  final StorageService storage = StorageService.instance;
  final _formKey = GlobalKey<FormState>();
  
  // متغيرات العميل
  List<Customer> _customers = [];
  int? _selectedCustomerId;
  bool _isNewCustomer = false;
  final TextEditingController _newNameController = TextEditingController();
  final TextEditingController _newPhoneController = TextEditingController();
  
  // متغيرات المادة
  String _selectedMaterial = AppConstants.materialList[0];
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _discountController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  
  // متغيرات التواريخ
  DateTime _startDate = DateTime.now();
  DateTime _returnDate = DateTime.now().add(const Duration(days: 30));
  
  // حالة التحميل
  bool _isLoading = false;
  bool _isLoadingCustomers = true;

  @override
  void initState() {
    super.initState();
    _loadCustomers();
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
    // تحقق من صحة النموذج
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    
    try {
      int customerId = _selectedCustomerId ?? 0;
      
      // إذا كان عميل جديد
      if (_isNewCustomer) {
        String name = _newNameController.text.trim();
        if (name.isEmpty) {
          _showToast('الرجاء إدخال اسم العميل');
          setState(() => _isLoading = false);
          return;
        }
        
        int newId = await storage.getNextCustomerId();
        Customer newCustomer = Customer(
          id: newId,
          name: name,
          phone: _newPhoneController.text.trim().isEmpty ? null : _newPhoneController.text.trim(),
          createdAt: DateFormat('yyyy-MM-dd').format(DateTime.now()),
        );
        await storage.addCustomer(newCustomer);
        customerId = newId;
        await _loadCustomers();
        
        // إعادة تعيين حالة العميل الجديد
        setState(() {
          _isNewCustomer = false;
          _newNameController.clear();
          _newPhoneController.clear();
          _selectedCustomerId = newId;
        });
      }
      
      // تأكد من وجود عميل محدد
      if (customerId == 0) {
        _showToast('الرجاء اختيار عميل');
        setState(() => _isLoading = false);
        return;
      }
      
      // الحصول على الكمية والسعر والخصم
      double quantity = double.tryParse(_quantityController.text) ?? 0;
      double price = double.tryParse(_priceController.text) ?? 0;
      double discount = double.tryParse(_discountController.text) ?? 0;
      
      if (quantity <= 0) {
        _showToast('الرجاء إدخال كمية صحيحة');
        setState(() => _isLoading = false);
        return;
      }
      
      if (price <= 0) {
        _showToast('الرجاء إدخال سعر صحيح');
        setState(() => _isLoading = false);
        return;
      }
      
      // إنشاء المعاملة
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
      _showToast('✅ تم حفظ عملية السحب بنجاح');
      _resetForm();
      
    } catch (e) {
      _showToast('❌ خطأ: $e');
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
      _quantityController.clear();
      _priceController.clear();
      _discountController.clear();
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
            children: [
              _buildCustomerSection(),
              const SizedBox(height: 20),
              _buildMaterialSection(),
              const SizedBox(height: 20),
              _buildSummarySection(),
              const SizedBox(height: 30),
              _buildSaveButton(),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildCustomerSection() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('معلومات العميل', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            
            // اختيار نوع العميل
            Row(
              children: [
                Expanded(
                  child: _buildToggleButton('عميل موجود', !_isNewCustomer, () {
                    setState(() => _isNewCustomer = false);
                  }),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildToggleButton('عميل جديد', _isNewCustomer, () {
                    setState(() => _isNewCustomer = true);
                  }),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // عميل موجود
            if (!_isNewCustomer)
              DropdownButtonFormField<int>(
                decoration: const InputDecoration(
                  labelText: 'اختر العميل',
                  border: OutlineInputBorder(),
                ),
                value: _selectedCustomerId,
                items: [
                  const DropdownMenuItem(value: null, child: Text('-- اختر عميل --')),
                  ..._customers.map((c) => DropdownMenuItem(
                    value: c.id,
                    child: Text(c.name),
                  )),
                ],
                onChanged: (value) => setState(() => _selectedCustomerId = value),
                validator: (value) => value == null ? 'الرجاء اختيار عميل' : null,
              ),
            
            // عميل جديد
            if (_isNewCustomer) ...[
              TextFormField(
                controller: _newNameController,
                decoration: const InputDecoration(
                  labelText: 'اسم العميل',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value?.trim().isEmpty == true ? 'الرجاء إدخال اسم العميل' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _newPhoneController,
                decoration: const InputDecoration(
                  labelText: 'رقم الهاتف (اختياري)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  Widget _buildToggleButton(String text, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppConstants.primaryColor : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            text,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.black87,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildMaterialSection() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('معلومات المادة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            
            // نوع المادة
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: 'نوع المادة',
                border: OutlineInputBorder(),
              ),
              value: _selectedMaterial,
              items: AppConstants.materialList.map((m) => DropdownMenuItem(
                value: m,
                child: Text(m),
              )).toList(),
              onChanged: (value) => setState(() => _selectedMaterial = value!),
            ),
            const SizedBox(height: 16),
            
            // الكمية والسعر
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _quantityController,
                    decoration: InputDecoration(
                      labelText: 'الكمية',
                      suffixText: AppConstants.getUnit(_selectedMaterial),
                      border: const OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'الرجاء إدخال الكمية';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _priceController,
                    decoration: InputDecoration(
                      labelText: 'سعر الفرد',
                      suffixText: AppConstants.currencySymbol,
                      border: const OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'الرجاء إدخال السعر';
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // الخصم
            TextFormField(
              controller: _discountController,
              decoration: const InputDecoration(
                labelText: 'الخصم (%)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            
            // التواريخ
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      DateTime? picked = await showDatePicker(
                        context: context,
                        initialDate: _startDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (picked != null) setState(() => _startDate = picked);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today, size: 18),
                          const SizedBox(width: 8),
                          Text(DateFormat('yyyy-MM-dd').format(_startDate)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      DateTime? picked = await showDatePicker(
                        context: context,
                        initialDate: _returnDate,
                        firstDate: DateTime.now(),
                        lastDate: DateTime(2030),
                      );
                      if (picked != null) setState(() => _returnDate = picked);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today, size: 18, color: Colors.red),
                          const SizedBox(width: 8),
                          Text(DateFormat('yyyy-MM-dd').format(_returnDate)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // ملاحظة
            TextFormField(
              controller: _noteController,
              decoration: const InputDecoration(
                labelText: 'ملاحظة',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSummarySection() {
    double quantity = double.tryParse(_quantityController.text) ?? 0;
    double price = double.tryParse(_priceController.text) ?? 0;
    double discount = double.tryParse(_discountController.text) ?? 0;
    
    if (quantity <= 0 || price <= 0) return const SizedBox.shrink();
    
    double total = quantity * price;
    double discountAmount = total * (discount / 100);
    double finalTotal = total - discountAmount;
    
    return Card(
      color: AppConstants.primaryColor.withAlpha(26),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text('ملخص الفاتورة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('الإجمالي قبل الخصم:'),
                Text('${total.toStringAsFixed(2)} ${AppConstants.currencySymbol}'),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('قيمة الخصم:'),
                Text('- ${discountAmount.toStringAsFixed(2)} ${AppConstants.currencySymbol}', style: const TextStyle(color: Colors.red)),
              ],
            ),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('الإجمالي النهائي:', style: TextStyle(fontWeight: FontWeight.bold)),
                Text('${finalTotal.toStringAsFixed(2)} ${AppConstants.currencySymbol}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _saveWithdrawal,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppConstants.primaryColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: _isLoading
            ? const CircularProgressIndicator(color: Colors.white)
            : const Text('💾 حفظ عملية السحب', style: TextStyle(fontSize: 16)),
      ),
    );
  }
}