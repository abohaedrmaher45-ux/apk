// lib/accounting_table_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';

class AccountingTableScreen extends StatefulWidget {
  const AccountingTableScreen({super.key});

  @override
  State<AccountingTableScreen> createState() => _AccountingTableScreenState();
}

class _AccountingTableScreenState extends State<AccountingTableScreen> {
  // قائمة الأعمدة
  final List<ColumnData> columns = [];
  
  // الأعمدة الثابتة الأساسية
  final List<FixedColumn> fixedColumns = [
    FixedColumn(name: 'العمود 1', lengthCM: 200, widthCM: 70),
    FixedColumn(name: 'العمود 2', lengthCM: 180, widthCM: 70),
    FixedColumn(name: 'العمود 3', lengthCM: 100, widthCM: 100),
  ];
  
  // أنواع الإسفنج
  final List<SpongeType> spongeTypes = [
    SpongeType(name: 'سوبر اول مميز', price: 2.65),
    SpongeType(name: 'سوفت', price: 2.70),
    SpongeType(name: 'سوبر ثقيل مميز', price: 3.00),
    SpongeType(name: 'ممتاز اول مميز', price: 2.15),
    SpongeType(name: 'سوبر اول', price: 2.65),
  ];
  
  // النوع المختار
  SpongeType selectedSpongeType = SpongeType(name: 'سوبر اول مميز', price: 2.65);
  
  // سعر الدولار
  final TextEditingController dollarPriceController = TextEditingController();
  double dollarPrice = 0.0;
  String? dollarPriceError;
  
  // تاريخ اليوم
  String currentDate = '';
  
  @override
  void initState() {
    super.initState();
    _loadSavedData();
    _updateDate();
    _initializeColumns();
  }
  
  void _initializeColumns() {
    // إضافة الأعمدة الثابتة
    for (var fixed in fixedColumns) {
      columns.add(ColumnData(
        name: fixed.name,
        lengthCM: fixed.lengthCM,
        widthCM: fixed.widthCM,
        heightCMController: TextEditingController(),
        quantityController: TextEditingController(),
        discountController: TextEditingController(),
        isFixed: true,
      ));
    }
    
    // تحميل الأعمدة الإضافية المحفوظة
    _loadCustomColumns();
  }
  
  void _loadCustomColumns() async {
    final prefs = await SharedPreferences.getInstance();
    int customCount = prefs.getInt('custom_columns_count') ?? 0;
    
    for (int i = 0; i < customCount; i++) {
      String? name = prefs.getString('custom_column_name_$i');
      double? length = prefs.getDouble('custom_column_length_$i');
      double? width = prefs.getDouble('custom_column_width_$i');
      
      if (name != null && length != null && width != null) {
        columns.add(ColumnData(
          name: name,
          lengthCM: length,
          widthCM: width,
          heightCMController: TextEditingController(),
          quantityController: TextEditingController(),
          discountController: TextEditingController(),
          isFixed: false,
        ));
        
        // تحميل القيم المدخلة
        String? height = prefs.getString('custom_column_height_$i');
        String? quantity = prefs.getString('custom_column_quantity_$i');
        String? discount = prefs.getString('custom_column_discount_$i');
        
        if (height != null) columns.last.heightCMController.text = height;
        if (quantity != null) columns.last.quantityController.text = quantity;
        if (discount != null) columns.last.discountController.text = discount;
      }
    }
  }
  
  void _addCustomColumn() {
    setState(() {
      columns.add(ColumnData(
        name: 'عمود جديد',
        lengthCM: 100,
        widthCM: 100,
        heightCMController: TextEditingController(),
        quantityController: TextEditingController(),
        discountController: TextEditingController(),
        isFixed: false,
      ));
    });
    _saveCustomColumns();
    // فتح نافذة تعديل الاسم والأبعاد
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
    final widthController = TextEditingController(text: columns[index].widthCM.toString());
    
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
          TextButton(onPressed: () {
            String newName = nameController.text.trim();
            if (newName.isNotEmpty) columns[index].name = newName;
            
            double? newLength = double.tryParse(lengthController.text);
            if (newLength != null && newLength > 0) columns[index].lengthCM = newLength;
            
            double? newWidth = double.tryParse(widthController.text);
            if (newWidth != null && newWidth > 0) columns[index].widthCM = newWidth;
            
            setState(() {});
            _saveCustomColumns();
            Navigator.pop(context);
            _showSnackBar('تم تحديث العمود', Colors.green);
          }, child: const Text('حفظ')),
        ],
      ),
    );
  }
  
  void _updateDate() {
    final now = DateTime.now();
    setState(() {
      currentDate = '${now.year}/${now.month}/${now.day} - ${now.hour}:${now.minute}:${now.second}';
    });
  }
  
  Future<void> _loadSavedData() async {
    final prefs = await SharedPreferences.getInstance();
    
    double savedDollarPrice = prefs.getDouble('dollar_price') ?? 0.0;
    setState(() {
      dollarPrice = savedDollarPrice;
      if (savedDollarPrice > 0) {
        dollarPriceController.text = savedDollarPrice.toString();
      }
    });
    
    // تحميل نوع الإسفنج المختار
    String savedSpongeType = prefs.getString('selected_sponge_type') ?? 'سوبر اول مميز';
    var found = spongeTypes.firstWhere((t) => t.name == savedSpongeType, orElse: () => spongeTypes.first);
    setState(() {
      selectedSpongeType = found;
    });
  }
  
  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('dollar_price', dollarPrice);
    await prefs.setString('selected_sponge_type', selectedSpongeType.name);
    await _saveCustomColumns();
  }
  
  Future<void> _saveCustomColumns() async {
    final prefs = await SharedPreferences.getInstance();
    
    int customIndex = 0;
    for (int i = 0; i < columns.length; i++) {
      if (!columns[i].isFixed) {
        await prefs.setString('custom_column_name_$customIndex', columns[i].name);
        await prefs.setDouble('custom_column_length_$customIndex', columns[i].lengthCM);
        await prefs.setDouble('custom_column_width_$customIndex', columns[i].widthCM);
        await prefs.setString('custom_column_height_$customIndex', columns[i].heightCMController.text);
        await prefs.setString('custom_column_quantity_$customIndex', columns[i].quantityController.text);
        await prefs.setString('custom_column_discount_$customIndex', columns[i].discountController.text);
        customIndex++;
      }
    }
    await prefs.setInt('custom_columns_count', customIndex);
  }
  
  double calculateVolume(ColumnData col) {
    double height = double.tryParse(col.heightCMController.text) ?? 0;
    if (height <= 0) return 0;
    double volumeCM = col.lengthCM * col.widthCM * height;
    return volumeCM / 20000;
  }
  
  double calculateTotalUSD(ColumnData col) {
    double volumeValue = calculateVolume(col);
    if (volumeValue <= 0) return 0;
    
    double quantity = double.tryParse(col.quantityController.text) ?? 1;
    if (quantity <= 0) quantity = 1;
    
    double discountPercent = double.tryParse(col.discountController.text) ?? 0;
    if (discountPercent < 0) discountPercent = 0;
    if (discountPercent > 100) discountPercent = 100;
    
    double totalBeforeDiscount = quantity * volumeValue * selectedSpongeType.price;
    double totalAfterDiscount = totalBeforeDiscount * (1 - discountPercent / 100);
    
    return totalAfterDiscount;
  }
  
  double calculateTotalSYP(ColumnData col) {
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
            col.heightCMController.clear();
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
            pw.Header(level: 0, child: pw.Text('صفحة المحاسبة - فاتورة', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold))),
            pw.SizedBox(height: 10),
            pw.Text('التاريخ: $currentDate', style: pw.TextStyle(fontSize: 12)),
            pw.Text('نوع الإسفنج: ${selectedSpongeType.name} (${selectedSpongeType.price} \$/م³)', style: pw.TextStyle(fontSize: 12)),
            pw.Text('سعر الدولار: ${dollarPrice > 0 ? _formatNumber(dollarPrice) : "لم يتم إدخاله"} ل.س', style: pw.TextStyle(fontSize: 12)),
            pw.SizedBox(height: 20),
            pw.Table(
              border: pw.TableBorder.all(),
              children: [
                pw.TableRow(children: [
                  pw.Text('العمود', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.Text('الطول (سم)', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.Text('العرض (سم)', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.Text('الارتفاع (سم)', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.Text('العدد', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.Text('الخصم %', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.Text('الإجمالي (\$)', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                ]),
                for (var col in columns)
                  pw.TableRow(children: [
                    pw.Text(col.name),
                    pw.Text(col.lengthCM.toString()),
                    pw.Text(col.widthCM.toString()),
                    pw.Text(col.heightCMController.text.isEmpty ? '0' : col.heightCMController.text),
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
      final file = File('${output.path}/invoice.pdf');
      await file.writeAsBytes(await pdf.save());
      
      await Share.shareXFiles([XFile(file.path)], text: 'فاتورة المحاسبة - $currentDate');
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
        title: const Text('صفحة المحاسبة', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        centerTitle: true,
        actions: [
          IconButton(icon: const Icon(Icons.delete_sweep), onPressed: _clearAllData, tooltip: 'مسح الكل'),
          IconButton(icon: const Icon(Icons.add_box), onPressed: _addCustomColumn, tooltip: 'إضافة عمود جديد'),
          IconButton(icon: const Icon(Icons.share), onPressed: _sharePDF, tooltip: 'مشاركة الفاتورة'),
        ],
      ),
      body: Column(
        children: [
          // معلومات أعلى الصفحة
          Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.teal.shade50, borderRadius: BorderRadius.circular(12)),
            child: Column(
              children: [
                Row(children: [
                  Expanded(child: Text('📅 $currentDate', style: const TextStyle(fontSize: 12))),
                ]),
                const SizedBox(height: 8),
                // قائمة أنواع الإسفنج
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.teal),
                  ),
                  child: DropdownButton<SpongeType>(
                    value: selectedSpongeType,
                    isExpanded: true,
                    icon: const Icon(Icons.arrow_drop_down),
                    underline: const SizedBox(),
                    onChanged: (SpongeType? newValue) {
                      if (newValue != null) {
                        setState(() {
                          selectedSpongeType = newValue;
                        });
                        _saveData();
                        updateAllCalculations();
                      }
                    },
                    items: spongeTypes.map((type) {
                      return DropdownMenuItem(
                        value: type,
                        child: Text('${type.name} - ${type.price} \$/م³'),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 8),
                // سعر الدولار
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
          
          // الجدول - الأعمدة
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
                      ColumnData col = entry.value;
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
        color: Colors.teal.shade50,
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('إجمالي الحجم:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('${_formatNumber(getTotalVolume())}', style: const TextStyle(color: Colors.teal, fontWeight: FontWeight.bold)),
            ]),
            const Divider(),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('الإجمالي بالدولار:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal)),
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
          ],
        ),
      ),
    );
  }
  
  Widget _buildColumnCard(int index, ColumnData col) {
    return Container(
      width: 180,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: col.isFixed ? Colors.teal.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.teal.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // رأس العمود
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.teal,
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
          
          // محتوى العمود
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              children: [
                // الأبعاد الثابتة
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.teal.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Text('📏 ${col.lengthCM} × ${col.widthCM} سم',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                
                // الارتفاع
                TextField(
                  controller: col.heightCMController,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => updateAllCalculations(),
                  decoration: _inputDecoration(label: 'الارتفاع (سم)', hint: '0'),
                ),
                const SizedBox(height: 8),
                
                // العدد
                TextField(
                  controller: col.quantityController,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => updateAllCalculations(),
                  decoration: _inputDecoration(label: 'العدد', hint: '1'),
                ),
                const SizedBox(height: 8),
                
                // الخصم
                TextField(
                  controller: col.discountController,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => updateAllCalculations(),
                  decoration: _inputDecoration(label: 'الخصم %', hint: '0'),
                ),
                const SizedBox(height: 12),
                
                // النتائج
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

// ==================== الفئات المساعدة ====================

class SpongeType {
  final String name;
  final double price;
  
  SpongeType({required this.name, required this.price});
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SpongeType && other.name == name;
  }
  
  @override
  int get hashCode => name.hashCode;
}

class FixedColumn {
  final String name;
  final double lengthCM;
  final double widthCM;
  
  FixedColumn({required this.name, required this.lengthCM, required this.widthCM});
}

class ColumnData {
  String name;
  double lengthCM;
  double widthCM;
  final TextEditingController heightCMController;
  final TextEditingController quantityController;
  final TextEditingController discountController;
  final bool isFixed;
  
  ColumnData({
    required this.name,
    required this.lengthCM,
    required this.widthCM,
    required this.heightCMController,
    required this.quantityController,
    required this.discountController,
    required this.isFixed,
  });
  
  void dispose() {
    heightCMController.dispose();
    quantityController.dispose();
    discountController.dispose();
  }
}