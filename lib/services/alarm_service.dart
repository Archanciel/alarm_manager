// lib/services/alarm_service.dart - Fixed version with proper time limit logic
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

  /// Check if current time is within the alarm's allowed time limit
  bool _isWithinTimeLimit(DateTime currentTime, AlarmLimit limit) {
    final int currentTotalMinutes = currentTime.hour * 60 + currentTime.minute;
    final int fromTotalMinutes = limit.fromHours * 60 + limit.fromMinutes;
    final int toTotalMinutes = limit.toHours * 60 + limit.toMinutes;
    
    if (fromTotalMinutes <= toTotalMinutes) {
      // Normal case: 08:00 to 22:00 (same day)
      return currentTotalMinutes >= fromTotalMinutes && currentTotalMinutes <= toTotalMinutes;
    } else {
      // Crossing midnight: 22:00 to 06:00 (next day)
      return currentTotalMinutes >= fromTotalMinutes || currentTotalMinutes <= toTotalMinutes;
    }
  }

  /// Reschedule alarm for the next valid time window
  Future<void> _rescheduleAlarmForNextValidTime(AlarmModel alarm) async {
    try {
      final now = DateTime.now();
      final limit = alarm.limit;
      
      DateTime nextValidTime;
      
      // Check if limit crosses midnight (e.g., 22:00 to 06:00)
      final bool crossesMidnight = (limit.fromHours * 60 + limit.fromMinutes) > 
                                   (limit.toHours * 60 + limit.toMinutes);
      
      if (crossesMidnight) {
        // Handle midnight crossing (e.g., 22:00 to 06:00)
        final todayValidStart = DateTime(
          now.year, now.month, now.day,
          limit.fromHours, limit.fromMinutes,
        );
        final tomorrowValidStart = DateTime(
          now.year, now.month, now.day + 1,
          limit.fromHours, limit.fromMinutes,
        );
        
        if (now.isBefore(todayValidStart)) {
          nextValidTime = todayValidStart;
        } else {
          nextValidTime = tomorrowValidStart;
        }
      } else {
        // Normal case (e.g., 08:00 to 22:00)
        final todayValidStart = DateTime(
          now.year, now.month, now.day,
          limit.fromHours, limit.fromMinutes,
        );
        final tomorrowValidStart = DateTime(
          now.year, now.month, now.day + 1,
          limit.fromHours, limit.fromMinutes,
        );
        
        nextValidTime = now.isBefore(todayValidStart) 
            ? todayValidStart 
            : tomorrowValidStart;
      }
      
      // Update alarm with new time
      final updatedAlarm = alarm.copyWith(nextAlarmDateTime: nextValidTime);
      await updateAlarm(updatedAlarm);
      
      _logger.i('📅 Rescheduled alarm "${alarm.name}" to next valid time: $nextValidTime');
    } catch (e) {
      _logger.e('Error rescheduling alarm: $e');
    }
  }

  Future<void> checkAndTriggerAlarms() async {
    try {
      final alarms = await getAlarms();
      final now = DateTime.now();

      _logger.i('🔍 Checking ${alarms.length} alarms at $now (SILENT mode)');

      for (final alarm in alarms) {
        _logger.i('Checking alarm: ${alarm.name}');
        _logger.i('  - Active: ${alarm.isActive}');
        _logger.i('  - Next alarm: ${alarm.nextAlarmDateTime}');
        _logger.i('  - Time passed: ${now.isAfter(alarm.nextAlarmDateTime)}');
        _logger.i('  - Time limit: ${alarm.limit.formattedString}');
        
        final bool isOverdue = now.isAfter(alarm.nextAlarmDateTime);
        final bool isWithinTimeLimit = _isWithinTimeLimit(now, alarm.limit);
        
        _logger.i('  - Is overdue: $isOverdue');
        _logger.i('  - Within time limit: $isWithinTimeLimit');

        if (alarm.isActive && isOverdue && isWithinTimeLimit) {
          _logger.i(
            '⏰ Triggering overdue alarm (CUSTOM sound only): ${alarm.name}',
          );
          await _handleAlarmTrigger(alarm.id);
        } else if (alarm.isActive && isOverdue && !isWithinTimeLimit) {
          _logger.i('⏸️ Alarm overdue but outside time limit: ${alarm.name}');
          // Optionally reschedule for next valid time window
          await _rescheduleAlarmForNextValidTime(alarm);
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