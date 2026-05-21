import 'dart:io';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../models/customer.dart';
import '../models/transaction.dart';
import '../utils/constants.dart';

class PdfGenerator {
  static Future<void> generateReturnInvoice({
    required Customer customer,
    required Transaction transaction,
  }) async {
    final pdf = pw.Document();
    
    final totalBeforeDiscount = transaction.quantity * transaction.pricePerUnit;
    final discountAmount = totalBeforeDiscount * (transaction.discountPercent / 100);
    final totalAfterDiscount = totalBeforeDiscount - discountAmount;
    
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.all(20),
        build: (context) => [
          pw.Center(
            child: pw.Column(
              children: [
                pw.Text(
                  companyName,
                  style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 10),
                pw.Text(
                  'فاتورة إرجاع',
                  style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 20),
              ],
            ),
          ),
          pw.Container(
            padding: pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(border: pw.Border.all()),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('العميل: ${customer.name}'),
                if (customer.phone != null) pw.Text('الهاتف: ${customer.phone}'),
                pw.Text('التاريخ: ${DateFormat('yyyy-MM-dd').format(DateTime.now())}'),
              ],
            ),
          ),
          pw.SizedBox(height: 20),
          pw.Table(
            border: pw.TableBorder.all(),
            children: [
              pw.TableRow(
                decoration: pw.BoxDecoration(color: PdfColors.grey300),
                children: [
                  pw.Padding(padding: pw.EdgeInsets.all(8), child: pw.Text('البيان', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                  pw.Padding(padding: pw.EdgeInsets.all(8), child: pw.Text('الكمية', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                  pw.Padding(padding: pw.EdgeInsets.all(8), child: pw.Text('سعر الوحدة', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                  pw.Padding(padding: pw.EdgeInsets.all(8), child: pw.Text('الخصم', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                  pw.Padding(padding: pw.EdgeInsets.all(8), child: pw.Text('الإجمالي', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                ],
              ),
              pw.TableRow(
                children: [
                  pw.Padding(padding: pw.EdgeInsets.all(8), child: pw.Text(transaction.materialName)),
                  pw.Padding(padding: pw.EdgeInsets.all(8), child: pw.Text('${transaction.quantity.toStringAsFixed(2)} ${materialUnit[transaction.materialName]}')),
                  pw.Padding(padding: pw.EdgeInsets.all(8), child: pw.Text('${transaction.pricePerUnit.toStringAsFixed(2)} $currencySymbol')),
                  pw.Padding(padding: pw.EdgeInsets.all(8), child: pw.Text('${transaction.discountPercent}%')),
                  pw.Padding(padding: pw.EdgeInsets.all(8), child: pw.Text('${totalAfterDiscount.toStringAsFixed(2)} $currencySymbol')),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 20),
          pw.Container(
            alignment: pw.Alignment.centerRight,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text('الإجمالي قبل الخصم: ${totalBeforeDiscount.toStringAsFixed(2)} $currencySymbol'),
                pw.Text('قيمة الخصم: ${discountAmount.toStringAsFixed(2)} $currencySymbol'),
                pw.Text(
                  'الإجمالي بعد الخصم: ${totalAfterDiscount.toStringAsFixed(2)} $currencySymbol',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 30),
          pw.Container(
            alignment: pw.Alignment.center,
            child: pw.Column(
              children: [
                pw.Text(managerName),
                pw.Text(contactPhone),
              ],
            ),
          ),
        ],
      ),
    );
    
    final output = await getTemporaryDirectory();
    final file = File('${output.path}/return_invoice_${customer.id}_${DateTime.now().millisecondsSinceEpoch}.pdf');
    await file.writeAsBytes(await pdf.save());
    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'فاتورة إرجاع - ${customer.name}',
    );
  }
  
  static Future<void> generateCustomerReport({
    required Customer customer,
    required List<Transaction> transactions,
    required List<Map<String, dynamic>> remainingMaterials,
  }) async {
    final pdf = pw.Document();
    
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.all(20),
        build: (context) => [
          pw.Center(
            child: pw.Text(
              companyName,
              style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.SizedBox(height: 10),
          pw.Center(
            child: pw.Text(
              'تقرير العميل',
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.SizedBox(height: 20),
          pw.Container(
            padding: pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(border: pw.Border.all()),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('العميل: ${customer.name}'),
                if (customer.phone != null) pw.Text('الهاتف: ${customer.phone}'),
                pw.Text('تاريخ التقرير: ${DateFormat('yyyy-MM-dd').format(DateTime.now())}'),
              ],
            ),
          ),
          pw.SizedBox(height: 20),
          if (remainingMaterials.isNotEmpty) ...[
            pw.Text('الكميات المتبقية', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
            pw.SizedBox(height: 10),
            ...remainingMaterials.map((item) => pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(item['materialName']),
                pw.Text('${(item['remaining'] as double).toStringAsFixed(2)} ${materialUnit[item['materialName']]}'),
              ],
            )).toList(),
            pw.SizedBox(height: 20),
          ],
          pw.Text('سجل المعاملات', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
          pw.SizedBox(height: 10),
          pw.Table(
            border: pw.TableBorder.all(),
            children: [
              pw.TableRow(
                decoration: pw.BoxDecoration(color: PdfColors.grey300),
                children: [
                  pw.Padding(padding: pw.EdgeInsets.all(8), child: pw.Text('التاريخ')),
                  pw.Padding(padding: pw.EdgeInsets.all(8), child: pw.Text('النوع')),
                  pw.Padding(padding: pw.EdgeInsets.all(8), child: pw.Text('المادة')),
                  pw.Padding(padding: pw.EdgeInsets.all(8), child: pw.Text('الكمية')),
                  pw.Padding(padding: pw.EdgeInsets.all(8), child: pw.Text('الإجمالي')),
                ],
              ),
              ...transactions.map((t) => pw.TableRow(
                children: [
                  pw.Padding(padding: pw.EdgeInsets.all(8), child: pw.Text(t.date)),
                  pw.Padding(padding: pw.EdgeInsets.all(8), child: pw.Text(t.type.name)),
                  pw.Padding(padding: pw.EdgeInsets.all(8), child: pw.Text(t.materialName)),
                  pw.Padding(padding: pw.EdgeInsets.all(8), child: pw.Text('${t.quantity.toStringAsFixed(2)} ${materialUnit[t.materialName]}')),
                  pw.Padding(padding: pw.EdgeInsets.all(8), child: pw.Text('${t.totalAfterDiscount.toStringAsFixed(2)} $currencySymbol')),
                ],
              )),
            ],
          ),
          pw.SizedBox(height: 30),
          pw.Container(
            alignment: pw.Alignment.center,
            child: pw.Column(
              children: [
                pw.Text(managerName),
                pw.Text(contactPhone),
              ],
            ),
          ),
        ],
      ),
    );
    
    final output = await getTemporaryDirectory();
    final file = File('${output.path}/customer_report_${customer.id}_${DateTime.now().millisecondsSinceEpoch}.pdf');
    await file.writeAsBytes(await pdf.save());
    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'تقرير العميل - ${customer.name}',
    );
  }
}