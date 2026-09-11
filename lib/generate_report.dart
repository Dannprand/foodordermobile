import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:excel/excel.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';

// Format Rupiah
String formatCurrency(num value) {
  return 'Rp ${value.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (match) => '${match[1]}.')}';
}

// Helper Rata Kanan
pw.Widget buildAmountLineRight(String label, dynamic value, {bool isBold = false}) {
  return pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.end,
    children: [
      pw.SizedBox(width: 120, child: pw.Text(label, textAlign: pw.TextAlign.right)),
      pw.Text(' : '),
      pw.SizedBox(
        width: 100,
        child: pw.Text(
          value.toString(),
          textAlign: pw.TextAlign.right,
          style: isBold ? pw.TextStyle(fontWeight: pw.FontWeight.bold) : null,
        ),
      ),
    ],
  );
}

// Helper Rata Kiri
pw.Widget buildAmountLineLeft(String label, dynamic value, {bool isBold = false}) {
  return pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.start,
    children: [
      pw.SizedBox(width: 100, child: pw.Text(label, textAlign: pw.TextAlign.left)),
      pw.Text(': '),
      pw.Text(
        value.toString(),
        style: isBold ? pw.TextStyle(fontWeight: pw.FontWeight.bold) : null,
      ),
    ],
  );
}

Future<Uint8List> generatePdfReport(String title, Map<String, String> params) async {
  final pdf = pw.Document();

  final uri = Uri.parse('http://172.19.10.208/food_order_api/get_filter_order_details.php')
      .replace(queryParameters: params);
  final response = await http.get(uri);
  if (response.statusCode != 200) throw Exception('Failed to fetch data');

  final List<dynamic> data = jsonDecode(response.body);
  final List<Map<String, dynamic>> orders = data.map((e) => Map<String, dynamic>.from(e)).toList();

  final grouped = <String, Map<String, dynamic>>{};
  for (var order in orders) {
    grouped[order['order_id'].toString()] = order;
  }

  // Hitung ulang dari detail item
  double totalTax = 0;
  double totalServiceCharge = 0;
  double grandTotal = 0;

  for (var order in grouped.values) {
    final List<dynamic> items = (order['items'] ?? []);
    for (var item in items) {
      totalTax += (item['food_service_tax'] ?? 0).toDouble();
      totalServiceCharge += (item['food_service_charge'] ?? 0).toDouble();
      grandTotal += (item['food_price'] ?? 0).toDouble();
    }
  }

  String _getMonthName(int month) {
    const months = [
      'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
    ];
    return months[month - 1];
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '';
    try {
      final dateTime = DateTime.parse(dateStr);
      return '${dateTime.day} ${_getMonthName(dateTime.month)} ${dateTime.year}';
    } catch (e) {
      return '';
    }
  }

  String getPeriodText(Map<String, String> params) {
    if (params.containsKey('day')) {
      return _formatDate(params['day']);
    } else if (params.containsKey('month') && params.containsKey('year')) {
      return '${_getMonthName(int.parse(params['month']!))} ${params['year']}';
    } else if (params.containsKey('year')) {
      return params['year']!;
    } else if (params.containsKey('from') && params.containsKey('to')) {
      final from = _formatDate(params['from']);
      final to = _formatDate(params['to']);
      return '$from s/d $to';
    } else {
      return 'Semua Periode';
    }
  }

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.all(24),
      footer: (context) => pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text(
          'Page ${context.pageNumber} / ${context.pagesCount}',
          style: pw.TextStyle(fontSize: 10),
        ),
      ),

      // ✅ HEADER MUNCUL DI SETIAP HALAMAN
      header: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Center(
            child: pw.Text(
              title,
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: pw.EdgeInsets.only(bottom: 8),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                buildAmountLineLeft('Tenant Name', orders.isNotEmpty ? orders.first['tenant_name'] : '-'),
                buildAmountLineLeft('Period', getPeriodText(params)),
                buildAmountLineLeft('Order Status', 'Complete'),
              ],
            ),
          ),
          pw.SizedBox(height: 10),
          pw.Container(
            color: PdfColors.grey200,
            padding: pw.EdgeInsets.symmetric(vertical: 6, horizontal: 4),
            child: pw.Row(
              children: [
                pw.Expanded(flex: 2, child: pw.Text('Date')),
                pw.Expanded(flex: 2, child: pw.Text('Order ID')),
                pw.Expanded(flex: 3, child: pw.Text('Patient Name')),
                pw.Expanded(flex: 3, child: pw.Text('Order Item')),
                pw.Expanded(flex: 1, child: pw.Text('Item')),
                pw.Expanded(flex: 2, child: pw.Text('Tax')),
                pw.Expanded(flex: 2, child: pw.Text('Service Charge')),
                pw.Expanded(flex: 2, child: pw.Text('Total Price')),
              ],
            ),
          ),
          pw.SizedBox(height: 4),
        ],
      ),

      // ✅ BODY UTAMA
      build: (context) => [
        ...grouped.entries.expand((entry) {
          final order = entry.value;
          final List<dynamic> items = (order['items'] ?? []);
          return items.asMap().entries.map((itemEntry) {
            final i = itemEntry.key;
            final item = itemEntry.value;
            return pw.Container(
              padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 4),
              child: pw.Row(
                children: [
                  pw.Expanded(
                    flex: 2,
                    child: i == 0
                        ? pw.Text(_formatDate(order['order_date']))
                        : pw.Text(''),
                  ),
                  pw.Expanded(flex: 2, child: i == 0 ? pw.Text(order['order_number'] ?? '') : pw.Text('')),
                  pw.Expanded(flex: 3, child: i == 0 ? pw.Text(order['patient_name'] ?? '') : pw.Text('')),
                  pw.Expanded(flex: 3, child: pw.Text(item['food_name'] ?? '-')),
                  pw.Expanded(flex: 1, child: pw.Text('${item['quantity'] ?? 0}')),
                  pw.Expanded(flex: 2, child: pw.Text(formatCurrency(item['food_service_tax'] ?? 0))),
                  pw.Expanded(flex: 2, child: pw.Text(formatCurrency(item['food_service_charge'] ?? 0))),
                  pw.Expanded(flex: 2, child: pw.Text(
                    formatCurrency(item['food_price'] ?? 0),
                    textAlign: pw.TextAlign.right,
                  )),
                ],
              ),
            );
          });
        }),

        pw.SizedBox(height: 10),

        // ✅ BAGIAN PENUTUP (dengan KeepTogether agar tidak terpotong)
        pw.Wrap(
          runSpacing: 4,
          children: [
            pw.Divider(),
            pw.Container(
              alignment: pw.Alignment.centerRight,
              margin: const pw.EdgeInsets.only(top: 4, bottom: 12),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  buildAmountLineRight('Total Tax', formatCurrency(totalTax)),
                  buildAmountLineRight('Total Service Charge', formatCurrency(totalServiceCharge)),
                  buildAmountLineRight('Grand Total', formatCurrency(grandTotal), isBold: true),
                ],
              ),
            ),
            pw.Text('END OF REPORT'),
          ],
        )



      ],
    ),
  );

  return pdf.save();
}

Future<String> generateExcelReport(Map<String, String> params) async {
  final response = await http.get(Uri.parse('http://172.19.10.208/food_order_api/get_filter_order_details.php').replace(queryParameters: params));
  if (response.statusCode != 200) throw Exception('Gagal mengambil data');

  final List<dynamic> data = jsonDecode(response.body);
  final List<Map<String, dynamic>> orders = data.map((e) => Map<String, dynamic>.from(e)).toList();

  final excel = Excel.createExcel();
  final Sheet sheet = excel['Sales Report'];

  final header = ['Date', 'Order ID', 'Patient Name', 'Order Item', 'Qty', 'Tax', 'Service Charge', 'Total Price'];
  sheet.appendRow(header);

  double totalTax = 0, totalServiceCharge = 0, grandTotal = 0;
  final grouped = <String, Map<String, dynamic>>{};
  for (var order in orders) {
    grouped[order['order_id'].toString()] = order;
  }

  for (var order in grouped.values) {
    final items = (order['items'] is List) ? order['items'] : [];
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      final isFirst = i == 0;

      final row = [
        isFirst ? order['order_date'] : '',
        isFirst ? order['order_number'] : '',
        isFirst ? order['patient_name'] : '',
        item['food_name'] ?? '-',
        item['quantity'] ?? 0,
        item['food_service_tax']?.toDouble() ?? 0,
        item['food_service_charge']?.toDouble() ?? 0,
        item['food_price']?.toDouble() ?? 0,
      ];
      sheet.appendRow(row);

      totalTax += (item['food_service_tax'] ?? 0).toDouble();
      totalServiceCharge += (item['food_service_charge'] ?? 0).toDouble();
      grandTotal += (item['food_price'] ?? 0).toDouble();
    }
  }

  sheet.appendRow([]);
  sheet.appendRow(['', '', '', '', '', 'Total Tax', '', totalTax]);
  sheet.appendRow(['', '', '', '', '', 'Total Service Charge', '', totalServiceCharge]);
  sheet.appendRow(['', '', '', '', '', 'Grand Total', '', grandTotal]);
  sheet.appendRow([]);
  sheet.appendRow(['END OF REPORT']);

  final dir = await getApplicationDocumentsDirectory();
  final filePath = '${dir.path}/sales_report_${DateTime.now().millisecondsSinceEpoch}.xlsx';
  final file = File(filePath);
  final excelBytes = excel.encode();
  if (excelBytes == null) throw Exception('Gagal encode Excel');

  await file.writeAsBytes(excelBytes);
  return filePath;
}
