// lib/services/notification_service.dart - Fixed timezone handling
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
      
      // Set local timezone - this is crucial!
      final String timeZoneName = await _getLocalTimeZone();
      tz.setLocalLocation(tz.getLocation(timeZoneName));
      
      _logger.i('Timezone initialized: $timeZoneName');
      _logger.i('Current local time: ${tz.TZDateTime.now(tz.local)}');
      
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

  Future<String> _getLocalTimeZone() async {
    try {
      // Try to get system timezone
      final DateTime now = DateTime.now();
      final String offset = now.timeZoneOffset.toString();
      _logger.i('System timezone offset: $offset');
      
      // For Central European Summer Time (CEST) - UTC+2
      // You can modify this based on your needs
      if (now.timeZoneOffset.inHours == 2) {
        return 'Europe/Paris'; // CEST
      } else if (now.timeZoneOffset.inHours == 1) {
        return 'Europe/Paris'; // CET
      }
      
      // Default fallback
      return 'Europe/Paris';
    } catch (e) {
      _logger.e('Error getting timezone: $e');
      return 'Europe/Paris'; // Safe fallback
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
      // Convert to timezone-aware datetime
      final scheduledDate = tz.TZDateTime.from(
        alarm.nextAlarmDateTime, 
        tz.local,
      );
      
      final now = tz.TZDateTime.now(tz.local);
      
      _logger.i('Scheduling notification:');
      _logger.i('  Current time: $now');
      _logger.i('  Alarm time: ${alarm.nextAlarmDateTime}');
      _logger.i('  Scheduled TZ time: $scheduledDate');
      _logger.i('  Time difference: ${scheduledDate.difference(now).inMinutes} minutes');
      
      // Only schedule if in the future
      if (scheduledDate.isAfter(now)) {
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
        
        _logger.i('Successfully scheduled notification for: ${alarm.name}');
      } else {
        _logger.w('Cannot schedule notification in the past: ${alarm.name}');
      }
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