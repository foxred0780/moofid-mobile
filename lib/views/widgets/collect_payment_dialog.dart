import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../viewmodels/payment_viewmodel.dart';
import '../../viewmodels/customer_viewmodel.dart';
import '../../viewmodels/dashboard_viewmodel.dart';
import '../../viewmodels/invoice_viewmodel.dart';
import '../../core/theme/app_colors.dart';

class CollectPaymentDialog extends StatefulWidget {
  final String customerId;
  final String customerName;

  const CollectPaymentDialog({
    super.key,
    required this.customerId,
    required this.customerName,
  });

  @override
  State<CollectPaymentDialog> createState() => _CollectPaymentDialogState();
}

class _CollectPaymentDialogState extends State<CollectPaymentDialog> {
  final TextEditingController _amountController = TextEditingController();
  List<Map<String, dynamic>> _installments = [];
  bool _isLoading = true;
  String _selectedCurrency = 'IQD';
  final _currencyFormat = NumberFormat('#,##0.00');

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() async {
    setState(() => _isLoading = true);
    final data = await context.read<InvoiceViewModel>().getPendingInstallments(widget.customerId);
    setState(() {
      _installments = data;
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
      // Filter installments by selected currency
      final filteredInstallments = _installments.where((i) => (i['Currency'] ?? 'IQD') == _selectedCurrency).toList();
      double totalDebt = filteredInstallments.fold(0, (sum, item) => sum + (item['Amount'] - item['PaidAmount']));

      return AlertDialog(
        title: const Text('استلام دفعة نقداً', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
        content: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
            child: SizedBox(
              width: MediaQuery.of(context).size.width * 0.9,
              child: _isLoading 
                ? const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()))
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Currency Selector Toggle
                      Center(
                        child: SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(value: 'IQD', label: Text('دينار IQD'), icon: Icon(Icons.money)),
                            ButtonSegment(value: 'USD', label: Text('دولار USD'), icon: Icon(Icons.attach_money)),
                          ],
                          selected: {_selectedCurrency},
                          showSelectedIcon: false,
                          onSelectionChanged: (Set<String> newSelection) {
                            setState(() {
                              _selectedCurrency = newSelection.first;
                            });
                          },
                          style: SegmentedButton.styleFrom(
                            backgroundColor: AppColors.surfaceContainerLow,
                            selectedBackgroundColor: AppColors.primary,
                            selectedForegroundColor: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: Text('المطلوب بالـ $_selectedCurrency: ${_currencyFormat.format(totalDebt)}', 
                              style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.secondary, fontSize: 11)),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text('العميل: ${widget.customerName}', 
                              textAlign: TextAlign.right,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                          ),
                        ],
                      ),
                      const Divider(height: 32),
                      Text('الأقساط المستحقة ($_selectedCurrency):', textAlign: TextAlign.right, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Container(
                        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.3),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: filteredInstallments.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.all(32.0),
                              child: Center(child: Text('لا توجد أقساط لهذه العملة', style: TextStyle(color: AppColors.outline, fontSize: 12))),
                            )
                          : ListView.separated(
                              shrinkWrap: true,
                              itemCount: filteredInstallments.length,
                              separatorBuilder: (context, index) => const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final inst = filteredInstallments[index];
                                final remaining = inst['Amount'] - inst['PaidAmount'];
                                return ListTile(
                                  dense: true,
                                  title: Row(
                                    children: [
                                      Text('#${inst['InstallmentNumber']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                      const SizedBox(width: 8),
                                      Expanded(child: Text(inst['ItemName'] ?? 'بدون مادة', style: const TextStyle(fontSize: 12))),
                                    ],
                                  ),
                                  subtitle: Text(DateFormat('yyyy/MM/dd').format(DateTime.parse(inst['DueDate'])), style: const TextStyle(fontSize: 10)),
                                  trailing: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(_currencyFormat.format(remaining), style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
                                      Text(_selectedCurrency, style: const TextStyle(fontSize: 8)),
                                    ],
                                  ),
                                );
                              },
                            ),
                      ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _amountController,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      autofocus: false, // Changed from true to prevent screen jumping
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.primary),
                      decoration: InputDecoration(
                        labelText: 'المبلغ المستلم الآن',
                        labelStyle: const TextStyle(fontSize: 14),
                        alignLabelWithHint: true,
                        filled: true,
                        fillColor: AppColors.primaryContainer.withOpacity(0.1),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                        prefixIcon: const Icon(Icons.payments_outlined),
                      ),
                    ),
                  ],
                ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: _isLoading ? null : () async {
            final amount = double.tryParse(_amountController.text) ?? 0;
            if (amount <= 0) return;

            final success = await context.read<PaymentViewModel>().payAmountForCustomer(
              customerId: widget.customerId,
              totalAmount: amount,
              currency: _selectedCurrency,
            );

            if (success && mounted) {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تسجيل الدفعة وتحديث الجداول بنجاح')));
              context.read<InvoiceViewModel>().fetchLedger(widget.customerId);
              context.read<CustomerViewModel>().fetchCustomers();
              context.read<DashboardViewModel>().loadDashboard();
            }
          },
          child: const Text('تأكيد واستلام'),
        ),
      ],
    );
  }
}
