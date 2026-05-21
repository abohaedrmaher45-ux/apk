import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../services/storage_service.dart';
import '../models/customer.dart';
import '../models/transaction.dart';
import '../utils/constants.dart';
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
  Customer? customer;
  String selectedMaterial = materialList[0];
  double quantity = 0;
  double pricePerUnit = 0;
  double discountPercent = 0;
  String note = '';

  @override
  void initState() {
    super.initState();
    _loadCustomer();
  }

  Future<void> _loadCustomer() async {
    final customers = await storage.getCustomers();
    setState(() => customer = storage.getCustomerById(customers, widget.customerId));
  }

  Future<void> _saveReturn() async {
    if (!_formKey.currentState!.validate()) return;
    if (customer == null) return;
    final transactionId = await storage.getNextTransactionId();
    final transaction = Transaction(
      id: transactionId,
      customerId: widget.customerId,
      materialName: selectedMaterial,
      type: TransactionType.return_,
      quantity: quantity,
      pricePerUnit: pricePerUnit,
      discountPercent: discountPercent,
      date: DateFormat('yyyy-MM-dd').format(DateTime.now()),
      returnDate: null,
      note: note.isEmpty ? null : note,
      linkedWithdrawalId: null,
    );
    await storage.addTransaction(transaction);
    await PdfGenerator.generateReturnInvoice(customer: customer!, transaction: transaction);
    Fluttertoast.showToast(msg: 'تم حفظ الإرجاع وإنشاء PDF');
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    if (customer == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('فاتورة إرجاع')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('فاتورة إرجاع')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text(customer!.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      if (customer!.phone != null) Text(customer!.phone!),
                      const SizedBox(height: 8),
                      Text('التاريخ: ${DateFormat('yyyy-MM-dd').format(DateTime.now())}', style: const TextStyle(color: Colors.grey)),
                    ],
                  ),
                ),
              ),
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
                    child: TextFormField(
                      decoration: InputDecoration(labelText: 'الكمية المرتجعة *', suffixText: materialUnit[selectedMaterial]),
                      keyboardType: TextInputType.number,
                      onChanged: (value) => quantity = double.tryParse(value) ?? 0,
                      validator: (value) => (value == null || value.isEmpty) ? 'الرجاء إدخال الكمية' : null,
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
              TextFormField(
                decoration: const InputDecoration(labelText: 'الخصم (%)'),
                keyboardType: TextInputType.number,
                onChanged: (value) => discountPercent = double.tryParse(value) ?? 0,
              ),
              const SizedBox(height: 16),
              TextFormField(decoration: const InputDecoration(labelText: 'ملاحظة (اختياري)'), maxLines: 2, onChanged: (value) => note = value),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(12)),
                child: Column(
                  children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('الإجمالي قبل الخصم:'), Text('${(quantity * pricePerUnit).toStringAsFixed(2)} $currencySymbol')]),
                    const SizedBox(height: 8),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('قيمة الخصم:'), Text('${(quantity * pricePerUnit * discountPercent / 100).toStringAsFixed(2)} $currencySymbol')]),
                    const Divider(),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('الإجمالي بعد الخصم:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), Text('${(quantity * pricePerUnit * (1 - discountPercent / 100)).toStringAsFixed(2)} $currencySymbol', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))]),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(onPressed: _saveReturn, child: const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text('💾 حفظ وإنشاء PDF', style: TextStyle(fontSize: 16)))),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        color: Colors.blue[50],
        child: Column(mainAxisSize: MainAxisSize.min, children: [Text(managerName, style: const TextStyle(fontWeight: FontWeight.bold)), Text(contactPhone)]),
      ),
    );
  }
}