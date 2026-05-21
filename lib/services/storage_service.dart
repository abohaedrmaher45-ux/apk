import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/customer.dart';
import '../models/transaction.dart';

class StorageService {
  static const String _customersKey = 'customers';
  static const String _transactionsKey = 'transactions';
  static const String _nextCustomerIdKey = 'nextCustomerId';
  static const String _nextTransactionIdKey = 'nextTransactionId';

  late SharedPreferences _prefs;

  StorageService._private();
  static final StorageService instance = StorageService._private();

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // ========== العملاء ==========
  
  Future<List<Customer>> getCustomers() async {
    final String? jsonString = _prefs.getString(_customersKey);
    if (jsonString == null) return [];
    
    List<dynamic> jsonList = jsonDecode(jsonString);
    return jsonList.map((json) => Customer.fromJson(json)).toList();
  }

  Future<void> _saveCustomers(List<Customer> customers) async {
    final String jsonString = jsonEncode(customers.map((c) => c.toJson()).toList());
    await _prefs.setString(_customersKey, jsonString);
  }

  Future<int> getNextCustomerId() async {
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

  Future<void> deleteCustomer(int id) async {
    final customers = await getCustomers();
    customers.removeWhere((c) => c.id == id);
    await _saveCustomers(customers);
    
    final transactions = await getTransactions();
    transactions.removeWhere((t) => t.customerId == id);
    await _saveTransactions(transactions);
  }

  Customer? getCustomerById(List<Customer> customers, int id) {
    try {
      return customers.firstWhere((c) => c.id == id);
    } catch (e) {
      return null;
    }
  }

  // ========== المعاملات ==========
  
  Future<List<Transaction>> getTransactions() async {
    final String? jsonString = _prefs.getString(_transactionsKey);
    if (jsonString == null) return [];
    
    List<dynamic> jsonList = jsonDecode(jsonString);
    return jsonList.map((json) => Transaction.fromJson(json)).toList();
  }

  Future<void> _saveTransactions(List<Transaction> transactions) async {
    final String jsonString = jsonEncode(transactions.map((t) => t.toJson()).toList());
    await _prefs.setString(_transactionsKey, jsonString);
  }

  Future<int> getNextTransactionId() async {
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
    final Set<String> materials = {};
    
    for (var t in transactions) {
      if (t.customerId == customerId) {
        materials.add(t.materialName);
      }
    }
    
    List<Map<String, dynamic>> result = [];
    
    for (String material in materials) {
      double remaining = await getRemainingQuantity(customerId, material);
      if (remaining > 0) {
        result.add({
          'materialName': material,
          'remaining': remaining,
        });
      }
    }
    
    return result;
  }
  
  Future<List<Transaction>> getTransactionsByCustomer(int customerId) async {
    final transactions = await getTransactions();
    return transactions
        .where((t) => t.customerId == customerId)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }
  
  Future<List<Transaction>> getWithdrawalsByCustomer(int customerId) async {
    final transactions = await getTransactions();
    return transactions
        .where((t) => t.customerId == customerId && t.type == TransactionType.withdrawal)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }
}