import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'daily_movement_screen.dart';
import '../main.dart'; // استيراد TrialTimerProvider

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

  String _formatTime(int seconds) {
    if (seconds <= 0) return '00:00';
    int minutes = seconds ~/ 60;
    int secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  Color _getTimerColor(int seconds) {
    if (seconds <= 60) return Colors.red;
    if (seconds <= 300) return Colors.orange;
    return Colors.teal;
  }

  @override
  Widget build(BuildContext context) {
    // الحصول على وقت المؤقت من الـ Provider
    final timerProvider = TrialTimerProvider.of(context);
    final remainingSeconds = timerProvider?.remainingSeconds ?? 0;

    print('🕒 remainingSeconds in DateSelectionScreen: $remainingSeconds'); // للتأكد

    return WillPopScope(
      onWillPop: () async {
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
          automaticallyImplyLeading: false,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
        ),
        body: Directionality(
          textDirection: TextDirection.rtl,
          child: Column(
            children: [
              // ✅ المؤقت - يظهر دائماً في الأعلى
              Container(
                width: double.infinity,
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      _getTimerColor(remainingSeconds).withOpacity(0.1),
                      _getTimerColor(remainingSeconds).withOpacity(0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _getTimerColor(remainingSeconds).withOpacity(0.3),
                    width: 2,
                  ),
                ),
                child: Row(
                  children: [
                    // أيقونة المؤقت
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _getTimerColor(remainingSeconds).withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        remainingSeconds < 300 
                          ? Icons.timer_off_outlined 
                          : Icons.timer_outlined,
                        color: _getTimerColor(remainingSeconds),
                        size: 30,
                      ),
                    ),
                    const SizedBox(width: 16),
                    
                    // النصوص
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'الوقت المتبقي في الفترة التجريبية',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _formatTime(remainingSeconds),
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: _getTimerColor(remainingSeconds),
                              letterSpacing: 2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // شريط التقدم الدائري
                    SizedBox(
                      width: 50,
                      height: 50,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CircularProgressIndicator(
                            value: remainingSeconds / 900, // 15 دقيقة
                            backgroundColor: Colors.grey.shade200,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              _getTimerColor(remainingSeconds)
                            ),
                            strokeWidth: 4,
                          ),
                          Text(
                            '${((remainingSeconds / 900) * 100).toStringAsFixed(0)}%',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: _getTimerColor(remainingSeconds),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              // ✅ التاريخ المحدد
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
              
              // ✅ منتقي التاريخ
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
              
              // ✅ زر الدخول
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
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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