// lib/services/notification_service.dart
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import '../models/transaction.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    tz.initializeTimeZones();
    
    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings();
    
    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    
    await _notifications.initialize(settings);
  }

  Future<void> scheduleReturnReminder(Transaction transaction) async {
    if (transaction.returnDate == null) return;
    
    final returnDate = DateTime.parse(transaction.returnDate!);
    final reminderDate = returnDate.subtract(const Duration(days: 3));
    
    if (reminderDate.isBefore(DateTime.now())) return;
    
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'return_reminders',
      'تذكيرات الاسترجاع',
      channelDescription: 'تذكيرات بتواريخ استرجاع المواد',
      importance: Importance.high,
      priority: Priority.high,
    );
    
    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails();
    
    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    
    await _notifications.zonedSchedule(
      transaction.id,
      'موعد استرجاع',
      'مادة ${transaction.materialName} للعميل يجب استرجاعها بعد 3 أيام',
      tz.TZDateTime.from(reminderDate, tz.local),
      details,
      androidAllowWhileIdle: true,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
  }
}