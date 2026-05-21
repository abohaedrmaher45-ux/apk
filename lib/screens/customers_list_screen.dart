import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import '../models/customer.dart';

class CustomersListScreen extends StatefulWidget {
  const CustomersListScreen({super.key});

  @override
  State<CustomersListScreen> createState() => _CustomersListScreenState();
}

class _CustomersListScreenState extends State<CustomersListScreen> {
  final StorageService storage = StorageService.instance;
  List<Customer> customers = [];
  String searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  Future<void> _loadCustomers() async {
    final loadedCustomers = await storage.getCustomers();
    setState(() {
      customers = loadedCustomers;
    });
  }

  List<Customer> get filteredCustomers {
    if (searchQuery.isEmpty) return customers;
    return customers.where((c) => c.name.contains(searchQuery)).toList();
  }

  Future<void> _deleteCustomer(Customer customer) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف عميل'),
        content: Text('هل أنت متأكد من حذف "${customer.name}"؟ سيتم حذف جميع فواتيره أيضاً.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      await storage.deleteCustomer(customer.id);
      await _loadCustomers();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تم حذف ${customer.name}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('قائمة العملاء'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add),
            onPressed: () {
              Navigator.pushNamed(context, '/');
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'بحث عن عميل...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (value) {
                setState(() {
                  searchQuery = value;
                });
              },
            ),
          ),
          Expanded(
            child: filteredCustomers.isEmpty
                ? const Center(child: Text('لا يوجد عملاء'))
                : ListView.builder(
                    itemCount: filteredCustomers.length,
                    itemBuilder: (context, index) {
                      final customer = filteredCustomers[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.blue[100],
                            child: Text(
                              customer.name.isNotEmpty ? customer.name[0] : '?',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          title: Text(customer.name),
                          subtitle: customer.phone != null ? Text(customer.phone!) : null,
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.receipt, color: Colors.green),
                                onPressed: () {
                                  Navigator.pushNamed(
                                    context,
                                    '/return_invoice',
                                    arguments: customer.id,
                                  );
                                },
                                tooltip: 'فاتورة إرجاع',
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _deleteCustomer(customer),
                                tooltip: 'حذف',
                              ),
                            ],
                          ),
                          onTap: () {
                            Navigator.pushNamed(
                              context,
                              '/customer_details',
                              arguments: customer.id,
                            );
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}