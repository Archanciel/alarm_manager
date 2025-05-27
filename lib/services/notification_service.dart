// lib/services/notification_service.dart
import 'dart:ui';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:logger/logger.dart';
import '../models/alarm_model.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  final Logger _logger = Logger();

  Future<void> initialize() async {
    try {
      // Initialize timezone data
      tz.initializeTimeZones();
      
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const initSettings = InitializationSettings(android: androidSettings);
      
      await _notifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );
      
      // Create notification channels
      await _createNotificationChannels();
      
      _logger.i('Notification service initialized');
    } catch (e) {
      _logger.e('Error initializing notifications: $e');
    }
  }

  Future<void> _createNotificationChannels() async {
    const AndroidNotificationChannel alarmChannel = AndroidNotificationChannel(
      'alarm_channel',
      'Alarms',
      description: 'Alarm notifications',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );

    const AndroidNotificationChannel triggeredChannel = AndroidNotificationChannel(
      'alarm_triggered_channel',
      'Triggered Alarms',
      description: 'Notifications when alarms are triggered',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );

    final plugin = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    
    if (plugin != null) {
      await plugin.createNotificationChannel(alarmChannel);
      await plugin.createNotificationChannel(triggeredChannel);
    }
  }

  Future<void> scheduleAlarmNotification(AlarmModel alarm) async {
    try {
      final scheduledDate = tz.TZDateTime.from(
        alarm.nextAlarmDateTime, 
        tz.local,
      );

      await _notifications.zonedSchedule(
        alarm.id.hashCode,
        'Alarm: ${alarm.name}',
        'Alarm is ringing!',
        scheduledDate,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'alarm_channel',
            'Alarms',
            channelDescription: 'Alarm notifications',
            importance: Importance.max,
            priority: Priority.high,
            playSound: true,
            enableVibration: true,
            fullScreenIntent: true,
            category: AndroidNotificationCategory.alarm,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
      
      _logger.i('Scheduled notification for alarm: ${alarm.name} at ${scheduledDate}');
    } catch (e) {
      _logger.e('Error scheduling notification: $e');
    }
  }

  Future<void> cancelAlarmNotification(String alarmId) async {
    try {
      await _notifications.cancel(alarmId.hashCode);
      _logger.i('Cancelled notification for alarm: $alarmId');
    } catch (e) {
      _logger.e('Error cancelling notification: $e');
    }
  }

  Future<void> showAlarmTriggeredNotification(AlarmModel alarm) async {
    try {
      await _notifications.show(
        alarm.id.hashCode + 1000,
        'Alarm Triggered: ${alarm.name}',
        'Your alarm is ringing now!',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'alarm_triggered_channel',
            'Triggered Alarms',
            channelDescription: 'Notifications when alarms are triggered',
            importance: Importance.max,
            priority: Priority.high,
            playSound: true,
            enableVibration: true,
            ongoing: true,
            fullScreenIntent: true,
            category: AndroidNotificationCategory.alarm,
            actions: <AndroidNotificationAction>[
              AndroidNotificationAction(
                'stop_alarm',
                'Stop Alarm',
                titleColor: Color.fromARGB(255, 255, 0, 0),
              ),
            ],
          ),
        ),
      );
      
      _logger.i('Showed triggered notification for alarm: ${alarm.name}');
    } catch (e) {
      _logger.e('Error showing triggered notification: $e');
    }
  }

  void _onNotificationTapped(NotificationResponse response) {
    _logger.i('Notification tapped: ${response.payload}');
    
    if (response.actionId == 'stop_alarm') {
      _logger.i('Stop alarm action triggered');
      // Handle stop alarm action - you can add audio service stop here
    }
  }

  Future<void> cancelAllNotifications() async {
    try {
      await _notifications.cancelAll();
      _logger.i('All notifications cancelled');
    } catch (e) {
      _logger.e('Error cancelling all notifications: $e');
    }
  }
}