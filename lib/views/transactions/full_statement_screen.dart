import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import 'package:moofid_mobile/viewmodels/invoice_viewmodel.dart';
import 'package:moofid_mobile/viewmodels/settings_viewmodel.dart';
import 'package:moofid_mobile/viewmodels/customer_viewmodel.dart';
import 'package:moofid_mobile/models/customer_model.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class FullStatementScreen extends StatefulWidget {
  final Customer customer;
  const FullStatementScreen({super.key, required this.customer});

  @override
  State<FullStatementScreen> createState() => _FullStatementScreenState();
}

class _FullStatementScreenState extends State<FullStatementScreen> {
  List<Map<String, dynamic>> _allInstallments = [];
  bool _isLoading = true;
  final _currencyFormat = NumberFormat('#,##0.00');

  // Arabic Month Names (Traditional levantine/Iraqi names)
  final List<String> _arabicMonths = [
    "كانون الثاني", "شباط", "آذار", "نيسان", "أيار", "حزيران",
    "تموز", "آب", "أيلول", "تشرين الأول", "تشرين الثاني", "كانون الأول"
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() async {
    final data = await context.read<InvoiceViewModel>().getAllInstallments(widget.customer.id);
    setState(() {
      _allInstallments = data;
      _isLoading = false;
    });
  }

  Future<void> _generateAndPrintPdf() async {
    final pdf = pw.Document();
    final settings = context.read<SettingsViewModel>().settings;
    final storeName = settings?.storeName ?? 'مكتب مفيد للأقساط';
    final storePhone = settings?.storePhone ?? '';
    final storeAddress = settings?.storeAddress ?? '';
    
    // Load font for Arabic support
    final font = await PdfGoogleFonts.cairoRegular();
    final boldFont = await PdfGoogleFonts.cairoBold();

    final cvm = context.read<CustomerViewModel>();
    final customer = cvm.customers.firstWhere(
      (c) => c.id == widget.customer.id,
      orElse: () => widget.customer,
    );

    final paidIQD = _allInstallments.where((i) => i['Currency'] == 'IQD' || i['Currency'] == null).fold(0.0, (sum, i) => sum + (i['PaidAmount'] ?? 0.0));
    final paidUSD = _allInstallments.where((i) => i['Currency'] == 'USD').fold(0.0, (sum, i) => sum + (i['PaidAmount'] ?? 0.0));
    
    final remainingIQD = customer.totalDebtIQD;
    final remainingUSD = customer.totalDebtUSD;
    
    final totalIQD = paidIQD + remainingIQD;
    final totalUSD = paidUSD + remainingUSD;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(base: font, bold: boldFont),
        build: (pw.Context context) {
          return pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                pw.Center(child: pw.Text(storeName, style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold))),
                if (storePhone.isNotEmpty || storeAddress.isNotEmpty)
                   pw.Center(child: pw.Text('$storePhone | $storeAddress', style: const pw.TextStyle(fontSize: 10))),
                pw.Center(child: pw.Text('كشف حساب مالي تفصيلي')),
                pw.Divider(),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('العميل: ${widget.customer.name}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    pw.Text('التاريخ: ${DateFormat('yyyy/MM/dd').format(DateTime.now())}'),
                  ],
                ),
                pw.SizedBox(height: 20),
                pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey)),
                  child: pw.Column(
                    children: [
                      if (totalIQD > 0 || remainingIQD > 0) ...[
                        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('${_currencyFormat.format(totalIQD)} IQD'), pw.Text('إجمالي مبلغ الديون (دينار):')]),
                        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('${_currencyFormat.format(remainingIQD)} IQD', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)), pw.Text('المبلغ المتبقي (دينار):')]),
                      ],
                      if (totalUSD > 0 || remainingUSD > 0) ...[
                        if (totalIQD > 0) pw.SizedBox(height: 5),
                        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('${_currencyFormat.format(totalUSD)} USD'), pw.Text('إجمالي مبلغ الديون (دولار):')]),
                        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('${_currencyFormat.format(remainingUSD)} USD', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)), pw.Text('المبلغ المتبقي (دولار):')]),
                      ],
                    ],
                  ),
                ),
                pw.SizedBox(height: 20),
                pw.TableHelper.fromTextArray(
                  headers: ['الحالة', 'المادة', 'الشهر', 'المبلغ', '#'],
                  data: _allInstallments.map((i) {
                    final date = DateTime.parse(i['DueDate']);
                    return [
                      i['IsPaid'] == 1 ? 'تم التسديد' : 'مطلوب',
                      i['ItemName'] ?? '-',
                      _arabicMonths[date.month - 1],
                      '${_currencyFormat.format(i['Amount'])} ${i['Currency'] ?? 'IQD'}',
                      i['InstallmentNumber'].toString(),
                    ];
                  }).toList(),
                  headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  cellAlignment: pw.Alignment.center,
                ),
              ],
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('كشف الحساب التفصيلي'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.print_outlined),
            onPressed: _isLoading ? null : _generateAndPrintPdf,
          ),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(),
                const SizedBox(height: 32),
                _buildSummaryTable(),
                const SizedBox(height: 32),
                const Text(
                  'تفاصيل الأقساط:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  textAlign: TextAlign.right,
                ),
                const SizedBox(height: 12),
                _buildInstallmentsTable(),
                const SizedBox(height: 40),
                _buildFooter(),
              ],
            ),
          ),
    );
  }

  Widget _buildHeader() {
    final settings = context.watch<SettingsViewModel>().settings;
    final storeName = settings?.storeName ?? 'مكتب مفيد للأقساط';
    
    return Column(
      children: [
        Text(
          storeName,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.primary),
        ),
        const Text('كشف حساب مالي ذكي'),
        const Divider(height: 32, thickness: 2),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('تاريخ الإصدار:', style: TextStyle(color: AppColors.outline, fontSize: 12)),
                Text(DateFormat('yyyy/MM/dd').format(DateTime.now()), style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text('اسم العميل:', style: TextStyle(color: AppColors.outline, fontSize: 12)),
                Text(widget.customer.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSummaryTable() {
    return Consumer<CustomerViewModel>(
      builder: (context, cvm, child) {
        final customer = cvm.customers.firstWhere(
          (c) => c.id == widget.customer.id,
          orElse: () => widget.customer,
        );

        final paidIQD = _allInstallments.where((i) => i['Currency'] == 'IQD' || i['Currency'] == null).fold(0.0, (sum, i) => sum + (i['PaidAmount'] ?? 0.0));
        final paidUSD = _allInstallments.where((i) => i['Currency'] == 'USD').fold(0.0, (sum, i) => sum + (i['PaidAmount'] ?? 0.0));
        
        final remainingIQD = customer.totalDebtIQD;
        final remainingUSD = customer.totalDebtUSD;
        
        final totalIQD = paidIQD + remainingIQD;
        final totalUSD = paidUSD + remainingUSD;

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.outlineVariant),
          ),
          child: Column(
            children: [
              if (totalIQD > 0 || remainingIQD > 0) ...[
                _buildSummaryRow('إجمالي دين (دينار):', _currencyFormat.format(totalIQD)),
                _buildSummaryRow('المتبقي (دينار):', _currencyFormat.format(remainingIQD), color: AppColors.tertiary, isBold: true),
              ],
              if (totalUSD > 0 || remainingUSD > 0) ...[
                if (totalIQD > 0) const Divider(),
                _buildSummaryRow('إجمالي دين (دولار):', _currencyFormat.format(totalUSD)),
                _buildSummaryRow('المتبقي (دولار):', _currencyFormat.format(remainingUSD), color: AppColors.tertiary, isBold: true),
              ],
            ],
          ),
        );
      }
    );
  }

  Widget _buildSummaryRow(String label, String value, {Color? color, bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(value, style: TextStyle(fontWeight: isBold ? FontWeight.w900 : FontWeight.bold, color: color, fontSize: 16)),
          Text(label, style: const TextStyle(fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildInstallmentsTable() {
    return Table(
      border: TableBorder.symmetric(inside: const BorderSide(color: AppColors.outlineVariant, width: 0.5)),
      columnWidths: const {
        0: FlexColumnWidth(2),
        1: FlexColumnWidth(2),
        2: FlexColumnWidth(2), // Month column
        3: FlexColumnWidth(2),
        4: FlexColumnWidth(1),
      },
      children: [
        TableRow(
          decoration: const BoxDecoration(color: AppColors.surfaceContainerHighest),
          children: [
            _tableHeader('الحالة'),
            _tableHeader('المادة'),
            _tableHeader('الشهر'),
            _tableHeader('المبلغ'),
            _tableHeader('#'),
          ],
        ),
        ..._allInstallments.map((inst) {
          final isPaid = inst['IsPaid'] == 1;
          final date = DateTime.parse(inst['DueDate']);
          return TableRow(
            children: [
              _tableCell(isPaid ? 'تم التسديد' : 'مطلوب', color: isPaid ? Colors.green : Colors.red),
              _tableCell(inst['ItemName'] ?? '-', small: true),
              _tableCell(_arabicMonths[date.month - 1], small: true),
              _tableCell('${_currencyFormat.format(inst['Amount'])} ${inst['Currency'] ?? 'IQD'}', small: true),
              _tableCell(inst['InstallmentNumber'].toString()),
            ],
          );
        }),
      ],
    );
  }

  Widget _tableHeader(String text) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Text(text, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
    );
  }

  Widget _tableCell(String text, {Color? color, bool small = false}) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Text(
        text, 
        textAlign: TextAlign.center, 
        style: TextStyle(color: color, fontSize: small ? 10 : 12, fontWeight: color != null ? FontWeight.bold : FontWeight.normal)
      ),
    );
  }

  Widget _buildFooter() {
    return Column(
      children: [
        const Divider(thickness: 2),
        const SizedBox(height: 8),
        const Text(
          'شكراً لثقتكم بنا. يرجى مراجعة الحساب في حال وجود أي استفسار.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: AppColors.outline),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildSignatureArea('ختم المكتب'),
            _buildSignatureArea('توقيع المحاسب'),
          ],
        ),
      ],
    );
  }

  Widget _buildSignatureArea(String label) {
    return Column(
      children: [
        Container(
          width: 100,
          height: 60,
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.outlineVariant, style: BorderStyle.solid),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 10)),
      ],
    );
  }
}
