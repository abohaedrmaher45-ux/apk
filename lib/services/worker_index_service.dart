import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';

class WorkerData {
  String name;
  double balance;
  String mobile;
  String startDate;
  String currency;

  WorkerData({
    required this.name,
    this.balance = 0.0,
    this.mobile = '',
    required this.startDate,
    this.currency = '',
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'balance': balance,
        'mobile': mobile,
        'startDate': startDate,
        'currency': currency,
      };

  factory WorkerData.fromJson(dynamic json) {
    final now = DateTime.now();
    final defaultDate = '${now.year}/${now.month}/${now.day}';

    if (json is String) {
      return WorkerData(name: json, startDate: defaultDate);
    }
    return WorkerData(
      name: json['name'] ?? '',
      balance: (json['balance'] ?? 0.0).toDouble(),
      mobile: json['mobile'] ?? '',
      startDate: json['startDate'] ?? defaultDate,
      currency: json['currency'] ?? '',
    );
  }
}

class WorkerIndexService {
  static final WorkerIndexService _instance = WorkerIndexService._internal();
  factory WorkerIndexService() => _instance;
  WorkerIndexService._internal();

  static const String _fileName = 'worker_index.json';
  Map<int, WorkerData> _workerMap = {};
  bool _isInitialized = false;
  int _nextId = 1;

  Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      await _loadWorkers();
      _isInitialized = true;
    }
  }

  Future<String> _getFilePath() async {
    final directory = await getApplicationDocumentsDirectory();
    return '${directory.path}/$_fileName';
  }

  Future<void> _loadWorkers() async {
    try {
      final filePath = await _getFilePath();
      final file = File(filePath);

      if (await file.exists()) {
        final jsonString = await file.readAsString();
        if (jsonString.isEmpty) {
          // التعامل مع الملفات الفارغة
          _workerMap.clear();
          _nextId = 1;
          return;
        }
        final Map<String, dynamic> jsonData = jsonDecode(jsonString);

        if (jsonData.containsKey('workers') && jsonData.containsKey('nextId')) {
          final Map<String, dynamic> workersJson = jsonData['workers'];
          _workerMap.clear();
          workersJson.forEach((key, value) {
            _workerMap[int.parse(key)] = WorkerData.fromJson(value);
          });
          _nextId = jsonData['nextId'] ?? 1;
        }
      } else {
        _workerMap.clear();
        _nextId = 1;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('❌ خطأ في تحميل فهرس العمال: $e');
      _workerMap.clear();
      _nextId = 1;
    }
  }

  Future<void> _saveToFile() async {
    try {
      final filePath = await _getFilePath();
      final file = File(filePath);
      final Map<String, dynamic> workersJson = {};
      _workerMap.forEach((key, value) {
        workersJson[key.toString()] = value.toJson();
      });
      final Map<String, dynamic> jsonData = {
        'workers': workersJson,
        'nextId': _nextId,
      };
      await file.writeAsString(jsonEncode(jsonData));
    } catch (e) {
      if (kDebugMode) debugPrint('❌ خطأ في حفظ فهرس العمال: $e');
    }
  }

  Future<void> saveWorker(String workerName, {String? startDate}) async {
    await _ensureInitialized();
    if (workerName.trim().isEmpty) return;

    if (!_workerMap.values
        .any((w) => w.name.toLowerCase() == workerName.trim().toLowerCase())) {
      // استخدم التاريخ المُمرَّر إن وُجد، وإلا استخدم تاريخ اليوم كاحتياط
      String dateToSave;
      if (startDate != null && startDate.isNotEmpty) {
        dateToSave = startDate;
      } else {
        final now = DateTime.now();
        dateToSave = '${now.year}/${now.month}/${now.day}';
      }

      _workerMap[_nextId] = WorkerData(
        name: workerName.trim(),
        startDate: dateToSave,
      );
      _nextId++;
      await _saveToFile();
    }
  }

  // بقية الدوال تبقى كما هي بدون تغيير
  Future<void> updateWorkerBalance(
      String workerName, double amountChange) async {
    await _ensureInitialized();
    final normalizedWorker = workerName.trim().toLowerCase();
    for (var entry in _workerMap.entries) {
      if (entry.value.name.toLowerCase() == normalizedWorker) {
        entry.value.balance += amountChange;
        await _saveToFile();
        return;
      }
    }
  }

  Future<void> updateWorkerMobile(String workerName, String mobile) async {
    await _ensureInitialized();
    final normalizedWorker = workerName.trim().toLowerCase();
    for (var entry in _workerMap.entries) {
      if (entry.value.name.toLowerCase() == normalizedWorker) {
        entry.value.mobile = mobile;
        await _saveToFile();
        return;
      }
    }
  }

  Future<void> setInitialBalance(String workerName, double balance) async {
    await _ensureInitialized();
    final normalizedWorker = workerName.trim().toLowerCase();
    for (var entry in _workerMap.entries) {
      if (entry.value.name.toLowerCase() == normalizedWorker) {
        entry.value.balance = balance;
        await _saveToFile();
        return;
      }
    }
  }

  Future<List<String>> getSuggestions(String query) async {
    await _ensureInitialized();
    if (query.isEmpty) return [];
    return _workerMap.values
        .where((w) => w.name.toLowerCase().contains(query.toLowerCase().trim()))
        .map((w) => w.name)
        .toList();
  }

  Future<Map<int, String>> getAllWorkersWithNumbers() async {
    await _ensureInitialized();
    return _workerMap.map((key, value) => MapEntry(key, value.name));
  }

  Future<Map<int, WorkerData>> getAllWorkersWithData() async {
    await _ensureInitialized();
    return Map.from(_workerMap);
  }

  Future<void> removeWorker(String workerName) async {
    await _ensureInitialized();
    int? keyToRemove;
    for (var entry in _workerMap.entries) {
      if (entry.value.name.toLowerCase() == workerName.trim().toLowerCase()) {
        keyToRemove = entry.key;
        break;
      }
    }
    if (keyToRemove != null) {
      if (_workerMap[keyToRemove]?.balance == 0.0) {
        _workerMap.remove(keyToRemove);
        await _saveToFile();
      }
    }
  }

  Future<void> updateWorkerCurrency(String workerName, String currency) async {
    await _ensureInitialized();
    final normalized = workerName.trim().toLowerCase();
    for (var entry in _workerMap.entries) {
      if (entry.value.name.toLowerCase() == normalized) {
        entry.value.currency = currency;
        await _saveToFile();
        return;
      }
    }
  }
}
