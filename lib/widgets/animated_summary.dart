// lib/widgets/animated_summary.dart
import 'package:flutter/material.dart';
import '../utils/app_constants.dart';

class AnimatedSummary extends StatefulWidget {
  final double totalBeforeDiscount;
  final double discountPercent;
  final double totalAfterDiscount;
  final String currencySymbol;

  const AnimatedSummary({
    super.key,
    required this.totalBeforeDiscount,
    required this.discountPercent,
    required this.totalAfterDiscount,
    this.currencySymbol = AppConstants.currencySymbol,
  });

  @override
  State<AnimatedSummary> createState() => _AnimatedSummaryState();
}

class _AnimatedSummaryState extends State<AnimatedSummary>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    );
    
    _slideAnimation = Tween<double>(begin: 20, end: 0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(AnimatedSummary oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.totalAfterDiscount != widget.totalAfterDiscount) {
      _controller.reset();
      _controller.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.1),
          end: Offset.zero,
        ).animate(_controller),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppConstants.primaryColor.withAlpha(26),
                AppConstants.primaryColor.withAlpha(13),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppConstants.primaryColor.withAlpha(26),
            ),
          ),
          child: Column(
            children: [
              const Row(
                children: [
                  Icon(Icons.calculate, size: 20, color: AppConstants.primaryColor),
                  SizedBox(width: 8),
                  Text(
                    'ملخص الفاتورة',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildAnimatedRow(
                'الإجمالي قبل الخصم',
                '${widget.totalBeforeDiscount.toStringAsFixed(2)} ${widget.currencySymbol}',
                isNegative: false,
              ),
              const SizedBox(height: 8),
              _buildAnimatedRow(
                'قيمة الخصم (${widget.discountPercent.toStringAsFixed(1)}%)',
                '- ${(widget.totalBeforeDiscount * widget.discountPercent / 100).toStringAsFixed(2)} ${widget.currencySymbol}',
                isNegative: true,
              ),
              const Divider(height: 24),
              _buildAnimatedRow(
                'الإجمالي النهائي',
                '${widget.totalAfterDiscount.toStringAsFixed(2)} ${widget.currencySymbol}',
                isBold: true,
                isTotal: true,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedRow(String label, String value,
      {bool isNegative = false, bool isBold = false, bool isTotal = false}) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 600),
      builder: (context, value, child) {
        return Opacity(opacity: value, child: child);
      },
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              fontSize: isTotal ? 16 : 14,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              fontSize: isTotal ? 16 : 14,
              color: isNegative
                  ? AppConstants.dangerColor
                  : (isTotal ? AppConstants.successColor : Colors.black87),
            ),
          ),
        ],
      ),
    );
  }
}