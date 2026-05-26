// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../services/storage_service.dart';
import '../models/customer.dart';
import '../models/transaction.dart';
import '../utils/app_constants.dart';
import '../widgets/animated_summary.dart';
import '../widgets/custom_toggle.dart';
import '../widgets/quantity_slider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final StorageService storage = StorageService.instance;
  final _formKey = GlobalKey<FormState>();
  
  // Controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _materialController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _discountController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  
  // Variables
  int? _selectedCustomerId;
  DateTime _startDate = DateTime.now();
  DateTime _returnDate = DateTime.now().add(const Duration(days: 30));
  double _quantity = 0;
  double _price = 0;
  double _discount = 0;
  bool _isNewCustomer = false;
  bool _isLoading = false;
  
  List<Customer> _customers = [];
  bool _isLoadingCustomers = true;

  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _materialController.dispose();
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
    
    setState(() => _isLoading = true);
    
    try {
      int customerId = _selectedCustomerId ?? 0;
      
      if (_isNewCustomer) {
        String name = _nameController.text.trim();
        if (name.isEmpty) {
          _showToast('الرجاء إدخال اسم العميل');
          setState(() => _isLoading = false);
          return;
        }
        
        int newId = await storage.getNextCustomerId();
        Customer newCustomer = Customer(
          id: newId,
          name: name,
          phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
          createdAt: DateFormat('yyyy-MM-dd').format(DateTime.now()),
        );
        await storage.addCustomer(newCustomer);
        customerId = newId;
        await _loadCustomers();
        
        setState(() {
          _isNewCustomer = false;
          _nameController.clear();
          _phoneController.clear();
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
      
      if (_quantity <= 0) {
        _showToast('الرجاء إدخال كمية صحيحة');
        setState(() => _isLoading = false);
        return;
      }
      
      if (_price <= 0) {
        _showToast('الرجاء إدخال سعر صحيح');
        setState(() => _isLoading = false);
        return;
      }
      
      int transactionId = await storage.getNextTransactionId();
      Transaction transaction = Transaction(
        id: transactionId,
        customerId: customerId,
        materialName: materialName,
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
      _startDate = DateTime.now();
      _returnDate = DateTime.now().add(const Duration(days: 30));
      _quantity = 0;
      _price = 0;
      _discount = 0;
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
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _buildCustomerSection(),
              const SizedBox(height: 20),
              _buildMaterialSection(),
              const SizedBox(height: 20),
              AnimatedSummary(
                quantity: _quantity,
                price: _price,
                discount: _discount,
              ),
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppConstants.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.person,
                    color: AppConstants.primaryColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'معلومات العميل',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 20),
            
            // Custom Toggle Widget
            CustomToggle(
              isNewCustomer: _isNewCustomer,
              onToggle: (value) {
                setState(() {
                  _isNewCustomer = value;
                  if (!value) {
                    _selectedCustomerId = null;
                  }
                });
              },
            ),
            const SizedBox(height: 20),
            
            if (!_isNewCustomer)
              DropdownButtonFormField<int>(
                decoration: const InputDecoration(
                  labelText: 'اختر العميل',
                  prefixIcon: Icon(Icons.people_outline),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                  ),
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
            
            if (_isNewCustomer) ...[
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'اسم العميل',
                  prefixIcon: Icon(Icons.person_add),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                  ),
                ),
                validator: (value) => value?.trim().isEmpty == true ? 'الرجاء إدخال اسم العميل' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'رقم الهاتف (اختياري)',
                  prefixIcon: Icon(Icons.phone),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                  ),
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
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppConstants.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.inventory,
                    color: AppConstants.primaryColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'معلومات السحب',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 20),
            
            // نوع المادة - كتابة يدوية
            TextFormField(
              controller: _materialController,
              decoration: const InputDecoration(
                labelText: 'نوع المادة *',
                prefixIcon: Icon(Icons.edit_note),
                hintText: 'مثال: حديد 6 مم، اسمنت عادي، خشب بناء...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
              ),
              validator: (value) => value?.trim().isEmpty == true ? 'الرجاء إدخال نوع المادة' : null,
            ),
            const SizedBox(height: 16),
            
            // Quantity Slider Widget
            QuantitySlider(
              maxQuantity: 1000,
              initialValue: _quantity,
              unit: 'وحدة',
              onChanged: (value) {
                setState(() {
                  _quantity = value;
                  _quantityController.text = value.toString();
                });
              },
            ),
            const SizedBox(height: 16),
            
            // سعر الفرد
            TextFormField(
              controller: _priceController,
              decoration: InputDecoration(
                labelText: 'سعر الفرد',
                prefixIcon: const Icon(Icons.attach_money),
                suffixText: AppConstants.currencySymbol,
                border: const OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
              ),
              keyboardType: TextInputType.number,
              onChanged: (v) => _price = double.tryParse(v) ?? 0,
              validator: (value) {
                if (value == null || value.isEmpty) return 'الرجاء إدخال السعر';
                final val = double.tryParse(value);
                if (val == null) return 'الرجاء إدخال رقم صحيح';
                if (val <= 0) return 'السعر يجب أن يكون أكبر من 0';
                return null;
              },
            ),
            const SizedBox(height: 16),
            
            // الخصم
            TextFormField(
              controller: _discountController,
              decoration: const InputDecoration(
                labelText: 'الخصم (%)',
                prefixIcon: Icon(Icons.percent),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
              ),
              keyboardType: TextInputType.number,
              onChanged: (v) => _discount = double.tryParse(v) ?? 0,
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
                        builder: (context, child) {
                          return Theme(
                            data: Theme.of(context).copyWith(
                              colorScheme: const ColorScheme.light(primary: AppConstants.primaryColor),
                            ),
                            child: child!,
                          );
                        },
                      );
                      if (picked != null) setState(() => _startDate = picked);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today, size: 18, color: AppConstants.primaryColor),
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
                        builder: (context, child) {
                          return Theme(
                            data: Theme.of(context).copyWith(
                              colorScheme: const ColorScheme.light(primary: AppConstants.dangerColor),
                            ),
                            child: child!,
                          );
                        },
                      );
                      if (picked != null) setState(() => _returnDate = picked);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today, size: 18, color: AppConstants.dangerColor),
                          const SizedBox(width: 8),
                          Text(
                            DateFormat('yyyy-MM-dd').format(_returnDate),
                            style: const TextStyle(color: AppConstants.dangerColor),
                          ),
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
                prefixIcon: Icon(Icons.note_add),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
              ),
              maxLines: 2,
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
          elevation: 2,
        ),
        child: _isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.save, size: 20),
                  SizedBox(width: 8),
                  Text('💾 حفظ عملية السحب', style: TextStyle(fontSize: 16)),
                ],
              ),
      ),
    );
  }
}