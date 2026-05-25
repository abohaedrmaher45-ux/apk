// lib/widgets/quantity_slider.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/app_constants.dart';

class QuantitySlider extends StatefulWidget {
  final double maxQuantity;
  final double initialValue;
  final String unit;
  final ValueChanged<double> onChanged;

  const QuantitySlider({
    super.key,
    required this.maxQuantity,
    required this.initialValue,
    required this.unit,
    required this.onChanged,
  });

  @override
  State<QuantitySlider> createState() => _QuantitySliderState();
}

class _QuantitySliderState extends State<QuantitySlider> {
  late double _currentValue;
  final TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _currentValue = widget.initialValue;
    _controller.text = _currentValue.toStringAsFixed(2);
  }

  @override
  void didUpdateWidget(QuantitySlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialValue != widget.initialValue) {
      _currentValue = widget.initialValue;
      _controller.text = _currentValue.toStringAsFixed(2);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _updateValue(double value) {
    setState(() {
      _currentValue = value;
      _controller.text = value.toStringAsFixed(2);
    });
    widget.onChanged(value);
    HapticFeedback.lightImpact();
  }

  @override
  Widget build(BuildContext context) {
    final percentage = widget.maxQuantity > 0
        ? (_currentValue / widget.maxQuantity * 100).toStringAsFixed(0)
        : '0';

    return Column(
      children: [
        Row(
          children: [
            _buildButton(
              icon: Icons.remove,
              onPressed: _currentValue > 0
                  ? () => _updateValue((_currentValue - 1).clamp(0, widget.maxQuantity))
                  : null,
            ),
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 12),
                child: TextField(
                  controller: _controller,
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  decoration: InputDecoration(
                    suffixText: widget.unit,
                    suffixStyle: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 14,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: AppConstants.primaryColor,
                        width: 2,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onChanged: (value) {
                    final parsed = double.tryParse(value) ?? 0;
                    final clamped = parsed.clamp(0, widget.maxQuantity);
                    setState(() => _currentValue = clamped);
                    widget.onChanged(clamped);
                  },
                ),
              ),
            ),
            _buildButton(
              icon: Icons.add,
              onPressed: _currentValue < widget.maxQuantity
                  ? () => _updateValue((_currentValue + 1).clamp(0, widget.maxQuantity))
                  : null,
            ),
          ],
        ),
        const SizedBox(height: 16),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: widget.maxQuantity > 0 ? _currentValue / widget.maxQuantity : 0,
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation<Color>(
              _currentValue > widget.maxQuantity * 0.8
                  ? AppConstants.dangerColor
                  : _currentValue > widget.maxQuantity * 0.5
                      ? AppConstants.secondaryColor
                      : AppConstants.successColor,
            ),
            minHeight: 8,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '0 ${widget.unit}',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
            ),
            Text(
              '$percentage% من المتاح',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _currentValue > widget.maxQuantity * 0.8
                    ? AppConstants.dangerColor
                    : AppConstants.primaryColor,
              ),
            ),
            Text(
              '${widget.maxQuantity.toStringAsFixed(2)} ${widget.unit}',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildButton({
    required IconData icon,
    required VoidCallback? onPressed,
  }) {
    return Material(
      color: onPressed != null
          ? AppConstants.primaryColor.withOpacity(0.1)
          : Colors.grey.shade100,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          child: Icon(
            icon,
            color: onPressed != null
                ? AppConstants.primaryColor
                : Colors.grey.shade400,
            size: 20,
          ),
        ),
      ),
    );
  }
}
