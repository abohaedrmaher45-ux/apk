// lib/screens/advanced_search_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/storage_service.dart';
import '../models/transaction.dart';
import '../models/statistics.dart';
import '../utils/app_constants.dart';

class AdvancedSearchScreen extends StatefulWidget {
  const AdvancedSearchScreen({super.key});

  @override
  State<AdvancedSearchScreen> createState() => _AdvancedSearchScreenState();
}

class _AdvancedSearchScreenState extends State<AdvancedSearchScreen> {
  final StorageService storage = StorageService.instance;
  final TransactionFilter _filter = TransactionFilter();
  
  List<Transaction> _results = [];
  bool _isSearching = false;
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('بحث متقدم'),
        actions: [
          IconButton(
            icon: const Icon(Icons.clear_all),
            onPressed: _clearFilters,
            tooltip: 'مسح الفلاتر',
          ),
        ],
      ),
      body: Column(
        children: [
          // فلاتر البحث
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey.shade50,
            child: Column(
              children: [
                // فلتر التاريخ
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => _selectDateRange(context),
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'الفترة',
                            prefixIcon: Icon(Icons.calendar_today),
                          ),
                          child: Text(_getDateRangeText()),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                
                // فلتر المادة
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'نوع المادة',
                    prefixIcon: Icon(Icons.category),
                  ),
                  value: _filter.materialName,
                  items: [
                    const DropdownMenuItem(value: null, child: Text('الكل')),
                    ...AppConstants.materialList.map((m) => DropdownMenuItem(
                      value: m,
                      child: Text(m),
                    )),
                  ],
                  onChanged: (value) => setState(() => _filter.materialName = value),
                ),
                const SizedBox(height: 12),
                
                // فلتر النوع
                DropdownButtonFormField<TransactionType?>(
                  decoration: const InputDecoration(
                    labelText: 'نوع المعاملة',
                    prefixIcon: Icon(Icons.swap_horiz),
                  ),
                  value: _filter.type,
                  items: [
                    const DropdownMenuItem(value: null, child: Text('الكل')),
                    const DropdownMenuItem(
                      value: TransactionType.withdrawal,
                      child: Text('سحب'),
                    ),
                    const DropdownMenuItem(
                      value: TransactionType.return_,
                      child: Text('إرجاع'),
                    ),
                  ],
                  onChanged: (value) => setState(() => _filter.type = value),
                ),
                const SizedBox(height: 16),
                
                // زر البحث
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _search,
                    icon: const Icon(Icons.search),
                    label: const Text('بحث'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // نتائج البحث
          Expanded(
            child: _isSearching
                ? const Center(child: CircularProgressIndicator())
                : _results.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.search_off, size: 64, color: Colors.grey.shade400),
                            const SizedBox(height: 16),
                            Text(
                              'لا توجد نتائج',
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _results.length,
                        itemBuilder: (context, index) {
                          final t = _results[index];
                          return _buildResultItem(t);
                        },
                      ),
          ),
        ],
      ),
    );
  }
  
  Future<void> _selectDateRange(BuildContext context) async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      initialDateRange: _filter.startDate != null && _filter.endDate != null
          ? DateTimeRange(
              start: _filter.startDate!,
              end: _filter.endDate!,
            )
          : null,
    );
    
    if (picked != null) {
      setState(() {
        _filter.startDate = picked.start;
        _filter.endDate = picked.end;
      });
    }
  }
  
  String _getDateRangeText() {
    if (_filter.startDate != null && _filter.endDate != null) {
      return '${DateFormat('yyyy-MM-dd').format(_filter.startDate!)} → ${DateFormat('yyyy-MM-dd').format(_filter.endDate!)}';
    }
    return 'اختر فترة زمنية';
  }
  
  Future<void> _search() async {
    setState(() => _isSearching = true);
    final results = await storage.getTransactionsPaginated(
      limit: 1000,
      offset: 0,
      filter: _filter,
    );
    setState(() {
      _results = results;
      _isSearching = false;
    });
  }
  
  void _clearFilters() {
    setState(() {
      _filter.clear();
      _results = [];
    });
  }
  
  Widget _buildResultItem(Transaction t) {
    final icon = t.type == TransactionType.withdrawal ? Icons.arrow_upward : Icons.arrow_downward;
    final iconColor = t.type == TransactionType.withdrawal ? Colors.red : Colors.green;
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: iconColor.withAlpha(26),
          child: Icon(icon, color: iconColor),
        ),
        title: Text('${t.materialName} - ${t.type.name}'),
        subtitle: Text('التاريخ: ${t.date}\nالكمية: ${t.quantity} ${AppConstants.getUnit(t.materialName)}'),
        trailing: Text(
          '${t.totalAfterDiscount.toStringAsFixed(2)} ${AppConstants.currencySymbol}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        onTap: () {
          Navigator.pushNamed(
            context,
            '/edit_transaction',
            arguments: t.id,
          );
        },
      ),
    );
  }
}