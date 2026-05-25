// lib/widgets/animated_summary.dart
import 'package:flutter/material.dart';
import '../utils/app_constants.dart';

class AnimatedSummary extends StatelessWidget {
  final double quantity;
  final double price;
  final double discount;

  const AnimatedSummary({
    super.key,
    required this.quantity,
    required this.price,
    required this.discount,
  });

  @override
  Widget build(BuildContext context) {
    if (quantity <= 0 || price <= 0) {
      return const SizedBox.shrink();
    }

    final total = quantity * price;
    final discountAmount = total * (discount / 100);
    final finalTotal = total - discountAmount;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 50 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: child,
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(top: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppConstants.primaryColor.withOpacity(0.1),
              AppConstants.primaryColor.withOpacity(0.05),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppConstants.primaryColor.withOpacity(0.2),
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              Positioned(
                right: -20,
                top: -20,
                child: Icon(
                  Icons.receipt_long,
                  size: 120,
                  color: AppConstants.primaryColor.withOpacity(0.05),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.calculate,
                          color: AppConstants.primaryColor,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'ملخص الفاتورة',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: AppConstants.primaryColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildSummaryRow(
                      'الإجمالي قبل الخصم:',
                      '${total.toStringAsFixed(2)} ${AppConstants.currencySymbol}',
                      Colors.grey.shade700,
                    ),
                    const SizedBox(height: 8),
                    _buildSummaryRow(
                      'قيمة الخصم (${discount.toStringAsFixed(0)}%):',
                      '- ${discountAmount.toStringAsFixed(2)} ${AppConstants.currencySymbol}',
                      AppConstants.dangerColor,
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Divider(height: 1),
                    ),
                    _buildSummaryRow(
                      'الإجمالي النهائي:',
                      '${finalTotal.toStringAsFixed(2)} ${AppConstants.currencySymbol}',
                      AppConstants.successColor,
                      isBold: true,
                      fontSize: 18,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryRow(
    String label,
    String value,
    Color valueColor, {
    bool isBold = false,
    double fontSize = 14,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: fontSize - 1,
            color: Colors.grey.shade600,
          ),
        ),
        AnimatedCounter(
          value: value,
          color: valueColor,
          isBold: isBold,
          fontSize: fontSize,
        ),
      ],
    );
  }
}

class AnimatedCounter extends StatelessWidget {
  final String value;
  final Color color;
  final bool isBold;
  final double fontSize;

  const AnimatedCounter({
    super.key,
    required this.value,
    required this.color,
    this.isBold = false,
    this.fontSize = 14,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOut,
      builder: (context, animValue, child) {
        return Opacity(
          opacity: animValue,
          child: child,
        );
      },
      child: Text(
        value,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
