// lib/widgets/material_grid.dart
import 'package:flutter/material.dart';
import '../utils/app_constants.dart';

class MaterialGrid extends StatelessWidget {
  final String selectedMaterial;
  final ValueChanged<String> onMaterialSelected;

  const MaterialGrid({
    super.key,
    required this.selectedMaterial,
    required this.onMaterialSelected,
  });

  static const Map<String, IconData> materialIcons = {
    'حديد': Icons.construction,
    'اسمنت': Icons.inventory_2,
    'رمل': Icons.grain,
    'طوب': Icons.square,
    'بلاستيك': Icons.polymer,
    'دهان': Icons.format_paint,
    'بلاط': Icons.grid_on,
    'سيراميك': Icons.view_module,
    'خشب': Icons.forest,
    'مسامير': Icons.push_pin,
    'زجاج': Icons.window,
    'المنيوم': Icons.auto_awesome,
  };

  static const Map<String, Color> materialColors = {
    'حديد': Color(0xFF8B4513),
    'اسمنت': Color(0xFF808080),
    'رمل': Color(0xFFDAA520),
    'طوب': Color(0xFFB22222),
    'بلاستيك': Color(0xFFFF69B4),
    'دهان': Color(0xFF4169E1),
    'بلاط': Color(0xFF20B2AA),
    'سيراميك': Color(0xFF4682B4),
    'خشب': Color(0xFF8B6914),
    'مسامير': Color(0xFF708090),
    'زجاج': Color(0xFF87CEEB),
    'المنيوم': Color(0xFFC0C0C0),
  };

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 1.1,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: AppConstants.materialList.length,
      itemBuilder: (context, index) {
        final material = AppConstants.materialList[index];
        final isSelected = material == selectedMaterial;
        final icon = materialIcons[material] ?? Icons.category;
        final color = materialColors[material] ?? AppConstants.primaryColor;

        return GestureDetector(
          onTap: () => onMaterialSelected(material),
          child: AnimatedContainer(
            duration: AppConstants.animationDuration,
            curve: AppConstants.animationCurve,
            decoration: BoxDecoration(
              color: isSelected ? color.withOpacity(0.15) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? color : Colors.grey.shade200,
                width: isSelected ? 2.5 : 1,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: color.withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.grey.shade100,
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedScale(
                  duration: AppConstants.animationDuration,
                  scale: isSelected ? 1.2 : 1.0,
                  child: Icon(
                    icon,
                    size: 32,
                    color: isSelected ? color : Colors.grey.shade400,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  material,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? color : Colors.grey.shade600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 2),
                Text(
                  AppConstants.getUnit(material),
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey.shade400,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
