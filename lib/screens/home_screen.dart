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

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final StorageService storage = StorageService.instance;
  
  // متغيرات النموذج
  String? selectedCustomerName;
  int? selectedCustomerId;
  String selectedMaterial = AppConstants.materialList[0];
  DateTime selectedStartDate = DateTime.now();
  double discountPercent = 0;
  double quantity = 0;
  double pricePerUnit = 0;
  DateTime selectedReturnDate = DateTime.now().add(const Duration(days: 30));
  String note = '';
  bool isNewCustomer = false;
  
  final TextEditingController newCustomerNameController = TextEditingController();
  final TextEditingController newCustomerPhoneController = TextEditingController();
  final TextEditingController quantityController = TextEditingController();
  final TextEditingController priceController = TextEditingController();
  final TextEditingController discountController = TextEditingController();
  final TextEditingController noteController = TextEditingController();
  
  List<Customer> customers = [];
  bool isLoading = false;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _loadCustomers();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    newCustomerNameController.dispose();
    newCustomerPhoneController.dispose();
    quantityController.dispose();
    priceController.dispose();
    discountController.dispose();
    noteController.dispose();
    super.dispose();
  }

  Future<void> _loadCustomers() async {
    final loadedCustomers = await storage.getCustomers();
    setState(() => customers = loadedCustomers);
  }

  Future<void> _saveWithdrawal() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => isLoading = true);
    
    try {
      if (isNewCustomer) {
        if (newCustomerNameController.text.trim().isEmpty) {
          Fluttertoast.showToast(msg: 'الرجاء إدخال اسم العميل');
          setState(() => isLoading = false);
          return;
        }
        
        final newId = await storage.getNextCustomerId();
        final newCustomer = Customer(
          id: newId,
          name: newCustomerNameController.text.trim(),
          phone: newCustomerPhoneController.text.trim().isEmpty ? null : newCustomerPhoneController.text.trim(),
          createdAt: DateFormat('yyyy-MM-dd').format(DateTime.now()),
        );
        await storage.addCustomer(newCustomer);
        selectedCustomerId = newId;
        selectedCustomerName = newCustomer.name;
        await _loadCustomers();
      }
      
      if (selectedCustomerId == null) {
        Fluttertoast.showToast(msg: 'الرجاء اختيار عميل');
        setState(() => isLoading = false);
        return;
      }
      
      if (selectedReturnDate.isBefore(DateTime.now())) {
        Fluttertoast.showToast(msg: 'تاريخ العودة يجب أن يكون بعد اليوم');
        setState(() => isLoading = false);
        return;
      }
      
      if (quantity <= 0) {
        Fluttertoast.showToast(msg: 'الكمية يجب أن تكون أكبر من 0');
        setState(() => isLoading = false);
        return;
      }
      
      if (pricePerUnit <= 0) {
        Fluttertoast.showToast(msg: 'السعر يجب أن يكون أكبر من 0');
        setState(() => isLoading = false);
        return;
      }
      
      final transactionId = await storage.getNextTransactionId();
      final transaction = Transaction(
        id: transactionId,
        customerId: selectedCustomerId!,
        materialName: selectedMaterial,
        type: TransactionType.withdrawal,
        quantity: quantity,
        pricePerUnit: pricePerUnit,
        discountPercent: discountPercent,
        date: DateFormat('yyyy-MM-dd').format(selectedStartDate),
        returnDate: DateFormat('yyyy-MM-dd').format(selectedReturnDate),
        note: note.isEmpty ? null : note,
        linkedWithdrawalId: null,
      );
      
      await storage.addTransaction(transaction);
      
      if (mounted) {
        Fluttertoast.showToast(msg: '✅ تم حفظ عملية السحب بنجاح');
        _resetForm();
      }
    } catch (e) {
      Fluttertoast.showToast(msg: '❌ حدث خطأ: ${e.toString()}');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }
  
  void _resetForm() {
    _formKey.currentState?.reset();
    setState(() {
      isNewCustomer = false;
      selectedCustomerName = null;
      selectedCustomerId = null;
      newCustomerNameController.clear();
      newCustomerPhoneController.clear();
      selectedMaterial = AppConstants.materialList[0];
      selectedStartDate = DateTime.now();
      discountPercent = 0;
      quantity = 0;
      pricePerUnit = 0;
      selectedReturnDate = DateTime.now().add(const Duration(days: 30));
      note = '';
      quantityController.clear();
      priceController.clear();
      discountController.clear();
      noteController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // SliverAppBar مميز
          SliverAppBar(
            expandedHeight: 200,
            floating: false,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: const Text(
                'سحب مواد',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppConstants.primaryColor,
                      AppConstants.primaryColor.withBlue(100),
                    ],
                  ),
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.construction,
                        size: 60,
                        color: Colors.white70,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        AppConstants.companyName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'بيع وإيجار مواد البناء',
                        style: TextStyle(
                          color: Colors.white.withAlpha(204),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.people_outline),
                onPressed: () => Navigator.pushNamed(context, '/customers'),
                tooltip: 'قائمة العملاء',
              ),
            ],
          ),
          
          // نموذج الإدخال
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverToBoxAdapter(
              child: FadeTransition(
                opacity: _animationController,
                child: Card(
                  elevation: 8,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // عنوان القسم
                          const Row(
                            children: [
                              Icon(Icons.person, color: AppConstants.primaryColor),
                              SizedBox(width: 8),
                              Text(
                                'معلومات العميل',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 24),
                          
                          // اختيار نوع العميل
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(40),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () => setState(() => isNewCustomer = false),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      decoration: BoxDecoration(
                                        color: !isNewCustomer ? AppConstants.primaryColor : Colors.transparent,
                                        borderRadius: BorderRadius.circular(36),
                                      ),
                                      child: Center(
                                        child: Text(
                                          'عميل موجود',
                                          style: TextStyle(
                                            color: !isNewCustomer ? Colors.white : Colors.grey.shade700,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () => setState(() => isNewCustomer = true),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      decoration: BoxDecoration(
                                        color: isNewCustomer ? AppConstants.primaryColor : Colors.transparent,
                                        borderRadius: BorderRadius.circular(36),
                                      ),
                                      child: Center(
                                        child: Text(
                                          'عميل جديد',
                                          style: TextStyle(
                                            color: isNewCustomer ? Colors.white : Colors.grey.shade700,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          const SizedBox(height: 20),
                          
                          // اختيار العميل
                          if (!isNewCustomer)
                            DropdownButtonFormField<String>(
                              decoration: const InputDecoration(
                                labelText: 'اختر العميل *',
                                prefixIcon: Icon(Icons.person_outline),
                              ),
                              value: selectedCustomerName,
                              items: customers.map((c) => DropdownMenuItem(
                                value: c.name,
                                child: Text(c.name),
                              )).toList(),
                              onChanged: (value) => setState(() {
                                selectedCustomerName = value;
                                selectedCustomerId = customers.firstWhere((c) => c.name == value).id;
                              }),
                              validator: (value) => value == null ? 'الرجاء اختيار عميل' : null,
                            ),
                          
                          if (isNewCustomer) ...[
                            TextFormField(
                              controller: newCustomerNameController,
                              decoration: const InputDecoration(
                                labelText: 'اسم العميل *',
                                prefixIcon: Icon(Icons.person_add),
                              ),
                              validator: (value) => value?.trim().isEmpty == true ? 'الرجاء إدخال اسم العميل' : null,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: newCustomerPhoneController,
                              decoration: const InputDecoration(
                                labelText: 'رقم الهاتف (اختياري)',
                                prefixIcon: Icon(Icons.phone),
                              ),
                              keyboardType: TextInputType.phone,
                            ),
                          ],
                          
                          const SizedBox(height: 24),
                          
                          // عنوان قسم المواد
                          const Row(
                            children: [
                              Icon(Icons.inventory, color: AppConstants.primaryColor),
                              SizedBox(width: 8),
                              Text(
                                'معلومات المادة',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 24),
                          
                          // اختيار المادة
                          DropdownButtonFormField<String>(
                            decoration: const InputDecoration(
                              labelText: 'نوع المادة *',
                              prefixIcon: Icon(Icons.category),
                            ),
                            value: selectedMaterial,
                            items: AppConstants.materialList.map((m) => DropdownMenuItem(
                              value: m,
                              child: Text(m),
                            )).toList(),
                            onChanged: (value) => setState(() => selectedMaterial = value!),
                          ),
                          
                          const SizedBox(height: 16),
                          
                          // تاريخ البدء والخصم
                          Row(
                            children: [
                              Expanded(
                                child: InkWell(
                                  onTap: () async {
                                    final date = await showDatePicker(
                                      context: context,
                                      initialDate: selectedStartDate,
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
                                    if (date != null) setState(() => selectedStartDate = date);
                                  },
                                  child: InputDecorator(
                                    decoration: const InputDecoration(
                                      labelText: 'تاريخ البدء *',
                                      prefixIcon: Icon(Icons.calendar_today),
                                    ),
                                    child: Text(DateFormat('yyyy-MM-dd').format(selectedStartDate)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: TextFormField(
                                  controller: discountController,
                                  decoration: const InputDecoration(
                                    labelText: 'الخصم (%)',
                                    prefixIcon: Icon(Icons.percent),
                                  ),
                                  keyboardType: TextInputType.number,
                                  onChanged: (value) => discountPercent = double.tryParse(value) ?? 0,
                                ),
                              ),
                            ],
                          ),
                          
                          const SizedBox(height: 16),
                          
                          // الكمية والسعر
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: quantityController,
                                  decoration: InputDecoration(
                                    labelText: 'الكمية *',
                                    prefixIcon: const Icon(Icons.numbers),
                                    suffixText: AppConstants.getUnit(selectedMaterial),
                                  ),
                                  keyboardType: TextInputType.number,
                                  onChanged: (value) => quantity = double.tryParse(value) ?? 0,
                                  validator: (value) {
                                    if (value == null || value.isEmpty) return 'الرجاء إدخال الكمية';
                                    final val = double.tryParse(value);
                                    if (val == null) return 'الرجاء إدخال رقم صحيح';
                                    if (val <= 0) return 'الكمية يجب أن تكون أكبر من 0';
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: TextFormField(
                                  controller: priceController,
                                  decoration: InputDecoration(
                                    labelText: 'سعر الفرد *',
                                    prefixIcon: const Icon(Icons.attach_money),
                                    suffixText: AppConstants.currencySymbol,
                                  ),
                                  keyboardType: TextInputType.number,
                                  onChanged: (value) => pricePerUnit = double.tryParse(value) ?? 0,
                                  validator: (value) {
                                    if (value == null || value.isEmpty) return 'الرجاء إدخال السعر';
                                    final val = double.tryParse(value);
                                    if (val == null) return 'الرجاء إدخال رقم صحيح';
                                    if (val <= 0) return 'السعر يجب أن يكون أكبر من 0';
                                    return null;
                                  },
                                ),
                              ),
                            ],
                          ),
                          
                          const SizedBox(height: 16),
                          
                          // تاريخ العودة
                          InkWell(
                            onTap: () async {
                              final date = await showDatePicker(
                                context: context,
                                initialDate: selectedReturnDate,
                                firstDate: DateTime.now(),
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
                              if (date != null) setState(() => selectedReturnDate = date);
                            },
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'تاريخ العودة *',
                                prefixIcon: Icon(Icons.calendar_today, color: AppConstants.dangerColor),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.warning_amber, size: 18, color: AppConstants.dangerColor),
                                  const SizedBox(width: 8),
                                  Text(
                                    DateFormat('yyyy-MM-dd').format(selectedReturnDate),
                                    style: const TextStyle(color: AppConstants.dangerColor),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          
                          const SizedBox(height: 16),
                          
                          // ملاحظة
                          TextFormField(
                            controller: noteController,
                            decoration: const InputDecoration(
                              labelText: 'ملاحظة',
                              prefixIcon: Icon(Icons.note_add),
                            ),
                            maxLines: 2,
                            onChanged: (value) => note = value,
                          ),
                          
                          const SizedBox(height: 32),
                          
                          // عرض ملخص العملية
                          if (quantity > 0 && pricePerUnit > 0)
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppConstants.primaryColor.withAlpha(13),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: AppConstants.primaryColor.withAlpha(26)),
                              ),
                              child: Column(
                                children: [
                                  const Text(
                                    'ملخص العملية',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text('الإجمالي قبل الخصم:'),
                                      Text(
                                        '${(quantity * pricePerUnit).toStringAsFixed(2)} ${AppConstants.currencySymbol}',
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text('قيمة الخصم:'),
                                      Text(
                                        '- ${(quantity * pricePerUnit * discountPercent / 100).toStringAsFixed(2)} ${AppConstants.currencySymbol}',
                                        style: const TextStyle(color: AppConstants.dangerColor),
                                      ),
                                    ],
                                  ),
                                  const Divider(height: 20),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        'الإجمالي النهائي:',
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                      ),
                                      Text(
                                        '${(quantity * pricePerUnit * (1 - discountPercent / 100)).toStringAsFixed(2)} ${AppConstants.currencySymbol}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: AppConstants.successColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          
                          const SizedBox(height: 24),
                          
                          // زر الحفظ
                          SizedBox(
                            width: double.infinity,
                            height: 55,
                            child: ElevatedButton(
                              onPressed: isLoading ? null : _saveWithdrawal,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppConstants.primaryColor,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: isLoading
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
                                        Icon(Icons.save),
                                        SizedBox(width: 8),
                                        Text('💾 حفظ العملية', style: TextStyle(fontSize: 16)),
                                      ],
                                    ),
                            ),
                          ),
                          
                          const SizedBox(height: 12),
                          
                          // زر قائمة العملاء
                          SizedBox(
                            width: double.infinity,
                            height: 55,
                            child: OutlinedButton(
                              onPressed: () => Navigator.pushNamed(context, '/customers'),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: AppConstants.primaryColor),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.people, color: AppConstants.primaryColor),
                                  SizedBox(width: 8),
                                  Text('📋 قائمة العملاء', style: TextStyle(fontSize: 16)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}