import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';

enum ChipStatus { paid, overdue, pending }

class StatusChip extends StatelessWidget {
  final ChipStatus status;
  final String text;

  const StatusChip({
    super.key,
    required this.status,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    Color backgroundColor;
    Color textColor;

    switch (status) {
      case ChipStatus.paid:
        backgroundColor = AppColors.secondaryContainer;
        textColor = AppColors.onSecondaryContainer;
        break;
      case ChipStatus.overdue:
        backgroundColor = AppColors.errorContainer;
        textColor = AppColors.onErrorContainer;
        break;
      case ChipStatus.pending:
        backgroundColor = AppColors.primaryContainer;
        textColor = AppColors.onPrimaryContainer;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: textColor,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          fontFamily: 'Inter',
        ),
      ),
    );
  }
}
