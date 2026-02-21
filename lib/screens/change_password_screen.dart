import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../services/store_db_service.dart';

class ChangePasswordScreen extends StatefulWidget {
  final String currentStoreName;
  final Function(String) onStoreNameChanged;

  const ChangePasswordScreen({
    super.key,
    required this.currentStoreName,
    required this.onStoreNameChanged,
  });

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  int _currentScreen = 0;

  // متغيرات تعديل بيانات البائع
  final _oldSellerNameController = TextEditingController();
  final _oldPasswordController = TextEditingController();
  final _newSellerNameController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _sellerFormKey = GlobalKey<FormState>();

  // متغيرات اسم المحل
  final _storeNameController = TextEditingController();
  final _storeNameFormKey = GlobalKey<FormState>();

  // FocusNodes
  final _oldSellerFocus = FocusNode();
  final _oldPasswordFocus = FocusNode();
  final _newSellerFocus = FocusNode();
  final _newPasswordFocus = FocusNode();
  final _confirmPasswordFocus = FocusNode();
  final _storeNameFocus = FocusNode();

  bool _isLoading = false;
  String? _errorMessage;
  String? _currentSellerName;

  @override
  void initState() {
    super.initState();
    _loadStoreName();
    _loadCurrentSeller();
  }

  @override
  void dispose() {
    _oldSellerNameController.dispose();
    _oldPasswordController.dispose();
    _newSellerNameController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _storeNameController.dispose();

    _oldSellerFocus.dispose();
    _oldPasswordFocus.dispose();
    _newSellerFocus.dispose();
    _newPasswordFocus.dispose();
    _confirmPasswordFocus.dispose();
    _storeNameFocus.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentSeller() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _currentSellerName = prefs.getString('current_seller');
      // لا نقوم بتعبئة الحقول تلقائياً
    });
  }

  Future<Map<String, String>> _getAccounts() async {
    final prefs = await SharedPreferences.getInstance();
    final accounts = prefs.getString('accounts');
    return accounts != null
        ? Map<String, String>.from(json.decode(accounts))
        : {};
  }

  Future<void> _updateSellerData() async {
    if (!_sellerFormKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final oldSellerName = _oldSellerNameController.text;
    final oldPassword = _oldPasswordController.text;
    final newSellerName = _newSellerNameController.text;
    final newPassword = _newPasswordController.text;

    // التحقق من الهوية
    final accounts = await _getAccounts();

    if (!accounts.containsKey(oldSellerName) ||
        accounts[oldSellerName] != oldPassword) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'اسم البائع أو كلمة المرور القديمة غير صحيحة';
      });
      return;
    }

    // إذا لم يتم إدخال اسم جديد، نستخدم الاسم القديم
    final finalNewSellerName =
        newSellerName.isEmpty ? oldSellerName : newSellerName;

    // تحديث البيانات
    final updatedAccounts = Map<String, String>.from(accounts);

    // إذا تم تغيير اسم البائع
    if (oldSellerName != finalNewSellerName) {
      // حفظ الحساب القديم كتاريخ
      final prefs = await SharedPreferences.getInstance();
      final oldAccountsJson = prefs.getString('old_accounts');
      final Map<String, String> oldAccounts = oldAccountsJson != null
          ? Map<String, String>.from(json.decode(oldAccountsJson))
          : {};

      oldAccounts[oldSellerName] = updatedAccounts[oldSellerName]!;
      await prefs.setString('old_accounts', json.encode(oldAccounts));

      // حذف الحساب القديم
      updatedAccounts.remove(oldSellerName);
    }

    // تحديث كلمة المرور إذا تم إدخال كلمة مرور جديدة، وإلا نستخدم القديمة
    final finalPassword = newPassword.isNotEmpty ? newPassword : oldPassword;
    updatedAccounts[finalNewSellerName] = finalPassword;

    // حفظ التغييرات
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('accounts', json.encode(updatedAccounts));

    // إذا كان هذا هو البائع الحالي، تحديثه
    if (_currentSellerName == oldSellerName) {
      await prefs.setString('current_seller', finalNewSellerName);
      _currentSellerName = finalNewSellerName;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم تحديث بيانات البائع بنجاح'),
        backgroundColor: Colors.green,
      ),
    );

    // إعادة تعيين الحقول
    setState(() {
      _isLoading = false;
      _errorMessage = null;

      // تنظيف الحقول بعد النجاح
      _oldSellerNameController.clear();
      _oldPasswordController.clear();
      _newSellerNameController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();
    });
  }

  Future<void> _loadStoreName() async {
    final storeDbService = StoreDbService();
    final savedStoreName = await storeDbService.getStoreName();
    if (savedStoreName != null) {
      setState(() {
        _storeNameController.text = savedStoreName;
      });
    }
  }

  Future<void> _changeStoreName() async {
    if (!_storeNameFormKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final newStoreName = _storeNameController.text;
    final storeDbService = StoreDbService();

    await storeDbService.saveStoreName(newStoreName);

    // تحديث اسم المحل في الشاشة السابقة
    widget.onStoreNameChanged(newStoreName);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم تغيير اسم المحل بنجاح'),
        backgroundColor: Colors.green,
      ),
    );

    setState(() {
      _isLoading = false;
      _currentScreen = 0;
    });
  }

  void _resetToSelection() {
    setState(() {
      _currentScreen = 0;
      _errorMessage = null;
      _oldSellerNameController.clear();
      _oldPasswordController.clear();
      _newSellerNameController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape = MediaQuery.of(context).size.width > 600;

    return Scaffold(
      appBar: AppBar(
        title: Text(_getAppBarTitle()),
        centerTitle: true,
        backgroundColor: Colors.teal[600],
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.teal[400]!, Colors.teal[700]!],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
        ),
        child: _buildCurrentScreen(isLandscape),
      ),
    );
  }

  String _getAppBarTitle() {
    switch (_currentScreen) {
      case 0:
        return 'الإعدادات';
      case 1:
        return 'تعديل بيانات البائع';
      case 2:
        return 'تغيير اسم المحل';
      default:
        return 'الإعدادات';
    }
  }

  Widget _buildCurrentScreen(bool isLandscape) {
    switch (_currentScreen) {
      case 0:
        return _buildSelectionScreen();
      case 1:
        return _buildSellerDataScreen(isLandscape);
      case 2:
        return _buildStoreNameChangeScreen(isLandscape);
      default:
        return _buildSelectionScreen();
    }
  }

  Widget _buildSelectionScreen() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildSelectionOption(
                icon: Icons.person,
                label: 'بيانات البائع',
                description: 'تغيير الاسم وكلمة المرور',
                onTap: () => setState(() => _currentScreen = 1),
              ),
              _buildSelectionOption(
                icon: Icons.store,
                label: 'اسم المحل',
                description: 'تغيير اسم المحل',
                onTap: () => setState(() => _currentScreen = 2),
              ),
            ],
          ),
          const SizedBox(height: 30),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white.withOpacity(0.2),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: Colors.white, width: 1),
              ),
            ),
            child: const Text(
              'رجوع',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectionOption({
    required IconData icon,
    required String label,
    required String description,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 150,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white, width: 1),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 35, color: Colors.white),
            const SizedBox(height: 10),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 5),
            Text(
              description,
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSellerDataScreen(bool isLandscape) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(isLandscape ? 30.0 : 20.0),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: isLandscape ? 800 : 500,
          ),
          child: Form(
            key: _sellerFormKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // سطر التحقق (من اليمين لليسار)
                if (isLandscape)
                  Row(
                    children: [
                      Expanded(
                        child: _buildInputField(
                          _oldPasswordController,
                          'كلمة المرور الحالية',
                          true,
                          focusNode: _oldPasswordFocus,
                          onSubmitted: () => FocusScope.of(context)
                              .requestFocus(_newSellerFocus),
                          icon: Icons.lock,
                          isRequired: true,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildInputField(
                          _oldSellerNameController,
                          'اسم البائع الحالي',
                          false,
                          focusNode: _oldSellerFocus,
                          onSubmitted: () => FocusScope.of(context)
                              .requestFocus(_oldPasswordFocus),
                          icon: Icons.person,
                          isRequired: true,
                        ),
                      ),
                    ],
                  )
                else
                  Column(
                    children: [
                      _buildInputField(
                        _oldPasswordController,
                        'كلمة المرور الحالية',
                        true,
                        focusNode: _oldPasswordFocus,
                        onSubmitted: () => FocusScope.of(context)
                            .requestFocus(_oldSellerFocus),
                        icon: Icons.lock,
                        isRequired: true,
                      ),
                      const SizedBox(height: 10),
                      _buildInputField(
                        _oldSellerNameController,
                        'اسم البائع الحالي',
                        false,
                        focusNode: _oldSellerFocus,
                        onSubmitted: () => FocusScope.of(context)
                            .requestFocus(_newSellerFocus),
                        icon: Icons.person,
                        isRequired: true,
                      ),
                    ],
                  ),

                const SizedBox(height: 20),

                // سطر التعديل (من اليمين لليسار)
                if (isLandscape)
                  Row(
                    children: [
                      Expanded(
                        child: _buildInputField(
                          _confirmPasswordController,
                          'تأكيد كلمة المرور',
                          true,
                          focusNode: _confirmPasswordFocus,
                          onSubmitted: _updateSellerData,
                          icon: Icons.lock_reset,
                          isRequired: false,
                          optionalField: true,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildInputField(
                          _newPasswordController,
                          'كلمة المرور الجديدة (اختياري)',
                          true,
                          focusNode: _newPasswordFocus,
                          onSubmitted: () => FocusScope.of(context)
                              .requestFocus(_confirmPasswordFocus),
                          icon: Icons.lock_outline,
                          isRequired: false,
                          optionalField: true,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildInputField(
                          _newSellerNameController,
                          'اسم البائع الجديد (اختياري)',
                          false,
                          focusNode: _newSellerFocus,
                          onSubmitted: () => FocusScope.of(context)
                              .requestFocus(_newPasswordFocus),
                          icon: Icons.person_add,
                          isRequired: false,
                          optionalField: true,
                        ),
                      ),
                    ],
                  )
                else
                  Column(
                    children: [
                      _buildInputField(
                        _confirmPasswordController,
                        'تأكيد كلمة المرور',
                        true,
                        focusNode: _confirmPasswordFocus,
                        onSubmitted: _updateSellerData,
                        icon: Icons.lock_reset,
                        isRequired: false,
                        optionalField: true,
                      ),
                      const SizedBox(height: 10),
                      _buildInputField(
                        _newPasswordController,
                        'كلمة المرور الجديدة (اختياري)',
                        true,
                        focusNode: _newPasswordFocus,
                        onSubmitted: () => FocusScope.of(context)
                            .requestFocus(_confirmPasswordFocus),
                        icon: Icons.lock_outline,
                        isRequired: false,
                        optionalField: true,
                      ),
                      const SizedBox(height: 10),
                      _buildInputField(
                        _newSellerNameController,
                        'اسم البائع الجديد (اختياري)',
                        false,
                        focusNode: _newSellerFocus,
                        onSubmitted: () => FocusScope.of(context)
                            .requestFocus(_newPasswordFocus),
                        icon: Icons.person_add,
                        isRequired: false,
                        optionalField: true,
                      ),
                    ],
                  ),

                const SizedBox(height: 20),

                if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 15.0),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(
                        color: Colors.yellowAccent,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                // أزرار التحكم
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton(
                      onPressed: _resetToSelection,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white.withOpacity(0.2),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 30, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(color: Colors.white, width: 1),
                        ),
                      ),
                      child: const Text(
                        'رجوع',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 20),
                    _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : ElevatedButton(
                            onPressed: _updateSellerData,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.teal[700],
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 30, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'حفظ التغييرات',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ),
                  ],
                ),
                SizedBox(
                    height:
                        MediaQuery.of(context).viewInsets.bottom > 0 ? 200 : 0),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStoreNameChangeScreen(bool isLandscape) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(isLandscape ? 30.0 : 20.0),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: isLandscape ? 600 : 500,
          ),
          child: Form(
            key: _storeNameFormKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.store, size: 80, color: Colors.white),
                const SizedBox(height: 30),
                _buildInputField(
                  _storeNameController,
                  'اسم المحل الجديد',
                  false,
                  focusNode: _storeNameFocus,
                  onSubmitted: _changeStoreName,
                  icon: Icons.store_mall_directory,
                  isRequired: true,
                ),
                if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 15.0),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(
                        color: Colors.yellowAccent,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                const SizedBox(height: 30),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton(
                      onPressed: _resetToSelection,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white.withOpacity(0.2),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 30, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(color: Colors.white, width: 1),
                        ),
                      ),
                      child: const Text(
                        'رجوع',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 20),
                    _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : ElevatedButton(
                            onPressed: _changeStoreName,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.teal[700],
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 30, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'حفظ',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ),
                  ],
                ),
                SizedBox(
                    height:
                        MediaQuery.of(context).viewInsets.bottom > 0 ? 300 : 0),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputField(
    TextEditingController controller,
    String hint,
    bool obscure, {
    required Function()? onSubmitted,
    required FocusNode? focusNode,
    required IconData icon,
    required bool isRequired,
    bool optionalField = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: controller,
        obscureText: obscure,
        focusNode: focusNode,
        textAlign: TextAlign.center,
        textDirection: TextDirection.rtl,
        textInputAction:
            onSubmitted != null ? TextInputAction.done : TextInputAction.next,
        onFieldSubmitted: (_) {
          if (onSubmitted != null) onSubmitted();
        },
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
          contentPadding:
              const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          prefixIcon: Icon(icon, color: Colors.white70),
          errorStyle: const TextStyle(color: Colors.yellowAccent),
        ),
        validator: (value) {
          if (isRequired && (value == null || value.isEmpty)) {
            return 'الرجاء إدخال $hint';
          }

          // التحقق من تطابق كلمة المرور مع التأكيد
          if (hint.contains('تأكيد') && value!.isNotEmpty) {
            if (value != _newPasswordController.text) {
              return 'كلمتا المرور غير متطابقتين';
            }
          }

          // التحقق من طول كلمة المرور الجديدة إذا تم إدخالها
          if (hint.contains('كلمة المرور الجديدة') &&
              value!.isNotEmpty &&
              value.length < 4) {
            return 'كلمة المرور قصيرة جداً';
          }

          return null;
        },
      ),
    );
  }
}
