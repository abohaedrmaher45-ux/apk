import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// بناء خلية جدول مشتركة
Widget buildTableCell({
  required TextEditingController controller,
  required FocusNode focusNode,
  required bool isSerialField,
  required bool isNumericField,
  required int rowIndex,
  required int colIndex,
  required Function(int, int) scrollToField,
  required Function(String, int, int) onFieldSubmitted,
  required Function(String, int, int) onFieldChanged,
  bool isSField = false,
  List<TextInputFormatter>? inputFormatters,
  int maxLines = 1,
  double fontSize = 13,
  TextAlign textAlign = TextAlign.right,
  TextDirection textDirection = TextDirection.rtl,
}) {
  return Container(
    padding: const EdgeInsets.all(1),
    constraints: const BoxConstraints(minHeight: 25),
    child: TextField(
      controller: controller,
      focusNode: focusNode,
      enabled: !isSerialField,
      readOnly: isSerialField,
      decoration: const InputDecoration(
        contentPadding: EdgeInsets.symmetric(horizontal: 2, vertical: 1),
        border: InputBorder.none,
        hintText: '.',
        hintStyle: TextStyle(fontSize: 13),
      ),
      style: TextStyle(
        fontSize: fontSize,
        color: isSerialField ? Colors.grey[700] : Colors.black,
      ),
      maxLines: maxLines,
      keyboardType: isSField
          ? TextInputType.number
          : (isNumericField
              ? TextInputType.numberWithOptions(decimal: true)
              : TextInputType.text),
      textInputAction: TextInputAction.next,
      textAlign: textAlign,
      textDirection: textDirection,
      inputFormatters: inputFormatters,
      onTap: () {
        scrollToField(rowIndex, colIndex);
      },
      onSubmitted: (value) => onFieldSubmitted(value, rowIndex, colIndex),
      onChanged: (value) => onFieldChanged(value, rowIndex, colIndex),
    ),
  );
}

// بناء خلية نقدي أو دين مع وظيفة خاصة بالمبيعات
Widget buildCashOrDebtCell({
  required int rowIndex,
  required int colIndex,
  required String cashOrDebtValue,
  required String customerName,
  required TextEditingController customerController,
  required FocusNode focusNode,
  required bool hasUnsavedChanges,
  required ValueChanged<bool> setHasUnsavedChanges,
  required VoidCallback onTap,
  required Function(int, int) scrollToField,
  required ValueChanged<String> onCustomerNameChanged,
  required Function(String, int, int) onCustomerSubmitted,
  bool isSalesScreen = false,
}) {
  // إذا كانت شاشة المبيعات والقيمة "دين"
  if (isSalesScreen && cashOrDebtValue == 'دين') {
    return Container(
      padding: const EdgeInsets.all(1),
      constraints: const BoxConstraints(minHeight: 25),
      child: TextField(
        controller: customerController,
        focusNode: focusNode,
        decoration: const InputDecoration(
          contentPadding: EdgeInsets.symmetric(horizontal: 2, vertical: 1),
          border: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.red, width: 0.5),
          ),
          hintText: 'اسم الزبون',
          hintStyle: TextStyle(fontSize: 9, color: Colors.grey),
        ),
        style: TextStyle(
          fontSize: 11,
          color: Colors.red[700],
          fontWeight: FontWeight.bold,
        ),
        maxLines: 2,
        textDirection: TextDirection.rtl,
        textAlign: TextAlign.right,
        textInputAction: TextInputAction.next,
        onTap: () {
          scrollToField(rowIndex, colIndex);
        },
        onChanged: (value) {
          onCustomerNameChanged(value);
          setHasUnsavedChanges(true);
        },
        onSubmitted: (value) => onCustomerSubmitted(value, rowIndex, colIndex),
      ),
    );
  }

  // إذا كانت شاشة المشتريات والقيمة "دين"
  if (!isSalesScreen && cashOrDebtValue == 'دين') {
    return Container(
      padding: const EdgeInsets.all(1),
      constraints: const BoxConstraints(minHeight: 25),
      child: InkWell(
        onTap: () {
          onTap();
          scrollToField(rowIndex, colIndex);
        },
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: Colors.red,
              width: 0.5,
            ),
            borderRadius: BorderRadius.circular(2),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
          child: const Center(
            child: Text(
              'دين',
              style: TextStyle(
                fontSize: 11,
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }

  // إذا كانت القيمة "نقدي"
  if (cashOrDebtValue == 'نقدي') {
    return Container(
      padding: const EdgeInsets.all(1),
      constraints: const BoxConstraints(minHeight: 25),
      child: InkWell(
        onTap: () {
          onTap();
          scrollToField(rowIndex, colIndex);
        },
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: Colors.green,
              width: 0.5,
            ),
            borderRadius: BorderRadius.circular(2),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
          child: Center(
            child: Text(
              'نقدي',
              style: TextStyle(
                fontSize: isSalesScreen ? 9 : 11,
                color: Colors.green,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }

  // إذا كانت القيمة فارغة (لم يتم الاختيار بعد)
  return Container(
    padding: const EdgeInsets.all(1),
    constraints: const BoxConstraints(minHeight: 25),
    child: InkWell(
      onTap: () {
        onTap();
        scrollToField(rowIndex, colIndex);
      },
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(2),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                'اختر',
                style: TextStyle(
                  fontSize: isSalesScreen ? 9 : 11,
                  color: Colors.grey,
                  fontWeight: FontWeight.normal,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(
              Icons.arrow_drop_down,
              size: isSalesScreen ? 12 : 16,
              color: Colors.grey[600],
            ),
          ],
        ),
      ),
    ),
  );
}
