// lib/services/alarm_service.dart - Completely silent background alarms
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
  late AudioService _audioService;

  Future<List<AlarmModel>> getAlarms() async {
    _audioService = await AudioService.getInstance();

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
      final alarmsJson =
          alarms.map((alarm) => jsonEncode(alarm.toJson())).toList();

      await prefs.setStringList(_alarmsKey, alarmsJson);
      _logger.i('Alarms saved successfully');
    } catch (e) {
      _logger.e('Error saving alarms: $e');
    }
  }

  Future<void> addAlarm(AlarmModel alarm) async {
    try {
      List<AlarmModel> alarms = await getAlarms();
      alarms.add(alarm);
      await saveAlarms(alarms);

      // Schedule ONLY silent notification - NO AndroidAlarmManager
      await _notificationService.scheduleAlarmNotification(alarm);

      _logger.i(
        '✅ Alarm added (SILENT): ${alarm.name} for ${alarm.nextAlarmDateTime}',
      );
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

        // Only reschedule silent notification
        if (updatedAlarm.nextAlarmDateTime.isAfter(DateTime.now())) {
          await _notificationService.scheduleAlarmNotification(updatedAlarm);
        } else {
          _logger.w('Skipping scheduling for past alarm: ${updatedAlarm.name}');
        }

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

  Future<void> _handleAlarmTrigger(String alarmId) async {
    try {
      final alarms = await getAlarms();
      final alarmIndex = alarms.indexWhere((a) => a.id == alarmId);

      if (alarmIndex == -1) {
        _logger.e('Alarm not found: $alarmId');
        return;
      }

      final alarm = alarms[alarmIndex];

      _logger.i('🎵 Handling alarm trigger: ${alarm.name}');
      _logger.i('🔊 Playing ONLY custom sound: ${alarm.audioFile}');

      // Play ONLY custom sound - no system sounds involved
      await _audioService.playAlarm(alarm.audioFile);

      // Show completely silent notification
      await _notificationService.showAlarmTriggeredNotification(alarm);

      // Calculate next alarm time
      final nextAlarmTime = _calculateNextAlarmTime(
        alarm.nextAlarmDateTime,
        alarm.periodicity,
      );

      _logger.i('Next alarm calculation:');
      _logger.i('  Current alarm time: ${alarm.nextAlarmDateTime}');
      _logger.i('  Periodicity: ${alarm.periodicity.formattedString}');
      _logger.i('  Calculated next time: $nextAlarmTime');

      // Update alarm with new times
      final updatedAlarm = alarm.copyWith(
        lastAlarmDateTime: alarm.nextAlarmDateTime,
        realAlarmDateTime: DateTime.now(),
        nextAlarmDateTime: nextAlarmTime,
      );

      // Update the alarm in the list and save
      alarms[alarmIndex] = updatedAlarm;
      await saveAlarms(alarms);

      // Schedule the next occurrence (silent notification only)
      await _notificationService.scheduleAlarmNotification(updatedAlarm);

      _logger.i('✅ Alarm "${alarm.name}" triggered with CUSTOM sound ONLY');
      _logger.i('🔊 NO system sounds - Playing: ${alarm.audioFile}');
    } catch (e) {
      _logger.e('Error handling alarm trigger: $e');
    }
  }

  DateTime _calculateNextAlarmTime(
    DateTime currentAlarmTime,
    AlarmPeriodicity periodicity,
  ) {
    DateTime now = DateTime.now();

    if (currentAlarmTime.isAfter(now)) {
      _logger.i('Current alarm time is in the future: $currentAlarmTime');
      return currentAlarmTime;
    }

    DateTime nextTime = currentAlarmTime.add(periodicity.duration);
    int i = 1;

    while (nextTime.isBefore(now)) {
      nextTime = nextTime.add(periodicity.duration);
      i++;
    }

    _logger.i('Calculating next alarm:');
    _logger.i(
      '  Current alarm: $currentAlarmTime + $i Period: ${periodicity.duration} = Next alarm: $nextTime',
    );

    return nextTime;
  }

  Future<void> checkAndTriggerAlarms() async {
    try {
      final alarms = await getAlarms();
      final now = DateTime.now();
      final int hour = now.hour;
      final int minute = now.minute;

      _logger.i('🔍 Checking ${alarms.length} alarms at $now (SILENT mode)');

      for (final alarm in alarms) {
        _logger.i('Checking alarm: ${alarm.name}');
        _logger.i('  - Active: ${alarm.isActive}');
        _logger.i('  - Next alarm: ${alarm.nextAlarmDateTime}');
        _logger.i('  - Time passed: ${now.isAfter(alarm.nextAlarmDateTime)}');

        if (alarm.isActive &&
            now.isAfter(alarm.nextAlarmDateTime) &&
            hour >= alarm.limit.fromHours &&
            minute >= alarm.limit.fromMinutes &&
            hour <= alarm.limit.toHours &&
            minute <= alarm.limit.toMinutes) {
          _logger.i(
            '⏰ Triggering overdue alarm (CUSTOM sound only): ${alarm.name}',
          );
          await _handleAlarmTrigger(alarm.id);
        }
      }
    } catch (e) {
      _logger.e('Error checking alarms: $e');
    }
  }

  /// Manual trigger for testing - completely silent except for custom MP3
  Future<void> triggerAlarmNow(String alarmId) async {
    try {
      _logger.i('🧪 Manually triggering alarm (CUSTOM sound only): $alarmId');
      await _handleAlarmTrigger(alarmId);
    } catch (e) {
      _logger.e('Error manually triggering alarm: $e');
    }
  }

  DateTime calculateNextAlarmTime(
    DateTime baseTime,
    AlarmPeriodicity periodicity,
  ) {
    return _calculateNextAlarmTime(baseTime, periodicity);
  }
}
