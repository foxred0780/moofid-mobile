import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/primary_gradient_button.dart';

class CreateInvoiceScreen extends StatelessWidget {
  const CreateInvoiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('إنشاء فاتورة تقسيط', style: TextStyle(fontFamily: 'BeVietnamPro')),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('اختر العميل', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(hintText: 'اختر العميل من القائمة...'),
              items: const [
                DropdownMenuItem(value: '1', child: Text('أحمد محمد')),
                DropdownMenuItem(value: '2', child: Text('علي حسين')),
              ],
              onChanged: (value) {},
            ),
            const SizedBox(height: 24),
            
            const Text('المبلغ', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            const TextField(
              decoration: InputDecoration(
                hintText: 'أدخل المبلغ...',
                suffixText: 'د.ع',
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 24),

            const Text('ملاحظات المشتريات (اختياري)', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            const TextField(
              decoration: InputDecoration(
                hintText: 'تفاصيل المواد المشتراة...',
              ),
              maxLines: 4,
            ),
            const SizedBox(height: 48),

            PrimaryGradientButton(
              text: 'حفظ الفاتورة',
              onPressed: () {
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}
