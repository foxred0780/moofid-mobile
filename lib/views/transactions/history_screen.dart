import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../models/customer_model.dart';
import '../../viewmodels/invoice_viewmodel.dart';
import '../../viewmodels/settings_viewmodel.dart';
import '../../viewmodels/customer_viewmodel.dart';
import '../../viewmodels/payment_viewmodel.dart';
import '../../viewmodels/dashboard_viewmodel.dart';

import '../widgets/collect_payment_dialog.dart';
import '../transactions/full_statement_screen.dart';
import '../../core/utils/statement_helper.dart';

class HistoryScreen extends StatefulWidget {
  final Customer customer;
  const HistoryScreen({super.key, required this.customer});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  int _currentPage = 1;
  final int _pageSize = 10;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<InvoiceViewModel>().fetchLedger(widget.customer.id);
    });
  }

  void _shareViaWhatsApp() async {
    final ivm = context.read<InvoiceViewModel>();
    final svm = context.read<SettingsViewModel>();
    final installments = await ivm.getAllInstallments(widget.customer.id);
    final invoices = await ivm.getInvoices(widget.customer.id);
    final lastPaymentDate = await ivm.getLastPaymentDate(widget.customer.id);
    
    // Find latest customer data
    final cvm = context.read<CustomerViewModel>();
    final customer = cvm.customers.firstWhere((c) => c.id == widget.customer.id, orElse: () => widget.customer);

    final message = StatementHelper.generateTextSummary(
      customerName: customer.name,
      totalDebtIQD: customer.totalDebtIQD,
      totalDebtUSD: customer.totalDebtUSD,
      installments: installments,
      invoices: invoices,
      lastPaymentDate: lastPaymentDate,
      storeName: svm.settings?.storeName ?? "مكتب مفيد للأقساط",
    );

    await StatementHelper.shareViaWhatsApp(phone: customer.phone, message: message);
  }

  void _shareViaSMS() async {
    final ivm = context.read<InvoiceViewModel>();
    final svm = context.read<SettingsViewModel>();
    final installments = await ivm.getAllInstallments(widget.customer.id);
    final invoices = await ivm.getInvoices(widget.customer.id);
    final lastPaymentDate = await ivm.getLastPaymentDate(widget.customer.id);
    
    final cvm = context.read<CustomerViewModel>();
    final customer = cvm.customers.firstWhere((c) => c.id == widget.customer.id, orElse: () => widget.customer);

    final message = StatementHelper.generateTextSummary(
      customerName: customer.name,
      totalDebtIQD: customer.totalDebtIQD,
      totalDebtUSD: customer.totalDebtUSD,
      installments: installments,
      invoices: invoices,
      lastPaymentDate: lastPaymentDate,
      storeName: svm.settings?.storeName ?? "مكتب مفيد للأقساط",
    );

    await StatementHelper.shareViaSMS(phone: customer.phone, message: message);
  }

  void _showEditCustomerDialog() {
    final nameController = TextEditingController(text: widget.customer.name);
    final phoneController = TextEditingController(text: widget.customer.phone);
    final addressController = TextEditingController(text: widget.customer.address);

    showDialog(
      context: context,
      builder: (context) {
        String? phoneError;
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('تعديل بيانات العميل', textAlign: TextAlign.right),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameController, decoration: const InputDecoration(labelText: 'الاسم'), textAlign: TextAlign.right),
                const SizedBox(height: 8),
                TextField(
                  controller: phoneController, 
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                    TextInputFormatter.withFunction((oldValue, newValue) {
                      if (newValue.text.startsWith('0')) {
                        return oldValue;
                      }
                      return newValue;
                    }),
                  ],
                  decoration: InputDecoration(
                    labelText: 'رقم الهاتف',
                    helperText: 'أدخل 10 أرقام (بدون صفر البداية)',
                    errorText: phoneError,
                  ), 
                  textAlign: TextAlign.right, 
                ),
                TextField(controller: addressController, decoration: const InputDecoration(labelText: 'العنوان'), textAlign: TextAlign.right),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
              ElevatedButton(
                onPressed: () async {
                  String phone = phoneController.text.trim();
                  
                  if (phone.length != 10) {
                    setDialogState(() => phoneError = 'يجب أن يكون الرقم 10 أرقام بالضبط');
                    return;
                  }

                  final success = await context.read<CustomerViewModel>().updateCustomer(
                    widget.customer.id,
                    name: nameController.text.trim(),
                    phone: phone,
                    address: addressController.text.trim(),
                  );
                  if (success && mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تحديث البيانات بنجاح')));
                  }
                },
                child: const Text('حفظ'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showDeleteConfirmation() {
    final confirmController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف العميل', style: TextStyle(color: Colors.red), textAlign: TextAlign.right),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('سيتم حذف العميل وكل فواتيره نهائياً. يرجى كتابة اسم العميل للتأكيد:', textAlign: TextAlign.right),
            const SizedBox(height: 8),
            Text(widget.customer.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            TextField(controller: confirmController, textAlign: TextAlign.center),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              if (confirmController.text.trim() != widget.customer.name.trim()) return;
              final success = await context.read<CustomerViewModel>().deleteCustomer(widget.customer.id, confirmController.text);
              if (success && mounted) {
                Navigator.pop(context);
                Navigator.pop(context); 
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حذف العميل بنجاح')));
              }
            },
            child: const Text('حذف نهائي'),
          ),
        ],
      ),
    );
  }

  void _showPaymentDialog() {
    showDialog(
      context: context,
      builder: (context) => CollectPaymentDialog(
        customerId: widget.customer.id,
        customerName: widget.customer.name,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currency = context.select<SettingsViewModel, String>(
      (s) => s.settings?.defaultCurrency ?? 'IQD',
    );
    final currencyFormat = NumberFormat('#,##0.00');

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.primary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('كشف حساب العميل', style: TextStyle(color: AppColors.onPrimaryContainer, fontWeight: FontWeight.bold)),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'edit') _showEditCustomerDialog();
              if (value == 'delete') _showDeleteConfirmation();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, size: 18), SizedBox(width: 8), Text('تعديل البيانات')])),
              const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, color: Colors.red, size: 18), SizedBox(width: 8), Text('حذف العميل', style: TextStyle(color: Colors.red))])),
            ],
          ),
        ],
      ),
      body: Consumer<InvoiceViewModel>(
        builder: (context, vm, child) {
          if (vm.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          return RefreshIndicator(
            onRefresh: () => vm.fetchLedger(widget.customer.id),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        flex: 1,
                        child: _buildActionButton(
                          icon: Icons.add_card,
                          label: 'تسديد دفعة',
                          color: AppColors.primary,
                          onTap: _showPaymentDialog,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 1,
                        child: _buildActionButton(
                          icon: Icons.description,
                          label: 'كشف مالي',
                          color: AppColors.tertiary,
                          onTap: () {
                             final latestCustomer = context.read<CustomerViewModel>().customers.firstWhere(
                               (c) => c.id == widget.customer.id, 
                               orElse: () => widget.customer
                             );
                             Navigator.push(context, MaterialPageRoute(builder: (_) => FullStatementScreen(customer: latestCustomer)));
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildActionButton(
                          icon: Icons.share,
                          label: 'واتساب',
                          color: const Color(0xFF25D366),
                          onTap: _shareViaWhatsApp,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildActionButton(
                          icon: Icons.sms,
                          label: 'SMS',
                          color: Colors.blue,
                          onTap: _shareViaSMS,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // Summary Card
                  _buildSummaryCard(currencyFormat, currency),
                  const SizedBox(height: 32),

                  // Transactions Ledger
                  _buildLedger(vm, currencyFormat, currency),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildActionButton({required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.surfaceContainerLowest,
        foregroundColor: AppColors.onSurface,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 2,
      ),
      icon: Icon(icon, color: color),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      onPressed: onTap,
    );
  }

  Widget _buildSummaryCard(NumberFormat format, String currency) {
    return Consumer<CustomerViewModel>(
      builder: (context, cvm, child) {
        final customer = cvm.customers.firstWhere(
          (c) => c.id == widget.customer.id,
          orElse: () => widget.customer,
        );

        return Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.3),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('إجمالي المديونية الحالية', style: TextStyle(color: Colors.white, fontSize: 12)),
              ),
              const SizedBox(height: 16),
              Text(
                customer.name,
                style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              Text(
                customer.phone,
                style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14),
              ),
              const SizedBox(height: 32),
              Align(
                alignment: Alignment.centerLeft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('الرصيد المتبقي', style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 14)),
                    if (customer.totalDebtIQD > 0 || customer.totalDebtUSD == 0)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            format.format(customer.totalDebtIQD), 
                            style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(width: 8),
                          const Text('IQD', style: TextStyle(color: Colors.white, fontSize: 14)),
                        ],
                      ),
                    if (customer.totalDebtUSD > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              format.format(customer.totalDebtUSD), 
                              style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(width: 8),
                            const Text('USD', style: TextStyle(color: Colors.white, fontSize: 12)),
                          ],
                        ),
                      ),
                  ],
                ),
              )
            ],
          ),
        );
      }
    );
  }

  Widget _buildLedger(InvoiceViewModel vm, NumberFormat format, String currency) {
    final activities = vm.ledger;
    final totalPages = (activities.length / _pageSize).ceil();
    if (_currentPage > totalPages && totalPages > 0) _currentPage = totalPages;
    
    final startIndex = (_currentPage - 1) * _pageSize;
    final endIndex = startIndex + _pageSize > activities.length ? activities.length : startIndex + _pageSize;
    final pagedActivities = activities.isEmpty ? [] : activities.sublist(startIndex, endIndex);

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(32),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.history, color: AppColors.primary),
                    SizedBox(width: 8),
                    Text('سجل العمليات', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  ],
                ),
                Text('${activities.length} عملية', style: TextStyle(fontSize: 12, color: AppColors.outline.withOpacity(0.8))),
              ],
            ),
          ),
          if (activities.isEmpty)
             const Padding(
               padding: EdgeInsets.all(48.0),
               child: Center(child: Text('لا توجد عمليات مسجلة لهذا العميل', style: TextStyle(color: AppColors.outline))),
             ),
          ...pagedActivities.map((act) => _buildActivityItem(act as Map<String, dynamic>, format, currency)),
          
          if (activities.isNotEmpty && totalPages > 1) ...[
            const Divider(),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios, size: 18),
                    onPressed: _currentPage > 1 ? () => setState(() => _currentPage--) : null,
                  ),
                  const SizedBox(width: 16),
                  Text(
                    '$_currentPage / $totalPages',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(width: 16),
                  IconButton(
                    icon: const Icon(Icons.arrow_forward_ios, size: 18),
                    onPressed: _currentPage < totalPages ? () => setState(() => _currentPage++) : null,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActivityItem(Map<String, dynamic> act, NumberFormat format, String currency) {
    final bool isInvoice = act['type'] == 'invoice';
    final DateTime date = act['date'] as DateTime;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isInvoice ? AppColors.errorContainer : AppColors.secondaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isInvoice ? Icons.receipt_long : Icons.payments,
              color: isInvoice ? AppColors.tertiary : AppColors.secondary,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  act['title'].toString(),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('yyyy/MM/dd - hh:mm a').format(date),
                  style: const TextStyle(fontSize: 12, color: AppColors.outline),
                ),
              ],
            ),
          ),
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${isInvoice ? "-" : "+"}${format.format(act['amount'])}',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      color: isInvoice ? AppColors.tertiary : AppColors.secondary,
                    ),
                  ),
                  Text(
                    currency,
                    style: const TextStyle(fontSize: 10, color: AppColors.outline),
                  ),
                ],
              ),
              if (!isInvoice) ...[
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 20),
                  onPressed: () => _confirmDeletePayment(act['data']),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  void _confirmDeletePayment(Map<String, dynamic> transaction) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف عملية السداد', textAlign: TextAlign.right),
        content: const Text(
          'هل أنت متأكد من حذف هذه العملية؟ سيتم إرجاع المبلغ كدين على العميل مرة أخرى.',
          textAlign: TextAlign.right,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
            onPressed: () async {
              final success = await context.read<PaymentViewModel>().deletePaymentTransaction(transaction['Id']);
              if (success && mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حذف العملية وإعادة جدولة الدين بنجاح')));
                context.read<InvoiceViewModel>().fetchLedger(widget.customer.id);
                context.read<CustomerViewModel>().fetchCustomers();
                context.read<DashboardViewModel>().loadDashboard();
              }
            },
            child: const Text('تأكيد الحذف'),
          ),
        ],
      ),
    );
  }
}
