import 'dart:io';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../database/database_helper.dart';

class ExportService {
  static Future<void> exportToExcel() async {
    final db = await DatabaseHelper.instance.database;
    final excel = Excel.createExcel();

    // 1. Customers Sheet
    final customers = await db.query('Customers', where: 'IsDeleted = 0');
    Sheet customerSheet = excel['العملاء'];
    customerSheet.appendRow([
      TextCellValue('الاسم'),
      TextCellValue('الهاتف'),
      TextCellValue('العنوان'),
      TextCellValue('ملاحظات'),
      TextCellValue('تاريخ الإنشاء'),
    ]);

    for (var row in customers) {
      customerSheet.appendRow([
        TextCellValue(row['Name']?.toString() ?? ''),
        TextCellValue(row['Phone']?.toString() ?? ''),
        TextCellValue(row['Address']?.toString() ?? ''),
        TextCellValue(row['Notes']?.toString() ?? ''),
        TextCellValue(row['CreatedAt']?.toString() ?? ''),
      ]);
    }

    // 2. Invoices Sheet
    final invoices = await db.rawQuery('''
      SELECT i.*, c.Name as CustomerName 
      FROM Invoices i
      JOIN Customers c ON i.CustomerId = c.Id
      WHERE i.IsDeleted = 0
    ''');
    Sheet invoiceSheet = excel['القوائم والفواتير'];
    invoiceSheet.appendRow([
      TextCellValue('اسم العميل'),
      TextCellValue('المادة/الغرض'),
      TextCellValue('المبلغ الكلي'),
      TextCellValue('المقدمة'),
      TextCellValue('العملة'),
      TextCellValue('عدد الأشهر'),
      TextCellValue('حالة التسديد'),
      TextCellValue('التاريخ'),
    ]);

    for (var row in invoices) {
      invoiceSheet.appendRow([
        TextCellValue(row['CustomerName']?.toString() ?? ''),
        TextCellValue(row['ItemName']?.toString() ?? ''),
        DoubleCellValue(double.tryParse(row['TotalAmount'].toString()) ?? 0.0),
        DoubleCellValue(double.tryParse(row['DownPayment'].toString()) ?? 0.0),
        TextCellValue(row['Currency']?.toString() ?? ''),
        IntCellValue(int.tryParse(row['NumberOfMonths'].toString()) ?? 0),
        TextCellValue(row['IsFullyPaid'] == 1 ? 'مسددة بالكامل' : 'قيد التسديد'),
        TextCellValue(row['CreatedAt']?.toString() ?? ''),
      ]);
    }

    // 3. Payments Sheet
    final payments = await db.rawQuery('''
      SELECT p.*, c.Name as CustomerName, i.ItemName
      FROM PaymentTransactions p
      JOIN Invoices i ON p.InvoiceId = i.Id
      JOIN Customers c ON i.CustomerId = c.Id
      WHERE p.IsDeleted = 0
    ''');
    Sheet paymentSheet = excel['الدفعات المستلمة'];
    paymentSheet.appendRow([
      TextCellValue('العميل'),
      TextCellValue('الفاتورة'),
      TextCellValue('المبلغ المدفوع'),
      TextCellValue('تاريخ الدفع'),
      TextCellValue('ملاحظات'),
    ]);

    for (var row in payments) {
      paymentSheet.appendRow([
        TextCellValue(row['CustomerName']?.toString() ?? ''),
        TextCellValue(row['ItemName']?.toString() ?? ''),
        DoubleCellValue(double.tryParse(row['AmountPaid'].toString()) ?? 0.0),
        TextCellValue(row['PaymentDate']?.toString() ?? ''),
        TextCellValue(row['Notes']?.toString() ?? ''),
      ]);
    }

    // 4. Detailed Installments Sheet
    final installments = await db.rawQuery('''
      SELECT inst.*, i.ItemName, c.Name as CustomerName
      FROM Installments inst
      JOIN Invoices i ON inst.InvoiceId = i.Id
      JOIN Customers c ON i.CustomerId = c.Id
      WHERE inst.IsDeleted = 0
    ''');
    Sheet installmentSheet = excel['الأقساط التفصيلية'];
    installmentSheet.appendRow([
      TextCellValue('العميل'),
      TextCellValue('الفاتورة'),
      TextCellValue('رقم القسط'),
      TextCellValue('المبلغ'),
      TextCellValue('المبلغ المدفوع'),
      TextCellValue('تاريخ الاستحقاق'),
      TextCellValue('حالة القسط'),
      TextCellValue('تاريخ الدفع الفعلي'),
    ]);

    for (var row in installments) {
      installmentSheet.appendRow([
        TextCellValue(row['CustomerName']?.toString() ?? ''),
        TextCellValue(row['ItemName']?.toString() ?? ''),
        IntCellValue(int.tryParse(row['InstallmentNumber'].toString()) ?? 0),
        DoubleCellValue(double.tryParse(row['Amount'].toString()) ?? 0.0),
        DoubleCellValue(double.tryParse(row['PaidAmount'].toString()) ?? 0.0),
        TextCellValue(row['DueDate']?.toString() ?? ''),
        TextCellValue(row['IsPaid'] == 1 ? 'مدفوع' : 'غير مدفوع'),
        TextCellValue(row['PaidDate']?.toString() ?? ''),
      ]);
    }

    // Set Column Widths to prevent ######## issue
    for (var sheet in excel.sheets.values) {
      for (var i = 0; i < 10; i++) {
        sheet.setColumnWidth(i, 20.0);
      }
    }

    // Remove default sheet
    if (excel.sheets.containsKey('Sheet1')) {
      excel.delete('Sheet1');
    }

    // Save and Share
    final bytes = excel.save();
    if (bytes != null) {
      final directory = await getTemporaryDirectory();
      final date = DateFormat('yyyy-MM-dd_HH-mm').format(DateTime.now());
      final filePath = '${directory.path}/Mofid_Data_$date.xlsx';
      final file = File(filePath);
      await file.writeAsBytes(bytes);

      await Share.shareXFiles(
        [XFile(filePath)],
        subject: 'تصدير بيانات مفيد للأقساط',
        text: 'ملف إكسل شامل لبيانات العملاء والفواتير والأقساط والدفعات المستلمة.',
      );
    }
  }
}
