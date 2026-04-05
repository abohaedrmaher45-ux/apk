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
  // قوائم التحكم لكل صف
  final List<TextEditingController> lengthControllers = [];
  final List<TextEditingController> widthControllers = [];
  final List<TextEditingController> heightControllers = [];
  final List<TextEditingController> quantityControllers = [];
  final List<TextEditingController> discountControllers = [];
  
  // قائمة أنواع المواد (قابلة للتعديل)
  final List<Map<String, dynamic>> items = [];
  
  // متغير سعر الدولار بالليرة السورية
  final TextEditingController dollarPriceController = TextEditingController();
  double dollarPrice = 0.0;  // تم التعديل: أصبح 0 بدلاً من 15000
  String? dollarPriceError;
  
  // متغير وحدة القياس
  String selectedUnit = 'cm';
  
  // تاريخ اليوم
  String currentDate = '';
  
  // قوائم القيم المحسوبة
  final List<double> volumes = [];
  final List<double> totalsBeforeDiscountUSD = [];
  final List<double> totalsAfterDiscountUSD = [];
  final List<double> totalsSYP = [];

  // أسعار الأنواع الأصلية (دولار لكل متر مكعب)
  final List<double> defaultPrices = [2.65, 2.70, 3.00, 2.15];
  final List<String> defaultTypes = [
    'سوبر اول مميز',    // السعر: 2.65 دولار
    'سوفت',             // السعر: 2.70 دولار
    'سوبر ثقيل مميز',   // السعر: 3.00 دولار
    'ممتاز اول مميز',   // السعر: 2.15 دولار
  ];

  @override
  void initState() {
    super.initState();
    _loadSavedData();
    _updateDate();
    _initializeItems();
  }
  
  void _initializeItems() {
    for (int i = 0; i < defaultTypes.length; i++) {
      items.add({
        'type': defaultTypes[i],
        'price': defaultPrices[i],  // الأسعار الأصلية
        'isCustom': false,
      });
      _addControllersForIndex(i);
    }
  }
  
  void _addControllersForIndex(int index) {
    while (lengthControllers.length <= index) {
      lengthControllers.add(TextEditingController());
      widthControllers.add(TextEditingController());
      heightControllers.add(TextEditingController());
      quantityControllers.add(TextEditingController());
      discountControllers.add(TextEditingController());
      volumes.add(0.0);
      totalsBeforeDiscountUSD.add(0.0);
      totalsAfterDiscountUSD.add(0.0);
      totalsSYP.add(0.0);
    }
    
    lengthControllers[index].addListener(() => calculateForRow(index));
    widthControllers[index].addListener(() => calculateForRow(index));
    heightControllers[index].addListener(() => calculateForRow(index));
    quantityControllers[index].addListener(() => calculateForRow(index));
    discountControllers[index].addListener(() => calculateForRow(index));
  }
  
  void _addNewRow() {
    setState(() {
      items.add({
        'type': 'نوع جديد',
        'price': 0.0,
        'isCustom': true,
      });
      _addControllersForIndex(items.length - 1);
    });
    _saveData();
  }
  
  void _removeRow(int index) {
    if (items.length <= 1) {
      _showSnackBar('لا يمكن حذف الصف الأخير', Colors.orange);
      return;
    }
    
    _showConfirmDialog(
      title: 'حذف الصف',
      message: 'هل أنت متأكد من حذف صف "${items[index]['type']}"؟',
      onConfirm: () {
        setState(() {
          lengthControllers[index].dispose();
          widthControllers[index].dispose();
          heightControllers[index].dispose();
          quantityControllers[index].dispose();
          discountControllers[index].dispose();
          
          lengthControllers.removeAt(index);
          widthControllers.removeAt(index);
          heightControllers.removeAt(index);
          quantityControllers.removeAt(index);
          discountControllers.removeAt(index);
          items.removeAt(index);
          volumes.removeAt(index);
          totalsBeforeDiscountUSD.removeAt(index);
          totalsAfterDiscountUSD.removeAt(index);
          totalsSYP.removeAt(index);
        });
        _saveData();
      },
    );
  }
  
  void _clearAllData() {
    _showConfirmDialog(
      title: 'مسح جميع البيانات',
      message: 'هل أنت متأكد من مسح جميع البيانات؟ لا يمكن التراجع عن هذا الإجراء.',
      onConfirm: () {
        setState(() {
          for (int i = 0; i < items.length; i++) {
            lengthControllers[i].clear();
            widthControllers[i].clear();
            heightControllers[i].clear();
            quantityControllers[i].clear();
            discountControllers[i].clear();
            volumes[i] = 0.0;
            totalsBeforeDiscountUSD[i] = 0.0;
            totalsAfterDiscountUSD[i] = 0.0;
            totalsSYP[i] = 0.0;
          }
        });
        _saveData();
        _showSnackBar('تم مسح جميع البيانات', Colors.green);
      },
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
    
    // تحميل سعر الدولار (بدون قيمة افتراضية)
    double savedDollarPrice = prefs.getDouble('dollar_price') ?? 0.0;
    setState(() {
      dollarPrice = savedDollarPrice;
      if (savedDollarPrice > 0) {
        dollarPriceController.text = savedDollarPrice.toString();
      } else {
        dollarPriceController.clear(); // ترك الحقل فارغاً
      }
    });
    
    String savedUnit = prefs.getString('unit') ?? 'cm';
    setState(() {
      selectedUnit = savedUnit;
    });
    
    // تحميل عدد الصفوف المخصصة
    int savedItemCount = prefs.getInt('item_count') ?? defaultTypes.length;
    if (savedItemCount > defaultTypes.length) {
      for (int i = defaultTypes.length; i < savedItemCount; i++) {
        String? type = prefs.getString('type_$i');
        double price = prefs.getDouble('price_$i') ?? 0.0;
        if (type != null) {
          items.add({
            'type': type,
            'price': price,
            'isCustom': true,
          });
          _addControllersForIndex(items.length - 1);
        }
      }
    }
    
    // تحميل بيانات الجدول
    for (int i = 0; i < items.length; i++) {
      String? length = prefs.getString('length_$i');
      String? width = prefs.getString('width_$i');
      String? height = prefs.getString('height_$i');
      String? quantity = prefs.getString('quantity_$i');
      String? discount = prefs.getString('discount_$i');
      
      if (length != null) lengthControllers[i].text = length;
      if (width != null) widthControllers[i].text = width;
      if (height != null) heightControllers[i].text = height;
      if (quantity != null) quantityControllers[i].text = quantity;
      if (discount != null) discountControllers[i].text = discount;
    }
  }
  
  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    
    await prefs.setDouble('dollar_price', dollarPrice);
    await prefs.setString('unit', selectedUnit);
    await prefs.setInt('item_count', items.length);
    
    for (int i = 0; i < items.length; i++) {
      if (items[i]['isCustom'] == true) {
        await prefs.setString('type_$i', items[i]['type']);
        await prefs.setDouble('price_$i', items[i]['price']);
      }
      await prefs.setString('length_$i', lengthControllers[i].text);
      await prefs.setString('width_$i', widthControllers[i].text);
      await prefs.setString('height_$i', heightControllers[i].text);
      await prefs.setString('quantity_$i', quantityControllers[i].text);
      await prefs.setString('discount_$i', discountControllers[i].text);
    }
  }

  double _convertToMeters(double value, String unit) {
    if (unit == 'cm') {
      return value / 100.0;
    }
    return value;
  }

  void calculateForRow(int index) {
    String lengthStr = lengthControllers[index].text.trim();
    String widthStr = widthControllers[index].text.trim();
    String heightStr = heightControllers[index].text.trim();
    String quantityStr = quantityControllers[index].text.trim();
    String discountStr = discountControllers[index].text.trim();

    if (lengthStr.isEmpty || widthStr.isEmpty || heightStr.isEmpty) {
      setState(() {
        volumes[index] = 0.0;
        totalsBeforeDiscountUSD[index] = 0.0;
        totalsAfterDiscountUSD[index] = 0.0;
        totalsSYP[index] = 0.0;
      });
      _saveData();
      return;
    }

    double? lengthValue = double.tryParse(lengthStr);
    double? widthValue = double.tryParse(widthStr);
    double? heightValue = double.tryParse(heightStr);
    
    double quantity = 1.0;
    if (quantityStr.isNotEmpty) {
      double? parsedQuantity = double.tryParse(quantityStr);
      if (parsedQuantity != null && parsedQuantity > 0) {
        quantity = parsedQuantity;
      }
    }
    
    double discountPercent = 0.0;
    if (discountStr.isNotEmpty) {
      double? parsedDiscount = double.tryParse(discountStr);
      if (parsedDiscount != null && parsedDiscount > 0) {
        discountPercent = parsedDiscount.clamp(0.0, 100.0);
      }
    }

    if (lengthValue == null || widthValue == null || heightValue == null) {
      setState(() {
        volumes[index] = 0.0;
        totalsBeforeDiscountUSD[index] = 0.0;
        totalsAfterDiscountUSD[index] = 0.0;
        totalsSYP[index] = 0.0;
      });
      _saveData();
      return;
    }

    if (lengthValue <= 0 || widthValue <= 0 || heightValue <= 0) {
      setState(() {
        volumes[index] = 0.0;
        totalsBeforeDiscountUSD[index] = 0.0;
        totalsAfterDiscountUSD[index] = 0.0;
        totalsSYP[index] = 0.0;
      });
      _saveData();
      return;
    }

    double lengthM = _convertToMeters(lengthValue, selectedUnit);
    double widthM = _convertToMeters(widthValue, selectedUnit);
    double heightM = _convertToMeters(heightValue, selectedUnit);
    
    double volumeM3 = lengthM * widthM * heightM;
    double price = items[index]['price'];
    double totalBeforeDiscountUSD = quantity * volumeM3 * price;
    
    double discountAmount = totalBeforeDiscountUSD * (discountPercent / 100);
    double totalAfterDiscountUSD = totalBeforeDiscountUSD - discountAmount;
    
    double totalSYPValue = totalAfterDiscountUSD * dollarPrice;

    setState(() {
      volumes[index] = volumeM3;
      totalsBeforeDiscountUSD[index] = totalBeforeDiscountUSD;
      totalsAfterDiscountUSD[index] = totalAfterDiscountUSD;
      totalsSYP[index] = totalSYPValue;
    });
    _saveData();
  }
  
  void updateSYPCalculations() {
    String dollarPriceStr = dollarPriceController.text.trim();
    if (dollarPriceStr.isEmpty) {
      setState(() {
        dollarPrice = 0.0;
        dollarPriceError = 'الرجاء إدخال سعر الدولار';
        for (int i = 0; i < items.length; i++) {
          totalsSYP[i] = 0.0;
        }
      });
      return;
    }
    
    double? price = double.tryParse(dollarPriceStr);
    if (price == null || price <= 0) {
      setState(() {
        dollarPrice = 0.0;
        dollarPriceError = 'الرجاء إدخال سعر صحيح أكبر من 0';
        for (int i = 0; i < items.length; i++) {
          totalsSYP[i] = 0.0;
        }
      });
      return;
    }
    
    setState(() {
      dollarPrice = price;
      dollarPriceError = null;
      for (int i = 0; i < items.length; i++) {
        totalsSYP[i] = totalsAfterDiscountUSD[i] * dollarPrice;
      }
    });
    _saveData();
  }

  double getTotalVolume() {
    double sum = 0.0;
    for (double volume in volumes) {
      sum += volume;
    }
    return sum;
  }
  
  double getGrandTotalBeforeDiscountUSD() {
    double sum = 0.0;
    for (double total in totalsBeforeDiscountUSD) {
      sum += total;
    }
    return sum;
  }
  
  double getGrandTotalAfterDiscountUSD() {
    double sum = 0.0;
    for (double total in totalsAfterDiscountUSD) {
      sum += total;
    }
    return sum;
  }
  
  double getGrandTotalSYP() {
    double sum = 0.0;
    for (double total in totalsSYP) {
      sum += total;
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
  
  Future<void> _sharePDF() async {
    if (getGrandTotalAfterDiscountUSD() == 0) {
      _showSnackBar('لا توجد بيانات للمشاركة', Colors.orange);
      return;
    }
    
    try {
      final pdf = pw.Document();
      
      pdf.addPage(
        pw.MultiPage(
          build: (context) => [
            pw.Header(level: 0, child: pw.Text('فاتورة محاسبة', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold))),
            pw.SizedBox(height: 10),
            pw.Text('التاريخ: $currentDate', style: pw.TextStyle(fontSize: 12)),
            pw.Text('سعر الدولار: ${dollarPrice > 0 ? _formatNumber(dollarPrice) : "لم يتم إدخاله"} ل.س', style: pw.TextStyle(fontSize: 12)),
            pw.SizedBox(height: 20),
            pw.Table(
              border: pw.TableBorder.all(),
              children: [
                pw.TableRow(children: [
                  pw.Text('النوع', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.Text('الطول', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.Text('العرض', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.Text('الارتفاع', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.Text('العدد', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.Text('الحجم (م³)', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.Text('الخصم %', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.Text('الإجمالي (\$)', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                ]),
                for (int i = 0; i < items.length; i++)
                  pw.TableRow(children: [
                    pw.Text(items[i]['type']),
                    pw.Text(lengthControllers[i].text.isEmpty ? '0' : lengthControllers[i].text),
                    pw.Text(widthControllers[i].text.isEmpty ? '0' : widthControllers[i].text),
                    pw.Text(heightControllers[i].text.isEmpty ? '0' : heightControllers[i].text),
                    pw.Text(quantityControllers[i].text.isEmpty ? '1' : quantityControllers[i].text),
                    pw.Text(volumes[i].toStringAsFixed(4)),
                    pw.Text(discountControllers[i].text.isEmpty ? '0' : discountControllers[i].text),
                    pw.Text(totalsAfterDiscountUSD[i].toStringAsFixed(2)),
                  ]),
              ],
            ),
            pw.SizedBox(height: 20),
            pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
              pw.Text('الإجمالي قبل الخصم:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.Text('${_formatNumber(getGrandTotalBeforeDiscountUSD())} \$'),
            ]),
            pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
              pw.Text('الإجمالي بعد الخصم:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.Text('${_formatNumber(getGrandTotalAfterDiscountUSD())} \$'),
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
      
      await Share.shareXFiles([XFile(file.path)], text: 'فاتورة محاسبة - $currentDate');
      _showSnackBar('تم مشاركة الفاتورة بنجاح', Colors.green);
    } catch (e) {
      _showSnackBar('حدث خطأ: $e', Colors.red);
    }
  }

  @override
  void dispose() {
    for (int i = 0; i < lengthControllers.length; i++) {
      lengthControllers[i].dispose();
      widthControllers[i].dispose();
      heightControllers[i].dispose();
      quantityControllers[i].dispose();
      discountControllers[i].dispose();
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
          IconButton(icon: const Icon(Icons.add_box), onPressed: _addNewRow, tooltip: 'إضافة صنف جديد'),
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
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.teal)),
                    child: DropdownButton<String>(
                      value: selectedUnit,
                      icon: const Icon(Icons.arrow_drop_down),
                      underline: const SizedBox(),
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          setState(() { selectedUnit = newValue; _saveData(); });
                          for (int i = 0; i < items.length; i++) calculateForRow(i);
                        }
                      },
                      items: const [DropdownMenuItem(value: 'cm', child: Text('سم (cm)')), DropdownMenuItem(value: 'm', child: Text('متر (m)'))],
                    ),
                  ),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: dollarPriceController,
                      keyboardType: TextInputType.number,
                      onChanged: (_) => updateSYPCalculations(),
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
          
          // الجدول
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: DataTable(
                    columnSpacing: 6,
                    border: TableBorder.all(color: Colors.grey.shade300, width: 1),
                    columns: [
                      const DataColumn(label: Text('النوع', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('الطول (${selectedUnit == 'cm' ? 'سم' : 'م'})', style: const TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('العرض (${selectedUnit == 'cm' ? 'سم' : 'م'})', style: const TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('الارتفاع (${selectedUnit == 'cm' ? 'سم' : 'م'})', style: const TextStyle(fontWeight: FontWeight.bold))),
                      const DataColumn(label: Text('العدد', style: TextStyle(fontWeight: FontWeight.bold))),
                      const DataColumn(label: Text('الحجم (م³)', style: TextStyle(fontWeight: FontWeight.bold))),
                      const DataColumn(label: Text('الخصم %', style: TextStyle(fontWeight: FontWeight.bold))),
                      const DataColumn(label: Text('السعر (\$/م³)', style: TextStyle(fontWeight: FontWeight.bold))),
                      const DataColumn(label: Text('الإجمالي (\$)', style: TextStyle(fontWeight: FontWeight.bold))),
                      const DataColumn(label: Text('الإجمالي (ل.س)', style: TextStyle(fontWeight: FontWeight.bold))),
                      const DataColumn(label: Text('', style: TextStyle(fontWeight: FontWeight.bold))),
                    ],
                    rows: List.generate(items.length, (index) {
                      Color? rowColor = index % 2 == 0 ? Colors.teal.shade50 : null;
                      return DataRow(
                        color: rowColor != null ? WidgetStateProperty.all(rowColor) : null,
                        cells: [
                          DataCell(SizedBox(
                            width: 120,
                            child: Row(children: [
                              Expanded(child: Text(items[index]['type'], style: const TextStyle(fontSize: 12))),
                              IconButton(icon: const Icon(Icons.edit, size: 16), onPressed: () => _showEditPriceDialog(index)),
                            ]),
                          )),
                          DataCell(SizedBox(width: 70, child: TextField(controller: lengthControllers[index], keyboardType: TextInputType.number, decoration: _inputDecoration()))),
                          DataCell(SizedBox(width: 70, child: TextField(controller: widthControllers[index], keyboardType: TextInputType.number, decoration: _inputDecoration()))),
                          DataCell(SizedBox(width: 70, child: TextField(controller: heightControllers[index], keyboardType: TextInputType.number, decoration: _inputDecoration()))),
                          DataCell(SizedBox(width: 60, child: TextField(controller: quantityControllers[index], keyboardType: TextInputType.number, decoration: _inputDecoration(hint: '1')))),
                          DataCell(Container(width: 70, child: Text(volumes[index].toStringAsFixed(4), style: const TextStyle(color: Colors.teal, fontWeight: FontWeight.bold)))),
                          DataCell(SizedBox(width: 60, child: TextField(controller: discountControllers[index], keyboardType: TextInputType.number, decoration: _inputDecoration(hint: '0')))),
                          DataCell(Container(width: 70, child: Text('${items[index]['price']}', style: const TextStyle(fontWeight: FontWeight.bold)))),
                          DataCell(Container(width: 80, child: Text(_formatNumber(totalsAfterDiscountUSD[index]), style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.bold)))),
                          DataCell(Container(width: 100, child: Text(_formatNumber(totalsSYP[index]), style: TextStyle(color: Colors.blue.shade700, fontWeight: FontWeight.bold)))),
                          DataCell(IconButton(icon: const Icon(Icons.delete, color: Colors.red, size: 20), onPressed: () => _removeRow(index))),
                        ],
                      );
                    }),
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
              Text('${_formatNumber(getTotalVolume())} م³', style: const TextStyle(color: Colors.teal, fontWeight: FontWeight.bold)),
            ]),
            const Divider(),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('الإجمالي قبل الخصم:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('\$${_formatNumber(getGrandTotalBeforeDiscountUSD())}', style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
            ]),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('الإجمالي بعد الخصم:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal)),
              Text('\$${_formatNumber(getGrandTotalAfterDiscountUSD())}', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 16)),
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
  
  void _showEditPriceDialog(int index) {
    final controller = TextEditingController(text: items[index]['price'].toString());
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('تعديل سعر ${items[index]['type']}'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'السعر (\$/م³)', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          TextButton(onPressed: () {
            double? newPrice = double.tryParse(controller.text);
            if (newPrice != null && newPrice > 0) {
              setState(() { items[index]['price'] = newPrice; });
              calculateForRow(index);
              _saveData();
            }
            Navigator.pop(context);
          }, child: const Text('حفظ')),
        ],
      ),
    );
  }
  
  InputDecoration _inputDecoration({String hint = '0'}) {
    return InputDecoration(
      hintText: hint,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
    );
  }
}