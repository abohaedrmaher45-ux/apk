import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import '../models/attendance_model.dart';
import 'package:flutter/foundation.dart';

class AttendanceStorageService {
  Future<String> _getBasePath() async {
    final directory = Platform.isAndroid
        ? await getExternalStorageDirectory()
        : await getApplicationDocumentsDirectory();
    return directory!.path;
  }

  String _createFileName(String date) {
    final formattedDate = date.replaceAll('/', '-');
    return 'attendance-$formattedDate.json';
  }

  Future<bool> saveAttendanceDocument(AttendanceDocument document) async {
    try {
      final basePath = await _getBasePath();
      final folderPath = '$basePath/AttendanceJournals';
      await Directory(folderPath).create(recursive: true);

      final fileName = _createFileName(document.date);
      final filePath = '$folderPath/$fileName';
      final jsonString = jsonEncode(document.toJson());
      await File(filePath).writeAsString(jsonString);
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ خطأ في حفظ جدول التفقد: $e');
      return false;
    }
  }

  Future<AttendanceDocument?> loadAttendanceDocumentForDate(String date) async {
    try {
      final basePath = await _getBasePath();
      final folderPath = '$basePath/AttendanceJournals';
      final fileName = _createFileName(date);
      final filePath = '$folderPath/$fileName';

      final file = File(filePath);
      if (!await file.exists()) {
        return null;
      }

      final jsonString = await file.readAsString();
      if (jsonString.isEmpty) return null;
      final jsonMap = jsonDecode(jsonString) as Map<String, dynamic>;
      return AttendanceDocument.fromJson(jsonMap);
    } catch (e) {
      if (kDebugMode) debugPrint('❌ خطأ في قراءة جدول التفقد: $e');
      return null;
    }
  }
}
