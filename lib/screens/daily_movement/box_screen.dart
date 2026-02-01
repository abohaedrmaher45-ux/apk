import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import '../../models/box_model.dart';
import '../../services/box_storage_service.dart';
import '../../widgets/table_builder.dart' as TableBuilder;
import '../../widgets/table_components.dart' as TableComponents;
import '../../widgets/common_dialogs.dart' as CommonDialogs;
import '../../services/customer_index_service.dart';
import '../../services/supplier_index_service.dart';
import '../../services/enhanced_index_service.dart';
import '../../widgets/suggestions_banner.dart';
import '../../services/supplier_balance_tracker.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BoxScreen extends StatefulWidget {
  final String sellerName;
  final String selectedDate;
  final String storeName;

  const BoxScreen({
    Key? key,
    required this.sellerName,
    required this.selectedDate,
    required this.storeName,
  }) : super(key: key);

  @override
  _BoxScreenState createState() => _BoxScreenState();
}

class _BoxScreenState extends State<BoxScreen> {
  // خدمة التخزين
  final BoxStorageService _storageService = BoxStorageService();

  //  خدمة فهرس الزبائن
  final CustomerIndexService _customerIndexService = CustomerIndexService();
  // خدمة فهرس الموردين
  final SupplierIndexService _supplierIndexService = SupplierIndexService();

  List<String> _customerSuggestions = [];
  int? _activeCustomerRowIndex;
  final ScrollController _customerSuggestionsScrollController =
      ScrollController();

  // بيانات الحقول
  String dayName = '';

  // قائمة لتخزين صفوف الجدول
  List<List<TextEditingController>> rowControllers = [];
  List<List<FocusNode>> rowFocusNodes = [];
  List<String> accountTypeValues = [];
  List<String> sellerNames = []; // <-- تخزين اسم البائع لكل صف

  // متحكمات المجموع
  late TextEditingController totalReceivedController;
  late TextEditingController totalPaidController;

  // قوائم الخيارات
  final List<String> accountTypeOptions = ['زبون', 'مورد', 'مصروف'];

  // متحكمات للتمرير
  final ScrollController _verticalScrollController = ScrollController();
  final ScrollController _horizontalScrollController = ScrollController();
  final _scrollController = ScrollController();

  // حالة الحفظ
  bool _isSaving = false;
  bool _hasUnsavedChanges = false;

  // التواريخ المتاحة
  List<Map<String, String>> _availableDates = [];
  bool _isLoadingDates = false;

  String serialNumber = '';
  // ignore: unused_field
  String? _currentJournalNumber;

  List<String> _supplierSuggestions = [];

  int? _activeSupplierRowIndex;

  bool _showFullScreenSuggestions = false;
  String _currentSuggestionType = '';
  late ScrollController
      _horizontalSuggestionsController; // في initState قم بتعريفه: _horizontalSuggestionsController = ScrollController();

  // ============ تحديث أرصدة الموردين والزبائن ============
  Map<String, double> customerBalanceChanges = {};
  Map<String, double> supplierBalanceChanges = {};
  final SupplierBalanceTracker _balanceTracker = SupplierBalanceTracker();
  // متغير لتأخير حساب المجاميع (debouncing)
  Timer? _calculateTotalsDebouncer;
  bool _isCalculating = false;
  bool _isAdmin = false;
  @override
  void initState() {
    super.initState();
    dayName = _extractDayName(widget.selectedDate);

    totalReceivedController = TextEditingController();
    totalPaidController = TextEditingController();
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
    totalReceivedController.dispose();
    totalPaidController.dispose();
    _verticalScrollController.dispose();
    _horizontalScrollController.dispose();
    _scrollController.dispose();
    _customerSuggestionsScrollController.dispose();

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
        await _storageService.loadBoxDocumentForDate(widget.selectedDate);

    if (document != null && document.transactions.isNotEmpty) {
      // تحميل اليومية الموجودة
      _loadJournal(document);
    } else {
      // إنشاء يومية جديدة
      _createNewJournal();
    }
  }

  void _resetTotalValues() {
    totalReceivedController.text = '0.00';
    totalPaidController.text = '0.00';
  }

  void _createNewJournal() {
    setState(() {
      rowControllers.clear();
      rowFocusNodes.clear();
      accountTypeValues.clear();
      sellerNames.clear();
      _resetTotalValues();
      _hasUnsavedChanges = false;
      _addNewRow();
    });
  }

  void _addNewRow() {
    setState(() {
      final newSerialNumber = (rowControllers.length + 1).toString();

      List<TextEditingController> newControllers =
          List.generate(5, (index) => TextEditingController());

      List<FocusNode> newFocusNodes = List.generate(5, (index) => FocusNode());

      newControllers[0].text = newSerialNumber;

      // إضافة مستمع FocusNode لحقل اسم الحساب
      newFocusNodes[3].addListener(() {
        if (!newFocusNodes[3].hasFocus) {
          // إخفاء الاقتراحات عند فقدان التركيز
          Future.delayed(const Duration(milliseconds: 100), () {
            if (mounted) {
              setState(() {
                _supplierSuggestions = [];
                _activeSupplierRowIndex = null;
                _customerSuggestions = [];
                _activeCustomerRowIndex = null;
              });
            }
          });
        }
      });

      // إضافة مستمعات للتغيير
      _addChangeListenersToControllers(newControllers, rowControllers.length);

      // تخزين اسم البائع للصف الجديد
      sellerNames.add(widget.sellerName);

      rowControllers.add(newControllers);
      rowFocusNodes.add(newFocusNodes);
      accountTypeValues.add('');
    });

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
          _customerSuggestions = [];
          _supplierSuggestions = [];
          _activeCustomerRowIndex = null;
          _activeSupplierRowIndex = null;
        });
      }
    });
  }

  // دالة مساعدة لإضافة المستمعات
  void _addChangeListenersToControllers(
      List<TextEditingController> controllers, int rowIndex) {
    // حقل المقبوض
    controllers[1].addListener(() {
      _hasUnsavedChanges = true;
      if (controllers[1].text.isNotEmpty) {
        controllers[2].text = '';
      }
      _calculateAllTotals();
    });

    // حقل المدفوع
    controllers[2].addListener(() {
      _hasUnsavedChanges = true;
      if (controllers[2].text.isNotEmpty) {
        controllers[1].text = '';
      }
      _calculateAllTotals();
    });

    // حقل اسم الحساب (الحقل رقم 3)
    controllers[3].addListener(() {
      _hasUnsavedChanges = true;

      // فقط تحديث الاقتراحات بناءً على نوع الحساب
      if (accountTypeValues[rowIndex] == 'زبون') {
        _updateCustomerSuggestions(rowIndex);
      } else if (accountTypeValues[rowIndex] == 'مورد') {
        _updateSupplierSuggestions(rowIndex);
      } else {
        // إذا كان نوع الحساب "مصروف" أو أي شيء آخر
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              _customerSuggestions = [];
              _supplierSuggestions = [];
              _activeCustomerRowIndex = null;
              _activeSupplierRowIndex = null;
            });
          }
        });
      }
    });

    // حقل الملاحظات
    controllers[4].addListener(() => _hasUnsavedChanges = true);

    // إضافة مستمع FocusNode لحقل اسم الحساب (الحقل 3) فقط لإخفاء الاقتراحات عند فقدان التركيز
    if (rowIndex < rowFocusNodes.length && rowFocusNodes[rowIndex].length > 3) {
      rowFocusNodes[rowIndex][3].addListener(() {
        if (!rowFocusNodes[rowIndex][3].hasFocus) {
          // إخفاء الاقتراحات بعد تأخير بسيط
          Future.delayed(const Duration(milliseconds: 100), () {
            if (mounted) {
              setState(() {
                // إخفاء الاقتراحات فقط
                _customerSuggestions = [];
                _supplierSuggestions = [];
                _activeCustomerRowIndex = null;
                _activeSupplierRowIndex = null;
              });
            }
          });
        }
      });
    }
  }

  void _calculateAllTotals() {
    // إلغاء أي حساب سابق منتظر
    _calculateTotalsDebouncer?.cancel();

    // تأخير الحساب لتجنب التكرار المتعدد
    _calculateTotalsDebouncer = Timer(const Duration(milliseconds: 50), () {
      if (!mounted || _isCalculating) return;

      _isCalculating = true;

      double totalReceived = 0;
      double totalPaid = 0;

      for (var controllers in rowControllers) {
        try {
          totalReceived += double.tryParse(controllers[1].text) ?? 0;
          totalPaid += double.tryParse(controllers[2].text) ?? 0;
        } catch (e) {}
      }

      if (mounted) {
        setState(() {
          totalReceivedController.text = totalReceived.toStringAsFixed(2);
          totalPaidController.text = totalPaid.toStringAsFixed(2);
        });
      }

      _isCalculating = false;
    });
  }

  // تعديل _loadJournal لاستخدام الدالة المساعدة
  void _loadJournal(BoxDocument document) {
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
      accountTypeValues.clear();
      sellerNames.clear();

      // تحميل السجلات من الوثيقة
      for (int i = 0; i < document.transactions.length; i++) {
        var transaction = document.transactions[i];

        List<TextEditingController> newControllers = [
          TextEditingController(text: transaction.serialNumber),
          TextEditingController(text: transaction.received),
          TextEditingController(text: transaction.paid),
          TextEditingController(text: transaction.accountName),
          TextEditingController(text: transaction.notes),
        ];

        List<FocusNode> newFocusNodes =
            List.generate(5, (index) => FocusNode());

        // تخزين اسم البائع لهذا الصف
        sellerNames.add(transaction.sellerName);

        // التحقق إذا كان السجل مملوكاً للبائع الحالي
        final bool isOwnedByCurrentSeller =
            transaction.sellerName == widget.sellerName;

        // إضافة مستمعات للتغيير فقط إذا كان السجل مملوكاً للبائع الحالي
        if (isOwnedByCurrentSeller) {
          _addChangeListenersToControllers(newControllers, i);
        }

        rowControllers.add(newControllers);
        rowFocusNodes.add(newFocusNodes);
        accountTypeValues.add(transaction.accountType);
      }

      // تحميل المجاميع
      if (document.totals.isNotEmpty) {
        totalReceivedController.text =
            document.totals['totalReceived'] ?? '0.00';
        totalPaidController.text = document.totals['totalPaid'] ?? '0.00';
      }

      _hasUnsavedChanges = false;
    });
  }

  void _scrollToField(int rowIndex, int colIndex) {
    const double headerHeight = 32.0;
    const double rowHeight = 25.0;
    final double verticalPosition = (rowIndex * rowHeight);
    const double columnWidth = 80.0;
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
      columnWidths: {
        0: FlexColumnWidth(0.09),
        1: FlexColumnWidth(0.18),
        2: FlexColumnWidth(0.18),
        3: FlexColumnWidth(0.37),
        4: FlexColumnWidth(0.18),
      },
      border: TableBorder.all(color: Colors.grey, width: 0.5),
      children: [
        TableRow(
          decoration: BoxDecoration(color: Colors.grey[200]),
          children: [
            TableComponents.buildTableHeaderCell('مسلسل'),
            TableComponents.buildTableHeaderCell('مقبوض'),
            TableComponents.buildTableHeaderCell('مدفوع'),
            TableComponents.buildTableHeaderCell('الحساب'),
            TableComponents.buildTableHeaderCell('ملاحظات'),
          ],
        ),
      ],
    );
  }

  Widget _buildTableContent() {
    List<TableRow> contentRows = [];

    for (int i = 0; i < rowControllers.length; i++) {
      final bool isOwnedByCurrentSeller = sellerNames[i] == widget.sellerName;

      contentRows.add(
        TableRow(
          children: [
            _buildTableCell(rowControllers[i][0], rowFocusNodes[i][0], i, 0,
                isOwnedByCurrentSeller),
            _buildReceivedCell(rowControllers[i][1], rowFocusNodes[i][1], i, 1,
                isOwnedByCurrentSeller),
            _buildPaidCell(rowControllers[i][2], rowFocusNodes[i][2], i, 2,
                isOwnedByCurrentSeller),
            _buildAccountCell(i, 3, isOwnedByCurrentSeller),
            _buildNotesCell(rowControllers[i][4], rowFocusNodes[i][4], i, 4,
                isOwnedByCurrentSeller),
          ],
        ),
      );
    }

    if (rowControllers.length >= 1) {
      contentRows.add(
        TableRow(
          decoration: BoxDecoration(color: Colors.yellow[50]),
          children: [
            _buildEmptyCell(),
            TableComponents.buildTotalCell(totalReceivedController),
            TableComponents.buildTotalCell(totalPaidController),
            _buildEmptyCell(),
            _buildEmptyCell(),
          ],
        ),
      );
    }

    return Table(
      columnWidths: {
        0: FlexColumnWidth(0.09),
        1: FlexColumnWidth(0.18),
        2: FlexColumnWidth(0.18),
        3: FlexColumnWidth(0.37),
        4: FlexColumnWidth(0.18),
      },
      border: TableBorder.all(color: Colors.grey, width: 0.5),
      children: contentRows,
    );
  }

  Widget _buildTableCell(TextEditingController controller, FocusNode focusNode,
      int rowIndex, int colIndex, bool isOwnedByCurrentSeller) {
    bool isSerialField = colIndex == 0;

    Widget cell = TableBuilder.buildTableCell(
      controller: controller,
      focusNode: focusNode,
      isSerialField: isSerialField,
      isNumericField: false,
      rowIndex: rowIndex,
      colIndex: colIndex,
      scrollToField: _scrollToField,
      onFieldSubmitted: (value, rIndex, cIndex) =>
          _handleFieldSubmitted(value, rIndex, cIndex),
      onFieldChanged: (value, rIndex, cIndex) =>
          _handleFieldChanged(value, rIndex, cIndex),
      inputFormatters: null,
    );

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

  Widget _buildReceivedCell(
      TextEditingController controller,
      FocusNode focusNode,
      int rowIndex,
      int colIndex,
      bool isOwnedByCurrentSeller) {
    Widget cell = Container(
      padding: const EdgeInsets.all(1),
      constraints: const BoxConstraints(minHeight: 25),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        enabled:
            isOwnedByCurrentSeller && rowControllers[rowIndex][2].text.isEmpty,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Colors.black,
        ),
        decoration: InputDecoration(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
          border: InputBorder.none,
          hintText: '0.00',
        ),
        inputFormatters: [
          TableComponents.PositiveDecimalInputFormatter(),
          FilteringTextInputFormatter.deny(RegExp(r'\.\d{3,}')),
        ],
        onSubmitted: (value) {
          if (value.isNotEmpty) {
            _showAccountTypeDialog(rowIndex);
          } else {
            FocusScope.of(context).requestFocus(rowFocusNodes[rowIndex][2]);
          }
        },
        onChanged: (value) {
          _hasUnsavedChanges = true;
          if (value.isNotEmpty && mounted) {
            setState(() {
              rowControllers[rowIndex][2].text = '';
            });
          }
          _calculateAllTotals();
        },
      ),
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

  Widget _buildPaidCell(TextEditingController controller, FocusNode focusNode,
      int rowIndex, int colIndex, bool isOwnedByCurrentSeller) {
    Widget cell = Container(
      padding: const EdgeInsets.all(1),
      constraints: const BoxConstraints(minHeight: 25),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        enabled:
            isOwnedByCurrentSeller && rowControllers[rowIndex][1].text.isEmpty,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Colors.black,
        ),
        decoration: InputDecoration(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
          border: InputBorder.none,
          hintText: '0.00',
        ),
        inputFormatters: [
          TableComponents.PositiveDecimalInputFormatter(),
          FilteringTextInputFormatter.deny(RegExp(r'\.\d{3,}')),
        ],
        onSubmitted: (value) {
          _showAccountTypeDialog(rowIndex);
        },
        onChanged: (value) {
          _hasUnsavedChanges = true;
          if (value.isNotEmpty && mounted) {
            setState(() {
              rowControllers[rowIndex][1].text = '';
            });
          }
          _calculateAllTotals();
        },
      ),
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

  // تحديث خلية الحساب لدعم كلا النوعين
  Widget _buildAccountCell(
      int rowIndex, int colIndex, bool isOwnedByCurrentSeller) {
    final String accountType = accountTypeValues[rowIndex];
    final TextEditingController accountNameController =
        rowControllers[rowIndex][3];
    final FocusNode accountNameFocusNode = rowFocusNodes[rowIndex][3];

    if (accountType.isNotEmpty) {
      Widget cell = Container(
        padding: const EdgeInsets.all(1),
        constraints: const BoxConstraints(minHeight: 25),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: InkWell(
                onTap: isOwnedByCurrentSeller
                    ? () => _showAccountTypeDialog(rowIndex)
                    : null,
                child: Container(
                  decoration: BoxDecoration(
                      border: Border.all(
                          color: _getAccountTypeColor(accountType), width: 0.5),
                      borderRadius: BorderRadius.circular(2)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Center(
                      child: Text(accountType,
                          style: TextStyle(
                              fontSize: 10,
                              color: _getAccountTypeColor(accountType),
                              fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis)),
                ),
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              flex: 5,
              child: TextField(
                controller: accountNameController,
                focusNode: accountNameFocusNode,
                textAlign: TextAlign.right,
                enabled: isOwnedByCurrentSeller,
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.black),
                decoration: InputDecoration(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
                  border: const OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.grey, width: 0.5)),
                  hintText: _getAccountHintText(accountType),
                  hintStyle: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
                onSubmitted: (value) =>
                    _handleFieldSubmitted(value, rowIndex, colIndex),
                onChanged: (value) {
                  if (isOwnedByCurrentSeller) {
                    _hasUnsavedChanges = true;
                    if (accountType == 'زبون')
                      _updateCustomerSuggestions(rowIndex);
                    else if (accountType == 'مورد')
                      _updateSupplierSuggestions(rowIndex);
                  }
                },
              ),
            ),
          ],
        ),
      );
      return isOwnedByCurrentSeller
          ? cell
          : IgnorePointer(
              child: Opacity(
                  opacity: 0.7,
                  child: Container(
                      decoration: BoxDecoration(color: Colors.grey[100]),
                      child: cell)));
    }

    // زر "اختر" في حال كان النوع فارغاً
    return InkWell(
      onTap: isOwnedByCurrentSeller
          ? () => _showAccountTypeDialog(rowIndex)
          : null,
      child: Container(
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(3)),
        child:
            const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text('اختر', style: TextStyle(fontSize: 11)),
          Icon(Icons.arrow_drop_down, size: 16)
        ]),
      ),
    );
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

  Widget _buildNotesCell(TextEditingController controller, FocusNode focusNode,
      int rowIndex, int colIndex, bool isOwnedByCurrentSeller) {
    Widget cell = Container(
      padding: const EdgeInsets.all(1),
      constraints: const BoxConstraints(minHeight: 25),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        textAlign: TextAlign.center,
        enabled: isOwnedByCurrentSeller,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Colors.black,
        ),
        decoration: InputDecoration(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
          border: InputBorder.none,
          hintText: '...',
        ),
        onSubmitted: (value) {
          if (isOwnedByCurrentSeller) {
            _addNewRow();
            if (rowControllers.isNotEmpty) {
              final newRowIndex = rowControllers.length - 1;
              FocusScope.of(context)
                  .requestFocus(rowFocusNodes[newRowIndex][1]);
            }
          }
        },
        onChanged: (value) {
          if (isOwnedByCurrentSeller) {
            _hasUnsavedChanges = true;
          }
        },
      ),
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

  Color _getAccountTypeColor(String accountType) {
    switch (accountType) {
      case 'زبون':
        return Colors.green;
      case 'مورد':
        return Colors.blue;
      case 'مصروف':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _getAccountHintText(String accountType) {
    switch (accountType) {
      case 'زبون':
        return 'اسم الزبون';
      case 'مورد':
        return 'اسم المورد';
      case 'مصروف':
        return 'نوع المصروف';
      default:
        return '...';
    }
  }

  void _handleFieldSubmitted(String value, int rowIndex, int colIndex) {
    if (!_canEditRow(rowIndex)) {
      return;
    }

    if (colIndex == 0) {
      FocusScope.of(context).requestFocus(rowFocusNodes[rowIndex][1]);
    } else if (colIndex == 1) {
      if (value.isNotEmpty) {
        _showAccountTypeDialog(rowIndex);
      } else {
        FocusScope.of(context).requestFocus(rowFocusNodes[rowIndex][2]);
      }
    } else if (colIndex == 2) {
      _showAccountTypeDialog(rowIndex);
    } else if (colIndex == 3) {
      // إذا كان نوع الحساب زبون وكانت هناك اقتراحات
      if (accountTypeValues[rowIndex] == 'زبون' &&
          _customerSuggestions.isNotEmpty) {
        _selectCustomerSuggestion(_customerSuggestions[0], rowIndex);
        return;
      }

      // إذا كان نوع الحساب مورد وكانت هناك اقتراحات
      if (accountTypeValues[rowIndex] == 'مورد' &&
          _supplierSuggestions.isNotEmpty) {
        _selectSupplierSuggestion(_supplierSuggestions[0], rowIndex);
        return;
      }

      if (value.trim().isNotEmpty && value.trim().length > 1) {
        if (accountTypeValues[rowIndex] == 'زبون') {
          _saveCustomerToIndex(value);
        } else if (accountTypeValues[rowIndex] == 'مورد') {
          _saveSupplierToIndex(value);
        }
      }

      FocusScope.of(context).requestFocus(rowFocusNodes[rowIndex][4]);
    } else if (colIndex == 4) {
      _addNewRow();
      if (rowControllers.isNotEmpty) {
        final newRowIndex = rowControllers.length - 1;
        FocusScope.of(context).requestFocus(rowFocusNodes[newRowIndex][1]);
      }
    }
  }

  void _handleFieldChanged(String value, int rowIndex, int colIndex) {
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

      if (colIndex == 1 && value.isNotEmpty) {
        rowControllers[rowIndex][2].text = '';
        _calculateAllTotals();
      } else if (colIndex == 2 && value.isNotEmpty) {
        rowControllers[rowIndex][1].text = '';
        _calculateAllTotals();
      }
    });
  }

  void _showAccountTypeDialog(int rowIndex) {
    if (!_isRowOwnedByCurrentSeller(rowIndex)) {
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text(
            'اختر نوع الحساب',
            style: TextStyle(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 8.0,
              runSpacing: 8.0,
              children: accountTypeOptions.map((option) {
                return ChoiceChip(
                  label: Text(option),
                  selected: option == accountTypeValues[rowIndex],
                  selectedColor: _getAccountTypeColor(option),
                  backgroundColor: Colors.grey[200],
                  onSelected: (bool selected) {
                    if (selected) {
                      Navigator.pop(context);
                      _onAccountTypeSelected(option, rowIndex);
                    }
                  },
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _onAccountTypeCancelled(rowIndex);
              },
              child: const Text('إلغاء'),
            ),
          ],
        );
      },
    );
  }

  void _onAccountTypeSelected(String value, int rowIndex) {
    setState(() {
      accountTypeValues[rowIndex] = value;
      _hasUnsavedChanges = true;

      // إخفاء الاقتراحات عند تغيير نوع الحساب
      _customerSuggestions = [];
      _supplierSuggestions = [];
      _activeCustomerRowIndex = null;
      _activeSupplierRowIndex = null;

      if (value.isNotEmpty) {
        Future.delayed(const Duration(milliseconds: 150), () {
          if (mounted) {
            FocusScope.of(context).requestFocus(rowFocusNodes[rowIndex][3]);
            _scrollToField(rowIndex, 3);
          }
        });
      }
    });
  }

  void _onAccountTypeCancelled(int rowIndex) {
    if (rowControllers[rowIndex][1].text.isNotEmpty) {
      FocusScope.of(context).requestFocus(rowFocusNodes[rowIndex][1]);
    } else if (rowControllers[rowIndex][2].text.isNotEmpty) {
      FocusScope.of(context).requestFocus(rowFocusNodes[rowIndex][2]);
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
                  if (_currentSuggestionType == 'customer')
                    _selectCustomerSuggestion(val, idx);
                  if (_currentSuggestionType == 'supplier')
                    _selectSupplierSuggestion(val, idx);
                },
                onClose: () =>
                    _toggleFullScreenSuggestions(type: '', show: false),
              ),
            Expanded(
              child: Text(
                'يومية صندوق رقم /$serialNumber/ تاريخ ${widget.selectedDate} البائع ${widget.sellerName}',
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
                    builder: (context) => BoxScreen(
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

  Future<void> _saveCurrentRecord({bool silent = false}) async {
    if (_isSaving) return;

    if (rowControllers.isEmpty) {
      if (!silent && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('لا توجد بيانات للحفظ'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    final currentSellerTransactions = <BoxTransaction>[];
    for (int i = 0; i < rowControllers.length; i++) {
      final controllers = rowControllers[i];

      if (controllers[1].text.isNotEmpty ||
          controllers[2].text.isNotEmpty ||
          (controllers[3].text.isNotEmpty && accountTypeValues[i].isNotEmpty)) {
        currentSellerTransactions.add(BoxTransaction(
          serialNumber: controllers[0].text,
          received: controllers[1].text,
          paid: controllers[2].text,
          accountType: accountTypeValues[i],
          accountName: controllers[3].text,
          notes: controllers[4].text,
          sellerName: sellerNames[i],
        ));
      }
    }

    if (currentSellerTransactions.isEmpty) {
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

    setState(() => _isSaving = true);

    String journalNumber = serialNumber;
    if (journalNumber.isEmpty || journalNumber == '1') {
      final document =
          await _storageService.loadBoxDocumentForDate(widget.selectedDate);
      if (document == null) {
        journalNumber = await _storageService.getNextJournalNumber();
      } else {
        journalNumber = document.recordNumber;
      }
    }

    final document = BoxDocument(
      recordNumber: journalNumber,
      date: widget.selectedDate,
      sellerName: widget.sellerName,
      storeName: widget.storeName,
      dayName: dayName,
      transactions: currentSellerTransactions,
      totals: {
        'totalReceived': totalReceivedController.text,
        'totalPaid': totalPaidController.text,
      },
    );

    // ============ تحديث أرصدة الموردين والزبائن ============
    Map<String, double> customerBalanceChanges = {};
    Map<String, double> supplierBalanceChanges = {};

    // 1. طرح القيم القديمة (إذا كان السجل موجوداً)
    final existingDocument =
        await _storageService.loadBoxDocumentForDate(widget.selectedDate);
    if (existingDocument != null) {
      for (var trans in existingDocument.transactions) {
        if (trans.sellerName == widget.sellerName) {
          double receivedAmount = double.tryParse(trans.received) ?? 0;
          double paidAmount = double.tryParse(trans.paid) ?? 0;

          if (trans.accountType == 'زبون' && trans.accountName.isNotEmpty) {
            // للزبون: المدفوع يزيد رصيده والمقبوض ينقص رصيده
            double netChange = paidAmount - receivedAmount;
            customerBalanceChanges[trans.accountName] =
                (customerBalanceChanges[trans.accountName] ?? 0) - netChange;
          } else if (trans.accountType == 'مورد' &&
              trans.accountName.isNotEmpty) {
            // للمورد: المقبوض يزيد رصيده والمدفوع ينقص رصيده
            double netChange = receivedAmount - paidAmount;
            supplierBalanceChanges[trans.accountName] =
                (supplierBalanceChanges[trans.accountName] ?? 0) - netChange;
          }
        }
      }
    }

    // 2. إضافة القيم الجديدة
    for (var trans in currentSellerTransactions) {
      double receivedAmount = double.tryParse(trans.received) ?? 0;
      double paidAmount = double.tryParse(trans.paid) ?? 0;

      if (trans.accountType == 'زبون' && trans.accountName.isNotEmpty) {
        // للزبون: المدفوع يزيد رصيده والمقبوض ينقص رصيده
        double netChange = paidAmount - receivedAmount;
        customerBalanceChanges[trans.accountName] =
            (customerBalanceChanges[trans.accountName] ?? 0) + netChange;
      } else if (trans.accountType == 'مورد' && trans.accountName.isNotEmpty) {
        // للمورد: المقبوض يزيد رصيده والمدفوع ينقص رصيده
        double netChange = receivedAmount - paidAmount;
        supplierBalanceChanges[trans.accountName] =
            (supplierBalanceChanges[trans.accountName] ?? 0) + netChange;
      }
    }

    final success = await _storageService.saveBoxDocument(document);

    if (success) {
      // تحديث أرصدة الزبائن في الفهرس
      for (var entry in customerBalanceChanges.entries) {
        if (entry.value != 0) {
          await _customerIndexService.updateCustomerBalance(
              entry.key, entry.value);
          print('👤 تحديث زبون ${entry.key}: ${entry.value}');
        }
      }

      // تحديث أرصدة الموردين في الفهرس
      for (var entry in supplierBalanceChanges.entries) {
        if (entry.value != 0) {
          await _supplierIndexService.updateSupplierBalance(
              entry.key, entry.value);
          print('🏭 تحديث مورد ${entry.key}: ${entry.value}');
        }
      }

      setState(() {
        _hasUnsavedChanges = false;
        serialNumber = journalNumber;
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

  // تحديث اقتراحات الزبائن
  void _updateCustomerSuggestions(int rowIndex) async {
    final query = rowControllers[rowIndex][3].text;
    if (query.length >= 1 && accountTypeValues[rowIndex] == 'زبون') {
      final suggestions =
          await getEnhancedSuggestions(_customerIndexService, query);
      setState(() {
        _customerSuggestions = suggestions;
        _activeCustomerRowIndex = rowIndex;
        _toggleFullScreenSuggestions(
            type: 'customer', show: suggestions.isNotEmpty);
      });
    } else {
      setState(() {
        _customerSuggestions = [];
        _activeCustomerRowIndex = null;
      });
    }
  }

// تحديث اقتراحات الموردين
  void _updateSupplierSuggestions(int rowIndex) async {
    final query = rowControllers[rowIndex][3].text;
    if (query.length >= 1 && accountTypeValues[rowIndex] == 'مورد') {
      final suggestions =
          await getEnhancedSuggestions(_supplierIndexService, query);
      setState(() {
        _supplierSuggestions = suggestions;
        _activeSupplierRowIndex = rowIndex;
        _toggleFullScreenSuggestions(
            type: 'supplier', show: suggestions.isNotEmpty);
      });
    } else {
      // إخفاء الاقتراحات إذا كان الحقل فارغاً أو نوع الحساب ليس مورد
      setState(() {
        _supplierSuggestions = [];
        _activeSupplierRowIndex = null;
      });
    }
  }

  // اختيار اقتراح للزبون
  void _selectCustomerSuggestion(String suggestion, int rowIndex) {
    setState(() {
      _customerSuggestions = [];
      _activeCustomerRowIndex = null;
    });

    rowControllers[rowIndex][3].text = suggestion;
    _hasUnsavedChanges = true;

    if (suggestion.trim().length > 1) {
      _saveCustomerToIndex(suggestion);
    }

    Future.delayed(const Duration(milliseconds: 50), () {
      if (mounted) {
        FocusScope.of(context).requestFocus(rowFocusNodes[rowIndex][4]);
      }
    });
  }

  // اختيار اقتراح للمورد
  void _selectSupplierSuggestion(String suggestion, int rowIndex) {
    // إخفاء الاقتراحات فوراً
    setState(() {
      _supplierSuggestions = [];
      _activeSupplierRowIndex = null;
    });

    rowControllers[rowIndex][3].text = suggestion;
    _hasUnsavedChanges = true;

    if (suggestion.trim().length > 1) {
      _saveSupplierToIndex(suggestion);
    }

    Future.delayed(const Duration(milliseconds: 50), () {
      if (mounted) {
        // إخفاء باقي الاقتراحات أيضاً
        setState(() {
          _customerSuggestions = [];
          _activeCustomerRowIndex = null;
        });

        FocusScope.of(context).requestFocus(rowFocusNodes[rowIndex][4]);
      }
    });
  }

  // حفظ الزبون في الفهرس
  void _saveCustomerToIndex(String customer) {
    final trimmedCustomer = customer.trim();
    if (trimmedCustomer.length > 1) {
      _customerIndexService.saveCustomer(trimmedCustomer);
    }
  }

  // حفظ المورد في الفهرس
  void _saveSupplierToIndex(String supplier) {
    final trimmedSupplier = supplier.trim();
    if (trimmedSupplier.length > 1) {
      _supplierIndexService.saveSupplier(trimmedSupplier);
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
      case 'supplier':
        return _supplierSuggestions;
      case 'customer':
        return _customerSuggestions;
      default:
        return [];
    }
  }

  int _getCurrentRowIndexByType() {
    switch (_currentSuggestionType) {
      case 'supplier':
        return _activeSupplierRowIndex ?? -1;
      case 'customer':
        return _activeCustomerRowIndex ?? -1;
      default:
        return -1;
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
