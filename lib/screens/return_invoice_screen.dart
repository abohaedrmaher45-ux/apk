// lib/screens/return_invoice_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../services/storage_service.dart';
import '../models/customer.dart';
import '../models/transaction.dart';
import '../utils/app_constants.dart';
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
  String selectedMaterial = AppConstants.materialList[0];
  double quantity = 0;
  double pricePerUnit = 0;
  double discountPercent = 0;
  String note = '';
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCustomer();
  }

  Future<void> _loadCustomer() async {
    setState(() => isLoading = true);
    final customers = await storage.getCustomers();
    setState(() {
      customer = storage.getCustomerById(customers, widget.customerId);
      isLoading = false;
    });
  }

  Future<void> _saveReturn() async {
    if (!_formKey.currentState!.validate()) return;
    if (customer == null) return;
    
    // التحقق من صحة الكمية المرتجعة
    final remaining = await storage.getRemainingQuantity(widget.customerId, selectedMaterial);
    if (quantity > remaining) {
      Fluttertoast.showToast(msg: '⚠️ الكمية المرتجعة (${quantity.toStringAsFixed(2)}) أكبر من المتوفر (${remaining.toStringAsFixed(2)})');
      return;
    }
    
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
    
    Fluttertoast.showToast(msg: '✅ تم حفظ الإرجاع وإنشاء PDF');
    if (mounted) Navigator.pop(context);
  }

  double get totalBeforeDiscount => quantity * pricePerUnit;
  double get discountAmount => totalBeforeDiscount * (discountPercent / 100);
  double get totalAfterDiscount => totalBeforeDiscount - discountAmount;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('فاتورة إرجاع')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    
    if (customer == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('فاتورة إرجاع')),
        body: const Center(child: Text('العميل غير موجود')),
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
              // معلومات العميل
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Text(
                        customer!.name,
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                      if (customer!.phone != null) ...[
                        const SizedBox(height: 8),
                        Text(customer!.phone!, style: const TextStyle(color: Colors.grey)),
                      ],
                      const SizedBox(height: 8),
                      Text(
                        'التاريخ: ${DateFormat('yyyy-MM-dd').format(DateTime.now())}',
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              // المادة
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'نوع المادة *'),
                value: selectedMaterial,
                items: AppConstants.materialList.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                onChanged: (value) => setState(() => selectedMaterial = value!),
              ),
              const SizedBox(height: 16),
              
              // الكمية والسعر
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      decoration: InputDecoration(
                        labelText: 'الكمية المرتجعة *',
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
                      decoration: InputDecoration(
                        labelText: 'سعر الفرد *',
                        suffixText: AppConstants.currencySymbol,
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (value) => pricePerUnit = double.tryParse(value) ?? 0,
                      validator: (value) => (value == null || value.isEmpty) ? 'الرجاء إدخال السعر' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // الخصم
              TextFormField(
                decoration: const InputDecoration(labelText: 'الخصم (%)'),
                keyboardType: TextInputType.number,
                onChanged: (value) => discountPercent = double.tryParse(value) ?? 0,
              ),
              const SizedBox(height: 16),
              
              // ملاحظة
              TextFormField(
                decoration: const InputDecoration(labelText: 'ملاحظة (اختياري)'),
                maxLines: 2,
                onChanged: (value) => note = value,
              ),
              const SizedBox(height: 24),
              
              // ملخص الفاتورة
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('الإجمالي قبل الخصم:'),
                        Text('${totalBeforeDiscount.toStringAsFixed(2)} ${AppConstants.currencySymbol}'),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('قيمة الخصم:'),
                        Text('${discountAmount.toStringAsFixed(2)} ${AppConstants.currencySymbol}'),
                      ],
                    ),
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('الإجمالي بعد الخصم:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        Text(
                          '${totalAfterDiscount.toStringAsFixed(2)} ${AppConstants.currencySymbol}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppConstants.primaryColor),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              
              // زر الحفظ
              ElevatedButton(
                onPressed: _saveReturn,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('💾 حفظ وإنشاء PDF', style: TextStyle(fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        color: AppConstants.primaryColor.withAlpha(13),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(AppConstants.managerName, style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(AppConstants.contactPhone),
          ],
        ),
      ),
    );
  }
}