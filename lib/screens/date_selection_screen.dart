import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'daily_movement_screen.dart';
import '../main.dart'; // لاستخدام checkTrialStatus و buildTrialTimer
import '../security/activation_screen.dart';
import 'package:intl/intl.dart'; // أضف في pubspec.yaml: intl: ^0.18.1

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
  bool _timerCheckDone = false;
  int _remainingSeconds = 0;
  bool _isTimerExpired = false;
  bool _navigating = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _initializeTimer();
  }

  Future<void> _initializeTimer() async {
    // التحقق من حالة المؤقت
    final isActive = await checkTrialStatus(context);
    if (!isActive) return;

    // بدء مراقبة المؤقت
    _startTimerMonitoring();
    
    setState(() {
      _timerCheckDone = true;
    });
  }

  void _startTimerMonitoring() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (!mounted || _navigating) return;
      
      final remaining = await _getRemainingSeconds();
      if (mounted) {
        setState(() {
          _remainingSeconds = remaining;
          _isTimerExpired = remaining <= 0;
        });
      }
      
      if (_isTimerExpired && !_navigating) {
        _navigateToActivationScreen();
      }
    });
  }

  Future<int> _getRemainingSeconds() async {
    final prefs = await SharedPreferences.getInstance();
    final trialEndTime = prefs.getInt('trial_end_time') ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return (trialEndTime - now).clamp(0, 259200);
  }

  void _navigateToActivationScreen() {
    if (_navigating || !mounted) return;
    _navigating = true;
    
    _timer?.cancel();
    
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const ActivationScreen()),
      (route) => false,
    );
  }

  void _updateDate({int? year, int? month, int? day}) {
    final currentYear = year?.clamp(1900, 2100) ?? _selectedDate.year;
    final currentMonth = month?.clamp(1, 12) ?? _selectedDate.month;
    var currentDay = day?.clamp(1, 31) ?? _selectedDate.day;

    final daysInMonth = DateUtils.getDaysInMonth(currentYear, currentMonth);
    currentDay = currentDay.clamp(1, daysInMonth);

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
      'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
      'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر',
    ];

    String displayValue = isMonth ? months[currentValue - 1] : currentValue.toString();

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
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_drop_up),
                  onPressed: onIncrement,
                  color: Colors.green[600],
                  iconSize: 24,
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.green[50],
                  ),
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
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.red[50],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(int seconds) {
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$secs';
  }

  Future<void> _navigateToDailyMovement() async {
    // التحقق النهائي من المؤقت
    final isActive = await checkTrialStatus(context);
    if (!isActive || _navigating) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => DailyMovementScreen(
          selectedDate: '${_selectedDate.year}/${_selectedDate.month}/${_selectedDate.day}',
          storeType: widget.storeType,
          sellerName: widget.sellerName ?? 'غير معروف',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_timerCheckDone) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) SystemNavigator.pop();
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
            onPressed: () => Navigator.of(context).pop(),
          ),
          // ✅ المؤقت المرئي الجميل
          actions: [
            if (!_isTimerExpired)
              Padding(
                padding: const EdgeInsets.only(right: 16.0),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.red.shade600, Colors.orange.shade600],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(25),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.timer, color: Colors.white, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        _formatTime(_remainingSeconds),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          shadows: [
                            Shadow(offset: Offset(1, 1), blurRadius: 2, color: Colors.black54),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        body: Directionality(
          textDirection: TextDirection.rtl,
          child: Column(
            children: [
              // عرض التاريخ الحالي
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.teal[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.teal[200]!),
                  ),
                  child: Text(
                    DateFormat('yyyy/MM/dd').format(_selectedDate),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.teal,
                    ),
                    textAlign: TextAlign.center,
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
                padding: const EdgeInsets.all(24.0),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: !_isTimerExpired ? _navigateToDailyMovement : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: !_isTimerExpired 
                          ? Colors.green[600] 
                          : Colors.grey[400],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      elevation: !_isTimerExpired ? 8 : 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: const Icon(Icons.login, size: 28),
                    label: Text(
                      !_isTimerExpired ? 'دخــول النظام' : 'انتهت الفترة التجريبية',
                      style: const TextStyle(
                        fontSize: 20, 
                        fontWeight: FontWeight.bold,
                      ),
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

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}