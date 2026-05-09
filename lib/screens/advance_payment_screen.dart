import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import '../models/payment_model.dart';
import '../services/payment_storage_service.dart';
import '../services/worker_index_service.dart';
import '../widgets/table_components.dart' as TableComponents;
import '../widgets/suggestions_banner.dart';
import 'worker_management_screen.dart';

class AdvancePaymentScreen extends StatefulWidget {
  final String selectedDate;

  const AdvancePaymentScreen({
    Key? key,
    required this.selectedDate,
  }) : super(key: key);

  @override
  _AdvancePaymentScreenState createState() => _AdvancePaymentScreenState();
}

class _AdvancePaymentScreenState extends State<AdvancePaymentScreen> {
  final PaymentStorageService _storageService = PaymentStorageService();
  final WorkerIndexService _workerIndexService = WorkerIndexService();

  List<List<TextEditingController>> rowControllers = [];
  List<List<FocusNode>> rowFocusNodes = [];

  late TextEditingController totalPaymentsController;

  final ScrollController _verticalScrollController = ScrollController();
  final ScrollController _horizontalScrollController = ScrollController();

  bool _isSaving = false;
  bool _hasUnsavedChanges = false;

  List<String> _workerSuggestions = [];
  int? _activeWorkerRowIndex;
  bool _showFullScreenSuggestions = false;
  late ScrollController _suggestionsScrollController;

  Timer? _calculateTotalsDebouncer;

  @override
  void initState() {
    super.initState();
    totalPaymentsController = TextEditingController(text: '0.00');
    _suggestionsScrollController = ScrollController();

    _verticalScrollController.addListener(_hideSuggestions);
    _horizontalScrollController.addListener(_hideSuggestions);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadOrCreatePayments();
    });
  }

  @override
  void dispose() {
    // حفظ تلقائي عند الخروج بدون انتظار
    if (_hasUnsavedChanges && !_isSaving) {
      _saveCurrentRecord(silent: true);
    }
    for (var row in rowControllers) {
      for (var controller in row) {
        controller.dispose();
      }
    }
    for (var row in rowFocusNodes) {
      for (var node in row) {
        node.dispose();
      }
    }
    totalPaymentsController.dispose();
    _verticalScrollController.dispose();
    _horizontalScrollController.dispose();
    _suggestionsScrollController.dispose();
    _calculateTotalsDebouncer?.cancel();
    super.dispose();
  }

  void _hideSuggestions() {
    if (mounted) {
      setState(() {
        _workerSuggestions = [];
        _activeWorkerRowIndex = null;
        _showFullScreenSuggestions = false;
      });
    }
  }

  Future<void> _loadOrCreatePayments() async {
    final document =
        await _storageService.loadPaymentDocumentForDate(widget.selectedDate);
    if (document != null && document.transactions.isNotEmpty) {
      _loadPayments(document);
    } else {
      _createNewPayments();
    }
  }

  void _createNewPayments() {
    setState(() {
      rowControllers.clear();
      rowFocusNodes.clear();
      totalPaymentsController.text = '0.00';
      _hasUnsavedChanges = false;
      _addNewRow();
    });
  }

  void _loadPayments(PaymentDocument document) {
    setState(() {
      // تنظيف المتحكمات القديمة
      for (var row in rowControllers) {
        for (var c in row) c.dispose();
      }
      for (var row in rowFocusNodes) {
        for (var n in row) n.dispose();
      }

      rowControllers.clear();
      rowFocusNodes.clear();

      for (var transaction in document.transactions) {
        final newControllers = [
          TextEditingController(text: transaction.serialNumber),
          TextEditingController(text: transaction.paymentValue),
          TextEditingController(text: transaction.workerName),
          TextEditingController(text: transaction.notes),
        ];
        _addChangeListeners(newControllers, rowControllers.length);
        rowControllers.add(newControllers);
        rowFocusNodes.add(List.generate(4, (_) => FocusNode()));
      }
      totalPaymentsController.text = document.totals['totalPayments'] ?? '0.00';
      _hasUnsavedChanges = false;
    });
  }

  void _addNewRow() {
    setState(() {
      final newControllers = List.generate(4, (_) => TextEditingController());
      newControllers[0].text = (rowControllers.length + 1).toString();

      final newFocusNodes = List.generate(4, (_) => FocusNode());

      _addChangeListeners(newControllers, rowControllers.length);

      rowControllers.add(newControllers);
      rowFocusNodes.add(newFocusNodes);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (rowFocusNodes.isNotEmpty) {
        FocusScope.of(context).requestFocus(rowFocusNodes.last[1]);
      }
    });
  }

  void _addChangeListeners(
      List<TextEditingController> controllers, int rowIndex) {
    controllers[1].addListener(() {
      _hasUnsavedChanges = true;
      _calculateAllTotals();
    });
    controllers[2].addListener(() {
      _hasUnsavedChanges = true;
      _updateWorkerSuggestions(rowIndex);
    });
    controllers[3].addListener(() => _hasUnsavedChanges = true);
  }

  void _calculateAllTotals() {
    _calculateTotalsDebouncer?.cancel();
    _calculateTotalsDebouncer = Timer(const Duration(milliseconds: 100), () {
      if (!mounted) return;
      double total = 0;
      for (var controllers in rowControllers) {
        total += double.tryParse(controllers[1].text) ?? 0;
      }
      setState(() {
        totalPaymentsController.text = total.toStringAsFixed(2);
      });
    });
  }

  Future<void> _saveCurrentRecord({bool silent = false}) async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    // 1. تجميع السجلات الجديدة من الواجهة
    final List<PaymentTransaction> newTransactions = [];
    for (int i = 0; i < rowControllers.length; i++) {
      final controllers = rowControllers[i];
      if (controllers[1].text.isNotEmpty || controllers[2].text.isNotEmpty) {
        newTransactions.add(PaymentTransaction(
          serialNumber: (newTransactions.length + 1).toString(),
          paymentValue: controllers[1].text,
          workerName: controllers[2].text.trim(),
          notes: controllers[3].text,
        ));
      }
    }

    // 2. منطق تحديث الأرصدة (إلغاء القديم وتطبيق الجديد)
    Map<String, double> balanceChanges = {};
    final existingDoc =
        await _storageService.loadPaymentDocumentForDate(widget.selectedDate);

    // الخطوة أ: إلغاء أثر الدفعات القديمة
    if (existingDoc != null) {
      for (var oldTrans in existingDoc.transactions) {
        if (oldTrans.workerName.isNotEmpty) {
          double oldPayment = double.tryParse(oldTrans.paymentValue) ?? 0;
          // للإلغاء، نطرح قيمة الدفعة من الرصيد (عكس العملية)
          balanceChanges[oldTrans.workerName] =
              (balanceChanges[oldTrans.workerName] ?? 0) - oldPayment;
        }
      }
    }

    // الخطوة ب: تطبيق أثر الدفعات الجديدة
    for (var newTrans in newTransactions) {
      if (newTrans.workerName.isNotEmpty) {
        double newPayment = double.tryParse(newTrans.paymentValue) ?? 0;
        // للتطبيق، نضيف قيمة الدفعة للرصيد
        balanceChanges[newTrans.workerName] =
            (balanceChanges[newTrans.workerName] ?? 0) + newPayment;
      }
    }

    // 3. بناء الوثيقة النهائية
    final newTotal = newTransactions.fold(
        0.0, (sum, t) => sum + (double.tryParse(t.paymentValue) ?? 0));
    final documentToSave = PaymentDocument(
      date: widget.selectedDate,
      transactions: newTransactions,
      totals: {'totalPayments': newTotal.toStringAsFixed(2)},
    );

    // 4. الحفظ وتحديث الأرصدة
    final success = await _storageService.savePaymentDocument(documentToSave);

    if (success) {
      // حفظ أي عامل جديد للفهرس
      for (var trans in newTransactions) {
        if (trans.workerName.isNotEmpty) {
          await _workerIndexService.saveWorker(trans.workerName);
        }
      }
      setState(() => _hasUnsavedChanges = false); 
      await _loadOrCreatePayments();
    }
  }

  // --- دوال الاقتراحات ---
  void _updateWorkerSuggestions(int rowIndex) async {
    final query = rowControllers[rowIndex][2].text;
    if (query.length >= 1) {
      final suggestions = await _workerIndexService.getSuggestions(query);
      setState(() {
        _workerSuggestions = suggestions;
        _activeWorkerRowIndex = rowIndex;
        _showFullScreenSuggestions = suggestions.isNotEmpty;
      });
    } else {
      _hideSuggestions();
    }
  }

  void _selectWorkerSuggestion(String suggestion, int rowIndex) {
    setState(() {
      rowControllers[rowIndex][2].text = suggestion;
      _hasUnsavedChanges = true;
      _hideSuggestions();
    });
    Future.delayed(const Duration(milliseconds: 50), () {
      if (mounted) {
        FocusScope.of(context).requestFocus(rowFocusNodes[rowIndex][3]);
      }
    });
  }

  // تمت الإضافة: معالج الضغط على Enter
  void _handleFieldSubmitted(String value, int rowIndex, int colIndex) {
    if (colIndex == 1) {
      // من حقل الدفعة
      FocusScope.of(context).requestFocus(rowFocusNodes[rowIndex][2]);
    } else if (colIndex == 2) {
      // من حقل اسم العامل
      // إذا كان هناك اقتراحات، اختر الأول
      if (_workerSuggestions.isNotEmpty) {
        _selectWorkerSuggestion(_workerSuggestions.first, rowIndex);
      } else {
        // إذا لا يوجد اقتراحات، انتقل للحقل التالي
        FocusScope.of(context).requestFocus(rowFocusNodes[rowIndex][3]);
      }
    } else if (colIndex == 3) {
      // من حقل الملاحظات
      if (rowIndex == rowControllers.length - 1) {
        _addNewRow();
      } else {
        FocusScope.of(context).requestFocus(rowFocusNodes[rowIndex + 1][1]);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_hasUnsavedChanges && !_isSaving) {
          await _saveCurrentRecord(silent: true);
        }
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: _showFullScreenSuggestions
                ? SuggestionsBanner(
                    suggestions: _workerSuggestions,
                    type: 'supplier',
                    currentRowIndex: _activeWorkerRowIndex ?? 0,
                    scrollController: _suggestionsScrollController,
                    onSelect: _selectWorkerSuggestion,
                    onClose: _hideSuggestions,
                  )
                : Text(
                    'دفعة على الحساب\nبتاريخ ${widget.selectedDate}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16, height: 1.2),
                  ),
          ),
          centerTitle: true,
          backgroundColor: Colors.blue[700],
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              icon: const Icon(Icons.people),
              tooltip: 'فهرس العمال',
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (context) => WorkerManagementScreen(
                          selectedDate:
                              widget.selectedDate)), // أضف selectedDate
                );
                _loadOrCreatePayments();
              },
            ),
            IconButton(
              icon: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white)))
                  : Stack(
                      children: [
                        const Icon(Icons.save),
                        if (_hasUnsavedChanges)
                          Positioned(
                            right: 0,
                            top: 0,
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                  color: Colors.red,
                                  borderRadius: BorderRadius.circular(6)),
                              constraints: const BoxConstraints(
                                  minWidth: 12, minHeight: 12),
                              child: const SizedBox(width: 8, height: 8),
                            ),
                          ),
                      ],
                    ),
              tooltip: 'حفظ',
              onPressed: _isSaving ? null : () => _saveCurrentRecord(),
            ),
          ],
        ),
        body: _buildTableWithStickyHeader(),
        floatingActionButton: FloatingActionButton(
          onPressed: _addNewRow,
          backgroundColor: Colors.blue[700],
          foregroundColor: Colors.white,
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  Widget _buildTableWithStickyHeader() {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: CustomScrollView(
        controller: _verticalScrollController,
        slivers: [
          SliverPersistentHeader(
            pinned: true,
            delegate: TableComponents.StickyTableHeaderDelegate(
              child: Container(
                color: Colors.grey[200],
                child: _buildTableHeader(),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              controller: _horizontalScrollController,
              child: ConstrainedBox(
                constraints:
                    BoxConstraints(minWidth: MediaQuery.of(context).size.width),
                child: _buildTableContent(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableHeader() {
    return Table(
      columnWidths: const {
        0: FlexColumnWidth(0.1),
        1: FlexColumnWidth(0.25),
        2: FlexColumnWidth(0.4),
        3: FlexColumnWidth(0.25),
      },
      border: TableBorder.all(color: Colors.grey, width: 0.5),
      children: [
        TableRow(
          decoration: BoxDecoration(color: Colors.grey[200]),
          children: [
            TableComponents.buildTableHeaderCell('ت'),
            TableComponents.buildTableHeaderCell('قيمة الدفعة'),
            TableComponents.buildTableHeaderCell('اسم العامل'),
            TableComponents.buildTableHeaderCell('البيان'),
          ],
        ),
      ],
    );
  }

  Widget _buildTableContent() {
    List<TableRow> rows = [];
    for (int i = 0; i < rowControllers.length; i++) {
      rows.add(TableRow(children: [
        _buildCell(i, 0),
        _buildCell(i, 1,
            isNumeric: true,
            inputFormatters: [TableComponents.PositiveDecimalInputFormatter()]),
        _buildCell(i, 2),
        _buildCell(i, 3),
      ]));
    }
    rows.add(TableRow(
      decoration: BoxDecoration(color: Colors.yellow[50]),
      children: [
        Container(),
        TableComponents.buildTotalCell(totalPaymentsController),
        Container(),
        Container(),
      ],
    ));
    return Table(
      columnWidths: const {
        0: FlexColumnWidth(0.1),
        1: FlexColumnWidth(0.25),
        2: FlexColumnWidth(0.4),
        3: FlexColumnWidth(0.25),
      },
      border: TableBorder.all(color: Colors.grey, width: 0.5),
      children: rows,
    );
  }

  Widget _buildCell(int rowIndex, int colIndex,
      {bool isNumeric = false, List<TextInputFormatter>? inputFormatters}) {
    return Container(
      padding: const EdgeInsets.all(1),
      constraints: const BoxConstraints(minHeight: 25),
      child: TextField(
        controller: rowControllers[rowIndex][colIndex],
        focusNode: rowFocusNodes[rowIndex][colIndex],
        readOnly: colIndex == 0,
        decoration: const InputDecoration(
          contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          border: InputBorder.none,
          isDense: true,
        ),
        style: TextStyle(
            fontSize: 13,
            color: Colors.black,
            fontWeight: colIndex == 1 ? FontWeight.bold : FontWeight.normal),
        textAlign: isNumeric ? TextAlign.center : TextAlign.right,
        keyboardType: isNumeric
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.text,
        inputFormatters: inputFormatters,
        onSubmitted: (value) =>
            _handleFieldSubmitted(value, rowIndex, colIndex),
      ),
    );
  }
}
