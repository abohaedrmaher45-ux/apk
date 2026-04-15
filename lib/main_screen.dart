// lib/main_screen.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'models/models.dart';
import 'final_invoice_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  // بيانات الفرشات
  final List<MattressColumnData> mattressColumns = [];
  List<MattressType> mattressTypes = [];
  MattressType? selectedMattressType;
  final TextEditingController mattressDollarController = TextEditingController();
  double mattressDollarPrice = 0.0;
  String? mattressDollarError;
  
  // بيانات المساند
  final List<SupportColumnData> supportColumns = [];
  List<SupportType> supportTypes = [];
  SupportType? selectedSupportType;
  final TextEditingController supportDollarController = TextEditingController();
  double supportDollarPrice = 0.0;
  String? supportDollarError;
  
  String currentDate = '';
  
  // القوالب المخصصة
  List<CustomTemplate> savedTemplates = [];
  
  // قوائم ثابتة
  final List<MattressFixedColumn> mattressFixedColumns = [
    MattressFixedColumn(name: 'فرشة 1', lengthCM: 200, widthCM: 70),
    MattressFixedColumn(name: 'فرشة 2', lengthCM: 180, widthCM: 70),
    MattressFixedColumn(name: 'فرشة 3', lengthCM: 100, widthCM: 100),
  ];
  
  final List<SupportFixedColumn> supportFixedColumns = [
    SupportFixedColumn(name: 'مسند 1', lengthCM: 200, thicknessCM: 10),
    SupportFixedColumn(name: 'مسند 2', lengthCM: 180, thicknessCM: 10),
    SupportFixedColumn(name: 'مسند 3', lengthCM: 160, thicknessCM: 10),
    SupportFixedColumn(name: 'مسند 4', lengthCM: 140, thicknessCM: 10),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _updateDate();
    _initializeData();
    _loadAllData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    mattressDollarController.dispose();
    supportDollarController.dispose();
    for (var col in mattressColumns) {
      col.dispose();
    }
    for (var col in supportColumns) {
      col.dispose();
    }
    super.dispose();
  }

  void _updateDate() {
    final now = DateTime.now();
    setState(() {
      currentDate = DateFormat('yyyy/MM/dd - HH:mm').format(now);
    });
  }

  void _initializeData() {
    // تهيئة أنواع الإسفنج الافتراضية
    if (mattressTypes.isEmpty) {
      mattressTypes = [
        MattressType(name: 'سوبر اول مميز', price: 2.85),
        MattressType(name: 'سوفت', price: 2.70),
        MattressType(name: 'سوبر ثقيل مميز', price: 3.00),
        MattressType(name: 'ممتاز اول مميز', price: 2.15),
        MattressType(name: 'سوبر اول', price: 2.65),
      ];
    }
    
    // تهيئة أنواع المساند الافتراضية
    if (supportTypes.isEmpty) {
      supportTypes = [
        SupportType(name: 'سوبر اول مميز', price: 2.85),
        SupportType(name: 'سوفت', price: 2.70),
        SupportType(name: 'سوبر ثقيل مميز', price: 3.00),
        SupportType(name: 'ممتاز اول مميز', price: 2.15),
        SupportType(name: 'سوبر اول', price: 2.65),
      ];
    }
    
    // تهيئة أعمدة الفرشات
    if (mattressColumns.isEmpty) {
      for (var fixed in mattressFixedColumns) {
        mattressColumns.add(MattressColumnData(
          name: fixed.name,
          lengthCM: fixed.lengthCM,
          widthCM: fixed.widthCM,
          heightController: TextEditingController(),
          quantityController: TextEditingController(),
          discountController: TextEditingController(),
          isFixed: true,
        ));
      }
    }
    
    // تهيئة أعمدة المساند
    if (supportColumns.isEmpty) {
      for (var fixed in supportFixedColumns) {
        supportColumns.add(SupportColumnData(
          name: fixed.name,
          lengthCM: fixed.lengthCM,
          thicknessCM: fixed.thicknessCM,
          heightController: TextEditingController(),
          quantityController: TextEditingController(),
          discountController: TextEditingController(),
          isFixed: true,
        ));
      }
    }
  }

  Future<void> _loadAllData() async {
    final prefs = await SharedPreferences.getInstance();
    
    setState(() {
      // تحميل سعر دولار الفرشات
      mattressDollarPrice = prefs.getDouble('mattress_dollar_price') ?? 0.0;
      if (mattressDollarPrice > 0) {
        mattressDollarController.text = mattressDollarPrice.toString();
      }
      
      // تحميل سعر دولار المساند
      supportDollarPrice = prefs.getDouble('support_dollar_price') ?? 0.0;
      if (supportDollarPrice > 0) {
        supportDollarController.text = supportDollarPrice.toString();
      }
      
      // تحميل أنواع الإسفنج
      List<String>? mNames = prefs.getStringList('mattress_type_names');
      List<String>? mPrices = prefs.getStringList('mattress_type_prices');
      if (mNames != null && mPrices != null && mNames.isNotEmpty) {
        mattressTypes = [];
        for (int i = 0; i < mNames.length; i++) {
          mattressTypes.add(MattressType(
            name: mNames[i],
            price: double.tryParse(mPrices[i]) ?? 0.0,
          ));
        }
      }
      String? savedMattressType = prefs.getString('selected_mattress_type');
      if (savedMattressType != null) {
        selectedMattressType = mattressTypes.firstWhere(
          (t) => t.name == savedMattressType,
          orElse: () => mattressTypes.first,
        );
      } else {
        selectedMattressType = mattressTypes.first;
      }
      
      // تحميل أنواع المساند
      List<String>? sNames = prefs.getStringList('support_type_names');
      List<String>? sPrices = prefs.getStringList('support_type_prices');
      if (sNames != null && sPrices != null && sNames.isNotEmpty) {
        supportTypes = [];
        for (int i = 0; i < sNames.length; i++) {
          supportTypes.add(SupportType(
            name: sNames[i],
            price: double.tryParse(sPrices[i]) ?? 0.0,
          ));
        }
      }
      String? savedSupportType = prefs.getString('selected_support_type');
      if (savedSupportType != null) {
        selectedSupportType = supportTypes.firstWhere(
          (t) => t.name == savedSupportType,
          orElse: () => supportTypes.first,
        );
      } else {
        selectedSupportType = supportTypes.first;
      }
      
      // تحميل القوالب المحفوظة
      List<String>? templatesJson = prefs.getStringList('saved_templates');
      if (templatesJson != null) {
        savedTemplates = templatesJson.map((json) => CustomTemplate.fromJson(jsonDecode(json))).toList();
      }
    });
    
    await _loadCustomMattressColumns();
    await _loadCustomSupportColumns();
  }

  Future<void> _loadCustomMattressColumns() async {
    final prefs = await SharedPreferences.getInstance();
    int customCount = prefs.getInt('mattress_custom_count') ?? 0;
    
    for (int i = 0; i < customCount; i++) {
      String? name = prefs.getString('mattress_custom_name_$i');
      double? length = prefs.getDouble('mattress_custom_length_$i');
      double? width = prefs.getDouble('mattress_custom_width_$i');
      
      if (name != null && length != null && width != null) {
        var col = MattressColumnData(
          name: name,
          lengthCM: length,
          widthCM: width,
          heightController: TextEditingController(),
          quantityController: TextEditingController(),
          discountController: TextEditingController(),
          isFixed: false,
        );
        
        String? height = prefs.getString('mattress_custom_height_$i');
        String? quantity = prefs.getString('mattress_custom_quantity_$i');
        String? discount = prefs.getString('mattress_custom_discount_$i');
        
        if (height != null) col.heightController.text = height;
        if (quantity != null) col.quantityController.text = quantity;
        if (discount != null) col.discountController.text = discount;
        
        mattressColumns.add(col);
      }
    }
    setState(() {});
  }

  Future<void> _loadCustomSupportColumns() async {
    final prefs = await SharedPreferences.getInstance();
    int customCount = prefs.getInt('support_custom_count') ?? 0;
    
    for (int i = 0; i < customCount; i++) {
      String? name = prefs.getString('support_custom_name_$i');
      double? length = prefs.getDouble('support_custom_length_$i');
      double? thickness = prefs.getDouble('support_custom_thickness_$i');
      
      if (name != null && length != null && thickness != null) {
        var col = SupportColumnData(
          name: name,
          lengthCM: length,
          thicknessCM: thickness,
          heightController: TextEditingController(),
          quantityController: TextEditingController(),
          discountController: TextEditingController(),
          isFixed: false,
        );
        
        String? height = prefs.getString('support_custom_height_$i');
        String? quantity = prefs.getString('support_custom_quantity_$i');
        String? discount = prefs.getString('support_custom_discount_$i');
        
        if (height != null) col.heightController.text = height;
        if (quantity != null) col.quantityController.text = quantity;
        if (discount != null) col.discountController.text = discount;
        
        supportColumns.add(col);
      }
    }
    setState(() {});
  }

  Future<void> _saveAllData() async {
    final prefs = await SharedPreferences.getInstance();
    
    await prefs.setDouble('mattress_dollar_price', mattressDollarPrice);
    await prefs.setDouble('support_dollar_price', supportDollarPrice);
    
    // حفظ أنواع الإسفنج
    List<String> mNames = mattressTypes.map((t) => t.name).toList();
    List<String> mPrices = mattressTypes.map((t) => t.price.toString()).toList();
    await prefs.setStringList('mattress_type_names', mNames);
    await prefs.setStringList('mattress_type_prices', mPrices);
    if (selectedMattressType != null) {
      await prefs.setString('selected_mattress_type', selectedMattressType!.name);
    }
    
    // حفظ أنواع المساند
    List<String> sNames = supportTypes.map((t) => t.name).toList();
    List<String> sPrices = supportTypes.map((t) => t.price.toString()).toList();
    await prefs.setStringList('support_type_names', sNames);
    await prefs.setStringList('support_type_prices', sPrices);
    if (selectedSupportType != null) {
      await prefs.setString('selected_support_type', selectedSupportType!.name);
    }
    
    // حفظ القوالب
    List<String> templatesJson = savedTemplates.map((t) => jsonEncode(t.toJson())).toList();
    await prefs.setStringList('saved_templates', templatesJson);
    
    await _saveCustomMattressColumns();
    await _saveCustomSupportColumns();
  }

  Future<void> _saveCustomMattressColumns() async {
    final prefs = await SharedPreferences.getInstance();
    int customIndex = 0;
    for (var col in mattressColumns) {
      if (!col.isFixed) {
        await prefs.setString('mattress_custom_name_$customIndex', col.name);
        await prefs.setDouble('mattress_custom_length_$customIndex', col.lengthCM);
        await prefs.setDouble('mattress_custom_width_$customIndex', col.widthCM);
        await prefs.setString('mattress_custom_height_$customIndex', col.heightController.text);
        await prefs.setString('mattress_custom_quantity_$customIndex', col.quantityController.text);
        await prefs.setString('mattress_custom_discount_$customIndex', col.discountController.text);
        customIndex++;
      }
    }
    await prefs.setInt('mattress_custom_count', customIndex);
  }

  Future<void> _saveCustomSupportColumns() async {
    final prefs = await SharedPreferences.getInstance();
    int customIndex = 0;
    for (var col in supportColumns) {
      if (!col.isFixed) {
        await prefs.setString('support_custom_name_$customIndex', col.name);
        await prefs.setDouble('support_custom_length_$customIndex', col.lengthCM);
        await prefs.setDouble('support_custom_thickness_$customIndex', col.thicknessCM);
        await prefs.setString('support_custom_height_$customIndex', col.heightController.text);
        await prefs.setString('support_custom_quantity_$customIndex', col.quantityController.text);
        await prefs.setString('support_custom_discount_$customIndex', col.discountController.text);
        customIndex++;
      }
    }
    await prefs.setInt('support_custom_count', customIndex);
  }

  // ==================== دوال الحسابات ====================
  
  double calculateMattressVolume(MattressColumnData col) {
    double height = double.tryParse(col.heightController.text) ?? 0;
    if (height <= 0) return 0;
    return (col.lengthCM * col.widthCM * height) / 20000;
  }

  double calculateMattressTotal(MattressColumnData col) {
    if (selectedMattressType == null) return 0;
    double volume = calculateMattressVolume(col);
    if (volume <= 0) return 0;
    
    double quantity = double.tryParse(col.quantityController.text) ?? 1;
    if (quantity <= 0) quantity = 1;
    
    double discount = double.tryParse(col.discountController.text) ?? 0;
    discount = discount.clamp(0, 100);
    
    double total = quantity * volume * selectedMattressType!.price;
    return total * (1 - discount / 100);
  }

  double calculateMattressTotalSYP(MattressColumnData col) {
    return calculateMattressTotal(col) * mattressDollarPrice;
  }

  double getMattressGrandTotal() {
    return mattressColumns.fold(0, (sum, col) => sum + calculateMattressTotal(col));
  }

  double getMattressGrandTotalSYP() {
    return getMattressGrandTotal() * mattressDollarPrice;
  }

  double calculateSupportVolume(SupportColumnData col) {
    double height = double.tryParse(col.heightController.text) ?? 0;
    if (height <= 0) return 0;
    return (col.lengthCM * col.thicknessCM * height) / 20000;
  }

  double calculateSupportTotal(SupportColumnData col) {
    if (selectedSupportType == null) return 0;
    double volume = calculateSupportVolume(col);
    if (volume <= 0) return 0;
    
    double quantity = double.tryParse(col.quantityController.text) ?? 1;
    if (quantity <= 0) quantity = 1;
    
    double discount = double.tryParse(col.discountController.text) ?? 0;
    discount = discount.clamp(0, 100);
    
    double total = quantity * volume * selectedSupportType!.price;
    return total * (1 - discount / 100);
  }

  double calculateSupportTotalSYP(SupportColumnData col) {
    return calculateSupportTotal(col) * supportDollarPrice;
  }

  double getSupportGrandTotal() {
    return supportColumns.fold(0, (sum, col) => sum + calculateSupportTotal(col));
  }

  double getSupportGrandTotalSYP() {
    return getSupportGrandTotal() * supportDollarPrice;
  }

  String _formatNumber(double number) {
    if (number == 0) return '0';
    return NumberFormat.decimalPattern('ar').format(number);
  }

  // ==================== دوال الفاتورة ====================
  
  List<Map<String, dynamic>> getMattressInvoiceItems() {
    List<Map<String, dynamic>> items = [];
    for (var col in mattressColumns) {
      double height = double.tryParse(col.heightController.text) ?? 0;
      double quantity = double.tryParse(col.quantityController.text) ?? 1;
      double discount = double.tryParse(col.discountController.text) ?? 0;
      double totalUSD = calculateMattressTotal(col);
      
      if (height > 0 && totalUSD > 0) {
        items.add({
          'section': 'الفرشات',
          'type': selectedMattressType?.name ?? '',
          'dimensions': '${col.lengthCM} × ${col.widthCM}',
          'height': height,
          'quantity': quantity,
          'discount': discount,
          'totalUSD': totalUSD,
          'totalSYP': totalUSD * mattressDollarPrice,
        });
      }
    }
    return items;
  }

  List<Map<String, dynamic>> getSupportInvoiceItems() {
    List<Map<String, dynamic>> items = [];
    for (var col in supportColumns) {
      double height = double.tryParse(col.heightController.text) ?? 0;
      double quantity = double.tryParse(col.quantityController.text) ?? 1;
      double discount = double.tryParse(col.discountController.text) ?? 0;
      double totalUSD = calculateSupportTotal(col);
      
      if (height > 0 && totalUSD > 0) {
        items.add({
          'section': 'المساند',
          'type': selectedSupportType?.name ?? '',
          'dimensions': '${col.lengthCM} × ${col.thicknessCM}',
          'height': height,
          'quantity': quantity,
          'discount': discount,
          'totalUSD': totalUSD,
          'totalSYP': totalUSD * supportDollarPrice,
        });
      }
    }
    return items;
  }

  Future<void> _showFinalInvoice() async {
    final prefs = await SharedPreferences.getInstance();
    
    // حفظ بيانات الفرشات
    List<String> mattressItemsJson = getMattressInvoiceItems().map((item) => jsonEncode(item)).toList();
    await prefs.setStringList('temp_mattress_items', mattressItemsJson);
    await prefs.setDouble('temp_mattress_dollar_price', mattressDollarPrice);
    await prefs.setString('temp_mattress_type', selectedMattressType?.name ?? '');
    
    // حفظ بيانات المساند
    List<String> supportItemsJson = getSupportInvoiceItems().map((item) => jsonEncode(item)).toList();
    await prefs.setStringList('temp_support_items', supportItemsJson);
    await prefs.setDouble('temp_support_dollar_price', supportDollarPrice);
    await prefs.setString('temp_support_type', selectedSupportType?.name ?? '');
    
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const FinalInvoiceScreen()),
      );
    }
  }

  // ==================== دوال القوالب ====================
  
  void _saveAsTemplate() {
    final nameController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حفظ كقالب'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'اسم القالب',
            hintText: 'مثال: غرفة نوم',
            border: OutlineInputBorder(),
          ),
          textAlign: TextAlign.right,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () {
              String name = nameController.text.trim();
              if (name.isNotEmpty) {
                _performSaveTemplate(name);
                Navigator.pop(context);
              }
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  void _performSaveTemplate(String name) {
    List<MattressColumnTemplate> mTemplates = [];
    for (var col in mattressColumns) {
      if (!col.isFixed) {
        mTemplates.add(MattressColumnTemplate(
          name: col.name,
          lengthCM: col.lengthCM,
          widthCM: col.widthCM,
          height: double.tryParse(col.heightController.text) ?? 0,
          quantity: double.tryParse(col.quantityController.text) ?? 1,
          discount: double.tryParse(col.discountController.text) ?? 0,
        ));
      }
    }
    
    List<SupportColumnTemplate> sTemplates = [];
    for (var col in supportColumns) {
      if (!col.isFixed) {
        sTemplates.add(SupportColumnTemplate(
          name: col.name,
          lengthCM: col.lengthCM,
          thicknessCM: col.thicknessCM,
          height: double.tryParse(col.heightController.text) ?? 0,
          quantity: double.tryParse(col.quantityController.text) ?? 1,
          discount: double.tryParse(col.discountController.text) ?? 0,
        ));
      }
    }
    
    final template = CustomTemplate(
      name: name,
      createdAt: DateTime.now(),
      mattressColumns: mTemplates,
      supportColumns: sTemplates,
      mattressTypeName: selectedMattressType?.name,
      supportTypeName: selectedSupportType?.name,
    );
    
    setState(() {
      savedTemplates.add(template);
    });
    _saveAllData();
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('تم حفظ القالب "$name" بنجاح'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _loadTemplate(CustomTemplate template) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('تحميل القالب: ${template.name}'),
        content: const Text('سيتم استبدال الأعمدة المخصصة الحالية. هل تريد المتابعة؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () {
              _performLoadTemplate(template);
              Navigator.pop(context);
            },
            child: const Text('تحميل'),
          ),
        ],
      ),
    );
  }

  void _performLoadTemplate(CustomTemplate template) {
    setState(() {
      // حذف الأعمدة المخصصة الحالية
      mattressColumns.removeWhere((col) => !col.isFixed);
      supportColumns.removeWhere((col) => !col.isFixed);
      
      // إضافة أعمدة القالب
      for (var m in template.mattressColumns) {
        mattressColumns.add(MattressColumnData(
          name: m.name,
          lengthCM: m.lengthCM,
          widthCM: m.widthCM,
          heightController: TextEditingController(text: m.height > 0 ? m.height.toString() : ''),
          quantityController: TextEditingController(text: m.quantity > 0 ? m.quantity.toString() : ''),
          discountController: TextEditingController(text: m.discount > 0 ? m.discount.toString() : ''),
          isFixed: false,
        ));
      }
      
      for (var s in template.supportColumns) {
        supportColumns.add(SupportColumnData(
          name: s.name,
          lengthCM: s.lengthCM,
          thicknessCM: s.thicknessCM,
          heightController: TextEditingController(text: s.height > 0 ? s.height.toString() : ''),
          quantityController: TextEditingController(text: s.quantity > 0 ? s.quantity.toString() : ''),
          discountController: TextEditingController(text: s.discount > 0 ? s.discount.toString() : ''),
          isFixed: false,
        ));
      }
      
      // تحميل النوع المحدد إذا وجد
      if (template.mattressTypeName != null) {
        selectedMattressType = mattressTypes.firstWhere(
          (t) => t.name == template.mattressTypeName,
          orElse: () => mattressTypes.first,
        );
      }
      
      if (template.supportTypeName != null) {
        selectedSupportType = supportTypes.firstWhere(
          (t) => t.name == template.supportTypeName,
          orElse: () => supportTypes.first,
        );
      }
    });
    
    _saveAllData();
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('تم تحميل القالب "${template.name}" بنجاح'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _deleteTemplate(CustomTemplate template) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('حذف القالب: ${template.name}'),
        content: const Text('هل أنت متأكد من حذف هذا القالب؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                savedTemplates.remove(template);
              });
              _saveAllData();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('تم حذف القالب "${template.name}"'),
                  backgroundColor: Colors.red,
                ),
              );
            },
            child: const Text('حذف', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showTemplatesMenu() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'القوالب المحفوظة',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (savedTemplates.isEmpty)
              Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    Icon(Icons.folder_off, size: 48, color: Colors.grey.shade400),
                    const SizedBox(height: 16),
                    Text(
                      'لا توجد قوالب محفوظة',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ],
                ),
              )
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: savedTemplates.length,
                  itemBuilder: (context, index) {
                    final template = savedTemplates[index];
                    return ListTile(
                      leading: const Icon(Icons.folder, color: Colors.amber),
                      title: Text(template.name),
                      subtitle: Text(
                        '${DateFormat('yyyy/MM/dd').format(template.createdAt)} - ${template.mattressColumns.length} فرشات, ${template.supportColumns.length} مساند',
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.download, color: Colors.green),
                            onPressed: () {
                              Navigator.pop(context);
                              _loadTemplate(template);
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () {
                              Navigator.pop(context);
                              _deleteTemplate(template);
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _saveAsTemplate();
              },
              icon: const Icon(Icons.save),
              label: const Text('حفظ القالب الحالي'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 48),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== دوال إضافة وحذف الأعمدة ====================
  
  void _addMattressColumn() {
    setState(() {
      mattressColumns.add(MattressColumnData(
        name: 'فرشة جديدة',
        lengthCM: 100,
        widthCM: 100,
        heightController: TextEditingController(),
        quantityController: TextEditingController(),
        discountController: TextEditingController(),
        isFixed: false,
      ));
    });
    _saveAllData();
  }

  void _addSupportColumn() {
    setState(() {
      supportColumns.add(SupportColumnData(
        name: 'مسند جديد',
        lengthCM: 100,
        thicknessCM: 10,
        heightController: TextEditingController(),
        quantityController: TextEditingController(),
        discountController: TextEditingController(),
        isFixed: false,
      ));
    });
    _saveAllData();
  }

  void _removeMattressColumn(int index) {
    if (mattressColumns[index].isFixed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا يمكن حذف عمود ثابت'), backgroundColor: Colors.orange),
      );
      return;
    }
    setState(() {
      mattressColumns[index].dispose();
      mattressColumns.removeAt(index);
    });
    _saveAllData();
  }

  void _removeSupportColumn(int index) {
    if (supportColumns[index].isFixed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا يمكن حذف عمود ثابت'), backgroundColor: Colors.orange),
      );
      return;
    }
    setState(() {
      supportColumns[index].dispose();
      supportColumns.removeAt(index);
    });
    _saveAllData();
  }

  void _clearAllMattressData() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('مسح بيانات الفرشات'),
        content: const Text('هل أنت متأكد من مسح جميع بيانات الفرشات؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          TextButton(
            onPressed: () {
              setState(() {
                for (var col in mattressColumns) {
                  col.heightController.clear();
                  col.quantityController.clear();
                  col.discountController.clear();
                }
              });
              _saveAllData();
              Navigator.pop(context);
            },
            child: const Text('مسح', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _clearAllSupportData() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('مسح بيانات المساند'),
        content: const Text('هل أنت متأكد من مسح جميع بيانات المساند؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          TextButton(
            onPressed: () {
              setState(() {
                for (var col in supportColumns) {
                  col.heightController.clear();
                  col.quantityController.clear();
                  col.discountController.clear();
                }
              });
              _saveAllData();
              Navigator.pop(context);
            },
            child: const Text('مسح', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _editMattressColumn(int index) {
    final col = mattressColumns[index];
    final nameController = TextEditingController(text: col.name);
    final lengthController = TextEditingController(text: col.lengthCM.toString());
    final widthController = TextEditingController(text: col.widthCM.toString());
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تعديل العمود'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'اسم العمود', border: OutlineInputBorder()),
              textAlign: TextAlign.right,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: lengthController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'الطول (سم)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: widthController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'العرض (سم)', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          TextButton(
            onPressed: () {
              String newName = nameController.text.trim();
              if (newName.isNotEmpty) col.name = newName;
              
              double? newLength = double.tryParse(lengthController.text);
              if (newLength != null && newLength > 0) col.lengthCM = newLength;
              
              double? newWidth = double.tryParse(widthController.text);
              if (newWidth != null && newWidth > 0) col.widthCM = newWidth;
              
              setState(() {});
              _saveAllData();
              Navigator.pop(context);
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  void _editSupportColumn(int index) {
    final col = supportColumns[index];
    final nameController = TextEditingController(text: col.name);
    final lengthController = TextEditingController(text: col.lengthCM.toString());
    final thicknessController = TextEditingController(text: col.thicknessCM.toString());
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تعديل العمود'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'اسم العمود', border: OutlineInputBorder()),
              textAlign: TextAlign.right,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: lengthController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'الطول (سم)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: thicknessController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'السماكة (سم)', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          TextButton(
            onPressed: () {
              String newName = nameController.text.trim();
              if (newName.isNotEmpty) col.name = newName;
              
              double? newLength = double.tryParse(lengthController.text);
              if (newLength != null && newLength > 0) col.lengthCM = newLength;
              
              double? newThickness = double.tryParse(thicknessController.text);
              if (newThickness != null && newThickness > 0) col.thicknessCM = newThickness;
              
              setState(() {});
              _saveAllData();
              Navigator.pop(context);
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  void _addNewMattressType() {
    final nameController = TextEditingController();
    final priceController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إضافة نوع إسفنج جديد'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'اسم النوع', border: OutlineInputBorder()),
              textAlign: TextAlign.right,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: priceController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'السعر (\$/م³)', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          TextButton(
            onPressed: () {
              String newName = nameController.text.trim();
              double? newPrice = double.tryParse(priceController.text);
              
              if (newName.isNotEmpty && newPrice != null && newPrice > 0) {
                setState(() {
                  mattressTypes.add(MattressType(name: newName, price: newPrice));
                });
                _saveAllData();
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('تم إضافة النوع بنجاح'), backgroundColor: Colors.green),
                );
              }
            },
            child: const Text('إضافة'),
          ),
        ],
      ),
    );
  }

  void _addNewSupportType() {
    final nameController = TextEditingController();
    final priceController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إضافة نوع مسند جديد'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'اسم النوع', border: OutlineInputBorder()),
              textAlign: TextAlign.right,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: priceController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'السعر (\$/م³)', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          TextButton(
            onPressed: () {
              String newName = nameController.text.trim();
              double? newPrice = double.tryParse(priceController.text);
              
              if (newName.isNotEmpty && newPrice != null && newPrice > 0) {
                setState(() {
                  supportTypes.add(SupportType(name: newName, price: newPrice));
                });
                _saveAllData();
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('تم إضافة النوع بنجاح'), backgroundColor: Colors.green),
                );
              }
            },
            child: const Text('إضافة'),
          ),
        ],
      ),
    );
  }

  // ==================== دوال PDF ====================
  
  Future<void> _shareMattressPDF() async {
    if (getMattressGrandTotal() == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا توجد بيانات للمشاركة'), backgroundColor: Colors.orange),
      );
      return;
    }
    
    try {
      final pdf = pw.Document();
      final fontData = await rootBundle.load('assets/fonts/Cairo-Regular.ttf');
      final fontBoldData = await rootBundle.load('assets/fonts/Cairo-Bold.ttf');
      final ttf = pw.Font.ttf(fontData);
      final ttfBold = pw.Font.ttf(fontBoldData);
      
      pdf.addPage(
        pw.MultiPage(
          textDirection: pw.TextDirection.rtl,
          build: (context) => [
            pw.Header(
              level: 0,
              child: pw.Text('قسم الفرشات - فاتورة',
                style: pw.TextStyle(font: ttfBold, fontSize: 24)
              )
            ),
            pw.SizedBox(height: 10),
            pw.Text('التاريخ: $currentDate', style: pw.TextStyle(font: ttf, fontSize: 12)),
            pw.Text('نوع الإسفنج: ${selectedMattressType?.name ?? ""} (${selectedMattressType?.price ?? 0} \$/م³)', style: pw.TextStyle(font: ttf, fontSize: 12)),
            pw.Text('سعر الدولار: ${mattressDollarPrice > 0 ? _formatNumber(mattressDollarPrice) : "لم يتم إدخاله"} ل.س', style: pw.TextStyle(font: ttf, fontSize: 12)),
            pw.SizedBox(height: 20),
            pw.Table(
              border: pw.TableBorder.all(),
              children: [
                pw.TableRow(children: [
                  pw.Text('العمود', style: pw.TextStyle(font: ttfBold)),
                  pw.Text('الطول', style: pw.TextStyle(font: ttfBold)),
                  pw.Text('العرض', style: pw.TextStyle(font: ttfBold)),
                  pw.Text('الارتفاع', style: pw.TextStyle(font: ttfBold)),
                  pw.Text('العدد', style: pw.TextStyle(font: ttfBold)),
                  pw.Text('الخصم %', style: pw.TextStyle(font: ttfBold)),
                  pw.Text('الإجمالي (\$)', style: pw.TextStyle(font: ttfBold)),
                ]),
                for (var col in mattressColumns)
                  pw.TableRow(children: [
                    pw.Text(col.name, style: pw.TextStyle(font: ttf)),
                    pw.Text(col.lengthCM.toString(), style: pw.TextStyle(font: ttf)),
                    pw.Text(col.widthCM.toString(), style: pw.TextStyle(font: ttf)),
                    pw.Text(col.heightController.text.isEmpty ? '0' : col.heightController.text, style: pw.TextStyle(font: ttf)),
                    pw.Text(col.quantityController.text.isEmpty ? '1' : col.quantityController.text, style: pw.TextStyle(font: ttf)),
                    pw.Text(col.discountController.text.isEmpty ? '0' : col.discountController.text, style: pw.TextStyle(font: ttf)),
                    pw.Text(calculateMattressTotal(col).toStringAsFixed(2), style: pw.TextStyle(font: ttf)),
                  ]),
              ],
            ),
            pw.SizedBox(height: 20),
            pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
              pw.Text('الإجمالي بالدولار:', style: pw.TextStyle(font: ttfBold)),
              pw.Text('\$${_formatNumber(getMattressGrandTotal())}', style: pw.TextStyle(font: ttf)),
            ]),
            if (mattressDollarPrice > 0)
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                pw.Text('الإجمالي بالليرة:', style: pw.TextStyle(font: ttfBold)),
                pw.Text('${_formatNumber(getMattressGrandTotalSYP())} ل.س', style: pw.TextStyle(font: ttf)),
              ]),
          ],
        ),
      );
      
      final output = await getTemporaryDirectory();
      final file = File('${output.path}/mattress_invoice.pdf');
      await file.writeAsBytes(await pdf.save());
      await Share.shareXFiles([XFile(file.path)], text: 'فاتورة الفرشات - $currentDate');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _shareSupportPDF() async {
    if (getSupportGrandTotal() == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا توجد بيانات للمشاركة'), backgroundColor: Colors.orange),
      );
      return;
    }
    
    try {
      final pdf = pw.Document();
      final fontData = await rootBundle.load('assets/fonts/Cairo-Regular.ttf');
      final fontBoldData = await rootBundle.load('assets/fonts/Cairo-Bold.ttf');
      final ttf = pw.Font.ttf(fontData);
      final ttfBold = pw.Font.ttf(fontBoldData);
      
      pdf.addPage(
        pw.MultiPage(
          textDirection: pw.TextDirection.rtl,
          build: (context) => [
            pw.Header(
              level: 0,
              child: pw.Text('قسم المساند - فاتورة',
                style: pw.TextStyle(font: ttfBold, fontSize: 24)
              )
            ),
            pw.SizedBox(height: 10),
            pw.Text('التاريخ: $currentDate', style: pw.TextStyle(font: ttf, fontSize: 12)),
            pw.Text('نوع المسند: ${selectedSupportType?.name ?? ""} (${selectedSupportType?.price ?? 0} \$/م³)', style: pw.TextStyle(font: ttf, fontSize: 12)),
            pw.Text('سعر الدولار: ${supportDollarPrice > 0 ? _formatNumber(supportDollarPrice) : "لم يتم إدخاله"} ل.س', style: pw.TextStyle(font: ttf, fontSize: 12)),
            pw.SizedBox(height: 20),
            pw.Table(
              border: pw.TableBorder.all(),
              children: [
                pw.TableRow(children: [
                  pw.Text('العمود', style: pw.TextStyle(font: ttfBold)),
                  pw.Text('الطول', style: pw.TextStyle(font: ttfBold)),
                  pw.Text('السماكة', style: pw.TextStyle(font: ttfBold)),
                  pw.Text('الارتفاع', style: pw.TextStyle(font: ttfBold)),
                  pw.Text('العدد', style: pw.TextStyle(font: ttfBold)),
                  pw.Text('الخصم %', style: pw.TextStyle(font: ttfBold)),
                  pw.Text('الإجمالي (\$)', style: pw.TextStyle(font: ttfBold)),
                ]),
                for (var col in supportColumns)
                  pw.TableRow(children: [
                    pw.Text(col.name, style: pw.TextStyle(font: ttf)),
                    pw.Text(col.lengthCM.toString(), style: pw.TextStyle(font: ttf)),
                    pw.Text(col.thicknessCM.toString(), style: pw.TextStyle(font: ttf)),
                    pw.Text(col.heightController.text.isEmpty ? '0' : col.heightController.text, style: pw.TextStyle(font: ttf)),
                    pw.Text(col.quantityController.text.isEmpty ? '1' : col.quantityController.text, style: pw.TextStyle(font: ttf)),
                    pw.Text(col.discountController.text.isEmpty ? '0' : col.discountController.text, style: pw.TextStyle(font: ttf)),
                    pw.Text(calculateSupportTotal(col).toStringAsFixed(2), style: pw.TextStyle(font: ttf)),
                  ]),
              ],
            ),
            pw.SizedBox(height: 20),
            pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
              pw.Text('الإجمالي بالدولار:', style: pw.TextStyle(font: ttfBold)),
              pw.Text('\$${_formatNumber(getSupportGrandTotal())}', style: pw.TextStyle(font: ttf)),
            ]),
            if (supportDollarPrice > 0)
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                pw.Text('الإجمالي بالليرة:', style: pw.TextStyle(font: ttfBold)),
                pw.Text('${_formatNumber(getSupportGrandTotalSYP())} ل.س', style: pw.TextStyle(font: ttf)),
              ]),
          ],
        ),
      );
      
      final output = await getTemporaryDirectory();
      final file = File('${output.path}/support_invoice.pdf');
      await file.writeAsBytes(await pdf.save());
      await Share.shareXFiles([XFile(file.path)], text: 'فاتورة المساند - $currentDate');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ: $e'), backgroundColor: Colors.red),
      );
    }
  }

  // ==================== واجهة المستخدم ====================
  
  @override
  Widget build(BuildContext context) {
    final grandTotalUSD = getMattressGrandTotal() + getSupportGrandTotal();
    final grandTotalSYP = getMattressGrandTotalSYP() + getSupportGrandTotalSYP();
    
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '🏭 أبو ماهر',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 22,
            letterSpacing: 1,
          ),
        ),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 4,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          unselectedLabelStyle: const TextStyle(fontSize: 14),
          tabs: const [
            Tab(icon: Icon(Icons.bed), text: 'الفرشات'),
            Tab(icon: Icon(Icons.chair), text: 'المساند'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.folder),
            onPressed: _showTemplatesMenu,
            tooltip: 'القوالب المحفوظة',
          ),
          IconButton(
            icon: const Icon(Icons.receipt_long),
            onPressed: _showFinalInvoice,
            tooltip: 'الفاتورة النهائية',
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'save_template') {
                _saveAsTemplate();
              } else if (value == 'add_mattress_type') {
                _addNewMattressType();
              } else if (value == 'add_support_type') {
                _addNewSupportType();
              } else if (value == 'share_mattress') {
                _shareMattressPDF();
              } else if (value == 'share_support') {
                _shareSupportPDF();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'save_template',
                child: Row(children: [Icon(Icons.save, size: 20), SizedBox(width: 8), Text('حفظ كقالب')]),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'add_mattress_type',
                child: Row(children: [Icon(Icons.add_circle, size: 20, color: Colors.teal), SizedBox(width: 8), Text('إضافة نوع إسفنج')]),
              ),
              const PopupMenuItem(
                value: 'add_support_type',
                child: Row(children: [Icon(Icons.add_circle, size: 20, color: Colors.orange), SizedBox(width: 8), Text('إضافة نوع مسند')]),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'share_mattress',
                child: Row(children: [Icon(Icons.share, size: 20, color: Colors.teal), SizedBox(width: 8), Text('مشاركة فاتورة الفرشات')]),
              ),
              const PopupMenuItem(
                value: 'share_support',
                child: Row(children: [Icon(Icons.share, size: 20, color: Colors.orange), SizedBox(width: 8), Text('مشاركة فاتورة المساند')]),
              ),
            ],
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildMattressTab(),
          _buildSupportTab(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          if (_tabController.index == 0) {
            _addMattressColumn();
          } else {
            _addSupportColumn();
          }
        },
        icon: const Icon(Icons.add),
        label: Text(_tabController.index == 0 ? 'إضافة فرشة' : 'إضافة مسند'),
        backgroundColor: _tabController.index == 0 ? Colors.teal : Colors.orange,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withValues(alpha: 0.3),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildTotalCard(
                  'إجمالي الدولار',
                  '\$${_formatNumber(grandTotalUSD)}',
                  Colors.green,
                  Icons.attach_money,
                ),
                _buildTotalCard(
                  'إجمالي الليرة',
                  '${_formatNumber(grandTotalSYP)} ل.س',
                  Colors.blue,
                  Icons.account_balance_wallet,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _showFinalInvoice,
                    icon: const Icon(Icons.receipt, size: 20),
                    label: const Text(
                      'عرض الفاتورة النهائية',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 4,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTotalCard(String label, String value, Color color, IconData icon) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [color.withValues(alpha: 0.1), color.withValues(alpha: 0.05)],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500)),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildMattressTab() {
    return Container(
      color: Colors.grey.shade50,
      child: Column(
        children: [
          _buildTopBarMattress(),
          Expanded(
            child: mattressColumns.isEmpty
                ? _buildEmptyState(Icons.bed, 'لا توجد فرشات', _addMattressColumn)
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: mattressColumns.asMap().entries.map((entry) {
                            return _buildMattressCard(entry.key, entry.value);
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBarMattress() {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [Colors.teal.shade600, Colors.teal.shade400]),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.teal.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.calendar_today, color: Colors.white70, size: 16),
              const SizedBox(width: 8),
              Text(currentDate, style: const TextStyle(color: Colors.white, fontSize: 14)),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.delete_sweep, color: Colors.white70, size: 20),
                onPressed: _clearAllMattressData,
                tooltip: 'مسح البيانات',
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                  child: DropdownButton<MattressType>(
                    value: selectedMattressType,
                    isExpanded: true,
                    hint: const Text('اختر نوع الإسفنج'),
                    underline: const SizedBox(),
                    items: mattressTypes.map((type) {
                      return DropdownMenuItem(
                        value: type,
                        child: Text('${type.name} - ${type.price} \$/م³'),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() => selectedMattressType = value);
                      _saveAllData();
                    },
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                child: Row(
                  children: [
                    const Text('💵', style: TextStyle(fontSize: 16)),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 100,
                      child: TextField(
                        controller: mattressDollarController,
                        keyboardType: TextInputType.number,
                        onChanged: (value) {
                          setState(() {
                            mattressDollarPrice = double.tryParse(value) ?? 0;
                          });
                          _saveAllData();
                        },
                        decoration: const InputDecoration(
                          hintText: 'سعر الدولار',
                          border: InputBorder.none,
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMattressCard(int index, MattressColumnData col) {
    final totalUSD = calculateMattressTotal(col);
    
    return Container(
      width: 200,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.teal.withValues(alpha: 0.1), blurRadius: 8, offset: const Offset(0, 2))],
        border: Border.all(color: Colors.teal.shade100),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [Colors.teal.shade600, Colors.teal.shade500]),
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(col.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16), textAlign: TextAlign.center),
                ),
                if (!col.isFixed)
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.white70, size: 18),
                    onPressed: () => _editMattressColumn(index),
                  ),
                if (!col.isFixed)
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.white70, size: 18),
                    onPressed: () => _removeMattressColumn(index),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.teal.shade50, borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.straighten, size: 16, color: Colors.teal),
                      const SizedBox(width: 4),
                      Text('${col.lengthCM} × ${col.widthCM} سم', style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _buildInputField(controller: col.heightController, label: 'الارتفاع', icon: Icons.height, onChanged: (_) => setState(() {})),
                const SizedBox(height: 8),
                _buildInputField(controller: col.quantityController, label: 'العدد', icon: Icons.numbers, hint: '1', onChanged: (_) => setState(() {})),
                const SizedBox(height: 8),
                _buildInputField(controller: col.discountController, label: 'الخصم %', icon: Icons.discount, hint: '0', onChanged: (_) => setState(() {})),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [Colors.green.shade100, Colors.green.shade50]),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Column(
                    children: [
                      Text('الإجمالي', style: TextStyle(fontSize: 12, color: Colors.green.shade700)),
                      Text('\$${_formatNumber(totalUSD)}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green.shade800)),
                      if (mattressDollarPrice > 0)
                        Text('${_formatNumber(totalUSD * mattressDollarPrice)} ل.س', style: TextStyle(fontSize: 12, color: Colors.blue.shade700)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSupportTab() {
    return Container(
      color: Colors.grey.shade50,
      child: Column(
        children: [
          _buildTopBarSupport(),
          Expanded(
            child: supportColumns.isEmpty
                ? _buildEmptyState(Icons.chair, 'لا توجد مساند', _addSupportColumn)
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: supportColumns.asMap().entries.map((entry) {
                            return _buildSupportCard(entry.key, entry.value);
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBarSupport() {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [Colors.orange.shade600, Colors.orange.shade400]),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.orange.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.calendar_today, color: Colors.white70, size: 16),
              const SizedBox(width: 8),
              Text(currentDate, style: const TextStyle(color: Colors.white, fontSize: 14)),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.delete_sweep, color: Colors.white70, size: 20),
                onPressed: _clearAllSupportData,
                tooltip: 'مسح البيانات',
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                  child: DropdownButton<SupportType>(
                    value: selectedSupportType,
                    isExpanded: true,
                    hint: const Text('اختر نوع المسند'),
                    underline: const SizedBox(),
                    items: supportTypes.map((type) {
                      return DropdownMenuItem(
                        value: type,
                        child: Text('${type.name} - ${type.price} \$/م³'),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() => selectedSupportType = value);
                      _saveAllData();
                    },
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                child: Row(
                  children: [
                    const Text('💵', style: TextStyle(fontSize: 16)),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 100,
                      child: TextField(
                        controller: supportDollarController,
                        keyboardType: TextInputType.number,
                        onChanged: (value) {
                          setState(() {
                            supportDollarPrice = double.tryParse(value) ?? 0;
                          });
                          _saveAllData();
                        },
                        decoration: const InputDecoration(
                          hintText: 'سعر الدولار',
                          border: InputBorder.none,
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSupportCard(int index, SupportColumnData col) {
    final totalUSD = calculateSupportTotal(col);
    
    return Container(
      width: 200,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.orange.withValues(alpha: 0.1), blurRadius: 8, offset: const Offset(0, 2))],
        border: Border.all(color: Colors.orange.shade100),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [Colors.orange.shade600, Colors.orange.shade500]),
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(col.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16), textAlign: TextAlign.center),
                ),
                if (!col.isFixed)
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.white70, size: 18),
                    onPressed: () => _editSupportColumn(index),
                  ),
                if (!col.isFixed)
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.white70, size: 18),
                    onPressed: () => _removeSupportColumn(index),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.straighten, size: 16, color: Colors.orange),
                      const SizedBox(width: 4),
                      Text('${col.lengthCM} × ${col.thicknessCM} سم', style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _buildInputField(controller: col.heightController, label: 'الارتفاع', icon: Icons.height, onChanged: (_) => setState(() {})),
                const SizedBox(height: 8),
                _buildInputField(controller: col.quantityController, label: 'العدد', icon: Icons.numbers, hint: '1', onChanged: (_) => setState(() {})),
                const SizedBox(height: 8),
                _buildInputField(controller: col.discountController, label: 'الخصم %', icon: Icons.discount, hint: '0', onChanged: (_) => setState(() {})),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [Colors.green.shade100, Colors.green.shade50]),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Column(
                    children: [
                      Text('الإجمالي', style: TextStyle(fontSize: 12, color: Colors.green.shade700)),
                      Text('\$${_formatNumber(totalUSD)}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green.shade800)),
                      if (supportDollarPrice > 0)
                        Text('${_formatNumber(totalUSD * supportDollarPrice)} ل.س', style: TextStyle(fontSize: 12, color: Colors.blue.shade700)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String hint = '0',
    required Function(String) onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon, size: 18),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          isDense: true,
        ),
      ),
    );
  }

  Widget _buildEmptyState(IconData icon, String message, VoidCallback onAdd) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(message, style: TextStyle(fontSize: 18, color: Colors.grey.shade600)),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text('إضافة جديد'),
          ),
        ],
      ),
    );
  }
}