// lib/screens/edit_transaction_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../services/storage_service.dart';
import '../models/transaction.dart';
import '../utils/app_constants.dart';

class EditTransactionScreen extends StatefulWidget {
  final int transactionId;
  const EditTransactionScreen({super.key, required this.transactionId});

  @override
  State<EditTransactionScreen> createState() => _EditTransactionScreenState();
}

class _EditTransactionScreenState extends State<EditTransactionScreen> {
  final StorageService storage = StorageService.instance;
  final _formKey = GlobalKey<FormState>();
  Transaction? transaction;
  String selectedMaterial = AppConstants.materialList[0];
  double quantity = 0;
  double pricePerUnit = 0;
  double discountPercent = 0;
  String note = '';
  DateTime? returnDate;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTransaction();
  }

  Future<void> _loadTransaction() async {
    setState(() => isLoading = true);
    final found = await storage.getTransactionById(widget.transactionId);
    if (found != null) {
      setState(() {
        transaction = found;
        selectedMaterial = found.materialName;
        quantity = found.quantity;
        pricePerUnit = found.pricePerUnit;
        discountPercent = found.discountPercent;
        note = found.note ?? '';
        if (found.returnDate != null) returnDate = DateTime.parse(found.returnDate!);
      });
    }
    setState(() => isLoading = false);
  }

  Future<void> _updateTransaction() async {
    if (!_formKey.currentState!.validate()) return;
    if (transaction == null) return;
    
    final updatedTransaction = Transaction(
      id: transaction!.id,
      customerId: transaction!.customerId,
      materialName: selectedMaterial,
      type: transaction!.type,
      quantity: quantity,
      pricePerUnit: pricePerUnit,
      discountPercent: discountPercent,
      date: transaction!.date,
      returnDate: returnDate != null ? DateFormat('yyyy-MM-dd').format(returnDate!) : null,
      note: note.isEmpty ? null : note,
      linkedWithdrawalId: transaction!.linkedWithdrawalId,
    );
    
    await storage.updateTransaction(updatedTransaction);
    Fluttertoast.showToast(msg: '✅ تم التعديل بنجاح');
    if (mounted) Navigator.pop(context);
  }

  Future<void> _selectReturnDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: returnDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (date != null) setState(() => returnDate = date);
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('تعديل معاملة')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    
    if (transaction == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('تعديل معاملة')),
        body: const Center(child: Text('المعاملة غير موجودة')),
      );
    }
    
    return Scaffold(
      appBar: AppBar(title: Text('تعديل ${transaction!.type.name}')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
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
                      initialValue: quantity.toString(),
                      decoration: InputDecoration(
                        labelText: 'الكمية *',
                        suffixText: AppConstants.getUnit(selectedMaterial),
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (value) => quantity = double.tryParse(value) ?? 0,
                      validator: (value) => (value == null || value.isEmpty) ? 'الرجاء إدخال الكمية' : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      initialValue: pricePerUnit.toString(),
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
                initialValue: discountPercent.toString(),
                decoration: const InputDecoration(labelText: 'الخصم (%)'),
                keyboardType: TextInputType.number,
                onChanged: (value) => discountPercent = double.tryParse(value) ?? 0,
              ),
              const SizedBox(height: 16),
              
              // تاريخ العودة (للسحب فقط)
              if (transaction!.type == TransactionType.withdrawal)
                InkWell(
                  onTap: _selectReturnDate,
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'تاريخ العودة'),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today, size: 18),
                        const SizedBox(width: 8),
                        Text(returnDate != null ? DateFormat('yyyy-MM-dd').format(returnDate!) : 'اختر تاريخ'),
                      ],
                    ),
                  ),
                ),
              
              if (transaction!.type == TransactionType.withdrawal)
                const SizedBox(height: 16),
              
              // ملاحظة
              TextFormField(
                initialValue: note,
                decoration: const InputDecoration(labelText: 'ملاحظة'),
                maxLines: 2,
                onChanged: (value) => note = value,
              ),
              const SizedBox(height: 24),
              
              // زر الحفظ
              ElevatedButton(
                onPressed: _updateTransaction,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('💾 حفظ التعديلات', style: TextStyle(fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}