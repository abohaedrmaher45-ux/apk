import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'daily_movement_screen.dart';
import '../main.dart';
import '../security/activation_screen.dart';

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkTimerExpired();
    });
  }

  void _checkTimerExpired() {
    final timerProvider = TrialTimerProvider.of(context);
    if (timerProvider?.remainingSeconds == 0) {
      _navigateToActivationScreen();
    }
  }

  void _navigateToActivationScreen() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const ActivationScreen()),
      (route) => false,
    );
  }

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
    final timerProvider = TrialTimerProvider.of(context);
    final remainingSeconds = timerProvider?.remainingSeconds ?? 0;

    print('🕒 remainingSeconds in DateSelectionScreen: $remainingSeconds');

    // التحقق من انتهاء المؤقت
    if (remainingSeconds == 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _navigateToActivationScreen();
      });
    }

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
          // إضافة المؤقت في الـ AppBar
          actions: [
            if (remainingSeconds > 0)
              Padding(
                padding: const EdgeInsets.only(right: 16.0),
                child: Center(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: TrialTimer(
                      remainingSeconds: remainingSeconds,
                      onTimerExpired: _navigateToActivationScreen,
                    ),
                  ),
                ),
              ),
          ],
        ),
        body: Directionality(
          textDirection: TextDirection.rtl,
          child: Column(
            children: [
              // التاريخ المحدد
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
              
              // منتقي التاريخ
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
              
              // زر الدخول
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Center(
                  child: ElevatedButton.icon(
                    onPressed: remainingSeconds > 0 
                      ? () {
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
                        }
                      : null, // تعطيل الزر إذا انتهى الوقت
                    style: ElevatedButton.styleFrom(
                      backgroundColor: remainingSeconds > 0 
                        ? Colors.green[600] 
                        : Colors.grey[400],
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
                    label: Text(
                      remainingSeconds > 0 ? 'دخــول' : 'انتهت الفترة التجريبية',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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