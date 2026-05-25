// lib/widgets/custom_toggle.dart
import 'package:flutter/material.dart';
import '../utils/app_constants.dart';

class CustomToggle extends StatelessWidget {
  final bool isNewCustomer;
  final ValueChanged<bool> onToggle;

  const CustomToggle({
    super.key,
    required this.isNewCustomer,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            duration: AppConstants.animationDuration,
            curve: AppConstants.animationCurve,
            alignment: isNewCustomer ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              width: MediaQuery.of(context).size.width / 2 - 24,
              height: 44,
              margin: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppConstants.primaryColor,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: AppConstants.primaryColor.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => onToggle(false),
                  child: Container(
                    height: 52,
                    alignment: Alignment.center,
                    child: AnimatedDefaultTextStyle(
                      duration: AppConstants.animationDuration,
                      style: TextStyle(
                        color: !isNewCustomer ? Colors.white : Colors.grey.shade600,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                      child: const Text('عميل موجود'),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => onToggle(true),
                  child: Container(
                    height: 52,
                    alignment: Alignment.center,
                    child: AnimatedDefaultTextStyle(
                      duration: AppConstants.animationDuration,
                      style: TextStyle(
                        color: isNewCustomer ? Colors.white : Colors.grey.shade600,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                      child: const Text('عميل جديد'),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
