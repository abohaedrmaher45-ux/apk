import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/sales_model.dart';
import '../../services/sales_storage_service.dart';
// استيراد خدمات الفهرس
import '../../services/material_index_service.dart';
import '../../services/packaging_index_service.dart';
import '../../services/supplier_index_service.dart';
import '../../services/customer_index_service.dart';
import '../../services/enhanced_index_service.dart';

import '../../widgets/table_builder.dart' as TableBuilder;
import '../../widgets/table_components.dart' as TableComponents;
import '../../widgets/common_dialogs.dart' as CommonDialogs;

import 'package:flutter/foundation.dart';

import 'dart:async';
import '../../widgets/suggestions_banner.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SalesScreen extends StatefulWidget {
  final String sellerName;
  final String selectedDate;
  final String storeName;

  const SalesScreen({
    Key? key,
    required this.sellerName,
    required this.selectedDate,
    required this.storeName,
  }) : super(key: key);

  @override
  _SalesScreenState createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  // خدمة التخزين
  final SalesStorageService _storageService = SalesStorageService();

  // خدمات الفهرس
  final MaterialIndexService _materialIndexService = MaterialIndexService();
  final PackagingIndexService _packagingIndexService = PackagingIndexService();
  final SupplierIndexService _supplierIndexService = SupplierIndexService();
  final CustomerIndexService _customerIndexService = CustomerIndexService();
  // بيانات الحقول
  String dayName = '';

  // قائمة لتخزين صفوف الجدول
  List<List<TextEditingController>> rowControllers = [];
  List<List<FocusNode>> rowFocusNodes = [];
  List<String> cashOrDebtValues = [];
  List<String> emptiesValues = [];
  List<String> customerNames = [];
  List<String> sellerNames = []; // <-- تخزين اسم البائع لكل صف

  // متحكمات صف المجموع
  late TextEditingController totalCountController;
  late TextEditingController totalBaseController;
  late TextEditingController totalNetController;
  late TextEditingController totalGrandController;

  // قوائم الخيارات
  final List<String> cashOrDebtOptions = ['نقدي', 'دين'];
  final List<String> emptiesOptions = ['مع فوارغ', 'بدون فوارغ'];

  // متحكمات للتمرير
  final ScrollController _verticalScrollController = ScrollController();
  final ScrollController _horizontalScrollController = ScrollController();
  final _scrollController = ScrollController(); // للتمرير
  // حالة الحفظ
  bool _isSaving = false;
  bool _hasUnsavedChanges = false;

  // التواريخ المتاحة
  List<Map<String, String>> _availableRecords = [];
  bool _isLoadingRecords = false;

  String serialNumber = '';
  String? _recordCreator;

  // متغيرات للاقتراحات
  List<String> _materialSuggestions = [];
  List<String> _packagingSuggestions = [];
  List<String> _supplierSuggestions = [];
  List<String> _customerSuggestions = [];

  // مؤشرات الصفوف النشطة للاقتراحات
  int? _activeMaterialRowIndex;
  int? _activePackagingRowIndex;
  int? _activeSupplierRowIndex;
  int? _activeCustomerRowIndex;
// متغير لتتبع ما إذا كان يجب عرض الاقتراحات على كامل الشاشة
  bool _showFullScreenSuggestions = false;
  String _currentSuggestionType = '';

  late ScrollController _horizontalSuggestionsController;
  bool _isAdmin = false;
  @override
  void initState() {
    super.initState();

    dayName = _extractDayName(widget.selectedDate);

    totalCountController = TextEditingController();
    totalBaseController = TextEditingController();
    totalNetController = TextEditingController();
    totalGrandController = TextEditingController();

    _resetTotalValues();

    // تهيئة متحكم الاقتراحات الأفقية
    _horizontalSuggestionsController = ScrollController();

    // إخفاء الاقتراحات عند التمرير
    _verticalScrollController.addListener(() {
      _hideAllSuggestionsImmediately();
    });

    _horizontalScrollController.addListener(() {
      _hideAllSuggestionsImmediately();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadOrCreateRecord();
      _loadAvailableDates();
      _loadJournalNumber();
    });
  }

  @override
  void dispose() {
    // إزالة جميع مراجع الاقتراحات العمودية
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
    totalBaseController.dispose();
    totalNetController.dispose();
    totalGrandController.dispose();

    _verticalScrollController.dispose();
    _horizontalScrollController.dispose();
    _scrollController.dispose();

    // تحرير متحكم الاقتراحات الأفقية
    _horizontalSuggestionsController.dispose();

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

  // تحميل السجل إذا كان موجوداً، أو إنشاء جديد
  Future<void> _loadOrCreateRecord() async {
    final document =
        await _storageService.loadSalesDocument(widget.selectedDate);

    if (document != null && document.sales.isNotEmpty) {
      // تحميل اليومية الموجودة
      _loadDocument(document);
    } else {
      // إنشاء يومية جديدة
      _createNewRecord();
    }
  }

  void _resetTotalValues() {
    totalCountController.text = '0';
    totalBaseController.text = '0.00';
    totalNetController.text = '0.00';
    totalGrandController.text = '0.00';
  }

  void _createNewRecord() {
    setState(() {
      // لا نحدد الرقم هنا، بل سيتم تعيينه عند الحفظ لأول مرة
      // الدالة _loadJournalNumber ستهتم بعرض الرقم الصحيح في الواجهة
      serialNumber = '1'; // عرض رقم افتراضي مؤقتاً
      _recordCreator = widget.sellerName;
      rowControllers.clear();
      rowFocusNodes.clear();
      cashOrDebtValues.clear();
      emptiesValues.clear();
      customerNames.clear();
      sellerNames.clear();
      _resetTotalValues();
      _hasUnsavedChanges = false;
      _addNewRow();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (rowFocusNodes.isNotEmpty && rowFocusNodes[0].length > 1) {
        FocusScope.of(context).requestFocus(rowFocusNodes[0][1]);
      }
    });
  }

  // تعديل _addNewRow لتحسين المستمعات
  void _addNewRow() {
    setState(() {
      final newSerialNumber = (rowControllers.length + 1).toString();

      List<TextEditingController> newControllers =
          List.generate(12, (index) => TextEditingController());

      List<FocusNode> newFocusNodes = List.generate(12, (index) => FocusNode());

      newControllers[0].text = newSerialNumber;

      // إضافة مستمعات للتغيير باستخدام دالة مساعدة
      _addChangeListenersToControllers(newControllers, rowControllers.length);

      // تخزين اسم البائع للصف الجديد
      sellerNames.add(widget.sellerName);

      rowControllers.add(newControllers);
      rowFocusNodes.add(newFocusNodes);
      cashOrDebtValues.add('');
      emptiesValues.add('');
      customerNames.add('');
    });

    // تركيز الماوس على حقل المادة في السجل الجديد
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (rowFocusNodes.isNotEmpty) {
        final newRowIndex = rowFocusNodes.length - 1;
        FocusScope.of(context).requestFocus(rowFocusNodes[newRowIndex][1]);
      }
    });
  }

// دالة مساعدة لإضافة المستمعات - مثل purchases_screen
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
    controllers[5].addListener(() {
      _hasUnsavedChanges = true;
      _updatePackagingSuggestions(rowIndex);
    });

    // حقل اسم الزبون
    controllers[10].addListener(() {
      _hasUnsavedChanges = true;
      _updateCustomerSuggestions(rowIndex);
    });

    // الحقول الرقمية مع التحديث التلقائي
    controllers[4].addListener(() {
      _hasUnsavedChanges = true;
      _calculateRowValues(rowIndex);
      _calculateAllTotals();
    });

    controllers[6].addListener(() {
      _hasUnsavedChanges = true;
      _validateStandingAndNet(rowIndex);
      _calculateRowValues(rowIndex);
      _calculateAllTotals();
    });

    controllers[7].addListener(() {
      _hasUnsavedChanges = true;
      _validateStandingAndNet(rowIndex);
      _calculateRowValues(rowIndex);
      _calculateAllTotals();
    });

    controllers[8].addListener(() {
      _hasUnsavedChanges = true;
      _calculateRowValues(rowIndex);
      _calculateAllTotals();
    });
  }

  // تحديث اقتراحات المادة - مثل purchases_screen بالضبط
  void _updateMaterialSuggestions(int rowIndex) async {
    final query = rowControllers[rowIndex][1].text;
    if (query.length >= 1) {
      final suggestions =
          await getEnhancedSuggestions(_materialIndexService, query);
      if (mounted) {
        setState(() {
          _materialSuggestions = suggestions;
          _activeMaterialRowIndex = rowIndex;
          // عرض الاقتراحات تلقائياً عند وجودها
          if (suggestions.isNotEmpty) {
            _toggleFullScreenSuggestions(type: 'material', show: true);
          } else {
            _toggleFullScreenSuggestions(type: 'material', show: false);
          }
        });
      }
    } else {
      // إخفاء الاقتراحات إذا كان الحقل فارغاً
      if (mounted) {
        setState(() {
          _materialSuggestions = [];
          _activeMaterialRowIndex = null;
          _toggleFullScreenSuggestions(type: 'material', show: false);
        });
      }
    }
  }

  // تحديث اقتراحات العبوة - مثل purchases_screen بالضبط
  void _updatePackagingSuggestions(int rowIndex) async {
    final query = rowControllers[rowIndex][5].text;
    if (query.length >= 1) {
      final suggestions =
          await getEnhancedSuggestions(_packagingIndexService, query);
      if (mounted) {
        setState(() {
          _packagingSuggestions = suggestions;
          _activePackagingRowIndex = rowIndex;
          // عرض الاقتراحات تلقائياً عند وجودها
          if (suggestions.isNotEmpty) {
            _toggleFullScreenSuggestions(type: 'packaging', show: true);
          } else {
            _toggleFullScreenSuggestions(type: 'packaging', show: false);
          }
        });
      }
    } else {
      // إخفاء الاقتراحات إذا كان الحقل فارغاً
      if (mounted) {
        setState(() {
          _packagingSuggestions = [];
          _activePackagingRowIndex = null;
          _toggleFullScreenSuggestions(type: 'packaging', show: false);
        });
      }
    }
  }

  // تحديث اقتراحات الموردين (العائدية) - مثل purchases_screen بالضبط
  void _updateSupplierSuggestions(int rowIndex) async {
    final query = rowControllers[rowIndex][2].text;
    if (query.length >= 1) {
      final suggestions =
          await getEnhancedSuggestions(_supplierIndexService, query);
      if (mounted) {
        setState(() {
          _supplierSuggestions = suggestions;
          _activeSupplierRowIndex = rowIndex;
          // عرض الاقتراحات تلقائياً عند وجودها
          if (suggestions.isNotEmpty) {
            _toggleFullScreenSuggestions(type: 'supplier', show: true);
          } else {
            _toggleFullScreenSuggestions(type: 'supplier', show: false);
          }
        });
      }
    } else {
      // إخفاء الاقتراحات إذا كان الحقل فارغاً
      if (mounted) {
        setState(() {
          _supplierSuggestions = [];
          _activeSupplierRowIndex = null;
          _toggleFullScreenSuggestions(type: 'supplier', show: false);
        });
      }
    }
  }

  // 1. اختيار اقتراح للمادة
  void _selectMaterialSuggestion(String suggestion, int rowIndex) {
    // التأكد من أن الصف لا يزال موجوداً
    if (rowIndex >= rowControllers.length) return;

    // أولاً: إخفاء نافذة الاقتراحات
    _toggleFullScreenSuggestions(type: 'material', show: false);

    // ثانياً: تعيين النص في المتحكم مباشرة (لا حاجة لـ setState هنا)
    rowControllers[rowIndex][1].text = suggestion;

    // ثالثاً: تحديث حالة "التغييرات غير المحفوظة" (هنا نحتاج setState)
    setState(() {
      _hasUnsavedChanges = true;
    });

    // رابعاً: حفظ المادة في الفهرس
    if (suggestion.trim().length > 1) {
      _saveMaterialToIndex(suggestion);
    }

    // خامساً: نقل التركيز إلى الحقل التالي بعد تأخير بسيط للسماح للواجهة بالتحديث
    Future.delayed(const Duration(milliseconds: 50), () {
      if (mounted && rowIndex < rowFocusNodes.length) {
        FocusScope.of(context).requestFocus(rowFocusNodes[rowIndex][2]);
      }
    });
  }

// 2. اختيار اقتراح للعبوة
  void _selectPackagingSuggestion(String suggestion, int rowIndex) {
    // التأكد من أن الصف لا يزال موجوداً
    if (rowIndex >= rowControllers.length) return;

    // أولاً: إخفاء نافذة الاقتراحات
    _toggleFullScreenSuggestions(type: 'packaging', show: false);

    // ثانياً: تعيين النص في المتحكم مباشرة
    rowControllers[rowIndex][5].text = suggestion;

    // ثالثاً: تحديث حالة "التغييرات غير المحفوظة"
    setState(() {
      _hasUnsavedChanges = true;
    });

    // رابعاً: حفظ العبوة في الفهرس
    if (suggestion.trim().length > 1) {
      _savePackagingToIndex(suggestion);
    }

    // خامساً: نقل التركيز إلى الحقل التالي
    Future.delayed(const Duration(milliseconds: 50), () {
      if (mounted && rowIndex < rowFocusNodes.length) {
        FocusScope.of(context).requestFocus(rowFocusNodes[rowIndex][6]);
      }
    });
  }

// 3. اختيار اقتراح للمورد (العائدية)
  void _selectSupplierSuggestion(String suggestion, int rowIndex) {
    // التأكد من أن الصف لا يزال موجوداً
    if (rowIndex >= rowControllers.length) return;

    // أولاً: إخفاء نافذة الاقتراحات
    _toggleFullScreenSuggestions(type: 'supplier', show: false);

    // ثانياً: تعيين النص في المتحكم مباشرة
    rowControllers[rowIndex][2].text = suggestion;

    // ثالثاً: تحديث حالة "التغييرات غير المحفوظة"
    setState(() {
      _hasUnsavedChanges = true;
    });

    // رابعاً: حفظ المورد في الفهرس
    if (suggestion.trim().length > 1) {
      _saveSupplierToIndex(suggestion);
    }

    // خامساً: نقل التركيز إلى الحقل التالي
    Future.delayed(const Duration(milliseconds: 50), () {
      if (mounted && rowIndex < rowFocusNodes.length) {
        FocusScope.of(context).requestFocus(rowFocusNodes[rowIndex][3]);
      }
    });
  }

// 4. اختيار اقتراح للزبون
  void _selectCustomerSuggestion(String suggestion, int rowIndex) {
    // التأكد من أن الصف لا يزال موجوداً
    if (rowIndex >= rowControllers.length) return;

    // أولاً: إخفاء نافذة الاقتراحات
    _toggleFullScreenSuggestions(type: 'customer', show: false);

    // ثانياً: تعيين النص في المتحكم
    rowControllers[rowIndex][10].text = suggestion;

    // ثالثاً: تحديث حالة "التغييرات غير المحفوظة" والمتغير الخاص باسم الزبون
    setState(() {
      customerNames[rowIndex] = suggestion;
      _hasUnsavedChanges = true;
    });

    // رابعاً: حفظ الزبون في الفهرس
    if (suggestion.trim().length > 1) {
      _saveCustomerToIndex(suggestion);
    }

    // خامساً: فتح نافذة الفوارغ تلقائياً
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        _showEmptiesDialog(rowIndex);
      }
    });
  }

  // حفظ المادة في الفهرس
  void _saveMaterialToIndex(String material) {
    final trimmedMaterial = material.trim();
    if (trimmedMaterial.length > 1) {
      _materialIndexService.saveMaterial(trimmedMaterial);
    }
  }

  // حفظ العبوة في الفهرس
  void _savePackagingToIndex(String packaging) {
    final trimmedPackaging = packaging.trim();
    if (trimmedPackaging.length > 1) {
      _packagingIndexService.savePackaging(trimmedPackaging);
    }
  }

  // حفظ المورد في الفهرس
  void _saveSupplierToIndex(String supplier) {
    final trimmedSupplier = supplier.trim();
    if (trimmedSupplier.length > 1) {
      _supplierIndexService.saveSupplier(trimmedSupplier);
    }
  }

  // تعديل _validateStandingAndNet
  void _validateStandingAndNet(int rowIndex) {
    if (rowIndex >= rowControllers.length) return;

    final controllers = rowControllers[rowIndex];

    try {
      double standing = double.tryParse(controllers[6].text) ?? 0;
      double net = double.tryParse(controllers[7].text) ?? 0;

      if (standing < net) {
        controllers[7].text = standing.toStringAsFixed(2);
        _showInlineWarning(rowIndex, 'الصافي لا يمكن أن يكون أكبر من القائم');

        _calculateRowValues(rowIndex);
        _calculateAllTotals();
      } else if (standing == 0 && net > 0) {
        controllers[7].text = '0.00';
        _showInlineWarning(
            rowIndex, 'إذا كان القائم صفر، يجب أن يكون الصافي صفر');

        _calculateRowValues(rowIndex);
        _calculateAllTotals();
      }
    } catch (e) {
      // تجاهل الأخطاء في التحليل
    }
  }

  // تحسين _calculateRowValues
  void _calculateRowValues(int rowIndex) {
    if (rowIndex >= rowControllers.length) return;

    final controllers = rowControllers[rowIndex];

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          try {
            double count = (double.tryParse(controllers[4].text) ?? 0).abs();
            double net = (double.tryParse(controllers[7].text) ?? 0).abs();
            double price = (double.tryParse(controllers[8].text) ?? 0).abs();

            double baseValue = net > 0 ? net : count;
            double total = baseValue * price;
            controllers[9].text = total.toStringAsFixed(2);
          } catch (e) {
            controllers[9].text = '';
          }
        });
      }
    });
  }

  // تحسين _calculateAllTotals
  void _calculateAllTotals() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          double totalCount = 0;
          double totalBase = 0;
          double totalNet = 0;
          double totalGrand = 0;

          for (var controllers in rowControllers) {
            try {
              totalCount += double.tryParse(controllers[4].text) ?? 0;
              totalBase += double.tryParse(controllers[6].text) ?? 0;
              totalNet += double.tryParse(controllers[7].text) ?? 0;
              totalGrand += double.tryParse(controllers[9].text) ?? 0;
            } catch (e) {
              // تجاهل الأخطاء
            }
          }

          totalCountController.text = totalCount.toStringAsFixed(0);
          totalBaseController.text = totalBase.toStringAsFixed(2);
          totalNetController.text = totalNet.toStringAsFixed(2);
          totalGrandController.text = totalGrand.toStringAsFixed(2);
        });
      }
    });
  }

  void _loadDocument(SalesDocument document) {
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
      cashOrDebtValues.clear();
      emptiesValues.clear();
      customerNames.clear();
      sellerNames.clear();

      serialNumber = document.recordNumber;
      _recordCreator = document.sellerName;

      // تحميل السجلات من الوثيقة
      for (int i = 0; i < document.sales.length; i++) {
        var sale = document.sales[i];

        List<TextEditingController> newControllers = [
          TextEditingController(text: sale.serialNumber),
          TextEditingController(text: sale.material),
          TextEditingController(text: sale.affiliation),
          TextEditingController(text: sale.sValue),
          TextEditingController(text: sale.count),
          TextEditingController(text: sale.packaging),
          TextEditingController(text: sale.standing),
          TextEditingController(text: sale.net),
          TextEditingController(text: sale.price),
          TextEditingController(text: sale.total),
          TextEditingController(text: sale.customerName ?? ''),
          TextEditingController(),
        ];

        List<FocusNode> newFocusNodes =
            List.generate(12, (index) => FocusNode());

        // تخزين اسم البائع لهذا الصف
        sellerNames.add(sale.sellerName);

        // التحقق إذا كان السجل مملوكاً للبائع الحالي
        final bool isOwnedByCurrentSeller =
            sale.sellerName == widget.sellerName;

        // إضافة مستمعات للتغيير فقط إذا كان السجل مملوكاً للبائع الحالي
        if (isOwnedByCurrentSeller) {
          _addChangeListenersToControllers(newControllers, i);
        }

        rowControllers.add(newControllers);
        rowFocusNodes.add(newFocusNodes);
        cashOrDebtValues.add(sale.cashOrDebt);
        emptiesValues.add(sale.empties);
        customerNames.add(sale.customerName ?? '');
      }

      // تحميل المجاميع
      if (document.totals.isNotEmpty) {
        totalCountController.text = document.totals['totalCount'] ?? '0';
        totalBaseController.text = document.totals['totalBase'] ?? '0.00';
        totalNetController.text = document.totals['totalNet'] ?? '0.00';
        totalGrandController.text = document.totals['totalGrand'] ?? '0.00';
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
      columnWidths: {
        3: const FixedColumnWidth(30.0),
        10: const FlexColumnWidth(1.5),
      },
      border: TableBorder.all(color: Colors.grey, width: 0.5),
      children: [
        TableRow(
          decoration: BoxDecoration(color: Colors.grey[200]),
          children: [
            TableComponents.buildTableHeaderCell('مسلسل'),
            TableComponents.buildTableHeaderCell('المادة'),
            TableComponents.buildTableHeaderCell('العائدية'),
            TableComponents.buildTableHeaderCell('س'),
            TableComponents.buildTableHeaderCell('العدد'),
            TableComponents.buildTableHeaderCell('العبوة'),
            TableComponents.buildTableHeaderCell('القائم'),
            TableComponents.buildTableHeaderCell('الصافي'),
            TableComponents.buildTableHeaderCell('السعر'),
            TableComponents.buildTableHeaderCell('الإجمالي'),
            TableComponents.buildTableHeaderCell('نقدي او دين'),
            TableComponents.buildTableHeaderCell('الفوارغ'),
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
                isOwnedByCurrentSeller,
                isSField: true),
            _buildTableCell(rowControllers[i][4], rowFocusNodes[i][4], i, 4,
                isOwnedByCurrentSeller),
            _buildPackagingCell(rowControllers[i][5], rowFocusNodes[i][5], i, 5,
                isOwnedByCurrentSeller),
            _buildTableCell(rowControllers[i][6], rowFocusNodes[i][6], i, 6,
                isOwnedByCurrentSeller),
            _buildTableCell(rowControllers[i][7], rowFocusNodes[i][7], i, 7,
                isOwnedByCurrentSeller),
            _buildTableCell(rowControllers[i][8], rowFocusNodes[i][8], i, 8,
                isOwnedByCurrentSeller),
            TableComponents.buildTotalValueCell(rowControllers[i][9]),
            _buildCashOrDebtCell(i, 10, isOwnedByCurrentSeller),
            _buildEmptiesCell(i, 11, isOwnedByCurrentSeller),
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
            _buildEmptyCell(),
            TableComponents.buildTotalCell(totalCountController),
            _buildEmptyCell(),
            TableComponents.buildTotalCell(totalBaseController),
            TableComponents.buildTotalCell(totalNetController),
            _buildEmptyCell(),
            TableComponents.buildTotalCell(totalGrandController),
            _buildEmptyCell(),
            _buildEmptyCell(),
          ],
        ),
      );
    }

    return Table(
      defaultColumnWidth: const FlexColumnWidth(),
      columnWidths: {
        3: const FixedColumnWidth(30.0),
        10: const FlexColumnWidth(1.5),
      },
      border: TableBorder.all(color: Colors.grey, width: 0.5),
      children: contentRows,
    );
  }

  Widget _buildTableCell(TextEditingController controller, FocusNode focusNode,
      int rowIndex, int colIndex, bool isOwnedByCurrentSeller,
      {bool isSField = false}) {
    bool isSerialField = colIndex == 0;
    bool isNumericField =
        colIndex == 4 || colIndex == 6 || colIndex == 7 || colIndex == 8;

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
      isSField: isSField,
      inputFormatters: isSField
          ? [
              TableComponents.TwoDigitInputFormatter(),
              FilteringTextInputFormatter.digitsOnly,
            ]
          : (isNumericField
              ? [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*$')),
                  FilteringTextInputFormatter.deny(RegExp(r'\.\d{3,}')),
                ]
              : null),
      fontSize: isSField ? 11 : 13,
      textAlign: isSField ? TextAlign.center : TextAlign.right,
      textDirection: isSField ? TextDirection.ltr : TextDirection.rtl,
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
    } else if (colIndex == 5) {
      if (_packagingSuggestions.isNotEmpty) {
        _selectPackagingSuggestion(_packagingSuggestions[0], rowIndex);
        return;
      }
      if (value.trim().length > 1) _savePackagingToIndex(value);
      FocusScope.of(context).requestFocus(rowFocusNodes[rowIndex][6]);
    } else if (colIndex == 10) {
      // تم الإبقاء على منطق الزبون كما هو لأنه يعمل بشكل صحيح لديك
      if (cashOrDebtValues[rowIndex] == 'دين' &&
          _customerSuggestions.isNotEmpty) {
        _selectCustomerSuggestion(_customerSuggestions[0], rowIndex);
        return;
      }
      if (cashOrDebtValues[rowIndex] == 'دين') {
        if (value.trim().length > 1) _saveCustomerToIndex(value.trim());
        Future.delayed(const Duration(milliseconds: 50), () {
          if (mounted) _showEmptiesDialog(rowIndex);
        });
        return;
      }
      if (cashOrDebtValues[rowIndex] == 'نقدي') {
        Future.delayed(const Duration(milliseconds: 50), () {
          if (mounted) _showEmptiesDialog(rowIndex);
        });
        return;
      }
    } else if (colIndex == 0) {
      FocusScope.of(context).requestFocus(rowFocusNodes[rowIndex][1]);
    } else if (colIndex == 8) {
      _showCashOrDebtDialog(rowIndex);
    } else if (colIndex == 11) {
      _addNewRow();
      if (rowControllers.isNotEmpty) {
        final newRowIndex = rowControllers.length - 1;
        FocusScope.of(context).requestFocus(rowFocusNodes[newRowIndex][1]);
      }
    } else if (colIndex < 11) {
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
      } else if (colIndex == 5 && _activePackagingRowIndex != rowIndex) {
        _clearAllSuggestions();
      } else if (colIndex == 10 && _activeCustomerRowIndex != rowIndex) {
        _clearAllSuggestions();
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

  Widget _buildCashOrDebtCell(
      int rowIndex, int colIndex, bool isOwnedByCurrentSeller) {
    Widget cell = Stack(
      children: [
        TableBuilder.buildCashOrDebtCell(
          rowIndex: rowIndex,
          colIndex: colIndex,
          cashOrDebtValue: cashOrDebtValues[rowIndex],
          customerName: customerNames[rowIndex],
          customerController: rowControllers[rowIndex][10],
          focusNode: rowFocusNodes[rowIndex][colIndex],
          hasUnsavedChanges: _hasUnsavedChanges,
          setHasUnsavedChanges: (value) =>
              setState(() => _hasUnsavedChanges = value),
          onTap: () => _showCashOrDebtDialog(rowIndex),
          scrollToField: _scrollToField,
          onCustomerNameChanged: (value) {
            setState(() {
              customerNames[rowIndex] = value;
              _hasUnsavedChanges = true;
            });
            _updateCustomerSuggestions(rowIndex);
          },
          onCustomerSubmitted: (value, rIndex, cIndex) {
            _handleFieldSubmitted(value, rIndex, cIndex);
          },
          isSalesScreen: true,
        ),
      ],
    );
    if (!isOwnedByCurrentSeller) {
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
// بناء قائمة اقتراحات الزبائن بشكل أفقي - مثل purchases_screen بالضبط

  Widget _buildEmptiesCell(
      int rowIndex, int colIndex, bool isOwnedByCurrentSeller) {
    Widget cell = TableComponents.buildEmptiesCell(
      value: emptiesValues[rowIndex],
      onTap: () => _showEmptiesDialog(rowIndex),
      rowIndex: rowIndex,
      colIndex: colIndex,
      scrollToField: _scrollToField,
    );

    // إذا لم يكن السجل مملوكاً للبائع الحالي، جعل الخلية للقراءة فقط
    if (!isOwnedByCurrentSeller) {
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

  void _showCashOrDebtDialog(int rowIndex) {
    // التحقق إذا كان السجل مملوكاً للبائع الحالي
    if (!_canEditRow(rowIndex)) {
      return;
    }

    CommonDialogs.showCashOrDebtDialog(
      context: context,
      currentValue: cashOrDebtValues[rowIndex],
      options: cashOrDebtOptions,
      onSelected: (value) {
        setState(() {
          cashOrDebtValues[rowIndex] = value;
          _hasUnsavedChanges = true;

          if (value == 'نقدي') {
            customerNames[rowIndex] = '';
            // فتح نافذة الفوارغ بعد تأخير بسيط
            Future.delayed(const Duration(milliseconds: 100), () {
              if (mounted) {
                _showEmptiesDialog(rowIndex);
              }
            });
          } else if (value == 'دين') {
            // تفريغ اسم الزبون القديم إذا كان موجوداً
            customerNames[rowIndex] = '';
            rowControllers[rowIndex][10].text = '';
            // تركيز الماوس على حقل اسم الزبون بعد تأخير بسيط
            Future.delayed(const Duration(milliseconds: 100), () {
              if (mounted && rowIndex < rowFocusNodes.length) {
                FocusScope.of(context)
                    .requestFocus(rowFocusNodes[rowIndex][10]);
                // تحديث الاقتراحات
                _updateCustomerSuggestions(rowIndex);
              }
            });
          }
        });
      },
      onCancel: () {
        // إذا تم الإلغاء، نرجع التركيز لحقل السعر
        if (mounted && rowIndex < rowFocusNodes.length) {
          FocusScope.of(context).requestFocus(rowFocusNodes[rowIndex][8]);
        }
      },
    );
  }

  void _showEmptiesDialog(int rowIndex) {
    // التحقق إذا كان السجل مملوكاً للبائع الحالي
    if (!_isRowOwnedByCurrentSeller(rowIndex)) {
      return;
    }

    CommonDialogs.showEmptiesDialog(
      context: context,
      currentValue: emptiesValues[rowIndex],
      options: emptiesOptions,
      onSelected: (value) {
        setState(() {
          emptiesValues[rowIndex] = value;
          _hasUnsavedChanges = true;
        });
        // إضافة صف جديد بعد اختيار الفوارغ
        _addRowAfterEmptiesSelection(rowIndex);
      },
      onCancel: () {
        // إذا تم الإلغاء، نرجع التركيز لحقل اسم الزبون
        if (cashOrDebtValues[rowIndex] == 'دین') {
          Future.delayed(const Duration(milliseconds: 50), () {
            if (mounted && rowIndex < rowFocusNodes.length) {
              FocusScope.of(context).requestFocus(rowFocusNodes[rowIndex][10]);
            }
          });
        }
      },
    );
  }

  void _addRowAfterEmptiesSelection(int rowIndex) {
    _addNewRow();
    if (rowControllers.isNotEmpty) {
      final newRowIndex = rowControllers.length - 1;
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          // التركيز على حقل المادة في السجل الجديد
          FocusScope.of(context).requestFocus(rowFocusNodes[newRowIndex][1]);
          _scrollToField(newRowIndex, 1);
        }
      });
    }
  }

  // التحقق إذا كان السجل مملوكاً للبائع الحالي
  bool _isRowOwnedByCurrentSeller(int rowIndex) {
    if (rowIndex >= sellerNames.length) return false;
    return sellerNames[rowIndex] == widget.sellerName;
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
                  if (_currentSuggestionType == 'customer')
                    _selectCustomerSuggestion(val, idx);
                },
                onClose: () =>
                    _toggleFullScreenSuggestions(type: '', show: false),
              ),
            Expanded(
              child: Text(
                'يومية مبيعات رقم /$serialNumber/ تاريخ ${widget.selectedDate} البائع ${widget.sellerName}',
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                textAlign: TextAlign.right,
              ),
            ),
          ],
        ),
        centerTitle: false,
        backgroundColor: Colors.orange[700],
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
                : 'حفظ يومية المبيعات',
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
                    builder: (context) => SalesScreen(
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

              if (_isLoadingRecords) {
                items.add(
                  const PopupMenuItem<String>(
                    value: '',
                    enabled: false,
                    child: Center(child: Text('جاري التحميل...')),
                  ),
                );
              } else if (_availableRecords.isEmpty) {
                items.add(
                  const PopupMenuItem<String>(
                    value: '',
                    enabled: false,
                    child: Center(child: Text('لا توجد يوميات سابقة')),
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

                for (var record in _availableRecords) {
                  final date = record['date']!;
                  final journalNumber = record['journalNumber']!;

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
                              ? Colors.orange
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
      // التعديل هنا: إذا كان ارتفاع لوحة المفاتيح أكبر من 0، نعيد null لإخفاء الزر
      floatingActionButton: MediaQuery.of(context).viewInsets.bottom > 0
          ? null
          : Container(
              margin: const EdgeInsets.only(bottom: 16, right: 16),
              child: Material(
                color: Colors.orange[700],
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
      resizeToAvoidBottomInset: true,
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

  Future<void> _saveCurrentRecord({bool silent = false}) async {
    if (_isSaving) return;

    if (_recordCreator != null && _recordCreator != widget.sellerName) {
      if (!silent && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('هذا السجل ليس سجلك، لا يمكنك التعديل عليه'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    final currentSellerSales = <Sale>[];
    for (int i = 0; i < rowControllers.length; i++) {
      if (_isRowOwnedByCurrentSeller(i)) {
        final controllers = rowControllers[i];
        if (controllers[1].text.isNotEmpty ||
            controllers[4].text.isNotEmpty ||
            controllers[8].text.isNotEmpty) {
          currentSellerSales.add(Sale(
            serialNumber: controllers[0].text,
            material: controllers[1].text,
            affiliation: controllers[2].text,
            sValue: controllers[3].text,
            count: controllers[4].text,
            packaging: controllers[5].text,
            standing: controllers[6].text,
            net: controllers[7].text,
            price: controllers[8].text,
            total: controllers[9].text,
            cashOrDebt: cashOrDebtValues[i],
            empties: emptiesValues[i],
            customerName:
                cashOrDebtValues[i] == 'دين' ? customerNames[i] : null,
            sellerName: sellerNames[i],
          ));
        }
      }
    }

    if (currentSellerSales.isEmpty) {
      if (!silent && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('لا توجد سجلات مضافة للحفظ'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    bool hasInvalidNetValue = false;
    for (int i = 0; i < rowControllers.length; i++) {
      if (_isRowOwnedByCurrentSeller(i)) {
        final controllers = rowControllers[i];
        double standing = double.tryParse(controllers[6].text) ?? 0;
        double net = double.tryParse(controllers[7].text) ?? 0;
        if (standing < net || (standing == 0 && net > 0)) {
          hasInvalidNetValue = true;
          controllers[7].text =
              (standing < net) ? standing.toStringAsFixed(2) : '0.00';
          _calculateRowValues(i);
        }
      }
    }

    if (hasInvalidNetValue && !silent && mounted) {
      bool confirmed = await _showNetValueWarning();
      if (!confirmed) {
        setState(() => _isSaving = false);
        return;
      }
    }

    _calculateAllTotals();
    setState(() => _isSaving = true);

    SalesDocument? existingDocument =
        await _storageService.loadSalesDocument(widget.selectedDate);
    List<Sale> allSales = [];

    if (existingDocument != null) {
      allSales.addAll(existingDocument.sales
          .where((s) => s.sellerName != widget.sellerName));
    }
    allSales.addAll(currentSellerSales);
    allSales.sort((a, b) =>
        int.parse(a.serialNumber).compareTo(int.parse(b.serialNumber)));

    for (int i = 0; i < allSales.length; i++) {
      var oldSale = allSales[i];
      allSales[i] = Sale(
        serialNumber: (i + 1).toString(),
        material: oldSale.material,
        affiliation: oldSale.affiliation,
        sValue: oldSale.sValue,
        count: oldSale.count,
        packaging: oldSale.packaging,
        standing: oldSale.standing,
        net: oldSale.net,
        price: oldSale.price,
        total: oldSale.total,
        cashOrDebt: oldSale.cashOrDebt,
        empties: oldSale.empties,
        customerName: oldSale.customerName,
        sellerName: oldSale.sellerName,
      );
    }

    // --- الجزء الأهم: تحديد رقم اليومية الصحيح قبل الحفظ ---
    String journalNumberToSave = serialNumber;
    if (existingDocument == null) {
      // إذا كانت اليومية جديدة، احصل على الرقم التالي
      journalNumberToSave = await _storageService.getNextJournalNumber();
    } else {
      // إذا كانت موجودة، استخدم رقمها الحالي لضمان الثبات
      journalNumberToSave = existingDocument.recordNumber;
    }

    final document = SalesDocument(
      recordNumber: journalNumberToSave, // استخدام الرقم الصحيح
      date: widget.selectedDate,
      sellerName: widget.sellerName,
      storeName: widget.storeName,
      dayName: dayName,
      sales: allSales,
      totals: {
        'totalCount': totalCountController.text,
        'totalBase': totalBaseController.text,
        'totalNet': totalNetController.text,
        'totalGrand': totalGrandController.text,
      },
    );

    Map<String, double> balanceChanges = {};
    if (existingDocument != null) {
      for (var sale in existingDocument.sales) {
        if (sale.sellerName == widget.sellerName &&
            sale.cashOrDebt == 'دين' &&
            sale.customerName != null) {
          double amount = double.tryParse(sale.total) ?? 0;
          balanceChanges[sale.customerName!] =
              (balanceChanges[sale.customerName!] ?? 0) - amount;
        }
      }
    }
    for (var sale in currentSellerSales) {
      if (sale.cashOrDebt == 'دين' && sale.customerName != null) {
        double amount = double.tryParse(sale.total) ?? 0;
        balanceChanges[sale.customerName!] =
            (balanceChanges[sale.customerName!] ?? 0) + amount;
      }
    }

    final success = await _storageService.saveSalesDocument(document);

    if (success) {
      for (var entry in balanceChanges.entries) {
        if (entry.value != 0) {
          await _customerIndexService.updateCustomerBalance(
              entry.key, entry.value);
        }
      }
      setState(() {
        _hasUnsavedChanges = false;
        _recordCreator = widget.sellerName;
        serialNumber =
            journalNumberToSave; // تحديث الواجهة بالرقم الصحيح بعد الحفظ
      });
    }

    setState(() => _isSaving = false);

    if (!silent && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'تم حفظ يومية المبيعات بنجاح' : 'فشل الحفظ'),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  Future<void> _shareFile() async {
    final filePath = await _storageService.getFilePath(
      widget.selectedDate,
      serialNumber,
    );

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

  Future<bool> _showNetValueWarning() async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('تنبيه'),
            content: const Text(
              'تم تصحيح بعض القيم في حقل الصافي لأنها كانت أكبر من القائم.\n\nتذكر: يجب أن يكون القائم دائماً أكبر من أو يساوي الصافي.',
              textAlign: TextAlign.center,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('موافق'),
              ),
            ],
          ),
        ) ??
        false;
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

  void _showInlineWarning(int rowIndex, String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  // دالة مساعدة لإخفاء جميع الاقتراحات فوراً - مثل purchases_screen
  void _hideAllSuggestionsImmediately() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _materialSuggestions = [];
          _packagingSuggestions = [];
          _supplierSuggestions = [];
          _customerSuggestions = [];
          _activeMaterialRowIndex = null;
          _activePackagingRowIndex = null;
          _activeSupplierRowIndex = null;
          _activeCustomerRowIndex = null;
          _showFullScreenSuggestions = false;
          _currentSuggestionType = '';
        });
      }
    });
  }

// دالة مساعدة لإخفاء جميع الاقتراحات
  void _clearAllSuggestions() {
    if (_materialSuggestions.isNotEmpty ||
        _packagingSuggestions.isNotEmpty ||
        _supplierSuggestions.isNotEmpty ||
        _customerSuggestions.isNotEmpty) {
      if (mounted) {
        setState(() {
          _materialSuggestions = [];
          _packagingSuggestions = [];
          _supplierSuggestions = [];
          _customerSuggestions = [];
          _activeMaterialRowIndex = null;
          _activePackagingRowIndex = null;
          _activeSupplierRowIndex = null;
          _activeCustomerRowIndex = null;
        });
      }
    }
  }

  // دالة لتحميل التواريخ المتاحة (مشابهة للمشتريات)
  Future<void> _loadAvailableDates() async {
    if (_isLoadingRecords) return;

    setState(() {
      _isLoadingRecords = true;
    });

    try {
      // جلب التواريخ مع أرقام اليوميات
      final dates = await _storageService.getAvailableDatesWithNumbers();

      if (kDebugMode) {
        debugPrint('✅ تم تحميل ${dates.length} يومية مبيعات');
        for (var date in dates) {
          debugPrint(
              '   - تاريخ: ${date['date']}, رقم: ${date['journalNumber']}');
        }
      }

      setState(() {
        _availableRecords = dates;
        _isLoadingRecords = false;
      });
    } catch (e) {
      setState(() {
        _availableRecords = [];
        _isLoadingRecords = false;
      });

      if (kDebugMode) {
        debugPrint('❌ خطأ في تحميل اليوميات: $e');
      }
    }
  }

  // تحديث اقتراحات الزبائن - مثل purchases_screen بالضبط
  void _updateCustomerSuggestions(int rowIndex) async {
    final query = rowControllers[rowIndex][10].text;
    if (query.length >= 1 && cashOrDebtValues[rowIndex] == 'دين') {
      final suggestions =
          await getEnhancedSuggestions(_customerIndexService, query);
      if (mounted) {
        setState(() {
          _customerSuggestions = suggestions;
          _activeCustomerRowIndex = rowIndex;
          // عرض الاقتراحات تلقائياً عند وجودها
          if (suggestions.isNotEmpty) {
            _toggleFullScreenSuggestions(type: 'customer', show: true);
          } else {
            _toggleFullScreenSuggestions(type: 'customer', show: false);
          }
        });
      }
    } else {
      // إخفاء الاقتراحات إذا كان الحقل فارغاً أو ليس "دين"
      if (mounted) {
        setState(() {
          _customerSuggestions = [];
          _activeCustomerRowIndex = null;
          _toggleFullScreenSuggestions(type: 'customer', show: false);
        });
      }
    }
  }

  // حفظ الزبون في الفهرس
  void _saveCustomerToIndex(String customer) {
    final trimmedCustomer = customer.trim();
    if (trimmedCustomer.length > 1) {
      _customerIndexService.saveCustomer(trimmedCustomer);
    }
  }

  void _toggleFullScreenSuggestions(
      {required String type, required bool show}) {
    if (mounted) {
      setState(() {
        _showFullScreenSuggestions = show;
        if (show) {
          _currentSuggestionType = type;
        } else {
          _currentSuggestionType = '';
        }
      });
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
      case 'customer':
        return _activeCustomerRowIndex ?? -1;
      default:
        return -1;
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
      case 'customer':
        return _customerSuggestions;
      default:
        return [];
    }
  }

  Future<void> _loadJournalNumber() async {
    try {
      final journalNumber =
          await _storageService.getJournalNumberForDate(widget.selectedDate);
      if (mounted) {
        setState(() {
          serialNumber = journalNumber;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          serialNumber = '1'; // الرقم الافتراضي في حالة الخطأ
        });
      }
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
