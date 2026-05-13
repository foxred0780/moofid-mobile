import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';

class StatementHelper {
  static final NumberFormat _format = NumberFormat('#,##0.00');

  /// Generates a professional text summary based on the user's specific format.
  static String generateTextSummary({
    required String customerName,
    required double totalDebtIQD,
    required double totalDebtUSD,
    required List<Map<String, dynamic>> installments,
    required List<Map<String, dynamic>> invoices,
    required DateTime? lastPaymentDate,
    String? storeName = "مكتب مفيد للأقساط",
  }) {
    final date = DateFormat('yyyy/MM/dd').format(DateTime.now());
    
    // Split installments by currency
    final installmentsIQD = installments.where((i) => i['Currency'] == 'IQD' || i['Currency'] == null).toList();
    final installmentsUSD = installments.where((i) => i['Currency'] == 'USD').toList();

    final paidIQD = installmentsIQD.fold(0.0, (sum, i) => sum + (i['PaidAmount'] ?? 0.0));
    final paidUSD = installmentsUSD.fold(0.0, (sum, i) => sum + (i['PaidAmount'] ?? 0.0));
    
    final originalIQD = paidIQD + totalDebtIQD;
    final originalUSD = paidUSD + totalDebtUSD;

    final paidCount = installments.where((i) => i['IsPaid'] == 1).length;
    final lastPaymentStr = lastPaymentDate != null ? DateFormat('yyyy/MM/dd').format(lastPaymentDate) : 'لا يوجد';

    StringBuffer buffer = StringBuffer();
    buffer.writeln("كشف حساب العميل: *$customerName*");
    buffer.writeln("التاريخ: $date");
    buffer.writeln("-------------------------");
    
    buffer.writeln("*تفاصيل المشتريات:*");
    for (int i = 0; i < invoices.length; i++) {
      final inv = invoices[i];
      final curr = inv['Currency'] ?? 'IQD';
      buffer.writeln("${i + 1}- المادة: ${inv['ItemName']} | السعر: ${_format.format(inv['TotalAmount'])} $curr | المقدمة: ${_format.format(inv['DownPayment'])} $curr");
    }
    buffer.writeln("");
    
    buffer.writeln("*تفاصيل الأقساط والدفعات:*");
    buffer.writeln("* عدد الأقساط الكلية المسددة: $paidCount");
    buffer.writeln("* تاريخ آخر الدفعات المسجلة: $lastPaymentStr");
    buffer.writeln("-------------------------");
    
    buffer.writeln("*الملخص المالي الختامي:*");
    if (originalIQD > 0 || totalDebtIQD > 0) {
      buffer.writeln("* بالدينار العراقي (IQD):");
      buffer.writeln("  - إجمالي المشتريات: ${_format.format(originalIQD)} د.ع");
      buffer.writeln("  - إجمالي المدفوع: ${_format.format(paidIQD)} د.ع");
      buffer.writeln("  - الباقي في الذمة: *${_format.format(totalDebtIQD)} د.ع*");
    }
    
    if (originalUSD > 0 || totalDebtUSD > 0) {
      if (originalIQD > 0) buffer.writeln("");
      buffer.writeln("* بالدولار الأمريكي (USD):");
      buffer.writeln("  - إجمالي المشتريات: \$${_format.format(originalUSD)}");
      buffer.writeln("  - إجمالي المدفوع: \$${_format.format(paidUSD)}");
      buffer.writeln("  - الباقي في الذمة: *\$${_format.format(totalDebtUSD)}*");
    }

    buffer.writeln("");
    buffer.writeln("نرجو مراجعة كشف الحساب، شكراً لتعاملكم معنا.");
    if (storeName != null && storeName.isNotEmpty) {
      buffer.writeln("");
      buffer.writeln("*$storeName*");
    }
    
    return buffer.toString();
  }

  /// Launches WhatsApp with the generated message.
  static Future<void> shareViaWhatsApp({
    required String phone,
    required String message,
  }) async {
    String cleanPhone = phone;
    if (cleanPhone.startsWith('0')) {
      cleanPhone = cleanPhone.substring(1);
    }
    
    final url = "https://wa.me/964$cleanPhone?text=${Uri.encodeComponent(message)}";
    final uri = Uri.parse(url);
    
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
    } catch (e) {
      await launchUrl(uri, mode: LaunchMode.platformDefault);
    }
  }

  /// Launches SMS app with the generated message.
  static Future<void> shareViaSMS({
    required String phone,
    required String message,
  }) async {
    String cleanPhone = phone;
    if (cleanPhone.startsWith('0')) {
      cleanPhone = cleanPhone.substring(1);
    }

    final url = "sms:0$cleanPhone?body=${Uri.encodeComponent(message)}";
    final uri = Uri.parse(url);
    
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }
}
