import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../viewmodels/settings_viewmodel.dart';
import '../../core/services/sync_service.dart';
import '../../core/services/app_logger.dart';
import 'package:flutter/services.dart';
import '../../core/services/pairing_service.dart';
import '../../core/database/database_helper.dart';
import '../../viewmodels/auth_viewmodel.dart';
import 'sync_setup_screen.dart';
import 'log_viewer_screen.dart';
import '../login/login_screen.dart';
import '../../core/services/export_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _exchangeController = TextEditingController();
  
  bool _initialized = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _exchangeController.dispose();
    super.dispose();
  }

  void _initControllers(SettingsViewModel vm) {
    if (!_initialized && vm.settings != null) {
      final s = vm.settings!;
      _nameController.text = s.storeName;
      _phoneController.text = s.storePhone;
      _addressController.text = s.storeAddress;
      _exchangeController.text = s.exchangeRate.toString();
      _initialized = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsVM = context.watch<SettingsViewModel>();
    _initControllers(settingsVM);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('إعدادات النظام', style: TextStyle(fontWeight: FontWeight.w900)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: settingsVM.isLoading 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('قم بتخصيص بيانات متجرك وتفضيلات النظام المالية', style: TextStyle(color: AppColors.onSurfaceVariant)),
                const SizedBox(height: 32),

                // Store Info Card
                _buildStoreInfoCard(),
                const SizedBox(height: 24),

                // System Options Card
                _buildSystemOptionsCard(settingsVM),
                const SizedBox(height: 24),

                // Data Synchronization Hub
                _buildSyncHubCard(),
                const SizedBox(height: 24),

                // Backup Card
                _buildBackupCard(),
                const SizedBox(height: 24),

                // Session Management
                _buildSessionCard(),
                const SizedBox(height: 100), 
              ],
            ),
          ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            minimumSize: const Size(double.infinity, 50),
          ),
          icon: const Icon(Icons.save),
          label: const Text('حفظ جميع التغييرات', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          onPressed: () async {
            final rate = double.tryParse(_exchangeController.text) ?? 1.0;
            await settingsVM.updateSettings(
              storeName: _nameController.text,
              storePhone: _phoneController.text,
              storeAddress: _addressController.text,
              exchangeRate: rate,
            );
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('تم حفظ الإعدادات بنجاح')),
              );
            }
          },
        ),
      ),
    );
  }

  Widget _buildStoreInfoCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineVariant.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.storefront, color: AppColors.primary),
              SizedBox(width: 8),
              Text('بيانات المتجر', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary)),
            ],
          ),
          const SizedBox(height: 24),
          _buildInputGroup('اسم المتجر', _nameController),
          const SizedBox(height: 16),
          _buildInputGroup('رقم الهاتف', _phoneController, dir: TextDirection.ltr),
          const SizedBox(height: 16),
          _buildInputGroup('العنوان بالتفصيل', _addressController, maxLines: 2),
        ],
      ),
    );
  }

  Widget _buildInputGroup(String label, TextEditingController controller, {TextDirection dir = TextDirection.rtl, int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.onSurfaceVariant)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          textDirection: dir,
          maxLines: maxLines,
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.surfaceContainerLow,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
      ],
    );
  }

  Widget _buildSystemOptionsCard(SettingsViewModel vm) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineVariant.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.settings_suggest, color: AppColors.primary),
              SizedBox(width: 8),
              Text('خيارات النظام', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary)),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('تنبيهات المتأخرات', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text('تفعيل إرسال تنبيهات تلقائية', style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant)),
                ],
              ),
              Switch(
                value: vm.settings?.enableOverdueAlerts ?? true,
                activeThumbColor: AppColors.primary,
                onChanged: (val) => vm.updateSettings(enableOverdueAlerts: val),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('العملة الافتراضية', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.onSurfaceVariant)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(color: AppColors.surfaceContainerLow, borderRadius: BorderRadius.circular(12)),
                      child: DropdownButtonFormField<String>(
                        value: vm.settings?.defaultCurrency ?? 'IQD',
                        decoration: const InputDecoration(border: InputBorder.none),
                        items: const [
                          DropdownMenuItem(value: 'IQD', child: Text('IQD')),
                          DropdownMenuItem(value: 'USD', child: Text('USD')),
                        ],
                        onChanged: (v) => vm.updateSettings(defaultCurrency: v),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(child: _buildInputGroup('سعر الصرف (للـ 100\$)', _exchangeController, dir: TextDirection.ltr)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSyncHubCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.sync_rounded, color: AppColors.secondary),
              SizedBox(width: 8),
              Text('مركز المزامنة والربط', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.secondary)),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'قم بربط هاتفك ببرنامج الوندوز لمزامنة العملاء والدفعات لاسلكياً.',
            style: TextStyle(fontSize: 13, color: AppColors.onSurfaceVariant),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const SyncSetupScreen())),
                  icon: const Icon(Icons.qr_code_scanner_rounded),
                  label: const Text('ربط مع الكمبيوتر'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final error = await SyncService.performSync();
                    if (mounted) {
                      // Auto-refresh user session after sync
                      try {
                        final serverInfo = await SyncService.checkServerStatus();
                        if (serverInfo != null) {
                          final authVM = Provider.of<AuthViewModel>(context, listen: false);
                          await authVM.loginById(
                            serverInfo['userId']?.toString() ?? '',
                            serverInfo['userName']?.toString() ?? 'User',
                          );
                        }
                      } catch (_) {}
                      
                      if (error == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('تمت المزامنة بنجاح ✓'), backgroundColor: Colors.green),
                        );
                      } else {
                        _showLogDialog(context, error);
                      }
                    }
                  },
                  icon: const Icon(Icons.cloud_sync_rounded),
                  label: const Text('مزامنة الآن'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.secondary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Sync Log Button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _showLogDialog(context, AppLogger.getFullLog()),
              icon: const Icon(Icons.history_rounded),
              label: const Text('سجل المزامنة التتابعي'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.onSurfaceVariant,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // System Log Button (New)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const LogViewerScreen())),
              icon: const Icon(Icons.list_alt_rounded, size: 18),
              label: const Text('سجل النظام الشامل (Logging)'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.surfaceContainerHigh,
                foregroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 12),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackupCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.primaryFixed,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('النسخ الاحتياطي اليدوي', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.onPrimaryFixed)),
          const SizedBox(height: 8),
          Text(
            'نوصي بحفظ نسخة احتياطية بشكل دوري لضمان سلامة بياناتك.',
            style: TextStyle(color: AppColors.onPrimaryFixedVariant.withOpacity(0.8), fontSize: 12),
          ),
          const SizedBox(height: 24),
          
          // Row for Database Backup/Restore
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white.withOpacity(0.2),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.upload_file),
                  label: const Text('استيراد (.db)', style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: () async {
                    final proceed = await showDialog<bool>(
                      context: context,
                      builder: (c) => AlertDialog(
                        title: const Text('تأكيد الاسترجاع'),
                        content: const Text('استرجاع نسخة احتياطية سيؤدي لمسح كافة البيانات الحالية بالكامل. هل أنت متأكد؟'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('إلغاء')),
                          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('تأكيد الاسترجاع', style: TextStyle(color: Colors.red))),
                        ],
                      ),
                    );

                    if (proceed == true) {
                      try {
                        await DatabaseHelper.instance.restoreBackup();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('تم استعادة البيانات بنجاح. يرجى إغلاق التطبيق وفتحه من جديد.')),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('فشل الاسترجاع: $e'), backgroundColor: Colors.red),
                          );
                        }
                      }
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white.withOpacity(0.2),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.backup_rounded),
                  label: const Text('تصدير (.db)', style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: () async {
                    try {
                      await DatabaseHelper.instance.createBackup();
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('فشل إنشاء النسخة: $e'), backgroundColor: Colors.red),
                        );
                      }
                    }
                  },
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),

          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              minimumSize: const Size(double.infinity, 0),
            ),
            icon: const Icon(Icons.download),
            label: const Text('تنزيل كافة البيانات (Excel)', style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: () async {
              try {
                await ExportService.exportToExcel();
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('حدث خطأ أثناء التصدير: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }


  Widget _buildSessionCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineVariant.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.account_circle_outlined, color: AppColors.primary),
              SizedBox(width: 8),
              Text('جلسة العمل', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary)),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'حسابك حالياً: ${context.read<AuthViewModel>().currentUser?.username ?? "غير معروف"}',
            style: const TextStyle(color: AppColors.onSurfaceVariant),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              minimumSize: const Size(double.infinity, 0),
            ),
            icon: const Icon(Icons.logout_rounded),
            label: const Text('تسجيل الخروج من الحساب', style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: () => _showLogoutConfirmation(),
          ),
        ],
      ),
    );
  }

  void _showLogoutConfirmation() {
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('تسجيل الخروج'),
          content: const Text('هل أنت متأكد أنك تريد تسجيل الخروج؟ ستحتاج إلى إدخال كلمة المرور مرة أخرى لاحقاً.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
            TextButton(
              onPressed: () async {
                final authVM = context.read<AuthViewModel>();
                await authVM.logout();
                if (mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => LoginScreen()),
                    (route) => false,
                  );
                }
              },
              child: const Text('تأكيد الخروج', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }


  void _showLogDialog(BuildContext context, String log) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: Row(
          children: [
            Icon(AppLogger.hasErrors ? Icons.error_outline : Icons.info_outline,
                color: AppLogger.hasErrors ? Colors.red : Colors.blue),
            const SizedBox(width: 8),
            Text(AppLogger.hasErrors ? 'سجل أخطاء النظام' : 'سجل النظام'),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: SingleChildScrollView(
            child: SelectableText(
              log,
              style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
            ),
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: log));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('تم نسخ السجل ✓'), backgroundColor: Colors.green),
              );
            },
            icon: const Icon(Icons.copy, size: 18),
            label: const Text('نسخ السجل'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }
}
