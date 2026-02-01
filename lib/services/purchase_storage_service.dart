import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import '../models/purchase_model.dart';
import 'package:flutter/foundation.dart';

class PurchaseStorageService {
  Future<String> _getBasePath() async {
    Directory? directory;

    if (Platform.isAndroid) {
      directory = await getExternalStorageDirectory();
    } else if (Platform.isWindows) {
      directory = await getApplicationDocumentsDirectory();
    } else {
      directory = await getApplicationDocumentsDirectory();
    }

    return directory!.path;
  }

  // اسم الملف الآن يحتوي فقط على التاريخ
  String _createFileName(String date) {
    final dateParts = date.split('/');
    final formattedDate = dateParts.join('-');
    return 'purchases-$formattedDate.json';
  }

  // حفظ يومية المشتريات (ملف واحد لكل تاريخ)
  Future<bool> savePurchaseDocument(
    PurchaseDocument document, {
    String? journalNumber,
  }) async {
    try {
      final basePath = await _getBasePath();
      final folderPath = '$basePath/AlhalJournals';

      // إنشاء مجلد اليوميات إذا لم يكن موجوداً
      final folder = Directory(folderPath);
      if (!await folder.exists()) {
        await folder.create(recursive: true);
      }

      // اسم الملف: purchases-YYYY-MM-DD.json
      final fileName = _createFileName(document.date);
      final filePath = '$folderPath/$fileName';

      // قراءة الملف الحالي إذا كان موجوداً
      final file = File(filePath);
      PurchaseDocument? existingDocument;

      if (await file.exists()) {
        final jsonString = await file.readAsString();
        final jsonMap = jsonDecode(jsonString) as Map<String, dynamic>;
        existingDocument = PurchaseDocument.fromJson(jsonMap);
      }

      // دمج السجلات
      List<Purchase> mergedPurchases = [];
      if (existingDocument != null) {
        for (var existing in existingDocument.purchases) {
          bool found = false;
          for (var newPurchase in document.purchases) {
            if (existing.serialNumber == newPurchase.serialNumber) {
              found = true;
              break;
            }
          }
          if (!found) {
            mergedPurchases.add(existing);
          }
        }
      }

      // إضافة السجلات الجديدة/المعدلة
      mergedPurchases.addAll(document.purchases);

      // ترتيب السجلات حسب الرقم المسلسل
      mergedPurchases.sort((a, b) =>
          int.parse(a.serialNumber).compareTo(int.parse(b.serialNumber)));

      // الحصول على رقم اليومية
      final String finalJournalNumber;
      if (journalNumber != null) {
        finalJournalNumber = journalNumber;
      } else if (existingDocument != null &&
          existingDocument.recordNumber.isNotEmpty) {
        // استخدام الرقم الموجود إذا كان هناك
        finalJournalNumber = existingDocument.recordNumber;
      } else {
        // الحصول على الرقم التالي
        finalJournalNumber = await getNextJournalNumber();
      }

      // تحديث المجاميع
      final updatedDocument = PurchaseDocument(
        recordNumber: finalJournalNumber, // <-- رقم اليومية
        date: document.date,
        sellerName: 'Multiple Sellers',
        storeName: document.storeName,
        dayName: document.dayName,
        purchases: mergedPurchases,
        totals: _calculateTotals(mergedPurchases),
      );

      // حفظ المستند المحدث
      final updatedJsonString = jsonEncode(updatedDocument.toJson());
      await file.writeAsString(updatedJsonString);

      if (kDebugMode) {
        debugPrint('✅ تم حفظ اليومية رقم $finalJournalNumber: $filePath');
        debugPrint('📊 عدد السجلات: ${mergedPurchases.length}');
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ خطأ في حفظ اليومية: $e');
      }
      return false;
    }
  }

  // تحميل يومية المشترات لتاريخ معين
  Future<PurchaseDocument?> loadPurchaseDocument(String date) async {
    try {
      final basePath = await _getBasePath();
      final folderPath = '$basePath/AlhalJournals';
      final fileName = _createFileName(date);
      final filePath = '$folderPath/$fileName';

      final file = File(filePath);
      if (!await file.exists()) {
        if (kDebugMode) {
          debugPrint('⚠️ اليومية غير موجودة: $filePath');
        }
        return null;
      }

      final jsonString = await file.readAsString();
      final jsonMap = jsonDecode(jsonString) as Map<String, dynamic>;
      final document = PurchaseDocument.fromJson(jsonMap);

      if (kDebugMode) {
        debugPrint(
            '✅ تم تحميل اليومية رقم ${document.recordNumber}: $filePath');
        debugPrint('📊 عدد السجلات: ${document.purchases.length}');
      }

      return document;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ خطأ في قراءة اليومية: $e');
      }
      return null;
    }
  }

  // الحصول على تواريخ اليوميات المتاحة
  Future<List<Map<String, String>>> getAvailableDatesWithNumbers() async {
    try {
      final basePath = await _getBasePath();
      final folderPath = '$basePath/AlhalJournals';

      final folder = Directory(folderPath);
      if (!await folder.exists()) {
        return [];
      }

      final files = await folder.list().toList();
      final datesWithNumbers = <Map<String, String>>[];

      for (var file in files) {
        if (file is File && file.path.endsWith('.json')) {
          try {
            final jsonString = await file.readAsString();
            final jsonMap = jsonDecode(jsonString) as Map<String, dynamic>;
            final date = jsonMap['date']?.toString() ?? '';
            final journalNumber = jsonMap['recordNumber']?.toString() ?? '1';
            final fileName = file.path.split('/').last;

            if (fileName.startsWith('purchases-') && date.isNotEmpty) {
              datesWithNumbers.add({
                'date': date,
                'journalNumber': journalNumber,
                'fileName': fileName,
              });
            }
          } catch (e) {
            if (kDebugMode) {
              debugPrint('❌ خطأ في قراءة ملف: ${file.path}, $e');
            }
          }
        }
      }

      // ترتيب حسب رقم اليومية (تصاعدي)
      datesWithNumbers.sort((a, b) {
        final numA = int.tryParse(a['journalNumber'] ?? '0') ?? 0;
        final numB = int.tryParse(b['journalNumber'] ?? '0') ?? 0;
        return numA.compareTo(numB);
      });

      return datesWithNumbers;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ خطأ في قراءة التواريخ: $e');
      }
      return [];
    }
  }

  // حذف سجل معين من اليومية
  Future<bool> deletePurchaseRecord(
      String date, String recordSerial, String sellerName) async {
    try {
      final document = await loadPurchaseDocument(date);
      if (document == null) return false;

      // البحث عن السجل
      final recordIndex = document.purchases.indexWhere(
          (p) => p.serialNumber == recordSerial && p.sellerName == sellerName);

      if (recordIndex == -1) return false;

      // حذف السجل
      document.purchases.removeAt(recordIndex);

      // تحديث الأرقام المسلسلة
      for (int i = 0; i < document.purchases.length; i++) {
        document.purchases[i] = document.purchases[i].copyWith(
          serialNumber: (i + 1).toString(),
        );
      }

      // تحديث المجاميع
      final updatedDocument = PurchaseDocument(
        recordNumber: document.recordNumber,
        date: document.date,
        sellerName: document.sellerName,
        storeName: document.storeName,
        dayName: document.dayName,
        purchases: document.purchases,
        totals: _calculateTotals(document.purchases),
      );

      // حفظ اليومية المحدثة
      return await savePurchaseDocument(updatedDocument);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ خطأ في حذف السجل: $e');
      }
      return false;
    }
  }

  // حساب المجاميع من السجلات
  Map<String, String> _calculateTotals(List<Purchase> purchases) {
    double totalCount = 0;
    double totalBase = 0;
    double totalNet = 0;
    double totalGrand = 0;

    for (var purchase in purchases) {
      try {
        totalCount += double.tryParse(purchase.count) ?? 0;
        totalBase += double.tryParse(purchase.standing) ?? 0;
        totalNet += double.tryParse(purchase.net) ?? 0;
        totalGrand += double.tryParse(purchase.total) ?? 0;
      } catch (e) {}
    }

    return {
      'totalCount': totalCount.toStringAsFixed(0),
      'totalBase': totalBase.toStringAsFixed(2),
      'totalNet': totalNet.toStringAsFixed(2),
      'totalGrand': totalGrand.toStringAsFixed(2),
    };
  }

  Future<String?> getFilePath(String date) async {
    try {
      final basePath = await _getBasePath();
      final folderPath = '$basePath/AlhalJournals';
      final fileName = _createFileName(date);
      final filePath = '$folderPath/$fileName';

      final file = File(filePath);
      if (await file.exists()) {
        return filePath;
      }

      return null;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ خطأ في الحصول على مسار الملف: $e');
      }
      return null;
    }
  }

  // إضافة هذه الدالة إلى PurchaseStorageService
  Future<double> getCashPurchasesForSeller(
      String date, String sellerName) async {
    try {
      final document = await loadPurchaseDocument(date);
      if (document == null) return 0;

      double totalCashPurchases = 0;

      for (var purchase in document.purchases) {
        if (purchase.sellerName == sellerName &&
            purchase.cashOrDebt == 'نقدي' &&
            purchase.total.isNotEmpty) {
          totalCashPurchases += double.tryParse(purchase.total) ?? 0;
        }
      }

      return totalCashPurchases;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ خطأ في حساب المشتريات النقدية: $e');
      }
      return 0;
    }
  }

  Future<String> getJournalNumberForDate(String date) async {
    try {
      final basePath = await _getBasePath();
      final folderPath = '$basePath/AlhalJournals';
      final fileName = _createFileName(date);
      final filePath = '$folderPath/$fileName';

      final file = File(filePath);
      if (await file.exists()) {
        final jsonString = await file.readAsString();
        final jsonMap = jsonDecode(jsonString) as Map<String, dynamic>;
        return jsonMap['recordNumber'] ?? '1';
      }

      // إذا كان الملف غير موجود، نرجع الرقم 1
      return '1';
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ خطأ في الحصول على رقم اليومية: $e');
      }
      return '1';
    }
  }

  Future<String> getNextJournalNumber() async {
    try {
      final basePath = await _getBasePath();
      final folderPath = '$basePath/AlhalJournals';
      final folder = Directory(folderPath);

      if (!await folder.exists()) {
        return '1'; // أول يومية
      }

      final files = await folder.list().toList();
      int maxJournalNumber = 0;

      for (var file in files) {
        if (file is File && file.path.endsWith('.json')) {
          final jsonString = await file.readAsString();
          final jsonMap = jsonDecode(jsonString) as Map<String, dynamic>;
          final journalNumber =
              int.tryParse(jsonMap['recordNumber'] ?? '0') ?? 0;

          if (journalNumber > maxJournalNumber) {
            maxJournalNumber = journalNumber;
          }
        }
      }

      return (maxJournalNumber + 1).toString();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ خطأ في الحصول على الرقم التسلسلي التالي: $e');
      }
      return '1';
    }
  }
}
