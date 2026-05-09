import 'package:flutter/material.dart';
import 'dart:async';
import '../models/attendance_model.dart';
import '../services/attendance_storage_service.dart';
import '../services/worker_index_service.dart';

class AttendanceChecklistScreen extends StatefulWidget {
  final String selectedDate;

  const AttendanceChecklistScreen({Key? key, required this.selectedDate})
      : super(key: key);

  @override
  _AttendanceChecklistScreenState createState() =>
      _AttendanceChecklistScreenState();
}

class _AttendanceChecklistScreenState extends State<AttendanceChecklistScreen> {
  final AttendanceStorageService _storageService = AttendanceStorageService();
  final WorkerIndexService _workerIndexService = WorkerIndexService();

  List<String> _workerNames = [];

  List<String> _statusValues = [];

  bool _isSaving = false;
  bool _hasUnsavedChanges = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadOrCreateChecklist();
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadOrCreateChecklist() async {
    final allWorkers = await _workerIndexService.getAllWorkersWithData();
    if (!mounted) return;
    if (allWorkers.isEmpty) {
      setState(() {
        _workerNames = [];
      });
      return;
    }

    final document = await _storageService
        .loadAttendanceDocumentForDate(widget.selectedDate);

    setState(() {
      // تنظيف الموارد القديمة
      _workerNames.clear();

      _statusValues.clear();

      allWorkers.values.forEach((worker) {
        // البحث عن السجل المحفوظ للعامل الحالي
        final savedRecord = document?.records.firstWhere(
          (r) => r.workerName == worker.name,
          orElse: () => AttendanceRecord(
              workerName: '',
              wageDescription: '',
              status: ''), // قيمة وهمية في حالة عدم العثور
        );
        // التحقق مما إذا كان السجل موجوداً حقاً
        final bool recordFound =
            savedRecord != null && savedRecord.workerName.isNotEmpty;

        _workerNames.add(worker.name);

        _statusValues.add(recordFound ? savedRecord.status : 'غائب');
      });
      _hasUnsavedChanges = false;
    });
  }

  Future<void> _saveChecklist() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    final List<AttendanceRecord> records = [];
    for (int i = 0; i < _workerNames.length; i++) {
      records.add(AttendanceRecord(
        workerName: _workerNames[i],
        wageDescription: '',
        status: _statusValues[i],
      ));
    }

    final document =
        AttendanceDocument(date: widget.selectedDate, records: records);
    final success = await _storageService.saveAttendanceDocument(document);

    if (success) {
      setState(() => _hasUnsavedChanges = false);
    }
  }

  void _showStatusDialog(int index) {
    setState(() {
      _statusValues[index] = _statusValues[index] == 'موجود' ? 'غائب' : 'موجود';
      _hasUnsavedChanges = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_hasUnsavedChanges && !_isSaving) {
          await _saveChecklist();
        }
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'جدول التفقد\nبتاريخ ${widget.selectedDate}',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, height: 1.2),
          ),
          centerTitle: true,
          backgroundColor: Colors.green[700],
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              icon: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.white))
                  : Stack(
                      children: [
                        const Icon(Icons.save),
                        if (_hasUnsavedChanges)
                          Positioned(
                            right: 0,
                            top: 0,
                            child: Container(
                              padding: const EdgeInsets.all(1),
                              decoration: BoxDecoration(
                                  color: Colors.red, shape: BoxShape.circle),
                              constraints: const BoxConstraints(
                                  minWidth: 10, minHeight: 10),
                            ),
                          ),
                      ],
                    ),
              onPressed: _isSaving ? null : _saveChecklist,
            ),
          ],
        ),
        body: Directionality(
          textDirection: TextDirection.rtl,
          child: Column(
            children: [
              _buildTableHeader(),
              Expanded(
                child: _workerNames.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Text(
                            'لا يوجد عمال مسجلين.\nالرجاء إضافتهم من القائمة الرئيسية عبر "ادخال الاسماء" أولاً.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _workerNames.length,
                        itemBuilder: (context, index) => _buildTableRow(index),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTableHeader() {
    return Container(
      color: Colors.grey[200],
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: const [
          Expanded(
              flex: 1,
              child: Text('العامل',
                  style: TextStyle(fontWeight: FontWeight.bold))),
          Expanded(
              flex: 1,
              child: Text('الحالة',
                  style: TextStyle(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center)),
        ],
      ),
    );
  }

  Widget _buildTableRow(int index) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
                flex: 1,
                child: Text(_workerNames[index],
                    style: const TextStyle(fontWeight: FontWeight.w500))),
            Expanded(
              flex: 1,
              child: InkWell(
                onTap: () => _showStatusDialog(index),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    color: _statusValues[index] == 'موجود'
                        ? Colors.green.withOpacity(0.1)
                        : Colors.red.withOpacity(0.1),
                  ),
                  child: Center(
                    child: Text(
                      _statusValues[index],
                      style: TextStyle(
                        color: _statusValues[index] == 'موجود'
                            ? Colors.green[800]
                            : Colors.red[800],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
