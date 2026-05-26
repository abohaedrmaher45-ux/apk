// lib/screens/customers_list_screen.dart
import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import '../models/customer.dart';
import '../utils/app_constants.dart';

class CustomersListScreen extends StatefulWidget {
  const CustomersListScreen({super.key});

  @override
  State<CustomersListScreen> createState() => _CustomersListScreenState();
}

class _CustomersListScreenState extends State<CustomersListScreen> {
  final StorageService storage = StorageService.instance;
  List<Customer> _customers = [];
  Map<int, List<Map<String, dynamic>>> _customerRemainingMaterials = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCustomersWithRemaining();
  }

  Future<void> _loadCustomersWithRemaining() async {
    setState(() => _isLoading = true);
    
    final allCustomers = await storage.getCustomers();
    final List<Customer> customersWithRemaining = [];
    
    for (var customer in allCustomers) {
      final remaining = await storage.getCustomerRemainingMaterials(customer.id);
      if (remaining.isNotEmpty) {
        customersWithRemaining.add(customer);
        _customerRemainingMaterials[customer.id] = remaining;
      }
    }
    
    setState(() {
      _customers = customersWithRemaining;
      _isLoading = false;
    });
  }

  @override
      Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('العملاء (الذين لديهم مواد متبقية)'),
        backgroundColor: AppConstants.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _customers.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle, size: 80, color: Colors.green),
                      SizedBox(height: 16),
                      Text(
                        'لا يوجد عملاء لديهم مواد متبقية',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 8),
                      Text('جميع العملاء أنهوا موادهم'),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _customers.length,
                  itemBuilder: (context, index) {
                    final customer = _customers[index];
                    final remaining = _customerRemainingMaterials[customer.id] ?? [];
                    return _buildCustomerCard(customer, remaining);
                  },
                ),
    );
  }

  Widget _buildCustomerCard(Customer customer, List<Map<String, dynamic>> remaining) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () => Navigator.pushNamed(
          context,
          '/customer_details',
          arguments: customer.id,
        ),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: AppConstants.primaryColor.withAlpha(26),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        customer.name.isNotEmpty ? customer.name[0] : '?',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppConstants.primaryColor,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          customer.name,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        if (customer.phone != null)
                          Text(
                            customer.phone!,
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),
              const Text(
                'المواد المتبقية:',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: remaining.map((m) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.amber.withAlpha(26),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${m['materialName']}: ${(m['remaining'] as double).toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    icon: const Icon(Icons.receipt, color: Colors.green),
                    onPressed: () => Navigator.pushNamed(
                      context,
                      '/return_invoice',
                      arguments: customer.id,
                    ),
                    tooltip: 'فاتورة إرجاع',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}