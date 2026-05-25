// lib/widgets/custom_toggle.dart
import 'package:flutter/material.dart';
import '../utils/app_constants.dart';

class CustomToggle extends StatelessWidget {
  final List<String> options;
  final int selectedIndex;
  final Function(int) onChanged;
  final double height;
  final double borderRadius;

  const CustomToggle({
    super.key,
    required this.options,
    required this.selectedIndex,
    required this.onChanged,
    this.height = 48,
    this.borderRadius = 40,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Row(
        children: List.generate(options.length, (index) {
          final isSelected = selectedIndex == index;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                decoration: BoxDecoration(
                  color: isSelected ? AppConstants.primaryColor : Colors.transparent,
                  borderRadius: BorderRadius.circular(borderRadius - 4),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: AppConstants.primaryColor.withAlpha(51),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  child: Text(
                    options[index],
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.grey.shade600,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}