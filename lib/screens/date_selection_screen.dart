import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'daily_movement_screen.dart';
import '../main.dart'; // استيراد TrialTimer و TrialTimerProvider

class DateSelectionScreen extends StatefulWidget {
  final String storeType;
  final String storeName;
  final String? sellerName;

  const DateSelectionScreen({
    super.key,
    required this.storeType,
    required this.storeName,
    this.sellerName,
  });

  @override
  State<DateSelectionScreen> createState() => _DateSelectionScreenState();
}

class _DateSelectionScreenState extends State<DateSelectionScreen> {
  DateTime _selectedDate = DateTime.now();

  void _updateDate({int? year, int? month, int? day}) {
    final currentYear = year ?? _selectedDate.year;
    final currentMonth = month ?? _selectedDate.month;
    var currentDay = day ?? _selectedDate.day;

    final daysInMonth = DateUtils.getDaysInMonth(currentYear, currentMonth);
    if (currentDay > daysInMonth) {
      currentDay = daysInMonth;
    }

    setState(() {
      _selectedDate = DateTime(currentYear, currentMonth, currentDay);
    });
  }

  Widget _buildCompactPicker(
    String label,
    int currentValue,
    VoidCallback onIncrement,
    VoidCallback onDecrement, {
    bool isMonth = false,
  }) {
    const months = [
      'يناير',
      'فبراير',
      'مارس',
      'أبريل',
      'مايو',
      'يونيو',
      'يوليو',
      'أغسطس',
      'سبتمبر',
      'أكتوبر',
      'نوفمبر',
      'ديسمبر',
    ];

    String displayValue =
        isMonth ? months[currentValue - 1] : currentValue.toString();

    return Flexible(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '$label:',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Column(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_drop_up),
                  onPressed: onIncrement,
                  color: Colors.green[600],
                  iconSize: 24,
                ),
                SizedBox(
                  height: 30,
                  child: Center(
                    child: Text(
                      displayValue,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.arrow_drop_down),
                  onPressed: onDecrement,
                  color: Colors.red[600],
                  iconSize: 24,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // الحصول على وقت المؤقت من الـ Provider
    final timerProvider = TrialTimerProvider.of(context);
    final remainingSeconds = timerProvider?.remainingSeconds ?? 0;

    return WillPopScope(
      onWillPop: () async {
        // عند الضغط على زر الرجوع الجهازي، نخرج من التطبيق تماماً
        SystemNavigator.pop();
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'اختيار التاريخ',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.teal[600],
          foregroundColor: Colors.white,
          centerTitle: true,
          // تم إزالة المؤقت من AppBar
          automaticallyImplyLeading: false,
        ),
        body: Directionality(
          textDirection: TextDirection.rtl,
          child: Column(
            children: [
              // ✅ المؤقت في أعلى الصفحة بشكل واضح وبارز
              if (remainingSeconds > 0)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.teal.shade700, Colors.teal.shade500],
                      begin: Alignment.topRight,
                      end: Alignment.topLeft,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.teal.shade200.withOpacity(0.5),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                    border: Border.all(
                      color: Colors.white.withOpacity(0.3),
                      width: 2,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // النص التوضيحي
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.timer_outlined,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'الوقت المتبقي',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                'الفترة التجريبية',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      // عداد الوقت بشكل كبير وواضح
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 5,
                            ),
                          ],
                        ),
                        child: TrialTimer(
                          remainingSeconds: remainingSeconds,
                          onTimerExpired: timerProvider?.widget.onTimerExpired,
                        ),
                      ),
                    ],
                  ),
                ),
              // باقي محتوى الصفحة
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Align(
                  alignment: Alignment.topRight,
                  child: Text(
                    '${_selectedDate.year}/${_selectedDate.month}/${_selectedDate.day}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.black54,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildCompactPicker(
                      'اليوم',
                      _selectedDate.day,
                      () => _updateDate(day: _selectedDate.day + 1),
                      () => _updateDate(day: _selectedDate.day - 1),
                    ),
                    _buildCompactPicker(
                      'الشهر',
                      _selectedDate.month,
                      () => _updateDate(month: _selectedDate.month + 1),
                      () => _updateDate(month: _selectedDate.month - 1),
                      isMonth: true,
                    ),
                    _buildCompactPicker(
                      'السنة',
                      _selectedDate.year,
                      () => _updateDate(year: _selectedDate.year + 1),
                      () => _updateDate(year: _selectedDate.year - 1),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Center(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => DailyMovementScreen(
                            selectedDate:
                                '${_selectedDate.year}/${_selectedDate.month}/${_selectedDate.day}',
                            storeType: widget.storeType,
                            sellerName: widget.sellerName ?? 'غير معروف',
                          ),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[600],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 60,
                        vertical: 18,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 4,
                    ),
                    icon: const Icon(Icons.check_circle_outline, size: 24),
                    label: const Text(
                      'دخــول',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}