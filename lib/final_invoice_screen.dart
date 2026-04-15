// lib/final_invoice_screen.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';

class FinalInvoiceScreen extends StatefulWidget {
  const FinalInvoiceScreen({super.key});

  @override
  State<FinalInvoiceScreen> createState() => _FinalInvoiceScreenState();
}

class _FinalInvoiceScreenState extends State<FinalInvoiceScreen> {
  List<InvoiceItem> mattressItems = [];
  List<InvoiceItem> supportItems = [];
  double mattressDollarPrice = 0.0;
  double supportDollarPrice = 0.0;
  String mattressType = '';
  String supportType = '';
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    
    List<String>? mattressItemsJson = prefs.getStringList('temp_mattress_items');
    if (mattressItemsJson != null) {
      for (var json in mattressItemsJson) {
        Map<String, dynamic> data = jsonDecode(json);
        mattressItems.add(InvoiceItem(
          section: data['section'],
          type: data['type'],
          dimensions: data['dimensions'],
          height: data['height'],
          quantity: data['quantity'],
          discount: data['discount'],
          totalUSD: data['totalUSD'],
          totalSYP: data['totalSYP'],
        ));
      }
    }
    mattressDollarPrice = prefs.getDouble('temp_mattress_dollar_price') ?? 0.0;
    mattressType = prefs.getString('temp_mattress_type') ?? '';
    
    List<String>? supportItemsJson = prefs.getStringList('temp_support_items');
    if (supportItemsJson != null) {
      for (var json in supportItemsJson) {
        Map<String, dynamic> data = jsonDecode(json);
        supportItems.add(InvoiceItem(
          section: data['section'],
          type: data['type'],
          dimensions: data['dimensions'],
          height: data['height'],
          quantity: data['quantity'],
          discount: data['discount'],
          totalUSD: data['totalUSD'],
          totalSYP: data['totalSYP'],
        ));
      }
    }
    supportDollarPrice = prefs.getDouble('temp_support_dollar_price') ?? 0.0;
    supportType = prefs.getString('temp_support_type') ?? '';
    
    setState(() {
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final allItems = [...mattressItems, ...supportItems];
    final double mattressTotalUSD = mattressItems.fold(0, (sum, item) => sum + item.totalUSD);
    final double mattressTotalSYP = mattressItems.fold(0, (sum, item) => sum + item.totalSYP);
    final double supportTotalUSD = supportItems.fold(0, (sum, item) => sum + item.totalUSD);
    final double supportTotalSYP = supportItems.fold(0, (sum, item) => sum + item.totalSYP);
    final double grandTotalUSD = mattressTotalUSD + supportTotalUSD;
    final double grandTotalSYP = mattressTotalSYP + supportTotalSYP;

    final currentDate = DateFormat('yyyy/MM/dd - HH:mm:ss').format(DateTime.now());

    return Scaffold(
      appBar: AppBar(
        title: const Text('الفاتورة النهائية', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () => _sharePDF(context, allItems, mattressTotalUSD, mattressTotalSYP, supportTotalUSD, supportTotalSYP, grandTotalUSD, grandTotalSYP, currentDate, mattressDollarPrice, supportDollarPrice, mattressType, supportType),
            tooltip: 'مشاركة الفاتورة',
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.purple.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '📅 $currentDate',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '🛏️ نوع إسفنج الفرشات: $mattressType',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '🪑 نوع مسند المساند: $supportType',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '💵 سعر دولار الفرشات: ${_formatNumber(mattressDollarPrice)} ل.س',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '💵 سعر دولار المساند: ${_formatNumber(supportDollarPrice)} ل.س',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
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
                  child: DataTable(
                    columnSpacing: 8,
                    border: TableBorder.all(color: Colors.grey.shade300, width: 1),
                    columns: const [
                      DataColumn(label: Text('القسم', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('النوع', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('الأبعاد (سم)', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('الارتفاع (سم)', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('العدد', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('الخصم %', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('الإجمالي (\$)', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('الإجمالي (ل.س)', style: TextStyle(fontWeight: FontWeight.bold))),
                    ],
                    rows: [
                      DataRow(
                        color: WidgetStateProperty.all(Colors.teal.shade100),
                        cells: const [
                          DataCell(Text('🛏️ الفرشات', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataCell(Text('')),
                          DataCell(Text('')),
                          DataCell(Text('')),
                          DataCell(Text('')),
                          DataCell(Text('')),
                          DataCell(Text('')),
                          DataCell(Text('')),
                        ],
                      ),
                      ...mattressItems.map((item) => DataRow(cells: [
                        DataCell(Text('')),
                        DataCell(Text(item.type)),
                        DataCell(Text(item.dimensions)),
                        DataCell(Text(item.height.toString())),
                        DataCell(Text(item.quantity.toString())),
                        DataCell(Text(item.discount.toString())),
                        DataCell(Text('\$${_formatNumber(item.totalUSD)}'),),
                        DataCell(Text('${_formatNumber(item.totalSYP)} ل.س')),
                      ])),
                      DataRow(
                        color: WidgetStateProperty.all(Colors.teal.shade50),
                        cells: [
                          const DataCell(Text('')),
                          const DataCell(Text('')),
                          const DataCell(Text('')),
                          const DataCell(Text('')),
                          const DataCell(Text('')),
                          const DataCell(Text('الإجمالي:', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataCell(Text('\$${_formatNumber(mattressTotalUSD)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal))),
                          DataCell(Text('${_formatNumber(mattressTotalSYP)} ل.س', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal))),
                        ],
                      ),
                      const DataRow(cells: [
                        DataCell(SizedBox(height: 8)),
                        DataCell(SizedBox(height: 8)),
                        DataCell(SizedBox(height: 8)),
                        DataCell(SizedBox(height: 8)),
                        DataCell(SizedBox(height: 8)),
                        DataCell(SizedBox(height: 8)),
                        DataCell(SizedBox(height: 8)),
                        DataCell(SizedBox(height: 8)),
                      ]),
                      DataRow(
                        color: WidgetStateProperty.all(Colors.orange.shade100),
                        cells: const [
                          DataCell(Text('🪑 المساند', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataCell(Text('')),
                          DataCell(Text('')),
                          DataCell(Text('')),
                          DataCell(Text('')),
                          DataCell(Text('')),
                          DataCell(Text('')),
                          DataCell(Text('')),
                        ],
                      ),
                      ...supportItems.map((item) => DataRow(cells: [
                        DataCell(Text('')),
                        DataCell(Text(item.type)),
                        DataCell(Text(item.dimensions)),
                        DataCell(Text(item.height.toString())),
                        DataCell(Text(item.quantity.toString())),
                        DataCell(Text(item.discount.toString())),
                        DataCell(Text('\$${_formatNumber(item.totalUSD)}')),
                        DataCell(Text('${_formatNumber(item.totalSYP)} ل.س')),
                      ])),
                      DataRow(
                        color: WidgetStateProperty.all(Colors.orange.shade50),
                        cells: [
                          const DataCell(Text('')),
                          const DataCell(Text('')),
                          const DataCell(Text('')),
                          const DataCell(Text('')),
                          const DataCell(Text('')),
                          const DataCell(Text('الإجمالي:', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataCell(Text('\$${_formatNumber(supportTotalUSD)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange))),
                          DataCell(Text('${_formatNumber(supportTotalSYP)} ل.س', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange))),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        color: Colors.purple.shade50,
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Divider(thickness: 2),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'الإجمالي النهائي:',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.purple),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '\$${_formatNumber(grandTotalUSD)}',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green),
                    ),
                    Text(
                      '${_formatNumber(grandTotalSYP)} ل.س',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('رجوع'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
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

  String _formatNumber(double number) {
    if (number == 0) return '0';
    final formatter = NumberFormat.decimalPattern('ar');
    return formatter.format(number);
  }

  Future<void> _sharePDF(
    BuildContext context,
    List<InvoiceItem> allItems,
    double mattressTotalUSD,
    double mattressTotalSYP,
    double supportTotalUSD,
    double supportTotalSYP,
    double grandTotalUSD,
    double grandTotalSYP,
    String currentDate,
    double mattressDollarPrice,
    double supportDollarPrice,
    String mattressType,
    String supportType,
  ) async {
    if (grandTotalUSD == 0) {
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
              child: pw.Text('الفاتورة النهائية',
                style: pw.TextStyle(font: ttfBold, fontSize: 24)
              )
            ),
            pw.SizedBox(height: 10),
            pw.Text('التاريخ: $currentDate', style: pw.TextStyle(font: ttf, fontSize: 12)),
            pw.Text('نوع إسفنج الفرشات: $mattressType', style: pw.TextStyle(font: ttf, fontSize: 12)),
            pw.Text('نوع مسند المساند: $supportType', style: pw.TextStyle(font: ttf, fontSize: 12)),
            pw.Text('سعر دولار الفرشات: ${_formatNumber(mattressDollarPrice)} ل.س', style: pw.TextStyle(font: ttf, fontSize: 12)),
            pw.Text('سعر دولار المساند: ${_formatNumber(supportDollarPrice)} ل.س', style: pw.TextStyle(font: ttf, fontSize: 12)),
            pw.SizedBox(height: 20),
            pw.Table(
              border: pw.TableBorder.all(),
              children: [
                pw.TableRow(children: [
                  pw.Text('القسم', style: pw.TextStyle(font: ttfBold)),
                  pw.Text('النوع', style: pw.TextStyle(font: ttfBold)),
                  pw.Text('الأبعاد', style: pw.TextStyle(font: ttfBold)),
                  pw.Text('الارتفاع', style: pw.TextStyle(font: ttfBold)),
                  pw.Text('العدد', style: pw.TextStyle(font: ttfBold)),
                  pw.Text('الخصم %', style: pw.TextStyle(font: ttfBold)),
                  pw.Text('الإجمالي (\$)', style: pw.TextStyle(font: ttfBold)),
                ]),
                for (var item in allItems)
                  pw.TableRow(children: [
                    pw.Text(item.section, style: pw.TextStyle(font: ttf)),
                    pw.Text(item.type, style: pw.TextStyle(font: ttf)),
                    pw.Text(item.dimensions, style: pw.TextStyle(font: ttf)),
                    pw.Text(item.height.toString(), style: pw.TextStyle(font: ttf)),
                    pw.Text(item.quantity.toString(), style: pw.TextStyle(font: ttf)),
                    pw.Text(item.discount.toString(), style: pw.TextStyle(font: ttf)),
                    pw.Text(item.totalUSD.toStringAsFixed(2), style: pw.TextStyle(font: ttf)),
                  ]),
              ],
            ),
            pw.SizedBox(height: 20),
            pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
              pw.Text('إجمالي الفرشات:', style: pw.TextStyle(font: ttfBold)),
              pw.Text('\$${_formatNumber(mattressTotalUSD)}  /  ${_formatNumber(mattressTotalSYP)} ل.س', style: pw.TextStyle(font: ttf)),
            ]),
            pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
              pw.Text('إجمالي المساند:', style: pw.TextStyle(font: ttfBold)),
              pw.Text('\$${_formatNumber(supportTotalUSD)}  /  ${_formatNumber(supportTotalSYP)} ل.س', style: pw.TextStyle(font: ttf)),
            ]),
            pw.Divider(),
            pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
              pw.Text('الإجمالي النهائي:', style: pw.TextStyle(font: ttfBold, fontSize: 16)),
              pw.Text('\$${_formatNumber(grandTotalUSD)}  /  ${_formatNumber(grandTotalSYP)} ل.س', style: pw.TextStyle(font: ttf)),
            ]),
          ],
        ),
      );

      final output = await getTemporaryDirectory();
      final file = File('${output.path}/final_invoice.pdf');
      await file.writeAsBytes(await pdf.save());

      await Share.shareXFiles([XFile(file.path)], text: 'الفاتورة النهائية - $currentDate');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم مشاركة الفاتورة بنجاح'), backgroundColor: Colors.green),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ: $e'), backgroundColor: Colors.red),
      );
    }
  }
}

class InvoiceItem {
  final String section;
  final String type;
  final String dimensions;
  final double height;
  final double quantity;
  final double discount;
  final double totalUSD;
  final double totalSYP;

  InvoiceItem({
    required this.section,
    required this.type,
    required this.dimensions,
    required this.height,
    required this.quantity,
    required this.discount,
    required this.totalUSD,
    required this.totalSYP,
  });
}