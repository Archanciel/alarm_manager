import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:logger/logger.dart';
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
      
      // Schedule notification
      await _notificationService.scheduleAlarmNotification(alarm);
      
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
        alarms[index] = updatedAlarm;
        await saveAlarms(alarms);
        
        // Reschedule notification
        await _notificationService.scheduleAlarmNotification(updatedAlarm);
        
        _logger.i('Alarm updated: ${updatedAlarm.name}');
      }
    } catch (e) {
      _logger.e('Error updating alarm: $e');
    }
  }

  Future<void> deleteAlarm(String alarmId) async {
    try {
      final alarms = await getAlarms();
      alarms.removeWhere((alarm) => alarm.id == alarmId);
      await saveAlarms(alarms);
      
      // Cancel notification
      await _notificationService.cancelAlarmNotification(alarmId);
      
      _logger.i('Alarm deleted: $alarmId');
    } catch (e) {
      _logger.e('Error deleting alarm: $e');
    }
  }

  Future<void> checkAndTriggerAlarms() async {
    try {
      final alarms = await getAlarms();
      final now = DateTime.now();
      
      for (final alarm in alarms) {
        if (alarm.isActive && now.isAfter(alarm.nextAlarmDateTime)) {
          await _triggerAlarm(alarm);
        }
      }
    } catch (e) {
      _logger.e('Error checking alarms: $e');
    }
  }

  Future<void> _triggerAlarm(AlarmModel alarm) async {
    try {
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
      _logger.e('Error triggering alarm: $e');
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
