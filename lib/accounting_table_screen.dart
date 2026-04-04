// lib/accounting_table_screen.dart
import 'package:flutter/material.dart';

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

  // قوائم القيم المحسوبة
  final List<double> volumes = [0.0, 0.0, 0.0, 0.0];
  final List<double> totals = [0.0, 0.0, 0.0, 0.0];

  // أسعار الأنواع (دولار لكل متر مكعب) - تم التعديل
  final List<double> prices = [2.65, 2.70, 3.00, 2.15];

  // أسماء الأنواع - تمت الإضافة والتعديل
  final List<String> types = [
    'سوبر اول مميز',      // السعر: 2.65 دولار (تم التعديل)
    'سوفت',               // السعر: 2.70 دولار
    'سوبر ثقيل مميز',     // السعر: 3.00 دولار (جديد)
    'ممتاز اول مميز',     // السعر: 2.15 دولار (جديد)
  ];

  // رسائل الخطأ لكل صف
  final List<String?> errorMessages = [null, null, null, null];

  @override
  void initState() {
    super.initState();
    // تهيئة الـ controllers لكل صف (4 صفوف الآن)
    for (int i = 0; i < 4; i++) {
      lengthControllers.add(TextEditingController());
      widthControllers.add(TextEditingController());
      heightControllers.add(TextEditingController());

      // إضافة مستمعين للتغيير
      lengthControllers[i].addListener(() => calculateForRow(i));
      widthControllers[i].addListener(() => calculateForRow(i));
      heightControllers[i].addListener(() => calculateForRow(i));
    }
  }

  @override
  void dispose() {
    // تنظيف الـ controllers
    for (int i = 0; i < 4; i++) {
      lengthControllers[i].dispose();
      widthControllers[i].dispose();
      heightControllers[i].dispose();
    }
    super.dispose();
  }

  void calculateForRow(int index) {
    // الحصول على القيم المدخلة
    String lengthStr = lengthControllers[index].text.trim();
    String widthStr = widthControllers[index].text.trim();
    String heightStr = heightControllers[index].text.trim();

    // التحقق من الحقول الفارغة
    if (lengthStr.isEmpty || widthStr.isEmpty || heightStr.isEmpty) {
      setState(() {
        volumes[index] = 0.0;
        totals[index] = 0.0;
        errorMessages[index] = 'الرجاء إدخال جميع القيم';
      });
      return;
    }

    // تحويل القيم إلى أرقام
    double? length = double.tryParse(lengthStr);
    double? width = double.tryParse(widthStr);
    double? height = double.tryParse(heightStr);

    // التحقق من صحة الأرقام
    if (length == null || width == null || height == null) {
      setState(() {
        volumes[index] = 0.0;
        totals[index] = 0.0;
        errorMessages[index] = 'الرجاء إدخال أرقام صحيحة';
      });
      return;
    }

    // التحقق من أن القيم موجبة
    if (length <= 0 || width <= 0 || height <= 0) {
      setState(() {
        volumes[index] = 0.0;
        totals[index] = 0.0;
        errorMessages[index] = 'الرجاء إدخال قيم أكبر من 0';
      });
      return;
    }

    // حساب الحجم والإجمالي
    double volume = length * width * height;
    double total = volume * prices[index];

    setState(() {
      volumes[index] = volume;
      totals[index] = total;
      errorMessages[index] = null; // إزالة رسالة الخطأ عند نجاح الحساب
    });
  }

  double getGrandTotal() {
    double sum = 0.0;
    for (double total in totals) {
      sum += total;
    }
    return sum;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'صفحة المحاسبة',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: DataTable(
                columnSpacing: 16,
                border: TableBorder.all(
                  color: Colors.grey.shade300,
                  width: 1,
                ),
                columns: const [
                  DataColumn(label: Text('النوع', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('الطول (متر)', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('العرض (متر)', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('الارتفاع (متر)', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('الحجم (م³)', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('السعر (\$/م³)', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('الإجمالي (\$)', style: TextStyle(fontWeight: FontWeight.bold))),
                ],
                rows: List.generate(4, (index) {
                  // تلوين الصفوف بشكل متناوب
                  Color? rowColor;
                  if (index % 2 == 0) {
                    rowColor = Colors.teal.shade50;
                  }
                  
                  return DataRow(
                    color: MaterialStateProperty.all(rowColor),
                    cells: [
                      // عمود النوع
                      DataCell(
                        Container(
                          width: 140,
                          child: Text(
                            types[index],
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ),
                      ),
                      // عمود الطول
                      DataCell(
                        SizedBox(
                          width: 100,
                          child: TextField(
                            controller: lengthControllers[index],
                            keyboardType: TextInputType.numberWithOptions(decimal: true),
                            decoration: InputDecoration(
                              hintText: '0.00',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              isDense: true,
                              errorText: errorMessages[index] != null && 
                                        lengthControllers[index].text.isEmpty ? null : null,
                            ),
                          ),
                        ),
                      ),
                      // عمود العرض
                      DataCell(
                        SizedBox(
                          width: 100,
                          child: TextField(
                            controller: widthControllers[index],
                            keyboardType: TextInputType.numberWithOptions(decimal: true),
                            decoration: InputDecoration(
                              hintText: '0.00',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              isDense: true,
                            ),
                          ),
                        ),
                      ),
                      // عمود الارتفاع
                      DataCell(
                        SizedBox(
                          width: 100,
                          child: TextField(
                            controller: heightControllers[index],
                            keyboardType: TextInputType.numberWithOptions(decimal: true),
                            decoration: InputDecoration(
                              hintText: '0.00',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              isDense: true,
                            ),
                          ),
                        ),
                      ),
                      // عمود الحجم (تلقائي)
                      DataCell(
                        Container(
                          width: 80,
                          child: Text(
                            volumes[index].toStringAsFixed(2),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.teal,
                            ),
                          ),
                        ),
                      ),
                      // عمود السعر (ثابت)
                      DataCell(
                        Container(
                          width: 100,
                          child: Text(
                            '${prices[index].toStringAsFixed(2)} \$',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      // عمود الإجمالي (تلقائي)
                      DataCell(
                        Container(
                          width: 100,
                          child: Text(
                            totals[index].toStringAsFixed(2),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: totals[index] > 0 ? Colors.green.shade700 : Colors.grey,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: Container(
        color: Colors.teal.shade50,
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'الإجمالي النهائي:',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.teal,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.teal,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '\$${getGrandTotal().toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}