// lib/services/storage_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import '../models/customer.dart';
import '../models/transaction.dart';
import '../models/statistics.dart';

class StorageService {
  static const String _customersKey = 'customers';
  static const String _transactionsKey = 'transactions';
  static const String _nextCustomerIdKey = 'nextCustomerId';
  static const String _nextTransactionIdKey = 'nextTransactionId';

  late SharedPreferences _prefs;
  bool _isInitialized = false;

  StorageService._private();
  static final StorageService instance = StorageService._private();

  Future<void> init() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      _isInitialized = true;
      if (kDebugMode) print('✅ StorageService initialized');
    } catch (e) {
      if (kDebugMode) print('❌ StorageService init error: $e');
      rethrow;
    }
  }

  void _checkInitialized() {
    if (!_isInitialized) {
      throw Exception('StorageService not initialized. Call init() first.');
    }
  }

  // ==================== العملاء ====================
  
  Future<List<Customer>> getCustomers() async {
    _checkInitialized();
    try {
      final String? jsonString = _prefs.getString(_customersKey);
      if (jsonString == null || jsonString.isEmpty) return [];
      
      List<dynamic> jsonList = jsonDecode(jsonString);
      return jsonList.map((json) => Customer.fromJson(json)).toList();
    } catch (e) {
      if (kDebugMode) print('Error loading customers: $e');
      return [];
    }
  }

  Future<void> _saveCustomers(List<Customer> customers) async {
    final String jsonString = jsonEncode(customers.map((c) => c.toJson()).toList());
    await _prefs.setString(_customersKey, jsonString);
  }

  Future<int> getNextCustomerId() async {
    _checkInitialized();
    int nextId = _prefs.getInt(_nextCustomerIdKey) ?? 1;
    await _prefs.setInt(_nextCustomerIdKey, nextId + 1);
    return nextId;
  }

  Future<void> addCustomer(Customer customer) async {
    final customers = await getCustomers();
    customers.add(customer);
    await _saveCustomers(customers);
  }

  Future<void> updateCustomer(Customer updatedCustomer) async {
    final customers = await getCustomers();
    final index = customers.indexWhere((c) => c.id == updatedCustomer.id);
    if (index != -1) {
      customers[index] = updatedCustomer;
      await _saveCustomers(customers);
    }
  }

  Future<bool> deleteCustomer(int id) async {
    try {
      final customers = await getCustomers();
      customers.removeWhere((c) => c.id == id);
      await _saveCustomers(customers);
      
      final transactions = await getTransactions();
      transactions.removeWhere((t) => t.customerId == id);
      await _saveTransactions(transactions);
      return true;
    } catch (e) {
      return false;
    }
  }

  Customer? getCustomerById(List<Customer> customers, int id) {
    try {
      return customers.firstWhere((c) => c.id == id);
    } catch (e) {
      return null;
    }
  }

  // ==================== المعاملات ====================
  
  Future<List<Transaction>> getTransactions() async {
    _checkInitialized();
    try {
      final String? jsonString = _prefs.getString(_transactionsKey);
      if (jsonString == null || jsonString.isEmpty) return [];
      
      List<dynamic> jsonList = jsonDecode(jsonString);
      return jsonList.map((json) => Transaction.fromJson(json)).toList();
    } catch (e) {
      if (kDebugMode) print('Error loading transactions: $e');
      return [];
    }
  }

  Future<void> _saveTransactions(List<Transaction> transactions) async {
    final String jsonString = jsonEncode(transactions.map((t) => t.toJson()).toList());
    await _prefs.setString(_transactionsKey, jsonString);
  }

  Future<int> getNextTransactionId() async {
    _checkInitialized();
    int nextId = _prefs.getInt(_nextTransactionIdKey) ?? 1;
    await _prefs.setInt(_nextTransactionIdKey, nextId + 1);
    return nextId;
  }

  Future<void> addTransaction(Transaction transaction) async {
    final transactions = await getTransactions();
    transactions.add(transaction);
    await _saveTransactions(transactions);
  }

  Future<void> updateTransaction(Transaction updatedTransaction) async {
    final transactions = await getTransactions();
    final index = transactions.indexWhere((t) => t.id == updatedTransaction.id);
    if (index != -1) {
      transactions[index] = updatedTransaction;
      await _saveTransactions(transactions);
    }
  }

  Future<void> deleteTransaction(int id) async {
    final transactions = await getTransactions();
    transactions.removeWhere((t) => t.id == id);
    await _saveTransactions(transactions);
  }

  Future<double> getRemainingQuantity(int customerId, String materialName) async {
    final transactions = await getTransactions();
    
    double totalWithdrawn = 0;
    double totalReturned = 0;
    
    for (var t in transactions) {
      if (t.customerId == customerId && t.materialName == materialName) {
        if (t.type == TransactionType.withdrawal) {
          totalWithdrawn += t.quantity;
        } else {
          totalReturned += t.quantity;
        }
      }
    }
    
    return totalWithdrawn - totalReturned;
  }

  Future<List<Map<String, dynamic>>> getCustomerRemainingMaterials(int customerId) async {
    final transactions = await getTransactions();
    final Map<String, double> remainingMap = {};
    
    for (var t in transactions) {
      if (t.customerId == customerId) {
        if (t.type == TransactionType.withdrawal) {
          remainingMap[t.materialName] = (remainingMap[t.materialName] ?? 0) + t.quantity;
        } else {
          remainingMap[t.materialName] = (remainingMap[t.materialName] ?? 0) - t.quantity;
        }
      }
    }
    
    return remainingMap.entries
        .where((e) => e.value > 0)
        .map((e) => {'materialName': e.key, 'remaining': e.value})
        .toList();
  }
  
  Future<List<Transaction>> getTransactionsByCustomer(int customerId) async {
    final transactions = await getTransactions();
    return transactions
        .where((t) => t.customerId == customerId)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }
  
  Future<Transaction?> getTransactionById(int id) async {
    final transactions = await getTransactions();
    try {
      return transactions.firstWhere((t) => t.id == id);
    } catch (e) {
      return null;
    }
  }

  // ==================== الإحصائيات ====================
  
  Future<Statistics> getStatistics() async {
    final customers = await getCustomers();
    final transactions = await getTransactions();
    
    double totalRevenue = 0;
    final Map<String, double> monthlySales = {};
    final Map<int, double> customerSpending = {};
    final Map<int, int> customerTransactions = {};
    
    for (var t in transactions) {
      if (t.type == TransactionType.withdrawal) {
        totalRevenue += t.totalAfterDiscount;
        
        final month = t.date.substring(0, 7);
        monthlySales[month] = (monthlySales[month] ?? 0) + t.totalAfterDiscount;
        
        customerSpending[t.customerId] = (customerSpending[t.customerId] ?? 0) + t.totalAfterDiscount;
        customerTransactions[t.customerId] = (customerTransactions[t.customerId] ?? 0) + 1;
      }
    }
    
    final List<TopCustomer> topCustomers = [];
    for (var customer in customers) {
      if ((customerTransactions[customer.id] ?? 0) > 0) {
        topCustomers.add(TopCustomer(
          name: customer.name,
          transactionsCount: customerTransactions[customer.id] ?? 0,
          totalSpent: customerSpending[customer.id] ?? 0,
        ));
      }
    }
    topCustomers.sort((a, b) => b.totalSpent.compareTo(a.totalSpent));
    
    return Statistics(
      totalCustomers: customers.length,
      totalTransactions: transactions.length,
      totalRevenue: totalRevenue,
      monthlySales: monthlySales,
      topCustomers: topCustomers.take(5).toList(),
    );
  }

  // ==================== التحميل التدريجي والفلاتر ====================
  
  Future<List<Transaction>> getTransactionsPaginated({
    int limit = 20,
    int offset = 0,
    TransactionFilter? filter,
  }) async {
    var transactions = await getTransactions();
    
    if (filter != null && filter.hasFilters) {
      transactions = transactions.where((t) {
        if (filter.startDate != null) {
          final filterDate = filter.startDate!.toIso8601String().substring(0, 10);
          if (t.date.compareTo(filterDate) < 0) return false;
        }
        if (filter.endDate != null) {
          final filterDate = filter.endDate!.toIso8601String().substring(0, 10);
          if (t.date.compareTo(filterDate) > 0) return false;
        }
        if (filter.materialName != null && t.materialName != filter.materialName) return false;
        if (filter.type != null && t.type != filter.type) return false;
        return true;
      }).toList();
    }
    
    transactions.sort((a, b) => b.date.compareTo(a.date));
    
    return transactions.skip(offset).take(limit).toList();
  }

  // ==================== النسخ الاحتياطي ====================
  
  Future<String> backupData() async {
    final customers = await getCustomers();
    final transactions = await getTransactions();
    
    final backupData = {
      'version': '1.0',
      'exportDate': DateTime.now().toIso8601String(),
      'customers': customers.map((c) => c.toJson()).toList(),
      'transactions': transactions.map((t) => t.toJson()).toList(),
    };
    
    final jsonString = jsonEncode(backupData);
    final directory = await getApplicationDocumentsDirectory();
    final fileName = 'backup_${DateTime.now().millisecondsSinceEpoch}.json';
    final file = File('${directory.path}/$fileName');
    await file.writeAsString(jsonString);
    
    return file.path;
  }
  
  Future<bool> restoreData(String filePath) async {
    try {
      final file = File(filePath);
      final jsonString = await file.readAsString();
      final backupData = jsonDecode(jsonString);
      
      final customers = (backupData['customers'] as List)
          .map((json) => Customer.fromJson(json))
          .toList();
      final transactions = (backupData['transactions'] as List)
          .map((json) => Transaction.fromJson(json))
          .toList();
      
      await _saveCustomers(customers);
      await _saveTransactions(transactions);
      
      return true;
    } catch (e) {
      return false;
    }
  }
}