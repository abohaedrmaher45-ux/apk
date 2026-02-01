import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import '../models/receipt_model.dart';
import 'package:flutter/foundation.dart';

class ReceiptStorageService {
  Future<String> _getBasePath() async {
    Directory? directory;
    if (Platform.isAndroid) {
      directory = await getExternalStorageDirectory();
    } else {
      directory = await getApplicationDocumentsDirectory();
    }
    return directory!.path;
  }

  // *** تعديل: هذه الدالة الآن هي الأساس وتعتمد على التاريخ فقط ***
  String _createFileName(String date) {
    final dateParts = date.split('/');
    final formattedDate = dateParts.join('-');
    return 'receipt-$formattedDate.json';
  }

  Future<bool> saveReceiptDocument(ReceiptDocument document) async {
    try {
      final basePath = await _getBasePath();
      final folderPath = '$basePath/Receipts';

      final folder = Directory(folderPath);
      if (!await folder.exists()) {
        await folder.create(recursive: true);
      }

      final fileName = _createFileName(document.date);
      final filePath = '$folderPath/$fileName';
      final file = File(filePath);

      ReceiptDocument? existingDocument;
      if (await file.exists()) {
        final jsonString = await file.readAsString();
        final jsonMap = jsonDecode(jsonString) as Map<String, dynamic>;
        existingDocument = ReceiptDocument.fromJson(jsonMap);
      }

      List<Receipt> mergedReceipts = [];
      if (existingDocument != null) {
        mergedReceipts.addAll(existingDocument.receipts
            .where((r) => r.sellerName != document.sellerName));
      }
      mergedReceipts.addAll(document.receipts);

      for (int i = 0; i < mergedReceipts.length; i++) {
        mergedReceipts[i] =
            mergedReceipts[i].copyWith(serialNumber: (i + 1).toString());
      }

      double totalCount = 0;
      double totalStanding = 0;
      double totalPayment = 0;
      double totalLoad = 0;
      for (var receipt in mergedReceipts) {
        totalCount += double.tryParse(receipt.count) ?? 0;
        totalStanding += double.tryParse(receipt.standing) ?? 0;
        totalPayment += double.tryParse(receipt.payment) ?? 0;
        totalLoad += double.tryParse(receipt.load) ?? 0;
      }

      final String finalRecordNumber =
          existingDocument?.recordNumber ?? await getNextJournalNumber();

      final updatedDocument = ReceiptDocument(
        recordNumber: finalRecordNumber,
        date: document.date,
        sellerName: document.sellerName,
        storeName: document.storeName,
        dayName: document.dayName,
        receipts: mergedReceipts,
        totals: {
          'totalCount': totalCount.toStringAsFixed(0),
          'totalStanding': totalStanding.toStringAsFixed(2),
          'totalPayment': totalPayment.toStringAsFixed(2),
          'totalLoad': totalLoad.toStringAsFixed(2),
        },
      );

      final jsonString = jsonEncode(updatedDocument.toJson());
      await file.writeAsString(jsonString);

      if (kDebugMode) {
        debugPrint('✅ تم حفظ ملف الاستلام المدمج: $filePath');
      }
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ خطأ في حفظ ملف الاستلام: $e');
      }
      return false;
    }
  }

  Future<ReceiptDocument?> loadReceiptDocumentForDate(String date) async {
    try {
      final basePath = await _getBasePath();
      final folderPath = '$basePath/Receipts';
      final fileName = _createFileName(date);
      final filePath = '$folderPath/$fileName';

      final file = File(filePath);
      if (!await file.exists()) {
        return null;
      }

      final jsonString = await file.readAsString();
      final jsonMap = jsonDecode(jsonString) as Map<String, dynamic>;
      return ReceiptDocument.fromJson(jsonMap);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ خطأ في قراءة يومية الاستلام: $e');
      }
      return null;
    }
  }

  // *** تمت إعادتها وتكييفها: تعمل الآن مع الهيكل الجديد ***
  Future<ReceiptDocument?> loadReceiptDocument(
      String date, String recordNumber) async {
    // تتجاهل recordNumber لأن هناك ملف واحد فقط لكل يوم
    return await loadReceiptDocumentForDate(date);
  }

  // *** تمت إعادتها وتكييفها: تعمل الآن مع الهيكل الجديد ***
  Future<List<String>> getAvailableRecords(String date) async {
    try {
      final document = await loadReceiptDocumentForDate(date);
      if (document != null) {
        return [document.recordNumber];
      }
      return [];
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ خطأ في قراءة سجلات الاستلام: $e');
      }
      return [];
    }
  }

  Future<List<Map<String, String>>> getAvailableDatesWithNumbers() async {
    try {
      final basePath = await _getBasePath();
      final receiptsPath = '$basePath/Receipts';

      final folder = Directory(receiptsPath);
      if (!await folder.exists()) {
        return [];
      }

      final files = await folder.list().toList();
      final datesWithNumbers = <Map<String, String>>[];

      for (var file in files) {
        if (file is File &&
            file.path.endsWith('.json') &&
            file.path.split('/').last.startsWith('receipt-')) {
          try {
            final jsonString = await file.readAsString();
            final jsonMap = jsonDecode(jsonString) as Map<String, dynamic>;
            final date = jsonMap['date']?.toString() ?? '';
            final journalNumber = jsonMap['recordNumber']?.toString() ?? '1';
            if (date.isNotEmpty) {
              datesWithNumbers.add({
                'date': date,
                'journalNumber': journalNumber,
              });
            }
          } catch (e) {/* تجاهل الملفات التالفة */}
        }
      }

      datesWithNumbers.sort((a, b) {
        final numA = int.tryParse(a['journalNumber'] ?? '0') ?? 0;
        final numB = int.tryParse(b['journalNumber'] ?? '0') ?? 0;
        return numA.compareTo(numB);
      });

      return datesWithNumbers;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ خطأ في قراءة تواريخ الاستلام: $e');
      }
      return [];
    }
  }

  Future<String?> getFilePath(String date) async {
    try {
      final basePath = await _getBasePath();
      final folderPath = '$basePath/Receipts';
      final fileName = _createFileName(date);
      final filePath = '$folderPath/$fileName';

      final file = File(filePath);
      if (await file.exists()) {
        return filePath;
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ خطأ في الحصول على مسار ملف الاستلام: $e');
      }
      return null;
    }
  }

  Future<String> getJournalNumberForDate(String date) async {
    try {
      final document = await loadReceiptDocumentForDate(date);
      return document?.recordNumber ?? '1';
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ خطأ في الحصول على رقم يومية الاستلام: $e');
      }
      return '1';
    }
  }

  Future<String> getNextJournalNumber() async {
    try {
      final basePath = await _getBasePath();
      final receiptsPath = '$basePath/Receipts';

      final folder = Directory(receiptsPath);
      if (!await folder.exists()) {
        return '1';
      }

      final files = await folder.list().toList();
      int maxJournalNumber = 0;

      for (var file in files) {
        if (file is File &&
            file.path.endsWith('.json') &&
            file.path.split('/').last.startsWith('receipt-')) {
          try {
            final jsonString = await file.readAsString();
            final jsonMap = jsonDecode(jsonString) as Map<String, dynamic>;
            final journalNumber =
                int.tryParse(jsonMap['recordNumber'] ?? '0') ?? 0;
            if (journalNumber > maxJournalNumber) {
              maxJournalNumber = journalNumber;
            }
          } catch (e) {/* تجاهل الملفات التالفة */}
        }
      }
      return (maxJournalNumber + 1).toString();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ خطأ في الحصول على الرقم التسلسلي التالي للاستلام: $e');
      }
      return '1';
    }
  }
}
