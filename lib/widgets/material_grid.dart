// lib/widgets/material_grid.dart
import 'package:flutter/material.dart';
import '../utils/app_constants.dart';

class MaterialGrid extends StatelessWidget {
  final String? selectedMaterial;
  final Function(String) onMaterialSelected;
  final int crossAxisCount;

  const MaterialGrid({
    super.key,
    this.selectedMaterial,
    required this.onMaterialSelected,
    this.crossAxisCount = 3,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.2,
      ),
      itemCount: AppConstants.materialList.length,
      itemBuilder: (context, index) {
        final material = AppConstants.materialList[index];
        final isSelected = selectedMaterial == material;
        final unit = AppConstants.getUnit(material);
        
        return _buildMaterialCard(material, unit, isSelected);
      },
    );
  }

  Widget _buildMaterialCard(String material, String unit, bool isSelected) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        gradient: isSelected
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppConstants.primaryColor,
                  AppConstants.primaryColor.withBlue(80),
                ],
              )
            : null,
        color: isSelected ? null : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected
              ? AppConstants.primaryColor
              : Colors.grey.shade200,
          width: isSelected ? 2 : 1,
        ),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: AppConstants.primaryColor.withAlpha(51),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onMaterialSelected(material),
          borderRadius: BorderRadius.circular(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _getMaterialIcon(material),
                size: 32,
                color: isSelected ? Colors.white : AppConstants.primaryColor,
              ),
              const SizedBox(height: 8),
              Text(
                material,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                unit,
                style: TextStyle(
                  fontSize: 11,
                  color: isSelected ? Colors.white70 : Colors.grey.shade500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getMaterialIcon(String material) {
    switch (material) {
      case 'حديد':
        return Icons.hardware;
      case 'اسمنت':
        return Icons.business;
      case 'رمل':
        return Icons.grain;
      case 'طوب':
        return Icons.crop_square;
      case 'بلاستيك':
        return Icons.polymer;
      case 'دهان':
        return Icons.format_paint;
      case 'بلاط':
        return Icons.grid_on;
      case 'سيراميك':
        return Icons.grid_3x3;
      case 'خشب':
        return Icons.forest;
      case 'مسامير':
        return Icons.circle;
      case 'زجاج':
        return Icons.flip;
      case 'المنيوم':
        return Icons.square;
      default:
        return Icons.category;
    }
  }
}