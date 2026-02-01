import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import '../../models/receipt_model.dart';
import '../../services/receipt_storage_service.dart';
// استيراد خدمات الفهرس
import '../../services/material_index_service.dart';
import '../../services/packaging_index_service.dart';
import '../../services/supplier_index_service.dart';
import '../../services/enhanced_index_service.dart';

import '../../widgets/table_builder.dart' as TableBuilder;
import '../../widgets/table_components.dart' as TableComponents;
import '../../widgets/common_dialogs.dart' as CommonDialogs;
import '../../widgets/suggestions_banner.dart';
import '../../services/supplier_balance_tracker.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ReceiptScreen extends StatefulWidget {
  final String sellerName;
  final String selectedDate;
  final String storeName;

  const ReceiptScreen({
    Key? key,
    required this.sellerName,
    required this.selectedDate,
    required this.storeName,
  }) : super(key: key);

  @override
  _ReceiptScreenState createState() => _ReceiptScreenState();
}

class _ReceiptScreenState extends State<ReceiptScreen> {
  // خدمة التخزين
  final ReceiptStorageService _storageService = ReceiptStorageService();

  // خدمات الفهرس
  final MaterialIndexService _materialIndexService = MaterialIndexService();
  final PackagingIndexService _packagingIndexService = PackagingIndexService();
  final SupplierIndexService _supplierIndexService = SupplierIndexService();

  // بيانات الحقول
  String dayName = '';

  // قائمة لتخزين صفوف الجدول
  List<List<TextEditingController>> rowControllers = [];
  List<List<FocusNode>> rowFocusNodes = [];
  List<String> sellerNames = []; // <-- تخزين اسم البائع لكل صف

  // متحكمات صف المجموع
  late TextEditingController totalCountController;
  late TextEditingController totalStandingController;
  late TextEditingController totalPaymentController;
  late TextEditingController totalLoadController;

  // متحكمات للتمرير
  final ScrollController _verticalScrollController = ScrollController();
  final ScrollController _horizontalScrollController = ScrollController();
  final _scrollController = ScrollController(); // للتمرير

  // حالة الحفظ
  bool _isSaving = false;
  bool _hasUnsavedChanges = false;

  // التواريخ المتاحة
  List<Map<String, String>> _availableDates = [];
  bool _isLoadingDates = false;

  String serialNumber = '';
  // ignore: unused_field
  String? _currentJournalNumber;

  // متغيرات للاقتراحات
  List<String> _materialSuggestions = [];
  List<String> _packagingSuggestions = [];
  List<String> _supplierSuggestions = [];

  // مؤشرات الصفوف النشطة للاقتراحات
  int? _activeMaterialRowIndex;
  int? _activePackagingRowIndex;
  int? _activeSupplierRowIndex;

  // متحكمات التمرير الأفقي للاقتراحات
  final ScrollController _materialSuggestionsScrollController =
      ScrollController();
  final ScrollController _packagingSuggestionsScrollController =
      ScrollController();
  final ScrollController _supplierSuggestionsScrollController =
      ScrollController();
  bool _showFullScreenSuggestions = false;
  String _currentSuggestionType = '';
  late ScrollController
      _horizontalSuggestionsController; // في initState قم بتعريفه: _horizontalSuggestionsController = ScrollController();
  final SupplierBalanceTracker _balanceTracker = SupplierBalanceTracker();

  // متغير لتأخير حساب المجاميع (debouncing)
  Timer? _calculateTotalsDebouncer;
  bool _isCalculating = false;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    dayName = _extractDayName(widget.selectedDate);

    totalCountController = TextEditingController();
    totalStandingController = TextEditingController();
    totalPaymentController = TextEditingController();
    totalLoadController = TextEditingController();

    _resetTotalValues();

    // تهيئة المتحكم
    _horizontalSuggestionsController = ScrollController();

    _verticalScrollController.addListener(() {
      _hideAllSuggestionsImmediately();
    });

    _horizontalScrollController.addListener(() {
      _hideAllSuggestionsImmediately();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAdminStatus();
      _loadOrCreateJournal();
      _loadAvailableDates();
      _loadJournalNumber();
    });
  }

  @override
  void dispose() {
    _saveCurrentRecord(silent: true);
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
    totalCountController.dispose();
    totalStandingController.dispose();
    totalPaymentController.dispose();
    totalLoadController.dispose();
    _verticalScrollController.dispose();
    _horizontalScrollController.dispose();
    _scrollController.dispose();
    _materialSuggestionsScrollController.dispose();
    _packagingSuggestionsScrollController.dispose();
    _supplierSuggestionsScrollController.dispose();

    // إغلاق المتحكم
    _horizontalSuggestionsController.dispose();

    _balanceTracker.dispose();

    _calculateTotalsDebouncer?.cancel();
    super.dispose();
  }

  String _extractDayName(String dateString) {
    final days = [
      'الأحد',
      'الإثنين',
      'الثلاثاء',
      'الأربعاء',
      'الخميس',
      'الجمعة',
      'السبت'
    ];
    final now = DateTime.now();
    return days[now.weekday % 7];
  }

  // تحميل التواريخ المتاحة
  Future<void> _loadAvailableDates() async {
    if (_isLoadingDates) return;

    setState(() {
      _isLoadingDates = true;
    });

    try {
      final dates = await _storageService.getAvailableDatesWithNumbers();
      setState(() {
        _availableDates = dates;
        _isLoadingDates = false;
      });
    } catch (e) {
      setState(() {
        _availableDates = [];
        _isLoadingDates = false;
      });
    }
  }

  // تحميل اليومية إذا كانت موجودة، أو إنشاء جديدة
  Future<void> _loadOrCreateJournal() async {
    final document =
        await _storageService.loadReceiptDocumentForDate(widget.selectedDate);

    if (document != null && document.receipts.isNotEmpty) {
      // تحميل اليومية الموجودة
      _loadJournal(document);
    } else {
      // إنشاء يومية جديدة
      _createNewJournal();
    }
  }

  void _resetTotalValues() {
    totalCountController.text = '0';
    totalStandingController.text = '0.00';
    totalPaymentController.text = '0.00';
    totalLoadController.text = '0.00';
  }

  void _createNewJournal() {
    setState(() {
      rowControllers.clear();
      rowFocusNodes.clear();
      sellerNames.clear();
      _resetTotalValues();
      _hasUnsavedChanges = false;
      _addNewRow();
    });
  }

  // تعديل _addNewRow لتحسين المستمعات
  void _addNewRow() {
    setState(() {
      final newSerialNumber = (rowControllers.length + 1).toString();

      List<TextEditingController> newControllers =
          List.generate(8, (index) => TextEditingController());

      List<FocusNode> newFocusNodes = List.generate(8, (index) => FocusNode());

      newControllers[0].text = newSerialNumber;

      // إضافة مستمعات للتغيير باستخدام دالة مساعدة
      _addChangeListenersToControllers(newControllers, rowControllers.length);

      // تخزين اسم البائع للصف الجديد
      sellerNames.add(widget.sellerName);

      rowControllers.add(newControllers);
      rowFocusNodes.add(newFocusNodes);
    });

    // تركيز الماوس على حقل المادة في السجل الجديد
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (rowFocusNodes.isNotEmpty) {
        final newRowIndex = rowFocusNodes.length - 1;
        FocusScope.of(context).requestFocus(rowFocusNodes[newRowIndex][1]);
      }
    });
  }

  // دالة مساعدة لإخفاء جميع الاقتراحات فوراً
  void _hideAllSuggestionsImmediately() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _materialSuggestions = [];
          _packagingSuggestions = [];
          _supplierSuggestions = [];
          _activeMaterialRowIndex = null;
          _activePackagingRowIndex = null;
          _activeSupplierRowIndex = null;
        });
      }
    });
  }

  // دالة مساعدة لإضافة المستمعات
  void _addChangeListenersToControllers(
      List<TextEditingController> controllers, int rowIndex) {
    // حقل المادة
    controllers[1].addListener(() {
      _hasUnsavedChanges = true;
      _updateMaterialSuggestions(rowIndex);
    });

    // حقل العائدية
    controllers[2].addListener(() {
      _hasUnsavedChanges = true;
      _updateSupplierSuggestions(rowIndex);
    });

    // حقل العبوة
    controllers[4].addListener(() {
      _hasUnsavedChanges = true;
      _updatePackagingSuggestions(rowIndex);
    });

    // الحقول الرقمية مع التحديث التلقائي
    controllers[3].addListener(() {
      _hasUnsavedChanges = true;
      _calculateAllTotals();
    });

    controllers[5].addListener(() {
      _hasUnsavedChanges = true;
      _calculateAllTotals();
    });

    controllers[6].addListener(() {
      _hasUnsavedChanges = true;
      _calculateAllTotals();
    });

    controllers[7].addListener(() {
      _hasUnsavedChanges = true;
      _calculateAllTotals();
    });
  }

  // تحديث اقتراحات المادة
  void _updateMaterialSuggestions(int rowIndex) async {
    final query = rowControllers[rowIndex][1].text;
    if (query.length >= 1) {
      final suggestions =
          await getEnhancedSuggestions(_materialIndexService, query);
      setState(() {
        _materialSuggestions = suggestions;
        _activeMaterialRowIndex = rowIndex;
        _toggleFullScreenSuggestions(
            type: 'material', show: suggestions.isNotEmpty);
      });
    } else {
      // إخفاء الاقتراحات إذا كان الحقل فارغاً
      setState(() {
        _materialSuggestions = [];
        _activeMaterialRowIndex = null;
      });
    }
  }

  // تحديث اقتراحات العبوة
  void _updatePackagingSuggestions(int rowIndex) async {
    final query = rowControllers[rowIndex][4].text;
    if (query.length >= 1) {
      final suggestions =
          await getEnhancedSuggestions(_packagingIndexService, query);
      setState(() {
        _packagingSuggestions = suggestions;
        _activePackagingRowIndex = rowIndex;
        _toggleFullScreenSuggestions(
            type: 'packaging', show: suggestions.isNotEmpty);
      });
    } else {
      // إخفاء الاقتراحات إذا كان الحقل فارغاً
      setState(() {
        _packagingSuggestions = [];
        _activePackagingRowIndex = null;
      });
    }
  }

  // تحديث اقتراحات الموردين (العائدية)
  void _updateSupplierSuggestions(int rowIndex) async {
    final query = rowControllers[rowIndex][2].text;
    if (query.length >= 1) {
      final suggestions =
          await getEnhancedSuggestions(_supplierIndexService, query);
      setState(() {
        _supplierSuggestions = suggestions;
        _activeSupplierRowIndex = rowIndex;
        _toggleFullScreenSuggestions(
            type: 'supplier', show: suggestions.isNotEmpty);
      });
    } else {
      // إخفاء الاقتراحات إذا كان الحقل فارغاً
      setState(() {
        _supplierSuggestions = [];
        _activeSupplierRowIndex = null;
      });
    }
  }

  // اختيار اقتراح للمادة - معدلة تماماً
  void _selectMaterialSuggestion(String suggestion, int rowIndex) {
    // إخفاء الاقتراحات أولاً وفوراً
    _hideAllSuggestionsImmediately();

    // ثم تعيين النص
    rowControllers[rowIndex][1].text = suggestion;
    _hasUnsavedChanges = true;

    // حفظ المادة في الفهرس إذا لم تكن موجودة (مع شرط الطول)
    if (suggestion.trim().length > 1) {
      _saveMaterialToIndex(suggestion);
    }

    // نقل التركيز إلى الحقل التالي بعد تأخير بسيط
    Future.delayed(const Duration(milliseconds: 50), () {
      if (mounted) {
        FocusScope.of(context).requestFocus(rowFocusNodes[rowIndex][2]);
      }
    });
  }

  // اختيار اقتراح للعبوة - معدلة تماماً
  void _selectPackagingSuggestion(String suggestion, int rowIndex) {
    // إخفاء الاقتراحات أولاً وفوراً
    _hideAllSuggestionsImmediately();

    // ثم تعيين النص
    rowControllers[rowIndex][4].text = suggestion;
    _hasUnsavedChanges = true;

    // حفظ العبوة في الفهرس إذا لم تكن موجودة (مع شرط الطول)
    if (suggestion.trim().length > 1) {
      _savePackagingToIndex(suggestion);
    }

    // نقل التركيز إلى الحقل التالي بعد تأخير بسيط
    Future.delayed(const Duration(milliseconds: 50), () {
      if (mounted) {
        FocusScope.of(context).requestFocus(rowFocusNodes[rowIndex][5]);
      }
    });
  }

  // اختيار اقتراح للمورد (العائدية) - معدلة تماماً
  void _selectSupplierSuggestion(String suggestion, int rowIndex) {
    // إخفاء الاقتراحات أولاً وفوراً
    _hideAllSuggestionsImmediately();

    // ثم تعيين النص
    rowControllers[rowIndex][2].text = suggestion;
    _hasUnsavedChanges = true;

    // حفظ المورد في الفهرس إذا لم يكن موجوداً (مع شرط الطول)
    if (suggestion.trim().length > 1) {
      _saveSupplierToIndex(suggestion);
    }

    // نقل التركيز إلى الحقل التالي بعد تأخير بسيط
    Future.delayed(const Duration(milliseconds: 50), () {
      if (mounted) {
        FocusScope.of(context).requestFocus(rowFocusNodes[rowIndex][3]);
      }
    });
  }

  // حفظ المادة في الفهرس - معدلة لمنع تخزين حرف واحد
  void _saveMaterialToIndex(String material) {
    final trimmedMaterial = material.trim();
    // منع تخزين حرف واحد أو قيمة فارغة
    if (trimmedMaterial.length > 1) {
      _materialIndexService.saveMaterial(trimmedMaterial);
    }
  }

  // حفظ العبوة في الفهرس - معدلة لمنع تخزين حرف واحد
  void _savePackagingToIndex(String packaging) {
    final trimmedPackaging = packaging.trim();
    // منع تخزين حرف واحد أو قيمة فارغة
    if (trimmedPackaging.length > 1) {
      _packagingIndexService.savePackaging(trimmedPackaging);
    }
  }

  // حفظ المورد في الفهرس - معدلة لمنع تخزين حرف واحد
  void _saveSupplierToIndex(String supplier) {
    final trimmedSupplier = supplier.trim();
    // منع تخزين حرف واحد أو قيمة فارغة
    if (trimmedSupplier.length > 1) {
      _supplierIndexService.saveSupplier(trimmedSupplier);
    }
  }

  void _calculateAllTotals() {
    // إلغاء أي حساب سابق منتظر
    _calculateTotalsDebouncer?.cancel();

    // تأخير الحساب لتجنب التكرار المتعدد
    _calculateTotalsDebouncer = Timer(const Duration(milliseconds: 50), () {
      if (!mounted || _isCalculating) return;

      _isCalculating = true;

      double totalCount = 0;
      double totalStanding = 0;
      double totalPayment = 0;
      double totalLoad = 0;

      for (var controllers in rowControllers) {
        try {
          totalCount += double.tryParse(controllers[3].text) ?? 0;
          totalStanding += double.tryParse(controllers[5].text) ?? 0;
          totalPayment += double.tryParse(controllers[6].text) ?? 0;
          totalLoad += double.tryParse(controllers[7].text) ?? 0;
        } catch (e) {
          // تجاهل الأخطاء
        }
      }

      if (mounted) {
        setState(() {
          totalCountController.text = totalCount.toStringAsFixed(0);
          totalStandingController.text = totalStanding.toStringAsFixed(2);
          totalPaymentController.text = totalPayment.toStringAsFixed(2);
          totalLoadController.text = totalLoad.toStringAsFixed(2);
        });
      }

      _isCalculating = false;
    });
  }

  // تعديل _loadJournal لاستخدام الدالة المساعدة
  void _loadJournal(ReceiptDocument document) {
    setState(() {
      // تنظيف المتحكمات القديمة
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

      // إعادة تهيئة القوائم
      rowControllers.clear();
      rowFocusNodes.clear();
      sellerNames.clear();

      // تحميل السجلات من الوثيقة
      for (int i = 0; i < document.receipts.length; i++) {
        var receipt = document.receipts[i];

        List<TextEditingController> newControllers = [
          TextEditingController(text: receipt.serialNumber),
          TextEditingController(text: receipt.material),
          TextEditingController(text: receipt.affiliation),
          TextEditingController(text: receipt.count),
          TextEditingController(text: receipt.packaging),
          TextEditingController(text: receipt.standing),
          TextEditingController(text: receipt.payment),
          TextEditingController(text: receipt.load),
        ];

        List<FocusNode> newFocusNodes =
            List.generate(8, (index) => FocusNode());

        // تخزين اسم البائع لهذا الصف
        sellerNames.add(receipt.sellerName);

        // التحقق إذا كان السجل مملوكاً للبائع الحالي
        final bool isOwnedByCurrentSeller =
            receipt.sellerName == widget.sellerName;

        // إضافة مستمعات للتغيير فقط إذا كان السجل مملوكاً للبائع الحالي
        if (isOwnedByCurrentSeller) {
          _addChangeListenersToControllers(newControllers, i);
        }

        rowControllers.add(newControllers);
        rowFocusNodes.add(newFocusNodes);
      }

      // تحميل المجاميع
      if (document.totals.isNotEmpty) {
        totalCountController.text = document.totals['totalCount'] ?? '0';
        totalStandingController.text =
            document.totals['totalStanding'] ?? '0.00';
        totalPaymentController.text = document.totals['totalPayment'] ?? '0.00';
        totalLoadController.text = document.totals['totalLoad'] ?? '0.00';
      }

      _hasUnsavedChanges = false;
    });
  }

  void _scrollToField(int rowIndex, int colIndex) {
    const double headerHeight = 32.0;
    const double rowHeight = 25.0;
    final double verticalPosition = (rowIndex * rowHeight);
    const double columnWidth = 60.0;
    final double horizontalPosition = colIndex * columnWidth;

    _verticalScrollController.animateTo(
      verticalPosition + headerHeight,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );

    _horizontalScrollController.animateTo(
      horizontalPosition,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  Widget _buildTableHeader() {
    return Table(
      defaultColumnWidth: const FlexColumnWidth(),
      border: TableBorder.all(color: Colors.grey, width: 0.5),
      children: [
        TableRow(
          decoration: BoxDecoration(color: Colors.grey[200]),
          children: [
            TableComponents.buildTableHeaderCell('مسلسل'),
            TableComponents.buildTableHeaderCell('المادة'),
            TableComponents.buildTableHeaderCell('العائدية'),
            TableComponents.buildTableHeaderCell('العدد'),
            TableComponents.buildTableHeaderCell('العبوة'),
            TableComponents.buildTableHeaderCell('القائم'),
            TableComponents.buildTableHeaderCell('الدفعة'),
            TableComponents.buildTableHeaderCell('الحمولة'),
          ],
        ),
      ],
    );
  }

  Widget _buildTableContent() {
    List<TableRow> contentRows = [];

    for (int i = 0; i < rowControllers.length; i++) {
      // التحقق إذا كان السجل مملوكاً للبائع الحالي
      final bool isOwnedByCurrentSeller = sellerNames[i] == widget.sellerName;

      contentRows.add(
        TableRow(
          children: [
            _buildTableCell(rowControllers[i][0], rowFocusNodes[i][0], i, 0,
                isOwnedByCurrentSeller),
            _buildMaterialCell(rowControllers[i][1], rowFocusNodes[i][1], i, 1,
                isOwnedByCurrentSeller),
            _buildSupplierCell(rowControllers[i][2], rowFocusNodes[i][2], i, 2,
                isOwnedByCurrentSeller),
            _buildTableCell(rowControllers[i][3], rowFocusNodes[i][3], i, 3,
                isOwnedByCurrentSeller),
            _buildPackagingCell(rowControllers[i][4], rowFocusNodes[i][4], i, 4,
                isOwnedByCurrentSeller),
            _buildTableCell(rowControllers[i][5], rowFocusNodes[i][5], i, 5,
                isOwnedByCurrentSeller),
            _buildTableCell(rowControllers[i][6], rowFocusNodes[i][6], i, 6,
                isOwnedByCurrentSeller),
            _buildTableCell(rowControllers[i][7], rowFocusNodes[i][7], i, 7,
                isOwnedByCurrentSeller),
          ],
        ),
      );
    }

    if (rowControllers.length >= 2) {
      contentRows.add(
        TableRow(
          decoration: BoxDecoration(color: Colors.yellow[50]),
          children: [
            _buildEmptyCell(),
            _buildEmptyCell(),
            _buildEmptyCell(),
            TableComponents.buildTotalCell(totalCountController),
            _buildEmptyCell(),
            TableComponents.buildTotalCell(totalStandingController),
            TableComponents.buildTotalCell(totalPaymentController),
            TableComponents.buildTotalCell(totalLoadController),
          ],
        ),
      );
    }

    return Table(
      defaultColumnWidth: const FlexColumnWidth(),
      border: TableBorder.all(color: Colors.grey, width: 0.5),
      children: contentRows,
    );
  }

  Widget _buildTableCell(TextEditingController controller, FocusNode focusNode,
      int rowIndex, int colIndex, bool isOwnedByCurrentSeller) {
    bool isSerialField = colIndex == 0;
    bool isNumericField =
        colIndex == 3 || colIndex == 5 || colIndex == 6 || colIndex == 7;

    Widget cell = TableBuilder.buildTableCell(
      controller: controller,
      focusNode: focusNode,
      isSerialField: isSerialField,
      isNumericField: isNumericField,
      rowIndex: rowIndex,
      colIndex: colIndex,
      scrollToField: _scrollToField,
      onFieldSubmitted: (value, rIndex, cIndex) =>
          _handleFieldSubmitted(value, rIndex, cIndex),
      onFieldChanged: (value, rIndex, cIndex) =>
          _handleFieldChanged(value, rIndex, cIndex),
      inputFormatters: isNumericField
          ? [
              TableComponents.PositiveDecimalInputFormatter(),
              FilteringTextInputFormatter.deny(RegExp(r'\.\d{3,}')),
            ]
          : null,
    );

    // إذا لم يكن السجل مملوكاً للبائع الحالي، جعل الخلية للقراءة فقط
    if (!_canEditRow(rowIndex)) {
      return IgnorePointer(
        child: Opacity(
          opacity: 0.7,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.grey[100],
            ),
            child: cell,
          ),
        ),
      );
    }

    return cell;
  }

  Widget _buildMaterialCell(
      TextEditingController controller,
      FocusNode focusNode,
      int rowIndex,
      int colIndex,
      bool isOwnedByCurrentSeller) {
    return TableBuilder.buildTableCell(
      controller: controller,
      focusNode: focusNode,
      isSerialField: false,
      isNumericField: false,
      rowIndex: rowIndex,
      colIndex: colIndex,
      scrollToField: _scrollToField,
      onFieldSubmitted: (value, rIndex, cIndex) =>
          _handleFieldSubmitted(value, rIndex, cIndex),
      onFieldChanged: (value, rIndex, cIndex) =>
          _handleFieldChanged(value, rIndex, cIndex),
    );
  }

  Widget _buildPackagingCell(
      TextEditingController controller,
      FocusNode focusNode,
      int rowIndex,
      int colIndex,
      bool isOwnedByCurrentSeller) {
    return TableBuilder.buildTableCell(
      controller: controller,
      focusNode: focusNode,
      isSerialField: false,
      isNumericField: false,
      rowIndex: rowIndex,
      colIndex: colIndex,
      scrollToField: _scrollToField,
      onFieldSubmitted: (value, rIndex, cIndex) =>
          _handleFieldSubmitted(value, rIndex, cIndex),
      onFieldChanged: (value, rIndex, cIndex) =>
          _handleFieldChanged(value, rIndex, cIndex),
    );
  }

  Widget _buildSupplierCell(
      TextEditingController controller,
      FocusNode focusNode,
      int rowIndex,
      int colIndex,
      bool isOwnedByCurrentSeller) {
    return TableBuilder.buildTableCell(
      controller: controller,
      focusNode: focusNode,
      isSerialField: false,
      isNumericField: false,
      rowIndex: rowIndex,
      colIndex: colIndex,
      scrollToField: _scrollToField,
      onFieldSubmitted: (value, rIndex, cIndex) =>
          _handleFieldSubmitted(value, rIndex, cIndex),
      onFieldChanged: (value, rIndex, cIndex) =>
          _handleFieldChanged(value, rIndex, cIndex),
    );
  }

  void _handleFieldSubmitted(String value, int rowIndex, int colIndex) {
    if (!_canEditRow(rowIndex)) return;

    if (colIndex == 1) {
      if (_materialSuggestions.isNotEmpty) {
        _selectMaterialSuggestion(_materialSuggestions[0], rowIndex);
        return;
      }
      if (value.trim().length > 1) _saveMaterialToIndex(value);
      FocusScope.of(context).requestFocus(rowFocusNodes[rowIndex][2]);
    } else if (colIndex == 2) {
      if (_supplierSuggestions.isNotEmpty) {
        _selectSupplierSuggestion(_supplierSuggestions[0], rowIndex);
        return;
      }
      if (value.trim().length > 1) _saveSupplierToIndex(value);
      FocusScope.of(context).requestFocus(rowFocusNodes[rowIndex][3]);
    } else if (colIndex == 4) {
      if (_packagingSuggestions.isNotEmpty) {
        _selectPackagingSuggestion(_packagingSuggestions[0], rowIndex);
        return;
      }
      if (value.trim().length > 1) _savePackagingToIndex(value);
      FocusScope.of(context).requestFocus(rowFocusNodes[rowIndex][5]);
    } else if (colIndex == 0) {
      FocusScope.of(context).requestFocus(rowFocusNodes[rowIndex][1]);
    } else if (colIndex == 7) {
      _addNewRow();
      if (rowControllers.isNotEmpty) {
        final newRowIndex = rowControllers.length - 1;
        FocusScope.of(context).requestFocus(rowFocusNodes[newRowIndex][1]);
      }
    } else if (colIndex < 7) {
      FocusScope.of(context)
          .requestFocus(rowFocusNodes[rowIndex][colIndex + 1]);
    }

    _hideAllSuggestionsImmediately();
  }

  void _handleFieldChanged(String value, int rowIndex, int colIndex) {
    // التحقق إذا كان السجل مملوكاً للبائع الحالي
    if (!_canEditRow(rowIndex)) {
      return;
    }

    setState(() {
      _hasUnsavedChanges = true;

      if (colIndex == 0) {
        for (int i = 0; i < rowControllers.length; i++) {
          rowControllers[i][0].text = (i + 1).toString();
        }
      }

      // إذا بدأ المستخدم بالكتابة في حقل آخر، إخفاء اقتراحات الحقول الأخرى
      if (colIndex == 1 && _activeMaterialRowIndex != rowIndex) {
        _clearAllSuggestions();
      } else if (colIndex == 2 && _activeSupplierRowIndex != rowIndex) {
        _clearAllSuggestions();
      } else if (colIndex == 4 && _activePackagingRowIndex != rowIndex) {
        _clearAllSuggestions();
      }

      // تحديث المجاميع للحقول الرقمية
      if (colIndex == 3 || colIndex == 5 || colIndex == 6 || colIndex == 7) {
        _calculateAllTotals();
      }
    });
  }

  Widget _buildEmptyCell() {
    return Container(
      padding: const EdgeInsets.all(1),
      constraints: const BoxConstraints(minHeight: 25),
      child: TextField(
        controller: TextEditingController()..text = '',
        focusNode: FocusNode(),
        enabled: false,
        decoration: const InputDecoration(
          contentPadding: EdgeInsets.symmetric(horizontal: 2, vertical: 1),
          border: InputBorder.none,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (_showFullScreenSuggestions &&
                _getSuggestionsByType().isNotEmpty)
              SuggestionsBanner(
                suggestions: _getSuggestionsByType(),
                type: _currentSuggestionType,
                currentRowIndex: _getCurrentRowIndexByType(),
                scrollController: _horizontalSuggestionsController,
                onSelect: (val, idx) {
                  if (_currentSuggestionType == 'material')
                    _selectMaterialSuggestion(val, idx);
                  if (_currentSuggestionType == 'packaging')
                    _selectPackagingSuggestion(val, idx);
                  if (_currentSuggestionType == 'supplier')
                    _selectSupplierSuggestion(val, idx);
                },
                onClose: () =>
                    _toggleFullScreenSuggestions(type: '', show: false),
              ),
            Expanded(
              child: Text(
                'يومية استلام رقم /$serialNumber/ تاريخ ${widget.selectedDate} البائع ${widget.sellerName}',
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                textAlign: TextAlign.right,
              ),
            ),
          ],
        ),
        centerTitle: false,
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'مشاركة الملف',
            onPressed: () => _shareFile(),
          ),
          IconButton(
            icon: _isSaving
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
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
                              borderRadius: BorderRadius.circular(6),
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 12,
                              minHeight: 12,
                            ),
                            child: const SizedBox(
                              width: 8,
                              height: 8,
                            ),
                          ),
                        ),
                    ],
                  ),
            tooltip: _hasUnsavedChanges
                ? 'هناك تغييرات غير محفوظة - انقر للحفظ'
                : 'حفظ اليومية',
            onPressed: _isSaving
                ? null
                : () {
                    _saveCurrentRecord();
                  },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.calendar_today),
            tooltip: 'فتح يومية سابقة',
            onSelected: (selectedDate) async {
              if (selectedDate != widget.selectedDate) {
                if (_hasUnsavedChanges) {
                  final shouldSave = await _showUnsavedChangesDialog();
                  if (shouldSave) {
                    await _saveCurrentRecord(silent: true);
                  }
                }

                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ReceiptScreen(
                      sellerName: widget.sellerName,
                      selectedDate: selectedDate,
                      storeName: widget.storeName,
                    ),
                  ),
                );
              }
            },
            itemBuilder: (BuildContext context) {
              List<PopupMenuEntry<String>> items = [];

              if (_isLoadingDates) {
                items.add(
                  const PopupMenuItem<String>(
                    value: '',
                    enabled: false,
                    child: Text('جاري التحميل...'),
                  ),
                );
              } else if (_availableDates.isEmpty) {
                items.add(
                  const PopupMenuItem<String>(
                    value: '',
                    enabled: false,
                    child: Text('لا توجد يوميات سابقة'),
                  ),
                );
              } else {
                items.add(
                  const PopupMenuItem<String>(
                    value: '',
                    enabled: false,
                    child: Text(
                      'اليوميات المتاحة',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                );
                items.add(const PopupMenuDivider());

                for (var dateInfo in _availableDates) {
                  final date = dateInfo['date']!;
                  final journalNumber = dateInfo['journalNumber']!;

                  items.add(
                    PopupMenuItem<String>(
                      value: date,
                      child: Text(
                        'يومية رقم $journalNumber - تاريخ $date',
                        style: TextStyle(
                          fontWeight: date == widget.selectedDate
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: date == widget.selectedDate
                              ? Colors.blue
                              : Colors.black,
                        ),
                      ),
                    ),
                  );
                }
              }

              return items;
            },
          ),
        ],
      ),
      body: _buildMainContent(),
      // إخفاء زر الإضافة عند ظهور لوحة المفاتيح
      floatingActionButton: MediaQuery.of(context).viewInsets.bottom > 0
          ? null
          : Container(
              margin: const EdgeInsets.only(bottom: 16, right: 16),
              child: Material(
                color: Colors.blue[700],
                borderRadius: BorderRadius.circular(12),
                elevation: 8,
                child: InkWell(
                  onTap: _addNewRow,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 28, vertical: 16),
                    child: const Text(
                      'إضافة',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ),
              ),
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.startDocked,
      resizeToAvoidBottomInset: true, // تغيير من false إلى true
    );
  }

  Widget _buildMainContent() {
    return _buildTableWithStickyHeader();
  }

  Widget _buildTableWithStickyHeader() {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: CustomScrollView(
        controller: _verticalScrollController,
        slivers: [
          SliverPersistentHeader(
            pinned: true,
            floating: false,
            delegate: _StickyTableHeaderDelegate(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  border: Border.all(color: Colors.grey),
                ),
                child: _buildTableHeader(),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                controller: _horizontalScrollController,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minWidth: MediaQuery.of(context).size.width,
                  ),
                  child: _buildTableContent(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // In receipt_screen.dart -> _ReceiptScreenState

  Future<void> _saveCurrentRecord({bool silent = false}) async {
    if (_isSaving) return;

    if (rowControllers.isEmpty && !silent) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('لا توجد بيانات للحفظ'),
            backgroundColor: Colors.orange),
      );
      return;
    }

    // 1. تجميع سجلات البائع الحالي فقط
    final currentSellerReceipts = <Receipt>[];
    for (int i = 0; i < rowControllers.length; i++) {
      // فقط السجلات التي يملكها البائع الحالي
      if (sellerNames[i] == widget.sellerName) {
        final controllers = rowControllers[i];
        if (controllers[1].text.isNotEmpty || controllers[3].text.isNotEmpty) {
          currentSellerReceipts.add(Receipt(
            serialNumber: controllers[0].text,
            material: controllers[1].text,
            affiliation: controllers[2].text,
            count: controllers[3].text,
            packaging: controllers[4].text,
            standing: controllers[5].text,
            payment: controllers[6].text,
            load: controllers[7].text,
            sellerName: sellerNames[i], // استخدام اسم البائع المحفوظ
          ));
        }
      }
    }

    if (currentSellerReceipts.isEmpty && !silent) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('لا توجد سجلات جديدة أو معدلة للحفظ'),
            backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isSaving = true);

    // 2. حساب صافي التغير في أرصدة الموردين (منطق صحيح)
    Map<String, double> supplierBalanceChanges = {};
    final existingDocument =
        await _storageService.loadReceiptDocumentForDate(widget.selectedDate);

    // طرح القيم القديمة للبائع الحالي فقط
    if (existingDocument != null) {
      for (var receipt in existingDocument.receipts) {
        if (receipt.sellerName == widget.sellerName &&
            receipt.affiliation.isNotEmpty) {
          double oldDeduction = (double.tryParse(receipt.payment) ?? 0) +
              (double.tryParse(receipt.load) ?? 0);
          // لإلغاء الخصم، نعيد إضافة القيمة
          supplierBalanceChanges[receipt.affiliation] =
              (supplierBalanceChanges[receipt.affiliation] ?? 0) + oldDeduction;
        }
      }
    }

    // إضافة تأثير القيم الجديدة للبائع الحالي
    for (var receipt in currentSellerReceipts) {
      if (receipt.affiliation.isNotEmpty) {
        double newDeduction = (double.tryParse(receipt.payment) ?? 0) +
            (double.tryParse(receipt.load) ?? 0);
        // نطبق الخصم الجديد بالطرح
        supplierBalanceChanges[receipt.affiliation] =
            (supplierBalanceChanges[receipt.affiliation] ?? 0) - newDeduction;
      }
    }

    // 3. إنشاء المستند الذي سيتم تمريره لدالة الحفظ
    // هذه الدالة ستقوم بالدمج بنفسها
    final documentToSave = ReceiptDocument(
      recordNumber: serialNumber, // سيتم تحديثه داخل دالة الحفظ
      date: widget.selectedDate,
      sellerName: widget.sellerName, // اسم آخر من قام بالتعديل
      storeName: widget.storeName,
      dayName: dayName,
      receipts: currentSellerReceipts, // نمرر سجلات البائع الحالي فقط
      totals: {}, // المجاميع الكلية سيتم حسابها داخل دالة الحفظ
    );

    final success = await _storageService.saveReceiptDocument(documentToSave);

    if (success) {
      // تطبيق التغييرات على أرصدة الموردين
      for (var entry in supplierBalanceChanges.entries) {
        if (entry.value != 0) {
          await _supplierIndexService.updateSupplierBalance(
              entry.key, entry.value);
          if (kDebugMode) {
            print(
                '🔄 تم تحديث رصيد المورد ${entry.key} بمقدار: ${entry.value.toStringAsFixed(2)}');
          }
        }
      }

      // إعادة تحميل البيانات المدمجة بعد الحفظ لعرضها بشكل صحيح
      await _loadOrCreateJournal();
      setState(() {
        _hasUnsavedChanges = false;
      });
    }

    setState(() => _isSaving = false);

    if (!silent && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'تم الحفظ بنجاح' : 'فشل الحفظ'),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  Future<bool> _showUnsavedChangesDialog() async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('تغييرات غير محفوظة'),
            content: const Text(
              'هناك تغييرات غير محفوظة. هل تريد حفظها قبل الانتقال؟',
              textAlign: TextAlign.center,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('تجاهل'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('حفظ'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _loadJournalNumber() async {
    try {
      final journalNumber =
          await _storageService.getJournalNumberForDate(widget.selectedDate);
      setState(() {
        serialNumber = journalNumber;
        _currentJournalNumber = journalNumber;
      });
    } catch (e) {
      setState(() {
        serialNumber = '1';
        _currentJournalNumber = '1';
      });
    }
  }

  // دالة مساعدة لإخفاء جميع الاقتراحات
  void _clearAllSuggestions() {
    if (_materialSuggestions.isNotEmpty ||
        _packagingSuggestions.isNotEmpty ||
        _supplierSuggestions.isNotEmpty) {
      setState(() {
        _materialSuggestions = [];
        _packagingSuggestions = [];
        _supplierSuggestions = [];
        _activeMaterialRowIndex = null;
        _activePackagingRowIndex = null;
        _activeSupplierRowIndex = null;
      });
    }
  }

  void _toggleFullScreenSuggestions(
      {required String type, required bool show}) {
    if (mounted) {
      setState(() {
        _showFullScreenSuggestions = show;
        _currentSuggestionType = show ? type : '';
      });
    }
  }

  List<String> _getSuggestionsByType() {
    switch (_currentSuggestionType) {
      case 'material':
        return _materialSuggestions;
      case 'packaging':
        return _packagingSuggestions;
      case 'supplier':
        return _supplierSuggestions;

      default:
        return [];
    }
  }

  int _getCurrentRowIndexByType() {
    switch (_currentSuggestionType) {
      case 'material':
        return _activeMaterialRowIndex ?? -1;
      case 'packaging':
        return _activePackagingRowIndex ?? -1;
      case 'supplier':
        return _activeSupplierRowIndex ?? -1;

      default:
        return -1;
    }
  }

  Future<void> _shareFile() async {
    final filePath = await _storageService.getFilePath(widget.selectedDate);

    if (filePath == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('الرجاء حفظ اليومية أولاً'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    if (mounted) {
      CommonDialogs.showFilePathDialog(
        context: context,
        filePath: filePath,
      );
    }
  }

  Future<void> _checkAdminStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final adminSeller = prefs.getString('admin_seller');
    if (mounted) {
      setState(() {
        _isAdmin = (widget.sellerName == adminSeller);
      });
    }
  }

// أضف هذه الدالة الجديدة (بديل لـ _isRowOwnedByCurrentSeller)
  bool _canEditRow(int rowIndex) {
    if (rowIndex >= sellerNames.length) return false;
    // الأدمن يمكنه تعديل أي سجل
    if (_isAdmin) return true;
    // البائع العادي يمكنه تعديل سجلاته فقط
    return sellerNames[rowIndex] == widget.sellerName;
  }
}

class _StickyTableHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;

  _StickyTableHeaderDelegate({required this.child});

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return SizedBox.expand(child: child);
  }

  @override
  double get maxExtent => 32.0;

  @override
  double get minExtent => 32.0;

  @override
  bool shouldRebuild(_StickyTableHeaderDelegate oldDelegate) {
    return child != oldDelegate.child;
  }
}
