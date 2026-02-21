import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../services/purchase_storage_service.dart';
import '../../services/box_storage_service.dart';
import '../../services/receipt_storage_service.dart';
import '../../services/sales_storage_service.dart'; // إضافة لشاشة المبيعات

class YieldScreen extends StatefulWidget {
  final String sellerName;
  final String password;
  final String? selectedDate;

  const YieldScreen({
    super.key,
    required this.sellerName,
    required this.password,
    this.selectedDate,
  });

  @override
  State<YieldScreen> createState() => _YieldScreenState();
}

class _YieldScreenState extends State<YieldScreen> {
  final TextEditingController _cashSalesController = TextEditingController();
  final TextEditingController _receiptsController = TextEditingController();
  final TextEditingController _cashPurchasesController =
      TextEditingController();
  final TextEditingController _paymentsController = TextEditingController();
  final TextEditingController _collectedController = TextEditingController();

  // متغيرات التحكم بشاشة تسجيل الدخول
  bool _isLoggedIn = false;
  bool _isLoading = false;
  String? _errorMessage;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _sellerNameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  late FocusNode _loginSellerNameFocus;
  late FocusNode _loginPasswordFocus;

  double _yield = 0;
  String _status = '';
  List<String> _sellersList = [];
  String? _selectedSeller;

  void _calculateYield() {
    final double cashSales = double.tryParse(_cashSalesController.text) ?? 0;
    final double receipts = double.tryParse(_receiptsController.text) ?? 0;
    final double cashPurchases =
        double.tryParse(_cashPurchasesController.text) ?? 0;
    final double payments = double.tryParse(_paymentsController.text) ?? 0;
    final double collected = double.tryParse(_collectedController.text) ?? 0;

    // الغلة = (المبيعات النقدية + المقبوضات) - (المشتريات النقدية + المدفوعات)
    final double income = cashSales + receipts;
    final double expenses = cashPurchases + payments;
    _yield = double.parse((income - expenses).toStringAsFixed(2));

    if (collected == _yield) {
      _status = '';
    } else {
      final difference = (_yield - collected).abs().toStringAsFixed(2);
      _status = collected > _yield
          ? 'زيادة الغلة $difference'
          : 'نقص الغلة $difference';
    }
  }

  @override
  void initState() {
    super.initState();
    _loginSellerNameFocus = FocusNode();
    _loginPasswordFocus = FocusNode();

    _cashSalesController.addListener(() => setState(_calculateYield));
    _receiptsController.addListener(() => setState(_calculateYield));
    _cashPurchasesController.addListener(() => setState(_calculateYield));
    _paymentsController.addListener(() => setState(_calculateYield));
    _collectedController.addListener(() => setState(_calculateYield));

    // بدء عملية التحقق من الدخول والتحميل التلقائي
    _checkIfLoggedIn().then((_) async {
      if (_isLoggedIn) {
        await _refreshData(); // المرة الأولى
        await _refreshData(); // المرة الثانية
      }
    });

    // تحميل قائمة البائعين دائماً لشاشة الدخول
    _loadSellers();
  }

  // الدالة الوحيدة والموحدة لجلب كافة البيانات وتحديث الشاشة تلقائياً
  Future<void> _refreshData() async {
    // 1. التحقق من وجود التاريخ واسم البائع
    final String currentSeller = _sellerNameController.text.trim();
    if (widget.selectedDate == null || currentSeller.isEmpty || !_isLoggedIn)
      return;

    if (mounted) setState(() => _isLoading = true);

    try {
      // متغيرات لتجميع القيم محلياً
      double totalSales = 0;
      double totalPurchases = 0;
      double totalBoxReceived = 0;
      double totalBoxPaid = 0;
      double totalReceiptPayments = 0; // (دفعة + حمولة)

      // --- أولاً: جلب المبيعات النقدية ---
      final salesDoc =
          await SalesStorageService().loadSalesDocument(widget.selectedDate!);
      if (salesDoc != null) {
        for (var sale in salesDoc.sales) {
          if (sale.sellerName == currentSeller && sale.cashOrDebt == 'نقدي') {
            totalSales += double.tryParse(sale.total) ?? 0;
          }
        }
      }

      // --- ثانياً: جلب المشتريات النقدية ---
      final purchaseDoc = await PurchaseStorageService()
          .loadPurchaseDocument(widget.selectedDate!);
      if (purchaseDoc != null) {
        for (var p in purchaseDoc.purchases) {
          if (p.sellerName == currentSeller && p.cashOrDebt == 'نقدي') {
            totalPurchases += double.tryParse(p.total) ?? 0;
          }
        }
      }

      // --- ثالثاً: جلب بيانات الصندوق (مقبوضات ومدفوعات) ---
      final boxDoc = await BoxStorageService()
          .loadBoxDocumentForDate(widget.selectedDate!);
      if (boxDoc != null) {
        for (var trans in boxDoc.transactions) {
          if (trans.sellerName == currentSeller) {
            totalBoxReceived += double.tryParse(trans.received) ?? 0;
            totalBoxPaid += double.tryParse(trans.paid) ?? 0;
          }
        }
      }

      // --- رابعاً: جلب بيانات الاستلام (دفعة وحمولة البائع حصراً) ---
      final receiptDoc = await ReceiptStorageService()
          .loadReceiptDocumentForDate(widget.selectedDate!);
      if (receiptDoc != null) {
        // فحص كل سجل استلام داخل الملف للتحقق من صاحبه
        for (var r in receiptDoc.receipts) {
          // ملاحظة: التحقق من اسم البائع داخل كل سجل (Record)
          if (r.sellerName == currentSeller) {
            totalReceiptPayments += (double.tryParse(r.payment) ?? 0) +
                (double.tryParse(r.load) ?? 0);
          }
        }
      }

      // --- خامساً: تحديث واجهة المستخدم مرة واحدة بكل القيم ---
      if (mounted) {
        setState(() {
          _cashSalesController.text = totalSales.toStringAsFixed(2);
          _cashPurchasesController.text = totalPurchases.toStringAsFixed(2);
          _receiptsController.text = totalBoxReceived.toStringAsFixed(2);

          // المدفوعات = مدفوع الصندوق + (دفعة وحمولة الاستلام)
          double finalPayments = totalBoxPaid + totalReceiptPayments;
          _paymentsController.text = finalPayments.toStringAsFixed(2);

          _calculateYield(); // حساب الغلة النهائية
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      debugPrint('Error in Yield Refresh: $e');
    }
  }

  Future<void> _checkIfLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    final loggedIn = prefs.getBool('isLoggedIn') ?? false;
    final savedSellerName = prefs.getString('currentSellerName') ?? '';

    if (loggedIn && savedSellerName.isNotEmpty) {
      setState(() {
        _isLoggedIn = true;
        _sellerNameController.text = savedSellerName;
      });

      await _loadCollectedAmount();

      // التحديث التلقائي فور الدخول
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _refreshData();
      });
    }
  }

  Future<void> _login() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      try {
        final prefs = await SharedPreferences.getInstance();
        final accounts = prefs.getString('accounts');
        final Map<String, String> accountsMap = accounts != null
            ? Map<String, String>.from(json.decode(accounts))
            : {};

        final sellerName = _sellerNameController.text.trim();
        final password = _passwordController.text.trim();

        if (accountsMap.containsKey(sellerName) &&
            accountsMap[sellerName] == password) {
          await prefs.setBool('isLoggedIn', true);
          await prefs.setString('currentSellerName', sellerName);

          setState(() {
            _isLoggedIn = true;
            _isLoading = false;
          });

          // استدعاء التحديث التلقائي مرتين فور الدخول
          await _refreshData();
          await _refreshData();
        } else {
          setState(() {
            _errorMessage = 'اسم البائع أو كلمة المرور غير صحيحة';
            _isLoading = false;
          });
        }
      } catch (e) {
        setState(() {
          _errorMessage = 'حدث خطأ أثناء تسجيل الدخول';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', false);
    await prefs.remove('currentSellerName');

    setState(() {
      _isLoggedIn = false;
      _sellerNameController.clear();
      _passwordController.clear();
      _errorMessage = null;
      _cashSalesController.text = '0.00';
      _cashPurchasesController.text = '0.00';
      _receiptsController.text = '0.00';
      _paymentsController.text = '0.00';
      _collectedController.text = '';
      _yield = 0;
      _status = '';
    });
  }

  // --- واجهة تسجيل الدخول ---
  Widget _buildLoginScreen() {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 20),
          const Text(
            'تسجيل الدخول - شاشة الغلة',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 40),

          // قائمة اختيار البائعين (مشابهة لـ login_screen.dart)
          if (_sellersList.isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 50),
              child: DropdownButtonFormField<String>(
                value: _selectedSeller,
                hint: Text(
                  'اختر اسم البائع',
                  style: TextStyle(color: Colors.white70),
                  textAlign: TextAlign.center,
                ),
                items: _sellersList.map((seller) {
                  return DropdownMenuItem<String>(
                    value: seller,
                    child: Text(
                      seller,
                      style: TextStyle(
                        color: Colors.teal[700],
                        fontSize: 16,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedSeller = value;
                    _sellerNameController.text = value ?? '';
                    if (value != null) {
                      FocusScope.of(context).requestFocus(_loginPasswordFocus);
                    }
                  });
                },
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.2),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.white, width: 2),
                  ),
                ),
                dropdownColor: Colors.white,
                icon: Icon(Icons.arrow_drop_down, color: Colors.white),
                style: TextStyle(color: Colors.teal[700], fontSize: 16),
              ),
            ),
            const SizedBox(height: 20),
          ],

          // بقية الحقول كما هي...
          Row(
            textDirection: TextDirection.rtl,
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: _buildLoginInputField(
                    _sellerNameController,
                    'أدخل اسم البائع',
                    false,
                    focusNode: _loginSellerNameFocus,
                    nextFocusNode: _loginPasswordFocus,
                    isLastInRow: false,
                    errorText: _errorMessage,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: _buildLoginInputField(
                    _passwordController,
                    'أدخل كلمة المرور',
                    true,
                    focusNode: _loginPasswordFocus,
                    nextFocusNode: null,
                    isLastInRow: true,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 30),
          _isLoading
              ? const CircularProgressIndicator(color: Colors.white)
              : ElevatedButton(
                  onPressed: _login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.teal[700],
                    padding: const EdgeInsets.symmetric(
                      horizontal: 60,
                      vertical: 15,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'دخول',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
        ],
      ),
    );
  }

// دالة جديدة لحقول الإدخال في شاشة تسجيل الدخول
  Widget _buildLoginInputField(
    TextEditingController controller,
    String hint,
    bool obscure, {
    FocusNode? focusNode,
    FocusNode? nextFocusNode,
    bool isLastInRow = false,
    String? errorText,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      textAlign: TextAlign.center,
      focusNode: focusNode,
      textDirection: TextDirection.rtl,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white70),
        filled: true,
        fillColor: Colors.white.withOpacity(0.2),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.white, width: 2),
        ),
        errorText: errorText,
        errorStyle: const TextStyle(color: Colors.yellowAccent),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) return 'هذا الحقل مطلوب';
        return null;
      },
      onFieldSubmitted: (_) {
        if (isLastInRow) {
          _login();
        } else if (nextFocusNode != null) {
          FocusScope.of(context).requestFocus(nextFocusNode);
        }
      },
    );
  }

  Widget _buildYieldScreen() {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.selectedDate != null
              ? 'غلة البائع: ${_sellerNameController.text} بتاريخ ${widget.selectedDate}'
              : 'غلة البائع: ${_sellerNameController.text}',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis, // تقصير النص إذا كان طويلاً
          maxLines: 1, // تحديد سطر واحد فقط
        ),
        centerTitle: true,
        backgroundColor: Colors.teal[600],
        foregroundColor: Colors.white,
        // داخل AppBar في دالة _buildYieldScreen
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshData, // استخدام الدالة الموحدة
            tooltip: 'تحديث البيانات',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: 'تسجيل الخروج',
          ),
        ],
      ),
      body: SafeArea(
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: SingleChildScrollView(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.9,
                  minHeight: MediaQuery.of(context).size.height,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // الصف الأول: مبيعات نقدية - مقبوضات
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: _buildReadOnlyField(
                            'مبيعات نقدية',
                            _cashSalesController,
                            icon: Icons.shopping_cart,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildReadOnlyField(
                            'مقبوضات',
                            _receiptsController,
                            icon: Icons.account_balance_wallet,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),

                    // الصف الثاني: مشتريات نقدية - مدفوعات
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: _buildReadOnlyField(
                            'مشتريات نقدية',
                            _cashPurchasesController,
                            icon: Icons.shopping_bag,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildReadOnlyField(
                            'مدفوعات',
                            _paymentsController,
                            icon: Icons.payment,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),

                    // الصف الثالث: الغلة - المقبوض منه
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // حقل الناتج (الغلة) - تصميم مشابه لحقل الإدخال
                        Expanded(
                          child: _buildYieldResultField(
                            'الغلة',
                            TextEditingController(
                                text: _yield.toStringAsFixed(2)),
                            icon: Icons.calculate,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildYieldInputField(
                            'المقبوض منه',
                            _collectedController,
                            icon: Icons.money,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),

                    // الصف الرابع: زيادة أو نقص الغلة
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        vertical: 16,
                        horizontal: 24,
                      ),
                      decoration: BoxDecoration(
                        color: _status.contains('زيادة')
                            ? Colors.green[50]
                            : _status.contains('نقص')
                                ? Colors.red[50]
                                : Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _status.contains('زيادة')
                              ? Colors.green[200]!
                              : _status.contains('نقص')
                                  ? Colors.red[200]!
                                  : Colors.grey[300]!,
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            _status.isNotEmpty ? _status : 'لا يوجد فرق',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: _status.contains('زيادة')
                                  ? Colors.green[800]
                                  : _status.contains('نقص')
                                      ? Colors.red[800]
                                      : Colors.grey[600],
                            ),
                            textAlign: TextAlign.center,
                          ),
                          if (_status.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                _status.contains('زيادة')
                                    ? 'المقبوض أكبر من الغلة الحقيقية'
                                    : 'المقبوض أقل من الغلة الحقيقية',
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                        ],
                      ),
                    ),

                    // مسافة إضافية في الأسفل
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReadOnlyField(
    String label,
    TextEditingController controller, {
    IconData? icon,
    String? infoText,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 1,
            offset: const Offset(0, 0.54),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (infoText != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 4.0, right: 8.0),
              child: Text(
                infoText,
                style: const TextStyle(
                  fontSize: 9,
                  color: Colors.grey,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          TextField(
            controller: controller,
            readOnly: true,
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.teal[700],
            ),
            decoration: InputDecoration(
              labelText: label,
              labelStyle: TextStyle(
                fontSize: 12,
                color: Colors.grey[700],
                fontWeight: FontWeight.bold,
              ),
              prefixIcon: icon != null
                  ? Icon(
                      icon,
                      size: 18,
                      color: Colors.teal[600],
                    )
                  : null,
              filled: true,
              fillColor: Colors.grey[100],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.teal[400]!, width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildYieldResultField(
    String label,
    TextEditingController controller, {
    IconData? icon,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 1,
            offset: const Offset(0, 0.54),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        readOnly: true,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: Colors.teal[900],
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            fontSize: 12,
            color: Colors.grey[700],
            fontWeight: FontWeight.bold,
          ),
          prefixIcon: icon != null
              ? Icon(
                  icon,
                  size: 18,
                  color: Colors.teal[700],
                )
              : null,
          filled: true,
          fillColor: Colors.teal[50],
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.teal[300]!),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.teal[300]!),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.teal[500]!, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 1,
          ),
        ),
      ),
    );
  }

  Widget _buildYieldInputField(
    String label,
    TextEditingController controller, {
    IconData? icon,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 1,
            offset: const Offset(0, 0.54),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: controller,
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
            decoration: InputDecoration(
              labelText: label,
              labelStyle: TextStyle(
                fontSize: 12,
                color: Colors.grey[700],
                fontWeight: FontWeight.bold,
              ),
              prefixIcon: icon != null
                  ? Icon(
                      icon,
                      size: 18,
                      color: Colors.teal[600],
                    )
                  : null,
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.teal[400]!, width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 1,
              ),
            ),
            onChanged: (value) {
              setState(() {
                _calculateYield();
              });

              // حفظ القيمة فوراً عند تغييرها
              if (_isLoggedIn && value.isNotEmpty) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _saveCollectedAmount();
                });
              }
            },
            onTapOutside: (_) {
              // فقدان التركيز - الحفظ
              if (_isLoggedIn && _collectedController.text.isNotEmpty) {
                _saveCollectedAmount();
              }
            },
            onEditingComplete: () {
              // عند الضغط على Enter
              if (_isLoggedIn && _collectedController.text.isNotEmpty) {
                _saveCollectedAmount();
              }
            },
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    // حفظ قيمة المقبوض منه عند تدمير الشاشة
    if (_isLoggedIn && _collectedController.text.isNotEmpty) {
      _saveCollectedAmount();
    }

    _cashSalesController.dispose();
    _receiptsController.dispose();
    _cashPurchasesController.dispose();
    _paymentsController.dispose();
    _collectedController.dispose();
    _sellerNameController.dispose();
    _passwordController.dispose();
    _loginSellerNameFocus.dispose();
    _loginPasswordFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _calculateYield();

    // بناء واجهة المستخدم بناءً على حالة تسجيل الدخول
    if (!_isLoggedIn) {
      return Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.teal[400]!, Colors.teal[700]!],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: _buildLoginScreen(),
            ),
          ),
        ),
      );
    } else {
      return _buildYieldScreen();
    }
  }

  Future<void> _saveCollectedAmount() async {
    if (!_isLoggedIn) return;

    final prefs = await SharedPreferences.getInstance();
    final collectedValue = _collectedController.text.trim();
    final currentSellerName = _sellerNameController.text.trim();
    final dateKey = widget.selectedDate ?? 'default';

    if (currentSellerName.isNotEmpty) {
      // إنشاء مفتاح فريد يجمع بين البائع والتاريخ
      final uniqueKey = 'collected_${currentSellerName}_$dateKey';

      if (collectedValue.isEmpty) {
        // إذا كانت القيمة فارغة، احفظ "0.00"
        await prefs.setString(uniqueKey, '0.00');
      } else {
        // تأكد من تنسيق الرقم بشكل صحيح
        final doubleValue = double.tryParse(collectedValue);
        final formattedValue = doubleValue?.toStringAsFixed(2) ?? '0.00';
        await prefs.setString(uniqueKey, formattedValue);
      }
    }
  }

  Future<void> _loadCollectedAmount() async {
    // انتظار تسجيل الدخول أولاً
    if (!_isLoggedIn) return;

    final prefs = await SharedPreferences.getInstance();
    final currentSellerName = _sellerNameController.text.trim();
    final dateKey = widget.selectedDate ?? 'default';

    if (currentSellerName.isNotEmpty) {
      final uniqueKey = 'collected_${currentSellerName}_$dateKey';
      final savedValue = prefs.getString(uniqueKey);

      if (savedValue != null && savedValue.isNotEmpty && mounted) {
        setState(() {
          _collectedController.text = savedValue;
          // إعادة حساب الغلة بعد تحميل القيمة
          _calculateYield();
        });
      }
    }
  }

  Future<void> _loadSellers() async {
    final prefs = await SharedPreferences.getInstance();
    final accountsJson = prefs.getString('accounts');

    if (accountsJson != null && mounted) {
      try {
        final accounts = json.decode(accountsJson) as Map<String, dynamic>;
        setState(() {
          _sellersList = accounts.keys.toList();
        });
      } catch (e) {
        print('Error loading sellers: $e');
      }
    }
  }
}
