// lib/models/statistics.dart
import 'transaction.dart';  // ✅ أضف هذا السطر

class Statistics {
  final int totalCustomers;
  final int totalTransactions;
  final double totalRevenue;
  final Map<String, double> monthlySales;
  final List<TopCustomer> topCustomers;
  
  Statistics({
    required this.totalCustomers,
    required this.totalTransactions,
    required this.totalRevenue,
    required this.monthlySales,
    required this.topCustomers,
  });
}

class TopCustomer {
  final String name;
  final int transactionsCount;
  final double totalSpent;
  
  TopCustomer({
    required this.name,
    required this.transactionsCount,
    required this.totalSpent,
  });
}

class TransactionFilter {
  DateTime? startDate;
  DateTime? endDate;
  String? materialName;
  String? customerName;
  TransactionType? type;
  
  bool get hasFilters {
    return startDate != null ||
        endDate != null ||
        materialName != null ||
        customerName != null ||
        type != null;
  }
  
  void clear() {
    startDate = null;
    endDate = null;
    materialName = null;
    customerName = null;
    type = null;
  }
}