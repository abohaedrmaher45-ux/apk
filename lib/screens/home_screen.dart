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
  
  // متغيرات السحب
  final TextEditingController _materialController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _discountController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  
  DateTime _startDate = DateTime.now();
  DateTime _returnDate = DateTime.now().add(const Duration(days: 30));
  
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  Future<void> _loadCustomers() async {
    final customers = await storage.getCustomers();
    setState(() {
      _customers = customers;
    });
  }

  Future<void> _saveWithdrawal() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    
    try {
      int customerId = _selectedCustomerId ?? 0;
      
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
      
      String materialName = _materialController.text.trim();
      if (materialName.isEmpty) {
        _showToast('الرجاء إدخال نوع المادة');
        setState(() => _isLoading = false);
        return;
      }
      
      double quantity = double.tryParse(_quantityController.text) ?? 0;
      if (quantity <= 0) {
        _showToast('الرجاء إدخال كمية صحيحة');
        setState(() => _isLoading = false);
        return;
      }
      
      double price = double.tryParse(_priceController.text) ?? 0;
      if (price <= 0) {
        _showToast('الرجاء إدخال سعر صحيح');
        setState(() => _isLoading = false);
        return;
      }
      
      double discount = double.tryParse(_discountController.text) ?? 0;
      
      int transactionId = await storage.getNextTransactionId();
      Transaction transaction = Transaction(
        id: transactionId,
        customerId: customerId,
        materialName: materialName,
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
      _startDate = DateTime.now();
      _returnDate = DateTime.now().add(const Duration(days: 30));
      _materialController.clear();
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
              // قسم العميل
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('معلومات العميل', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      
                      // أزرار تبديل العميل
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => setState(() => _isNewCustomer = false),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: !_isNewCustomer ? AppConstants.primaryColor : Colors.grey,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('عميل موجود'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => setState(() => _isNewCustomer = true),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _isNewCustomer ? AppConstants.primaryColor : Colors.grey,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('عميل جديد'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      if (!_isNewCustomer)
                        DropdownButtonFormField<int>(
                          decoration: const InputDecoration(labelText: 'اختر العميل', border: OutlineInputBorder()),
                          value: _selectedCustomerId,
                          items: [
                            const DropdownMenuItem(value: null, child: Text('-- اختر عميل --')),
                            ..._customers.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))),
                          ],
                          onChanged: (value) => setState(() => _selectedCustomerId = value),
                          validator: (value) => value == null ? 'الرجاء اختيار عميل' : null,
                        ),
                      
                      if (_isNewCustomer) ...[
                        TextFormField(
                          controller: _newNameController,
                          decoration: const InputDecoration(labelText: 'اسم العميل *', border: OutlineInputBorder()),
                          validator: (value) => value?.trim().isEmpty == true ? 'الرجاء إدخال اسم العميل' : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _newPhoneController,
                          decoration: const InputDecoration(labelText: 'رقم الهاتف (اختياري)', border: OutlineInputBorder()),
                          keyboardType: TextInputType.phone,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // قسم السحب - هنا كل الحقول التي تريدها
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('معلومات السحب', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      
                      // 1. نوع المادة (كتابة يدوية)
                      TextFormField(
                        controller: _materialController,
                        decoration: const InputDecoration(
                          labelText: 'نوع المادة *',
                          hintText: 'مثال: حديد 6 مم، اسمنت عادي',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) => value?.trim().isEmpty == true ? 'الرجاء إدخال نوع المادة' : null,
                      ),
                      const SizedBox(height: 16),
                      
                      // 2. الكمية
                      TextFormField(
                        controller: _quantityController,
                        decoration: const InputDecoration(
                          labelText: 'الكمية *',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'الرجاء إدخال الكمية';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      // 3. سعر الفرد
                      TextFormField(
                        controller: _priceController,
                        decoration: InputDecoration(
                          labelText: 'سعر الفرد *',
                          suffixText: AppConstants.currencySymbol,
                          border: const OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'الرجاء إدخال السعر';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      // 4. الخصم
                      TextFormField(
                        controller: _discountController,
                        decoration: const InputDecoration(
                          labelText: 'الخصم (%)',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 16),
                      
                      // 5. تاريخ البدء
                      InkWell(
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
                              const Icon(Icons.calendar_today),
                              const SizedBox(width: 8),
                              Text('تاريخ البدء: ${DateFormat('yyyy-MM-dd').format(_startDate)}'),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // 6. تاريخ العودة المتوقع
                      InkWell(
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
                              const Icon(Icons.calendar_today, color: Colors.red),
                              const SizedBox(width: 8),
                              Text('تاريخ العودة المتوقع: ${DateFormat('yyyy-MM-dd').format(_returnDate)}'),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // 7. ملاحظة
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
              ),
              
              const SizedBox(height: 24),
              
              // زر الحفظ
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveWithdrawal,
                  child: _isLoading
                      ? const CircularProgressIndicator()
                      : const Text('حفظ عملية السحب', style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}