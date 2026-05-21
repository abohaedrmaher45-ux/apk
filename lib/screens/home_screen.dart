import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../services/storage_service.dart';
import '../models/customer.dart';
import '../models/transaction.dart';
import '../utils/constants.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _formKey = GlobalKey<FormState>();
  final StorageService storage = StorageService.instance;
  String? selectedCustomerName;
  int? selectedCustomerId;
  String selectedMaterial = materialList[0];
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

  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  Future<void> _loadCustomers() async {
    final loadedCustomers = await storage.getCustomers();
    setState(() => customers = loadedCustomers);
  }

  Future<void> _saveWithdrawal() async {
    if (!_formKey.currentState!.validate()) return;
    if (isNewCustomer) {
      if (newCustomerNameController.text.trim().isEmpty) {
        Fluttertoast.showToast(msg: 'الرجاء إدخال اسم العميل');
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
    Fluttertoast.showToast(msg: 'تم حفظ عملية السحب بنجاح');
    _formKey.currentState!.reset();
    setState(() {
      isNewCustomer = false;
      selectedCustomerName = null;
      selectedCustomerId = null;
      newCustomerNameController.clear();
      newCustomerPhoneController.clear();
      selectedMaterial = materialList[0];
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
      appBar: AppBar(
        title: const Text('سحب مواد'),
        actions: [IconButton(icon: const Icon(Icons.people), onPressed: () => Navigator.pushNamed(context, '/customers'), tooltip: 'قائمة العملاء')],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(16)),
              child: Column(
                children: [
                  Text(companyName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.blue)),
                  const SizedBox(height: 8),
                  const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.construction, size: 30), SizedBox(width: 8), Icon(Icons.hardware, size: 30), SizedBox(width: 8), Icon(Icons.apartment, size: 30)]),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      SegmentedButton<bool>(
                        segments: const [ButtonSegment(value: false, label: Text('عميل موجود')), ButtonSegment(value: true, label: Text('عميل جديد'))],
                        selected: {isNewCustomer},
                        onSelectionChanged: (Set<bool> selection) => setState(() {
                          isNewCustomer = selection.first;
                          if (!isNewCustomer) { selectedCustomerName = null; selectedCustomerId = null; }
                        }),
                      ),
                      const SizedBox(height: 16),
                      if (!isNewCustomer)
                        DropdownButtonFormField<String>(
                          decoration: const InputDecoration(labelText: 'اسم العميل *'),
                          value: selectedCustomerName,
                          items: customers.map((c) => DropdownMenuItem(value: c.name, child: Text(c.name))).toList(),
                          onChanged: (value) => setState(() {
                            selectedCustomerName = value;
                            selectedCustomerId = customers.firstWhere((c) => c.name == value).id;
                          }),
                          validator: (value) => value == null ? 'الرجاء اختيار عميل' : null,
                        ),
                      if (isNewCustomer) ...[
                        TextFormField(controller: newCustomerNameController, decoration: const InputDecoration(labelText: 'اسم العميل *'), validator: (value) => value?.trim().isEmpty == true ? 'الرجاء إدخال اسم العميل' : null),
                        const SizedBox(height: 12),
                        TextFormField(controller: newCustomerPhoneController, decoration: const InputDecoration(labelText: 'رقم الهاتف (اختياري)'), keyboardType: TextInputType.phone),
                      ],
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        decoration: const InputDecoration(labelText: 'نوع المادة *'),
                        value: selectedMaterial,
                        items: materialList.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                        onChanged: (value) => setState(() => selectedMaterial = value!),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                final date = await showDatePicker(context: context, initialDate: selectedStartDate, firstDate: DateTime(2020), lastDate: DateTime(2030));
                                if (date != null) setState(() => selectedStartDate = date);
                              },
                              child: InputDecorator(decoration: const InputDecoration(labelText: 'تاريخ البدء *'), child: Text(DateFormat('yyyy-MM-dd').format(selectedStartDate))),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              decoration: const InputDecoration(labelText: 'الخصم (%)'),
                              keyboardType: TextInputType.number,
                              onChanged: (value) => discountPercent = double.tryParse(value) ?? 0,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              decoration: InputDecoration(labelText: 'الكمية *', suffixText: materialUnit[selectedMaterial]),
                              keyboardType: TextInputType.number,
                              onChanged: (value) => quantity = double.tryParse(value) ?? 0,
                              validator: (value) {
                                if (value == null || value.isEmpty) return 'الرجاء إدخال الكمية';
                                if (double.tryParse(value) == null) return 'الرجاء إدخال رقم صحيح';
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              decoration: InputDecoration(labelText: 'سعر الفرد *', suffixText: currencySymbol),
                              keyboardType: TextInputType.number,
                              onChanged: (value) => pricePerUnit = double.tryParse(value) ?? 0,
                              validator: (value) => (value == null || value.isEmpty) ? 'الرجاء إدخال السعر' : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      InkWell(
                        onTap: () async {
                          final date = await showDatePicker(context: context, initialDate: selectedReturnDate, firstDate: DateTime.now(), lastDate: DateTime(2030));
                          if (date != null) setState(() => selectedReturnDate = date);
                        },
                        child: InputDecorator(decoration: const InputDecoration(labelText: 'تاريخ العودة *'), child: Text(DateFormat('yyyy-MM-dd').format(selectedReturnDate))),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(decoration: const InputDecoration(labelText: 'ملاحظة (اختياري)'), maxLines: 2, onChanged: (value) => note = value),
                      const SizedBox(height: 24),
                      ElevatedButton(onPressed: _saveWithdrawal, child: const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text('💾 حفظ العملية', style: TextStyle(fontSize: 16)))),
                      const SizedBox(height: 12),
                      OutlinedButton(onPressed: () => Navigator.pushNamed(context, '/customers'), child: const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text('📋 قائمة العملاء', style: TextStyle(fontSize: 16)))),
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
}