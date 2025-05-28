// lib/services/notification_service.dart - ULTRA SILENT notifications
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
      tz.initializeTimeZones();
      
      final String timeZoneName = await _getLocalTimeZone();
      tz.setLocalLocation(tz.getLocation(timeZoneName));
      
      _logger.i('Timezone initialized: $timeZoneName');
      
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const initSettings = InitializationSettings(android: androidSettings);
      
      await _notifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );
      
      await _createSilentNotificationChannels();
      
      _logger.i('🔇 ULTRA SILENT notification service initialized');
    } catch (e) {
      _logger.e('Error initializing silent notifications: $e');
    }
  }

  Future<String> _getLocalTimeZone() async {
    try {
      final DateTime now = DateTime.now();
      if (now.timeZoneOffset.inHours == 2) {
        return 'Europe/Paris';
      } else if (now.timeZoneOffset.inHours == 1) {
        return 'Europe/Paris';
      }
      return 'Europe/Paris';
    } catch (e) {
      return 'Europe/Paris';
    }
  }

  Future<void> _createSilentNotificationChannels() async {
    // ULTRA SILENT notification channels
    const AndroidNotificationChannel alarmChannel = AndroidNotificationChannel(
      'alarm_channel_silent',
      'Silent Alarms',
      description: 'Completely silent alarm notifications',
      importance: Importance.low,      // ← LOW importance = no sound
      playSound: false,               // ← NO sound
      enableVibration: false,         // ← NO vibration
      enableLights: false,            // ← NO lights
      showBadge: false,              // ← NO badge
    );

    const AndroidNotificationChannel triggeredChannel = AndroidNotificationChannel(
      'alarm_triggered_silent',
      'Silent Triggered Alarms',
      description: 'Completely silent triggered alarm notifications',
      importance: Importance.low,      // ← LOW importance = no sound
      playSound: false,               // ← NO sound
      enableVibration: false,         // ← NO vibration  
      enableLights: false,            // ← NO lights
      showBadge: false,              // ← NO badge
    );

    final plugin = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    
    if (plugin != null) {
      await plugin.createNotificationChannel(alarmChannel);
      await plugin.createNotificationChannel(triggeredChannel);
      _logger.i('🔇 Created ULTRA SILENT notification channels');
    }
  }

  Future<void> scheduleAlarmNotification(AlarmModel alarm) async {
    try {
      final scheduledDate = tz.TZDateTime.from(alarm.nextAlarmDateTime, tz.local);
      final now = tz.TZDateTime.now(tz.local);
      
      _logger.i('🔇 Scheduling ULTRA SILENT notification:');
      _logger.i('  Alarm: ${alarm.name}');
      _logger.i('  Time: $scheduledDate');
      
      if (scheduledDate.isAfter(now)) {
        await _notifications.zonedSchedule(
          alarm.id.hashCode,
          'Silent Alarm Ready',
          'Custom sound will play for: ${alarm.name}',
          scheduledDate,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'alarm_channel_silent',
              'Silent Alarms',
              channelDescription: 'Completely silent alarm notifications',
              importance: Importance.low,     // ← LOWEST importance
              priority: Priority.low,        // ← LOWEST priority  
              playSound: false,              // ← NO sound
              sound: null,                   // ← NO sound
              enableVibration: false,        // ← NO vibration
              enableLights: false,           // ← NO lights
              silent: true,                  // ← COMPLETELY silent
              autoCancel: true,             // ← Auto dismiss
            ),
          ),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        );
        
        _logger.i('✅ ULTRA SILENT notification scheduled for: ${alarm.name}');
      }
    } catch (e) {
      _logger.e('Error scheduling silent notification: $e');
    }
  }

  Future<void> showAlarmTriggeredNotification(AlarmModel alarm) async {
    try {
      await _notifications.show(
        alarm.id.hashCode + 1000,
        '♪ Custom Sound Playing',
        '${alarm.name} - ${alarm.audioFile}',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'alarm_triggered_silent',
            'Silent Triggered Alarms',
            channelDescription: 'Completely silent triggered notifications',
            importance: Importance.low,      // ← LOWEST importance
            priority: Priority.low,         // ← LOWEST priority
            playSound: false,               // ← NO sound
            sound: null,                    // ← NO sound
            enableVibration: false,         // ← NO vibration
            enableLights: false,            // ← NO lights
            silent: true,                   // ← COMPLETELY silent
            ongoing: false,                 // ← NOT persistent
            autoCancel: true,              // ← Auto dismiss
            actions: <AndroidNotificationAction>[
              AndroidNotificationAction(
                'stop_custom_sound',
                'Stop Custom Sound',
                titleColor: Color.fromARGB(255, 255, 0, 0),
              ),
            ],
          ),
        ),
      );
      
      _logger.i('🔇 Showed ULTRA SILENT triggered notification for: ${alarm.name}');
    } catch (e) {
      _logger.e('Error showing silent triggered notification: $e');
    }
  }

  Future<void> cancelAlarmNotification(String alarmId) async {
    try {
      await _notifications.cancel(alarmId.hashCode);
      _logger.i('Cancelled silent notification for: $alarmId');
    } catch (e) {
      _logger.e('Error cancelling silent notification: $e');
    }
  }

  void _onNotificationTapped(NotificationResponse response) {
    _logger.i('Silent notification tapped: ${response.payload}');
    
    if (response.actionId == 'stop_custom_sound') {
      _logger.i('🔇 Stop custom sound action triggered');
      // Add logic to stop AudioService here if needed
    }
  }

  Future<void> cancelAllNotifications() async {
    try {
      await _notifications.cancelAll();
      _logger.i('All silent notifications cancelled');
    } catch (e) {
      _logger.e('Error cancelling all silent notifications: $e');
    }
  }
}