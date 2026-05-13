import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../viewmodels/customer_viewmodel.dart';
import '../../viewmodels/settings_viewmodel.dart';
import '../transactions/history_screen.dart';
import '../../core/utils/statement_helper.dart';
import '../../models/customer_model.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CustomerViewModel>().fetchCustomers();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            _buildSearchFilter(),
            Expanded(
              child: _buildCustomersList(context),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddCustomerDialog,
        backgroundColor: AppColors.primaryContainer,
        foregroundColor: AppColors.onPrimaryContainer,
        icon: const Icon(Icons.person_add),
        label: const Text('إضافة عميل', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  void _showAddCustomerDialog() {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final addressCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        String? phoneError;
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('إضافة عميل جديد'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'اسم العميل الرباعي')),
                const SizedBox(height: 8),
                TextField(
                  controller: phoneCtrl, 
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
                    hintText: '7701234567',
                    helperText: 'أدخل 10 أرقام (بدون صفر البداية)',
                    errorText: phoneError,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(controller: addressCtrl, decoration: const InputDecoration(labelText: 'العنوان (اختياري)')),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
              ElevatedButton(
                onPressed: () async {
                  if (nameCtrl.text.trim().isEmpty) {
                    setDialogState(() {
                      phoneError = null;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('يرجى إدخال اسم العميل'), backgroundColor: Colors.red),
                    );
                    return;
                  }

                  String phone = phoneCtrl.text.trim();
                  
                  // Allow empty phone, but if provided must be 10 digits
                  if (phone.isNotEmpty && phone.length != 10) {
                    setDialogState(() {
                      phoneError = 'يجب أن يكون الرقم 10 أرقام بالضبط';
                    });
                    return;
                  }

                  final vm = context.read<CustomerViewModel>();
                  final success = await vm.addCustomer(
                    name: nameCtrl.text.trim(),
                    phone: phone,
                    address: addressCtrl.text.trim(),
                  );

                  if (success && mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('تم حفظ العميل بنجاح ✓'), backgroundColor: Colors.green),
                    );
                  } else if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('فشل حفظ العميل: ${vm.lastError}'),
                        backgroundColor: Colors.red,
                        duration: const Duration(seconds: 5),
                      ),
                    );
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

  void _launchWhatsApp(Customer customer) async {
    if (customer.phone.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('لا يوجد رقم هاتف لهذا العميل'), backgroundColor: Colors.red),
        );
      }
      return;
    }
    await StatementHelper.shareViaWhatsApp(phone: customer.phone, message: "");
  }

  Widget _buildHeader(BuildContext context) {
    final count = context.select<CustomerViewModel, int>((vm) => vm.customers.length);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'إدارة العملاء',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: AppColors.onSurface,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$count عميل',
                  style: const TextStyle(
                    color: AppColors.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'تتبع الديون والأرصدة لجميع العملاء المسجلين.',
            style: TextStyle(color: AppColors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchFilter() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: (val) => context.read<CustomerViewModel>().updateSearchQuery(val),
              decoration: InputDecoration(
                hintText: 'البحث عن اسم العميل...',
                prefixIcon: const Icon(Icons.search, color: AppColors.outline),
                filled: true,
                fillColor: AppColors.surfaceContainerLowest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(16),
            ),
            child: IconButton(
              icon: const Icon(Icons.filter_list, color: AppColors.onSurfaceVariant),
              onPressed: () {},
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomersList(BuildContext context) {
    final currency = context.select<SettingsViewModel, String>(
      (s) => s.settings?.defaultCurrency ?? 'IQD',
    );
    final NumberFormat currencyFormat = NumberFormat('#,##0.00');

    return Consumer<CustomerViewModel>(
      builder: (context, vm, child) {
        if (vm.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (vm.customers.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.people_outline, size: 64, color: AppColors.outline),
                SizedBox(height: 16),
                Text('لا يوجد عملاء حالياً', style: TextStyle(color: AppColors.outline)),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          itemCount: vm.customers.length,
          itemBuilder: (context, index) {
            final c = vm.customers[index];
            
            bool hasDebtIQD = c.totalDebtIQD > 0;
            bool hasDebtUSD = c.totalDebtUSD > 0;
            bool hasAnyDebt = hasDebtIQD || hasDebtUSD;

            String status = hasAnyDebt ? 'مطلوب' : 'تم التسديد';
            Color statusColor = hasAnyDebt ? AppColors.tertiary : AppColors.secondary;
            Color statusBg = hasAnyDebt ? AppColors.errorContainer : AppColors.secondaryContainer;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.onBackground.withOpacity(0.02),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ListTile(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => HistoryScreen(customer: c)),
                  );
                },
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: CircleAvatar(
                  backgroundColor: AppColors.surfaceContainerHighest,
                  child: Text(
                    c.name.isNotEmpty ? c.name.substring(0, 1) : '?',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                  ),
                ),
                title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Row(
                  children: [
                    Text(c.phone, style: const TextStyle(color: AppColors.outline, fontSize: 12)),
                    if (c.phone.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => _launchWhatsApp(c),
                        child: Icon(Icons.chat, size: 16, color: const Color(0xFF25D366)),
                      ),
                    ],
                  ],
                ),
                trailing: SizedBox(
                  width: 120, // Constrain width
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min, // Essential
                    children: [
                      if (hasDebtIQD)
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            '${currencyFormat.format(c.totalDebtIQD)} IQD',
                            style: TextStyle(fontWeight: FontWeight.w900, color: statusColor, fontSize: 13),
                          ),
                        ),
                      if (hasDebtUSD)
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            '${currencyFormat.format(c.totalDebtUSD)} USD',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: statusColor.withOpacity(0.8),
                                fontSize: 11),
                          ),
                        ),
                      if (!hasAnyDebt)
                        Text(
                          '0 IQD',
                          style: TextStyle(fontWeight: FontWeight.w900, color: statusColor, fontSize: 14),
                        ),
                      const SizedBox(height: 2), // Reduced spacing
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: statusBg,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          status,
                          style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: statusColor),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      }
    );
  }
}


