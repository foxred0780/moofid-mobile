import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../viewmodels/customer_viewmodel.dart';
import '../../viewmodels/invoice_viewmodel.dart';
import '../../viewmodels/settings_viewmodel.dart';
import '../../viewmodels/dashboard_viewmodel.dart';
import '../../models/customer_model.dart';

class CreateInvoiceScreen extends StatefulWidget {
  const CreateInvoiceScreen({super.key});

  @override
  State<CreateInvoiceScreen> createState() => _CreateInvoiceScreenState();
}

class _CreateInvoiceScreenState extends State<CreateInvoiceScreen> {
  final TextEditingController _productController = TextEditingController();
  final TextEditingController _totalPriceController = TextEditingController();
  final TextEditingController _downPaymentController = TextEditingController();
  final TextEditingController _monthsController = TextEditingController(text: '12');

  String? _selectedCustomerId;
  String _currency = 'IQD';
  final _currencyFormat = NumberFormat('#,##0.00');

  @override
  void initState() {
    super.initState();
    _totalPriceController.addListener(_onCalculationsChanged);
    _downPaymentController.addListener(_onCalculationsChanged);
    _monthsController.addListener(_onCalculationsChanged);
    
    // Default currency from settings
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final sVM = context.read<SettingsViewModel>();
      if (sVM.settings != null) {
        setState(() => _currency = sVM.settings!.defaultCurrency);
      }
    });
  }

  @override
  void dispose() {
    _totalPriceController.dispose();
    _downPaymentController.dispose();
    _monthsController.dispose();
    _productController.dispose();
    super.dispose();
  }

  void _onCalculationsChanged() {
    final double total = double.tryParse(_totalPriceController.text) ?? 0;
    final double down = double.tryParse(_downPaymentController.text) ?? 0;
    final int months = int.tryParse(_monthsController.text) ?? 0;

    context.read<InvoiceViewModel>().calculateInstallmentsPreview(
      totalAmount: total,
      downPayment: down,
      numberOfMonths: months,
    );
  }

  @override
  Widget build(BuildContext context) {
    final shopName = context.select<SettingsViewModel, String>((s) => s.settings?.storeName ?? 'Moofid');
    
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.primary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(shopName, style: const TextStyle(color: AppColors.onPrimaryContainer, fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'فاتورة تقسيط جديدة',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: AppColors.primary),
            ),
            const SizedBox(height: 8),
            const Text(
              'أدخل تفاصيل البيع لإعداد جدول الدفعات المالية.',
              style: TextStyle(color: AppColors.onSurfaceVariant),
            ),
            const SizedBox(height: 32),

            _buildCustomerProductSection(),
            const SizedBox(height: 24),
            _buildFinancialDetailsSection(),
            const SizedBox(height: 24),
            _buildSummarySection(context),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerProductSection() {
    return Consumer<CustomerViewModel>(
      builder: (context, vm, child) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(color: AppColors.onBackground.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('العميل المستفيد', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.onSurfaceVariant)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(color: AppColors.surfaceContainerLow, borderRadius: BorderRadius.circular(16)),
                child: DropdownButtonFormField<String>(
                  value: _selectedCustomerId,
                  hint: const Text('اختر العميل...'),
                  decoration: const InputDecoration(border: InputBorder.none),
                  icon: const Icon(Icons.expand_more, color: AppColors.outline),
                  items: vm.customers
                      .map((c) => DropdownMenuItem(value: c.id, child: Text(c.name, style: const TextStyle(fontWeight: FontWeight.bold))))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedCustomerId = v),
                ),
              ),
              const SizedBox(height: 16),
              const Text('اسم المنتج / الغرض', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.onSurfaceVariant)),
              const SizedBox(height: 8),
              TextField(
                controller: _productController,
                decoration: InputDecoration(
                  hintText: 'مثال: ثلاجة، هاتف، أثاث...',
                  filled: true,
                  fillColor: AppColors.surfaceContainerLow,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                ),
              ),
            ],
          ),
        );
      }
    );
  }

  Widget _buildFinancialDetailsSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: AppColors.onBackground.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('التفاصيل المالية', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary)),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(color: AppColors.surfaceContainerLow, borderRadius: BorderRadius.circular(24)),
                child: Row(
                  children: [
                    _buildCurrencyToggle('IQD'),
                    _buildCurrencyToggle('USD'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildNumericInput('السعر الإجمالي للسلعة', _totalPriceController),
          const SizedBox(height: 16),
          _buildNumericInput('الدفعة المقدمة (إن وجدت)', _downPaymentController),
          const SizedBox(height: 24),
          const Divider(height: 1, color: AppColors.surfaceContainerHigh),
          const SizedBox(height: 24),
          _buildNumericInput('فترة السداد (بالشهور)', _monthsController, isCurrency: false),
        ],
      ),
    );
  }

  Widget _buildNumericInput(String label, TextEditingController controller, {bool isCurrency = true}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.onSurfaceVariant)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.surfaceContainerLow,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            prefixIcon: isCurrency ? Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(_currency, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.outline)),
            ) : null,
          ),
        ),
      ],
    );
  }

  Widget _buildCurrencyToggle(String currency) {
    bool isSelected = _currency == currency;
    return GestureDetector(
      onTap: () => setState(() => _currency = currency),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          currency,
          style: TextStyle(
            color: isSelected ? Colors.white : AppColors.onSurfaceVariant,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildSummarySection(BuildContext context) {
    return Consumer<InvoiceViewModel>(
      builder: (context, vm, child) {
        final double remaining = (double.tryParse(_totalPriceController.text) ?? 0) - (double.tryParse(_downPaymentController.text) ?? 0);
        final previews = vm.previewInstallments;
        final double monthly = previews.isNotEmpty ? previews.first.amount : 0;

        return Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: AppColors.primaryFixed, 
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(color: AppColors.primary.withOpacity(0.2), blurRadius: 20, offset: const Offset(0, 10)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('جدول السداد المتوقع', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.onPrimaryFixed)),
              const SizedBox(height: 24),
              _buildSummaryRow('إجمالي المبلغ المتبقي', '${_currencyFormat.format(remaining)} $_currency', true),
              const SizedBox(height: 16),
              _buildSummaryRow('القسط الشهري', '${_currencyFormat.format(monthly)} $_currency', false),
              const SizedBox(height: 16),
              _buildSummaryRow('تاريخ أول استحقاق', previews.isNotEmpty ? DateFormat('yyyy/MM/dd').format(previews.first.dueDate) : '--/--/--', false),
              const SizedBox(height: 32),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
                  minimumSize: const Size(double.infinity, 60),
                  elevation: 8,
                ),
                onPressed: (vm.isLoading || _selectedCustomerId == null || previews.isEmpty) 
                  ? null 
                  : () async {
                      final success = await vm.saveInvoice(
                        customerId: _selectedCustomerId!,
                        itemName: _productController.text,
                        totalAmount: double.parse(_totalPriceController.text),
                        downPayment: double.tryParse(_downPaymentController.text) ?? 0,
                        currency: _currency,
                        numberOfMonths: int.parse(_monthsController.text),
                      );

                      if (success && mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ الفاتورة بنجاح')));
                        
                        // Refresh other data
                        context.read<CustomerViewModel>().fetchCustomers();
                        context.read<DashboardViewModel>().loadDashboard();

                        if (Navigator.canPop(context)) {
                          Navigator.pop(context);
                        } else {
                          // Clear form for tab reuse
                          _productController.clear();
                          _totalPriceController.clear();
                          _downPaymentController.clear();
                          _monthsController.text = '12';
                          setState(() => _selectedCustomerId = null);
                          context.read<InvoiceViewModel>().clearPreview();
                        }
                      }
                    },
                child: vm.isLoading 
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('تأكيد وحفظ الفاتورة', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
              ),
            ],
          ),
        );
      }
    );
  }

  Widget _buildSummaryRow(String label, String value, bool isLarge) {
    return Container(
      padding: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.onPrimaryFixedVariant.withOpacity(0.2))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 14, color: AppColors.onPrimaryFixed.withOpacity(0.7))),
          Text(value, style: TextStyle(fontSize: isLarge ? 24 : 18, fontWeight: isLarge ? FontWeight.w900 : FontWeight.bold, color: AppColors.onPrimaryFixed)),
        ],
      ),
    );
  }
}

