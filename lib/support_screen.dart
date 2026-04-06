// lib/support_screen.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'accounting_table_screen.dart';
import 'final_invoice_screen.dart';

class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  final List<SupportColumnData> columns = [];
  
  final List<SupportFixedColumn> fixedColumns = [
    SupportFixedColumn(name: 'العمود 1', lengthCM: 200, thicknessCM: 10),
    SupportFixedColumn(name: 'العمود 2', lengthCM: 180, thicknessCM: 10),
    SupportFixedColumn(name: 'العمود 3', lengthCM: 160, thicknessCM: 10),
    SupportFixedColumn(name: 'العمود 4', lengthCM: 140, thicknessCM: 10),
  ];
  
  List<SupportType> supportTypes = [];
  SupportType? selectedSupportType;
  
  final TextEditingController dollarPriceController = TextEditingController();
  double dollarPrice = 0.0;
  String? dollarPriceError;
  String currentDate = '';
  
  @override
  void initState() {
    super.initState();
    _loadSavedData();
    _updateDate();
    _initializeColumns();
  }
  
  void _initializeSupportTypes() {
    if (supportTypes.isEmpty) {
      supportTypes = [
        SupportType(name: 'سوبر اول مميز', price: 2.85),
        SupportType(name: 'سوفت', price: 2.70),
        SupportType(name: 'سوبر ثقيل مميز', price: 3.00),
        SupportType(name: 'ممتاز اول مميز', price: 2.15),
        SupportType(name: 'سوبر اول', price: 2.65),
      ];
    }
  }
  
  void _initializeColumns() {
    for (var fixed in fixedColumns) {
      columns.add(SupportColumnData(
        name: fixed.name,
        lengthCM: fixed.lengthCM,
        thicknessCM: fixed.thicknessCM,
        heightController: TextEditingController(),
        quantityController: TextEditingController(),
        discountController: TextEditingController(),
        isFixed: true,
      ));
    }
    _loadCustomColumns();
  }
  
  void _loadCustomColumns() async {
    final prefs = await SharedPreferences.getInstance();
    int customCount = prefs.getInt('support_custom_columns_count') ?? 0;
    
    for (int i = 0; i < customCount; i++) {
      String? name = prefs.getString('support_custom_column_name_$i');
      double? length = prefs.getDouble('support_custom_column_length_$i');
      double? thickness = prefs.getDouble('support_custom_column_thickness_$i');
      
      if (name != null && length != null && thickness != null) {
        columns.add(SupportColumnData(
          name: name,
          lengthCM: length,
          thicknessCM: thickness,
          heightController: TextEditingController(),
          quantityController: TextEditingController(),
          discountController: TextEditingController(),
          isFixed: false,
        ));
        
        String? height = prefs.getString('support_custom_column_height_$i');
        String? quantity = prefs.getString('support_custom_column_quantity_$i');
        String? discount = prefs.getString('support_custom_column_discount_$i');
        
        if (height != null) columns.last.heightController.text = height;
        if (quantity != null) columns.last.quantityController.text = quantity;
        if (discount != null) columns.last.discountController.text = discount;
      }
    }
  }
  
  void _addCustomColumn() {
    setState(() {
      columns.add(SupportColumnData(
        name: 'عمود جديد',
        lengthCM: 100,
        thicknessCM: 10,
        heightController: TextEditingController(),
        quantityController: TextEditingController(),
        discountController: TextEditingController(),
        isFixed: false,
      ));
    });
    _saveCustomColumns();
    Future.delayed(Duration.zero, () {
      _showEditColumnDialog(columns.length - 1);
    });
  }
  
  void _removeColumn(int index) {
    if (columns[index].isFixed) {
      _showSnackBar('لا يمكن حذف عمود ثابت', Colors.orange);
      return;
    }
    
    _showConfirmDialog(
      title: 'حذف العمود',
      message: 'هل أنت متأكد من حذف "${columns[index].name}"؟',
      onConfirm: () {
        setState(() {
          columns[index].dispose();
          columns.removeAt(index);
        });
        _saveCustomColumns();
      },
    );
  }
  
  void _showEditColumnDialog(int index) {
    final nameController = TextEditingController(text: columns[index].name);
    final lengthController = TextEditingController(text: columns[index].lengthCM.toString());
    final thicknessController = TextEditingController(text: columns[index].thicknessCM.toString());
    
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
          TextButton(onPressed: () {
            String newName = nameController.text.trim();
            if (newName.isNotEmpty) columns[index].name = newName;
            
            double? newLength = double.tryParse(lengthController.text);
            if (newLength != null && newLength > 0) columns[index].lengthCM = newLength;
            
            double? newThickness = double.tryParse(thicknessController.text);
            if (newThickness != null && newThickness > 0) columns[index].thicknessCM = newThickness;
            
            setState(() {});
            _saveCustomColumns();
            Navigator.pop(context);
            _showSnackBar('تم تحديث العمود', Colors.green);
          }, child: const Text('حفظ')),
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
          TextButton(onPressed: () {
            String newName = nameController.text.trim();
            double? newPrice = double.tryParse(priceController.text);
            
            if (newName.isNotEmpty && newPrice != null && newPrice > 0) {
              setState(() {
                supportTypes.add(SupportType(name: newName, price: newPrice));
                if (selectedSupportType == null) {
                  selectedSupportType = supportTypes.last;
                }
              });
              _saveSupportTypes();
              _showSnackBar('تم إضافة النوع بنجاح', Colors.green);
            } else {
              _showSnackBar('الرجاء إدخال اسم وسعر صحيحين', Colors.red);
            }
            Navigator.pop(context);
          }, child: const Text('إضافة')),
        ],
      ),
    );
  }
  
  void _editSupportType(SupportType type, int index) {
    final nameController = TextEditingController(text: type.name);
    final priceController = TextEditingController(text: type.price.toString());
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('تعديل نوع "${type.name}"'),
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
          TextButton(onPressed: () {
            String newName = nameController.text.trim();
            double? newPrice = double.tryParse(priceController.text);
            
            if (newName.isNotEmpty && newPrice != null && newPrice > 0) {
              setState(() {
                supportTypes[index] = SupportType(name: newName, price: newPrice);
                if (selectedSupportType?.name == type.name) {
                  selectedSupportType = supportTypes[index];
                }
              });
              _saveSupportTypes();
              _showSnackBar('تم تعديل النوع بنجاح', Colors.green);
            } else {
              _showSnackBar('الرجاء إدخال اسم وسعر صحيحين', Colors.red);
            }
            Navigator.pop(context);
          }, child: const Text('حفظ')),
        ],
      ),
    );
  }
  
  void _deleteSupportType(SupportType type, int index) {
    if (supportTypes.length <= 1) {
      _showSnackBar('لا يمكن حذف النوع الوحيد المتبقي', Colors.orange);
      return;
    }
    
    _showConfirmDialog(
      title: 'حذف النوع',
      message: 'هل أنت متأكد من حذف نوع "${type.name}"؟',
      onConfirm: () {
        setState(() {
          supportTypes.removeAt(index);
          if (selectedSupportType?.name == type.name) {
            selectedSupportType = supportTypes.first;
          }
        });
        _saveSupportTypes();
        _showSnackBar('تم حذف النوع بنجاح', Colors.green);
      },
    );
  }
  
  Future<void> _saveSupportTypes() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> names = [];
    List<String> prices = [];
    for (var type in supportTypes) {
      names.add(type.name);
      prices.add(type.price.toString());
    }
    await prefs.setStringList('support_names', names);
    await prefs.setStringList('support_prices', prices);
    if (selectedSupportType != null) {
      await prefs.setString('selected_support_type', selectedSupportType!.name);
    }
  }
  
  Future<void> _loadSupportTypes() async {
    final prefs = await SharedPreferences.getInstance();
    List<String>? names = prefs.getStringList('support_names');
    List<String>? pricesStr = prefs.getStringList('support_prices');
    
    if (names != null && pricesStr != null && names.isNotEmpty) {
      supportTypes = [];
      for (int i = 0; i < names.length; i++) {
        double price = double.tryParse(pricesStr[i]) ?? 0.0;
        supportTypes.add(SupportType(name: names[i], price: price));
      }
    } else {
      _initializeSupportTypes();
    }
    
    String savedSupportType = prefs.getString('selected_support_type') ?? supportTypes.first.name;
    var found = supportTypes.firstWhere((t) => t.name == savedSupportType, orElse: () => supportTypes.first);
    selectedSupportType = found;
  }
  
  void _updateDate() {
    final now = DateTime.now();
    setState(() {
      currentDate = '${now.year}/${now.month}/${now.day} - ${now.hour}:${now.minute}:${now.second}';
    });
  }
  
  Future<void> _loadSavedData() async {
    final prefs = await SharedPreferences.getInstance();
    
    double savedDollarPrice = prefs.getDouble('support_dollar_price') ?? 0.0;
    setState(() {
      dollarPrice = savedDollarPrice;
      if (savedDollarPrice > 0) {
        dollarPriceController.text = savedDollarPrice.toString();
      }
    });
    
    await _loadSupportTypes();
  }
  
  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('support_dollar_price', dollarPrice);
    if (selectedSupportType != null) {
      await prefs.setString('selected_support_type', selectedSupportType!.name);
    }
    await _saveCustomColumns();
  }
  
  Future<void> _saveCustomColumns() async {
    final prefs = await SharedPreferences.getInstance();
    
    int customIndex = 0;
    for (int i = 0; i < columns.length; i++) {
      if (!columns[i].isFixed) {
        await prefs.setString('support_custom_column_name_$customIndex', columns[i].name);
        await prefs.setDouble('support_custom_column_length_$customIndex', columns[i].lengthCM);
        await prefs.setDouble('support_custom_column_thickness_$customIndex', columns[i].thicknessCM);
        await prefs.setString('support_custom_column_height_$customIndex', columns[i].heightController.text);
        await prefs.setString('support_custom_column_quantity_$customIndex', columns[i].quantityController.text);
        await prefs.setString('support_custom_column_discount_$customIndex', columns[i].discountController.text);
        customIndex++;
      }
    }
    await prefs.setInt('support_custom_columns_count', customIndex);
  }
  
  double calculateVolume(SupportColumnData col) {
    double height = double.tryParse(col.heightController.text) ?? 0;
    if (height <= 0) return 0;
    double volumeCM = col.lengthCM * col.thicknessCM * height;
    return volumeCM / 20000;
  }
  
  double calculateTotalUSD(SupportColumnData col) {
    if (selectedSupportType == null) return 0;
    double volumeValue = calculateVolume(col);
    if (volumeValue <= 0) return 0;
    
    double quantity = double.tryParse(col.quantityController.text) ?? 1;
    if (quantity <= 0) quantity = 1;
    
    double discountPercent = double.tryParse(col.discountController.text) ?? 0;
    if (discountPercent < 0) discountPercent = 0;
    if (discountPercent > 100) discountPercent = 100;
    
    double totalBeforeDiscount = quantity * volumeValue * selectedSupportType!.price;
    double totalAfterDiscount = totalBeforeDiscount * (1 - discountPercent / 100);
    
    return totalAfterDiscount;
  }
  
  double calculateTotalSYP(SupportColumnData col) {
    return calculateTotalUSD(col) * dollarPrice;
  }
  
  double getGrandTotalUSD() {
    double sum = 0;
    for (var col in columns) {
      sum += calculateTotalUSD(col);
    }
    return sum;
  }
  
  double getGrandTotalSYP() {
    double sum = 0;
    for (var col in columns) {
      sum += calculateTotalSYP(col);
    }
    return sum;
  }
  
  double getTotalVolume() {
    double sum = 0;
    for (var col in columns) {
      sum += calculateVolume(col);
    }
    return sum;
  }
  
  List<InvoiceItem> getInvoiceItems() {
    List<InvoiceItem> items = [];
    for (var col in columns) {
      double height = double.tryParse(col.heightController.text) ?? 0;
      double quantity = double.tryParse(col.quantityController.text) ?? 1;
      double discount = double.tryParse(col.discountController.text) ?? 0;
      double totalUSD = calculateTotalUSD(col);
      double totalSYP = calculateTotalSYP(col);
      
      if (height > 0 && totalUSD > 0) {
        items.add(InvoiceItem(
          section: 'المساند',
          type: selectedSupportType?.name ?? '',
          dimensions: '${col.lengthCM} × ${col.thicknessCM}',
          height: height,
          quantity: quantity,
          discount: discount,
          totalUSD: totalUSD,
          totalSYP: totalSYP,
        ));
      }
    }
    return items;
  }
  
  String getCurrentSupportType() {
    return selectedSupportType?.name ?? '';
  }
  
  double getCurrentDollarPrice() {
    return dollarPrice;
  }
  
  void _showFinalInvoice() async {
    final prefs = await SharedPreferences.getInstance();
    
    List<String> supportItemsJson = [];
    for (var item in getInvoiceItems()) {
      supportItemsJson.add(jsonEncode({
        'section': item.section,
        'type': item.type,
        'dimensions': item.dimensions,
        'height': item.height,
        'quantity': item.quantity,
        'discount': item.discount,
        'totalUSD': item.totalUSD,
        'totalSYP': item.totalSYP,
      }));
    }
    await prefs.setStringList('temp_support_items', supportItemsJson);
    await prefs.setDouble('temp_support_dollar_price', dollarPrice);
    await prefs.setString('temp_support_type', getCurrentSupportType());
    
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const FinalInvoiceScreen()),
    );
  }
  
  String _formatNumber(double number) {
    if (number == 0) return '0';
    final formatter = NumberFormat.decimalPattern('ar');
    return formatter.format(number);
  }
  
  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }
  
  void _showConfirmDialog({required String title, required String message, required VoidCallback onConfirm}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          TextButton(onPressed: () { Navigator.pop(context); onConfirm(); }, child: const Text('تأكيد', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
  }
  
  void _clearAllData() {
    _showConfirmDialog(
      title: 'مسح جميع البيانات',
      message: 'هل أنت متأكد من مسح جميع البيانات؟ لا يمكن التراجع عن هذا الإجراء.',
      onConfirm: () {
        setState(() {
          for (var col in columns) {
            col.heightController.clear();
            col.quantityController.clear();
            col.discountController.clear();
          }
          dollarPriceController.clear();
          dollarPrice = 0;
        });
        _saveData();
        _showSnackBar('تم مسح جميع البيانات', Colors.green);
      },
    );
  }
  
  Future<void> _sharePDF() async {
    if (getGrandTotalUSD() == 0) {
      _showSnackBar('لا توجد بيانات للمشاركة', Colors.orange);
      return;
    }
    
    try {
      final pdf = pw.Document();
      
      pdf.addPage(
        pw.MultiPage(
          build: (context) => [
            pw.Header(level: 0, child: pw.Text('قسم المساند - فاتورة', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold))),
            pw.SizedBox(height: 10),
            pw.Text('التاريخ: $currentDate', style: pw.TextStyle(fontSize: 12)),
            pw.Text('نوع المسند: ${selectedSupportType?.name ?? "غير محدد"} (${selectedSupportType?.price ?? 0} \$/م³)', style: pw.TextStyle(fontSize: 12)),
            pw.Text('سعر الدولار: ${dollarPrice > 0 ? _formatNumber(dollarPrice) : "لم يتم إدخاله"} ل.س', style: pw.TextStyle(fontSize: 12)),
            pw.SizedBox(height: 20),
            pw.Table(
              border: pw.TableBorder.all(),
              children: [
                pw.TableRow(children: [
                  pw.Text('العمود', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.Text('الطول (سم)', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.Text('السماكة (سم)', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.Text('الارتفاع (سم)', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.Text('العدد', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.Text('الخصم %', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.Text('الإجمالي (\$)', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                ]),
                for (var col in columns)
                  pw.TableRow(children: [
                    pw.Text(col.name),
                    pw.Text(col.lengthCM.toString()),
                    pw.Text(col.thicknessCM.toString()),
                    pw.Text(col.heightController.text.isEmpty ? '0' : col.heightController.text),
                    pw.Text(col.quantityController.text.isEmpty ? '1' : col.quantityController.text),
                    pw.Text(col.discountController.text.isEmpty ? '0' : col.discountController.text),
                    pw.Text(calculateTotalUSD(col).toStringAsFixed(2)),
                  ]),
              ],
            ),
            pw.SizedBox(height: 20),
            pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
              pw.Text('إجمالي الحجم:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.Text('${_formatNumber(getTotalVolume())}'),
            ]),
            pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
              pw.Text('الإجمالي بالدولار:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.Text('\$${_formatNumber(getGrandTotalUSD())}'),
            ]),
            if (dollarPrice > 0)
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                pw.Text('الإجمالي بالليرة:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.Text('${_formatNumber(getGrandTotalSYP())} ل.س'),
              ]),
          ],
        ),
      );
      
      final output = await getTemporaryDirectory();
      final file = File('${output.path}/support_invoice.pdf');
      await file.writeAsBytes(await pdf.save());
      
      await Share.shareXFiles([XFile(file.path)], text: 'فاتورة المساند - $currentDate');
      _showSnackBar('تم مشاركة الفاتورة بنجاح', Colors.green);
    } catch (e) {
      _showSnackBar('حدث خطأ: $e', Colors.red);
    }
  }
  
  void updateAllCalculations() {
    setState(() {});
    _saveData();
  }
  
  @override
  void dispose() {
    for (var col in columns) {
      col.dispose();
    }
    dollarPriceController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('قسم المساند', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const AccountingTableScreen()),
              );
            },
            tooltip: 'الرجوع إلى قسم الفرشات',
          ),
          IconButton(icon: const Icon(Icons.delete_sweep), onPressed: _clearAllData, tooltip: 'مسح الكل'),
          IconButton(icon: const Icon(Icons.add_box), onPressed: _addCustomColumn, tooltip: 'إضافة عمود جديد'),
          IconButton(icon: const Icon(Icons.share), onPressed: _sharePDF, tooltip: 'مشاركة الفاتورة'),
          IconButton(icon: const Icon(Icons.add_circle), onPressed: _addNewSupportType, tooltip: 'إضافة نوع مسند جديد'),
        ],
      ),
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(12)),
            child: Column(
              children: [
                Row(children: [
                  Expanded(child: Text('📅 $currentDate', style: const TextStyle(fontSize: 12))),
                ]),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange),
                        ),
                        child: DropdownButton<SupportType>(
                          value: selectedSupportType,
                          isExpanded: true,
                          icon: const Icon(Icons.arrow_drop_down),
                          underline: const SizedBox(),
                          onChanged: (SupportType? newValue) {
                            if (newValue != null) {
                              setState(() {
                                selectedSupportType = newValue;
                              });
                              _saveData();
                              updateAllCalculations();
                            }
                          },
                          items: supportTypes.asMap().entries.map((entry) {
                            int index = entry.key;
                            SupportType type = entry.value;
                            return DropdownMenuItem(
                              value: type,
                              child: Row(
                                children: [
                                  Expanded(child: Text('${type.name} - ${type.price} \$/م³')),
                                  IconButton(
                                    icon: const Icon(Icons.edit, size: 18),
                                    onPressed: () => _editSupportType(type, index),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                                    onPressed: () => _deleteSupportType(type, index),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: dollarPriceController,
                      keyboardType: TextInputType.number,
                      onChanged: (_) {
                        double? price = double.tryParse(dollarPriceController.text);
                        setState(() {
                          if (price != null && price > 0) {
                            dollarPrice = price;
                            dollarPriceError = null;
                          } else {
                            dollarPrice = 0;
                            dollarPriceError = 'الرجاء إدخال سعر صحيح';
                          }
                        });
                        _saveData();
                        updateAllCalculations();
                      },
                      decoration: InputDecoration(
                        labelText: 'سعر الدولار (ل.س)',
                        hintText: 'مثال: 15000',
                        border: const OutlineInputBorder(),
                        isDense: true,
                        errorText: dollarPriceError,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(color: Colors.blue, borderRadius: BorderRadius.circular(8)),
                    child: Column(
                      children: [
                        const Text('السعر', style: TextStyle(color: Colors.white, fontSize: 10)),
                        Text(
                          dollarPrice > 0 ? '${_formatNumber(dollarPrice)} ل.س' : 'لم يدخل',
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ]),
              ],
            ),
          ),
          
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: columns.asMap().entries.map((entry) {
                      int index = entry.key;
                      SupportColumnData col = entry.value;
                      return _buildColumnCard(index, col);
                    }).toList(),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        color: Colors.orange.shade50,
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('إجمالي الحجم:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('${_formatNumber(getTotalVolume())}', style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
            ]),
            const Divider(),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('الإجمالي بالدولار:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
              Text('\$${_formatNumber(getGrandTotalUSD())}', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 16)),
            ]),
            if (dollarPrice > 0) ...[
              const SizedBox(height: 8),
              Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.blue, borderRadius: BorderRadius.circular(12)),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text('الإجمالي النهائي بالليرة:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  Text('${_formatNumber(getGrandTotalSYP())} ل.س', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                ]),
              ),
            ],
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _showFinalInvoice,
              icon: const Icon(Icons.receipt),
              label: const Text('عرض الفاتورة النهائية', style: TextStyle(fontSize: 16)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildColumnCard(int index, SupportColumnData col) {
    return Container(
      width: 180,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: col.isFixed ? Colors.orange.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.orange,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    col.name,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ),
                if (!col.isFixed)
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.white, size: 18),
                    onPressed: () => _showEditColumnDialog(index),
                  ),
                if (!col.isFixed)
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.white, size: 18),
                    onPressed: () => _removeColumn(index),
                  ),
              ],
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Text('📏 ${col.lengthCM} × ${col.thicknessCM} سم',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                
                TextField(
                  controller: col.heightController,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => updateAllCalculations(),
                  decoration: _inputDecoration(label: 'الارتفاع (سم)', hint: '0'),
                ),
                const SizedBox(height: 8),
                
                TextField(
                  controller: col.quantityController,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => updateAllCalculations(),
                  decoration: _inputDecoration(label: 'العدد', hint: '1'),
                ),
                const SizedBox(height: 8),
                
                TextField(
                  controller: col.discountController,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => updateAllCalculations(),
                  decoration: _inputDecoration(label: 'الخصم %', hint: '0'),
                ),
                const SizedBox(height: 12),
                
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'الحجم: ${_formatNumber(calculateVolume(col))}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '\$${_formatNumber(calculateTotalUSD(col))}',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.green.shade700),
                      ),
                      if (dollarPrice > 0)
                        Text(
                          '${_formatNumber(calculateTotalSYP(col))} ل.س',
                          style: TextStyle(fontSize: 12, color: Colors.blue.shade700),
                        ),
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
  
  InputDecoration _inputDecoration({required String label, String hint = '0'}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
    );
  }
}

class SupportType {
  String name;
  double price;
  
  SupportType({required this.name, required this.price});
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SupportType && other.name == name;
  }
  
  @override
  int get hashCode => name.hashCode;
}

class SupportFixedColumn {
  final String name;
  final double lengthCM;
  final double thicknessCM;
  
  SupportFixedColumn({required this.name, required this.lengthCM, required this.thicknessCM});
}

class SupportColumnData {
  String name;
  double lengthCM;
  double thicknessCM;
  final TextEditingController heightController;
  final TextEditingController quantityController;
  final TextEditingController discountController;
  final bool isFixed;
  
  SupportColumnData({
    required this.name,
    required this.lengthCM,
    required this.thicknessCM,
    required this.heightController,
    required this.quantityController,
    required this.discountController,
    required this.isFixed,
  });
  
  void dispose() {
    heightController.dispose();
    quantityController.dispose();
    discountController.dispose();
  }
}