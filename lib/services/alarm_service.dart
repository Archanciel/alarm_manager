// lib/services/alarm_service.dart - Fixed next alarm calculation and timezone handling
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
      final alarms = await getAlarms();
      alarms.add(alarm);
      await saveAlarms(alarms);

      // Schedule notification and background alarm
      await _notificationService.scheduleAlarmNotification(alarm);
      await _scheduleBackgroundAlarm(alarm);

      // Also schedule a manual check slightly after the alarm time for debugging
      await _scheduleDebugCheck(alarm);

      _logger.i('Alarm added: ${alarm.name} for ${alarm.nextAlarmDateTime}');
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

        // Only reschedule if the alarm is in the future
        if (updatedAlarm.nextAlarmDateTime.isAfter(DateTime.now())) {
          await _notificationService.scheduleAlarmNotification(updatedAlarm);
          await _scheduleBackgroundAlarm(updatedAlarm);
          await _scheduleDebugCheck(updatedAlarm);
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
      final alarmToDelete = alarms.firstWhere((alarm) => alarm.id == alarmId);

      // Cancel background alarm
      await _cancelBackgroundAlarm(alarmToDelete);
      await _cancelDebugCheck(alarmToDelete);

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
      final now = DateTime.now();

      _logger.i('Scheduling alarm: ${alarm.name}');
      _logger.i('Current time: $now');
      _logger.i('Alarm time: ${alarm.nextAlarmDateTime}');
      _logger.i(
        'Time difference: ${alarm.nextAlarmDateTime.difference(now).inMinutes} minutes',
      );

      // Only schedule if in the future
      if (alarm.nextAlarmDateTime.isAfter(now)) {
        await AndroidAlarmManager.oneShotAt(
          alarm.nextAlarmDateTime,
          alarmId,
          _backgroundAlarmCallback,
          exact: true,
          wakeup: true,
          allowWhileIdle: true,
          params: {'alarmId': alarm.id, 'alarmName': alarm.name},
        );

        _logger.i(
          'Successfully scheduled background alarm for: ${alarm.name} at ${alarm.nextAlarmDateTime}',
        );
      } else {
        _logger.w('Cannot schedule alarm in the past: ${alarm.name}');
      }
    } catch (e) {
      _logger.e('Error scheduling background alarm: $e');
    }
  }

  Future<void> _scheduleDebugCheck(AlarmModel alarm) async {
    try {
      // Only schedule debug check if the alarm is in the future
      if (!alarm.nextAlarmDateTime.isAfter(DateTime.now())) {
        return;
      }

      final debugTime = alarm.nextAlarmDateTime.add(const Duration(minutes: 1));
      final debugId = alarm.id.hashCode + 100000;

      await AndroidAlarmManager.oneShotAt(
        debugTime,
        debugId,
        _debugCheckCallback,
        exact: true,
        wakeup: true,
        allowWhileIdle: true,
        params: {
          'alarmId': alarm.id,
          'originalTime': alarm.nextAlarmDateTime.toIso8601String(),
        },
      );

      _logger.i('Scheduled debug check for alarm: ${alarm.name} at $debugTime');
    } catch (e) {
      _logger.e('Error scheduling debug check: $e');
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

  Future<void> _cancelDebugCheck(AlarmModel alarm) async {
    try {
      final debugId = alarm.id.hashCode + 100000;
      await AndroidAlarmManager.cancel(debugId);
      _logger.i('Cancelled debug check for: ${alarm.name}');
    } catch (e) {
      _logger.e('Error cancelling debug check: $e');
    }
  }

  /// This function is called by AndroidAlarmManager from native Android code.
  ///
  /// What happens without the 'pragma' annotation:
  ///
  /// Release builds might fail - Functions get removed during optimization.
  /// Background alarms won't work - The callback functions don't exist.
  /// Silent failures - No error messages, alarms just don't trigger.
  /// Works in debug, fails in release - Debug builds are less optimized.
  ///
  /// Removing these annotations would likely cause alarms to work in debug
  /// mode but fail silently in release builds - which is exactly the kind of
  /// bug that's hard to track down !
  /// It's basically telling Flutter: "Trust me, this function IS used, even
  /// though you can't see how !".
  @pragma('vm:entry-point')
  static void _backgroundAlarmCallback(
    int id,
    Map<String, dynamic> params,
  ) async {
    final logger = Logger();
    final now = DateTime.now();
    logger.i('🔔 ALARM TRIGGERED! Background alarm callback executed at $now');
    logger.i('Alarm ID: $id');
    logger.i('Params: $params');

    try {
      final alarmService = AlarmService();
      final alarmId = params['alarmId'] as String?;
      final alarmName = params['alarmName'] as String? ?? 'Unknown';

      logger.i('Triggering alarm: $alarmName (ID: $alarmId)');

      if (alarmId != null) {
        await alarmService._handleAlarmTrigger(alarmId);
      }
    } catch (e) {
      logger.e('Error in background alarm callback: $e');
    }
  }

  /// This function is called by the periodic background service.
  ///
  /// What happens without the 'pragma' annotation:
  ///
  /// Release builds might fail - Functions get removed during optimization.
  /// Background alarms won't work - The callback functions don't exist.
  /// Silent failures - No error messages, alarms just don't trigger.
  /// Works in debug, fails in release - Debug builds are less optimized.
  ///
  /// Removing these annotations would likely cause alarms to work in debug
  /// mode but fail silently in release builds - which is exactly the kind of
  /// bug that's hard to track down !
  /// It's basically telling Flutter: "Trust me, this function IS used, even
  /// though you can't see how !".
  @pragma('vm:entry-point')
  static void _debugCheckCallback(int id, Map<String, dynamic> params) async {
    final logger = Logger();
    final now = DateTime.now();
    logger.i('🐛 DEBUG CHECK: Running at $now');
    logger.i('Debug ID: $id');
    logger.i('Params: $params');

    try {
      final alarmService = AlarmService();
      final alarmId = params['alarmId'] as String?;
      final originalTimeStr = params['originalTime'] as String?;

      if (originalTimeStr != null) {
        final originalTime = DateTime.parse(originalTimeStr);
        logger.i('Original alarm time was: $originalTime');
        logger.i('Current time: $now');
        logger.i(
          'Time since alarm should have triggered: ${now.difference(originalTime).inMinutes} minutes',
        );
      }

      // Force check all alarms
      await alarmService.checkAndTriggerAlarms();
    } catch (e) {
      logger.e('Error in debug check callback: $e');
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

      // Play alarm sound
      await _audioService.playAlarm(alarm.audioFile);

      // Show notification
      await _notificationService.showAlarmTriggeredNotification(alarm);

      // Calculate next alarm time - FIXED CALCULATION
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

      // Schedule the next occurrence
      await _notificationService.scheduleAlarmNotification(updatedAlarm);
      await _scheduleBackgroundAlarm(updatedAlarm);
      await _scheduleDebugCheck(updatedAlarm);

      _logger.i(
        'Alarm "${alarm.name}" triggered successfully. Next alarm: $nextAlarmTime',
      );
    } catch (e) {
      _logger.e('Error handling alarm trigger: $e');
    }
  }

  DateTime _calculateNextAlarmTime(
    DateTime currentAlarmTime,
    AlarmPeriodicity periodicity,
  ) {
    // Simply add the periodicity to the current alarm time
    final nextTime = currentAlarmTime.add(periodicity.duration);

    _logger.i('Calculating next alarm:');
    _logger.i('  Current: $currentAlarmTime');
    _logger.i('  + Period: ${periodicity.duration}');
    _logger.i('  = Next: $nextTime');

    return nextTime;
  }

  Future<void> checkAndTriggerAlarms() async {
    try {
      final alarms = await getAlarms();
      final now = DateTime.now();

      _logger.i('🔍 Checking ${alarms.length} alarms at $now');

      for (final alarm in alarms) {
        _logger.i('Checking alarm: ${alarm.name}');
        _logger.i('  - Active: ${alarm.isActive}');
        _logger.i('  - Next alarm: ${alarm.nextAlarmDateTime}');
        _logger.i('  - Time passed: ${now.isAfter(alarm.nextAlarmDateTime)}');

        if (alarm.isActive && now.isAfter(alarm.nextAlarmDateTime)) {
          _logger.i('⏰ Triggering overdue alarm: ${alarm.name}');
          await _handleAlarmTrigger(alarm.id);
        }
      }
    } catch (e) {
      _logger.e('Error checking alarms: $e');
    }
  }

  // Manual trigger for testing
  Future<void> triggerAlarmNow(String alarmId) async {
    try {
      _logger.i('🧪 Manually triggering alarm: $alarmId');
      await _handleAlarmTrigger(alarmId);
    } catch (e) {
      _logger.e('Error manually triggering alarm: $e');
    }
  }

  DateTime calculateNextAlarmTime(
    DateTime baseTime,
    AlarmPeriodicity periodicity,
  ) {
    final now = DateTime.now();
    DateTime nextAlarm = baseTime;

    // If the base time is in the past, calculate the next occurrence
    while (nextAlarm.isBefore(now)) {
      nextAlarm = nextAlarm.add(periodicity.duration);
    }

    return nextAlarm;
  }
}
