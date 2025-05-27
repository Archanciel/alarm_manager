// lib/services/alarm_service.dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:logger/logger.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import '../models/alarm_model.dart';
import 'notification_service.dart';
import 'audio_service.dart';

class AlarmService {
  static const String _alarmsKey = 'alarms';
  final Logger _logger = Logger();
  final NotificationService _notificationService = NotificationService();
  final AudioService _audioService = AudioService();

  Future<List<AlarmModel>> getAlarms() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final alarmsJson = prefs.getStringList(_alarmsKey) ?? [];
      
      return alarmsJson
          .map((json) => AlarmModel.fromJson(jsonDecode(json)))
          .toList();
    } catch (e) {
      _logger.e('Error loading alarms: $e');
      return [];
    }
  }

  Future<void> saveAlarms(List<AlarmModel> alarms) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final alarmsJson = alarms
          .map((alarm) => jsonEncode(alarm.toJson()))
          .toList();
      
      await prefs.setStringList(_alarmsKey, alarmsJson);
      _logger.i('Alarms saved successfully');
    } catch (e) {
      _logger.e('Error saving alarms: $e');
    }
  }

  Future<void> addAlarm(AlarmModel alarm) async {
    try {
      final alarms = await getAlarms();
      alarms.add(alarm);
      await saveAlarms(alarms);
      
      // Schedule notification and background alarm
      await _notificationService.scheduleAlarmNotification(alarm);
      await _scheduleBackgroundAlarm(alarm);
      
      _logger.i('Alarm added: ${alarm.name}');
    } catch (e) {
      _logger.e('Error adding alarm: $e');
    }
  }

  Future<void> updateAlarm(AlarmModel updatedAlarm) async {
    try {
      final alarms = await getAlarms();
      final index = alarms.indexWhere((alarm) => alarm.id == updatedAlarm.id);
      
      if (index != -1) {
        // Cancel old alarm
        await _cancelBackgroundAlarm(alarms[index]);
        
        alarms[index] = updatedAlarm;
        await saveAlarms(alarms);
        
        // Reschedule notification and background alarm
        await _notificationService.scheduleAlarmNotification(updatedAlarm);
        await _scheduleBackgroundAlarm(updatedAlarm);
        
        _logger.i('Alarm updated: ${updatedAlarm.name}');
      }
    } catch (e) {
      _logger.e('Error updating alarm: $e');
    }
  }

  Future<void> deleteAlarm(String alarmId) async {
    try {
      final alarms = await getAlarms();
      final alarmToDelete = alarms.firstWhere((alarm) => alarm.id == alarmId);
      
      // Cancel background alarm
      await _cancelBackgroundAlarm(alarmToDelete);
      
      alarms.removeWhere((alarm) => alarm.id == alarmId);
      await saveAlarms(alarms);
      
      // Cancel notification
      await _notificationService.cancelAlarmNotification(alarmId);
      
      _logger.i('Alarm deleted: $alarmId');
    } catch (e) {
      _logger.e('Error deleting alarm: $e');
    }
  }

  Future<void> _scheduleBackgroundAlarm(AlarmModel alarm) async {
    try {
      final alarmId = alarm.id.hashCode;
      
      // Schedule exact alarm
      await AndroidAlarmManager.oneShotAt(
        alarm.nextAlarmDateTime,
        alarmId,
        _backgroundAlarmCallback,
        exact: true,
        wakeup: true,
        params: {'alarmId': alarm.id},
      );
      
      _logger.i('Scheduled background alarm for: ${alarm.name}');
    } catch (e) {
      _logger.e('Error scheduling background alarm: $e');
    }
  }

  Future<void> _cancelBackgroundAlarm(AlarmModel alarm) async {
    try {
      final alarmId = alarm.id.hashCode;
      await AndroidAlarmManager.cancel(alarmId);
      _logger.i('Cancelled background alarm for: ${alarm.name}');
    } catch (e) {
      _logger.e('Error cancelling background alarm: $e');
    }
  }

  @pragma('vm:entry-point')
  static void _backgroundAlarmCallback(int id, Map<String, dynamic> params) async {
    final logger = Logger();
    logger.i('Background alarm triggered with id: $id');
    
    try {
      final alarmService = AlarmService();
      final alarmId = params['alarmId'] as String?;
      
      if (alarmId != null) {
        await alarmService._handleAlarmTrigger(alarmId);
      }
    } catch (e) {
      logger.e('Error in background alarm callback: $e');
    }
  }

  Future<void> _handleAlarmTrigger(String alarmId) async {
    try {
      final alarms = await getAlarms();
      final alarm = alarms.firstWhere((a) => a.id == alarmId);
      
      _logger.i('Triggering alarm: ${alarm.name}');
      
      // Play alarm sound
      await _audioService.playAlarm(alarm.audioFile);
      
      // Show notification
      await _notificationService.showAlarmTriggeredNotification(alarm);
      
      // Calculate next alarm time
      final nextAlarmTime = alarm.nextAlarmDateTime.add(alarm.periodicity.duration);
      
      // Update alarm with new times
      final updatedAlarm = alarm.copyWith(
        lastAlarmDateTime: alarm.nextAlarmDateTime,
        realAlarmDateTime: DateTime.now(),
        nextAlarmDateTime: nextAlarmTime,
      );
      
      await updateAlarm(updatedAlarm);
      
    } catch (e) {
      _logger.e('Error handling alarm trigger: $e');
    }
  }

  Future<void> checkAndTriggerAlarms() async {
    try {
      final alarms = await getAlarms();
      final now = DateTime.now();
      
      for (final alarm in alarms) {
        if (alarm.isActive && now.isAfter(alarm.nextAlarmDateTime)) {
          await _handleAlarmTrigger(alarm.id);
        }
      }
    } catch (e) {
      _logger.e('Error checking alarms: $e');
    }
  }

  DateTime calculateNextAlarmTime(DateTime baseTime, AlarmPeriodicity periodicity) {
    final now = DateTime.now();
    DateTime nextAlarm = baseTime;
    
    // If the base time is in the past, calculate the next occurrence
    while (nextAlarm.isBefore(now)) {
      nextAlarm = nextAlarm.add(periodicity.duration);
    }
    
    return nextAlarm;
  }
}