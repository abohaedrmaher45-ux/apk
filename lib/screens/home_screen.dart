// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../services/storage_service.dart';
import '../models/customer.dart';
import '../models/transaction.dart';
import '../utils/app_constants.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_text_field.dart';

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
  
  List<Customer> customers = [];
  bool isLoading = false;
  
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _loadCustomers();
    _animationController = AnimationController(
      duration: AppConstants.animationDuration,
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(parent: _animationController, curve: Curves.easeIn);
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    newCustomerNameController.dispose();
    newCustomerPhoneController.dispose();
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
      
      // التحقق من صحة تاريخ العودة
      if (selectedReturnDate.isBefore(DateTime.now())) {
        Fluttertoast.showToast(msg: 'تاريخ العودة يجب أن يكون بعد اليوم');
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
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: CustomScrollView(
          slivers: [
            // Header جميل
            SliverAppBar(
              expandedHeight: 180,
              floating: false,
              pinned: true,
              flexibleSpace: FlexibleSpaceBar(
                title: const Text('سحب مواد', style: TextStyle(fontWeight: FontWeight.bold)),
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
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.construction, size: 50, color: Colors.white70),
                        const SizedBox(height: 8),
                        Text(
                          AppConstants.companyName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
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
                child: Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // نوع العميل
                          const Text('نوع العميل', style: TextStyle(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 8),
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
                                      child: Text(
                                        'عميل موجود',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: !isNewCustomer ? Colors.white : Colors.grey.shade700,
                                          fontWeight: FontWeight.w600,
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
                                      child: Text(
                                        'عميل جديد',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: isNewCustomer ? Colors.white : Colors.grey.shade700,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          const SizedBox(height: 20),
                          
                          // اختيار العميل أو إضافته
                          if (!isNewCustomer)
                            DropdownButtonFormField<String>(
                              decoration: const InputDecoration(labelText: 'اسم العميل *'),
                              value: selectedCustomerName,
                              items: customers.map((c) => DropdownMenuItem(
                                value: c.name,
                                child: Row(
                                  children: [
                                    const Icon(Icons.person_outline, size: 18),
                                    const SizedBox(width: 8),
                                    Text(c.name),
                                  ],
                                ),
                              )).toList(),
                              onChanged: (value) => setState(() {
                                selectedCustomerName = value;
                                selectedCustomerId = customers.firstWhere((c) => c.name == value).id;
                              }),
                              validator: (value) => value == null ? 'الرجاء اختيار عميل' : null,
                            ),
                          
                          if (isNewCustomer) ...[
                            CustomTextField(
                              label: 'اسم العميل *',
                              controller: newCustomerNameController,
                              validator: (value) => value?.trim().isEmpty == true ? 'الرجاء إدخال اسم العميل' : null,
                            ),
                            const SizedBox(height: 12),
                            CustomTextField(
                              label: 'رقم الهاتف',
                              controller: newCustomerPhoneController,
                              keyboardType: TextInputType.phone,
                            ),
                          ],
                          
                          const SizedBox(height: 16),
                          
                          // المادة
                          DropdownButtonFormField<String>(
                            decoration: const InputDecoration(labelText: 'نوع المادة *'),
                            value: selectedMaterial,
                            items: AppConstants.materialList.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                            onChanged: (value) => setState(() => selectedMaterial = value!),
                          ),
                          
                          const SizedBox(height: 16),
                          
                          // التاريخ والخصم
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
                                    decoration: const InputDecoration(labelText: 'تاريخ البدء *'),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.calendar_today, size: 18),
                                        const SizedBox(width: 8),
                                        Text(DateFormat('yyyy-MM-dd').format(selectedStartDate)),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: CustomTextField(
                                  label: 'الخصم (%)',
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
                                child: CustomTextField(
                                  label: 'الكمية *',
                                  keyboardType: TextInputType.number,
                                  suffixText: AppConstants.materialUnit[selectedMaterial],
                                  onChanged: (value) => quantity = double.tryParse(value) ?? 0,
                                  validator: (value) {
                                    if (value == null || value.isEmpty) return 'الرجاء إدخال الكمية';
                                    if (double.tryParse(value) == null) return 'الرجاء إدخال رقم صحيح';
                                    if (double.parse(value) <= 0) return 'الكمية يجب أن تكون أكبر من 0';
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: CustomTextField(
                                  label: 'سعر الفرد *',
                                  keyboardType: TextInputType.number,
                                  suffixText: AppConstants.currencySymbol,
                                  onChanged: (value) => pricePerUnit = double.tryParse(value) ?? 0,
                                  validator: (value) {
                                    if (value == null || value.isEmpty) return 'الرجاء إدخال السعر';
                                    if (double.tryParse(value) == null) return 'الرجاء إدخال رقم صحيح';
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
                              decoration: const InputDecoration(labelText: 'تاريخ العودة *'),
                              child: Row(
                                children: [
                                  const Icon(Icons.calendar_today, size: 18, color: AppConstants.dangerColor),
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
                          CustomTextField(
                            label: 'ملاحظة',
                            maxLines: 2,
                            onChanged: (value) => note = value,
                          ),
                          
                          const SizedBox(height: 24),
                          
                          // أزرار
                          CustomButton(
                            text: '💾 حفظ العملية',
                            onPressed: _saveWithdrawal,
                            isLoading: isLoading,
                            icon: Icons.save,
                          ),
                          
                          const SizedBox(height: 12),
                          
                          OutlinedButton.icon(
                            onPressed: () => Navigator.pushNamed(context, '/customers'),
                            icon: const Icon(Icons.people),
                            label: const Text('📋 قائمة العملاء'),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(double.infinity, 52),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}