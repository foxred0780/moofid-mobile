import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../viewmodels/dashboard_viewmodel.dart';
import '../../viewmodels/settings_viewmodel.dart';
import '../widgets/collect_payment_dialog.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final NumberFormat _currencyFormat = NumberFormat('#,##0.00');

  @override
  void initState() {
    super.initState();
    // Refresh data when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DashboardViewModel>().loadDashboard();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(),
      body: Consumer<DashboardViewModel>(
        builder: (context, dashboardVM, child) {
          if (dashboardVM.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final currency = context.select<SettingsViewModel, String>(
            (s) => s.settings?.defaultCurrency ?? 'IQD',
          );

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'التقرير المالي العام',
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.onSurface,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'متابعة دقيقة لتدفقات الأقساط والديون المستحقة',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: AppColors.onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // Statistics Grid
                _buildStatCard(
                  title: 'إجمالي الديون المعلقة (شامل)',
                  amountPrimary: _currencyFormat.format(dashboardVM.totalCombinedPending),
                  amountSecondary: currency == 'IQD' ? _currencyFormat.format(dashboardVM.totalPendingUSD) : _currencyFormat.format(dashboardVM.totalPendingIQD),
                  currency: currency,
                  badgeText: 'ديون غير مسددة',
                  icon: Icons.account_balance_wallet,
                  color: AppColors.tertiary,
                  containerColor: const Color(0xFFB10F2B), // tertiary-container
                ),
                const SizedBox(height: 16),
                _buildStatCard(
                  title: 'المبالغ المحصلة (شامل)',
                  amountPrimary: _currencyFormat.format(dashboardVM.totalCombinedCollected),
                  amountSecondary: currency == 'IQD' ? _currencyFormat.format(dashboardVM.totalCollectedUSD) : _currencyFormat.format(dashboardVM.totalCollectedIQD),
                  currency: currency,
                  badgeText: 'إجمالي المقبوضات',
                  icon: Icons.check_circle,
                  color: AppColors.onSecondaryContainer,
                  containerColor: AppColors.secondaryContainer,
                ),
                const SizedBox(height: 16),
                _buildStatCard(
                  title: 'الأقساط المتأخرة',
                  amountPrimary: '${dashboardVM.overdueInstallments.length}',
                  amountSecondary: '',
                  currency: currency,
                  badgeText: 'تجاوزت فترة السماح',
                  icon: Icons.schedule,
                  color: AppColors.primary,
                  containerColor: AppColors.primaryContainer,
                  isCount: true,
                ),
                const SizedBox(height: 32),

                // Overdue Customers List
                _buildOverdueList(context, dashboardVM, currency),
              ],
            ),
          );
        },
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.surface,
      elevation: 0,
      scrolledUnderElevation: 0,
      title: Consumer<SettingsViewModel>(
        builder: (context, sVM, child) {
          final shopName = sVM.settings?.storeName ?? 'Moofid Installments';
          return Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: AppColors.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.account_balance_wallet, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    shopName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.onPrimaryContainer,
                    ),
                  ),
                  const Text(
                    'إدارة الأقساط الذكية',
                    style: TextStyle(
                      fontSize: 10,
                      color: AppColors.outline,
                    ),
                  ),
                ],
              ),
            ],
          );
        }
      ),

      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_outlined, color: AppColors.onSurfaceVariant),
          onPressed: () {
            context.read<DashboardViewModel>().loadDashboard();
          },
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String amountPrimary,
    required String amountSecondary,
    required String currency,
    required String badgeText,
    required IconData icon,
    required Color color,
    required Color containerColor,
    bool isCount = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.onBackground.withOpacity(0.04),
            blurRadius: 32,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: containerColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color == AppColors.primary ? Colors.white : color),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: containerColor.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
              child: Text(
                badgeText,
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          title,
          style: const TextStyle(fontSize: 14, color: AppColors.onSurfaceVariant),
        ),
        const SizedBox(height: 4),
        // Primary Amount (Based on Default Currency)
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              amountPrimary,
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: color),
            ),
            const SizedBox(width: 4),
            Text(
              isCount ? 'قسط' : currency,
              style: const TextStyle(fontSize: 14, color: AppColors.outline),
            ),
          ],
        ),
        // Secondary Amount (The other currency)
        if (!isCount && amountSecondary != '0.00')
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  amountSecondary,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color.withOpacity(0.7)),
                ),
                const SizedBox(width: 4),
                Text(
                  currency == 'IQD' ? 'USD' : 'IQD',
                  style: TextStyle(fontSize: 10, color: AppColors.outline.withOpacity(0.7)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverdueList(BuildContext context, DashboardViewModel dashboardVM, String currency) {
    final items = dashboardVM.overdueInstallments;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.onBackground.withOpacity(0.04),
            blurRadius: 32,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'عملاء الأقساط المتأخرة',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                if (items.isNotEmpty)
                  Text(
                    '${items.length} أقساط',
                    style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.bold),
                  ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.surfaceContainerHighest),
          items.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(32.0),
                  child: Center(
                    child: Text('لا توجد أقساط متأخرة الحين', style: TextStyle(color: AppColors.outline)),
                  ),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: items.length > 5 ? 5 : items.length, // Show up to 5
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    DateTime? dueDate;
                    try {
                      dueDate = DateTime.parse(item['DueDate'] ?? '');
                    } catch (_) {
                      dueDate = DateTime.now();
                    }
                    final daysLate = DateTime.now().difference(dueDate).inDays;
                    return ListTile(
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (context) => CollectPaymentDialog(
                            customerId: item['CustomerId'],
                            customerName: item['CustomerName'] ?? 'عميل غير معروف',
                          ),
                        );
                      },
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      leading: const CircleAvatar(
                        backgroundColor: AppColors.surfaceContainerHighest,
                        child: Icon(Icons.person, color: AppColors.primary),
                      ),
                      title: Text(item['CustomerName'] ?? 'عميل غير معروف', style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('${item['ItemName']} (#${item['InstallmentNumber']})', 
                                 style: const TextStyle(color: AppColors.outline, fontSize: 12)),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              '${_currencyFormat.format(item['Amount'])} $currency',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.errorContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'متأخر $daysLate أيام',
                              style: const TextStyle(fontSize: 9, color: AppColors.error, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ],
      ),
    );
  }
}

