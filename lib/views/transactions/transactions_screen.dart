import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/tonal_card.dart';
import '../../widgets/status_chip.dart';

class TransactionsScreen extends StatelessWidget {
  const TransactionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('سجل المعاملات', style: TextStyle(fontFamily: 'BeVietnamPro')),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(24.0),
        itemCount: 10,
        itemBuilder: (context, index) {
          final isDebit = index % 2 == 0;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: TonalCard(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('فاتورة رقم #${1000 + index}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 4),
                      const Text('01 مايو 2026', style: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 12)),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        isDebit ? '- 50,000 د.ع' : '+ 25,000 د.ع', 
                        style: TextStyle(
                          fontWeight: FontWeight.bold, 
                          color: isDebit ? AppColors.error : AppColors.secondary
                        ),
                      ),
                      const SizedBox(height: 4),
                      StatusChip(
                        status: isDebit ? ChipStatus.pending : ChipStatus.paid,
                        text: isDebit ? 'فاتورة ديون' : 'دفعة قسط',
                      ),
                    ],
                  )
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
