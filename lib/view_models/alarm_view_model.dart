import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import '../models/alarm_model.dart';
import '../services/alarm_service.dart';

class AlarmViewModel extends ChangeNotifier {
  final AlarmService _alarmService = AlarmService();
  final Logger _logger = Logger();

  List<AlarmModel> _alarms = [];
  bool _isLoading = false;

  List<AlarmModel> get alarms => _alarms;
  bool get isLoading => _isLoading;

  Future<void> loadAlarms() async {
    _isLoading = true;
    notifyListeners();

    try {
      _alarms = await _alarmService.getAlarms();
      _logger.i('Loaded ${_alarms.length} alarms');
    } catch (e) {
      _logger.e('Error loading alarms: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addAlarm(AlarmModel alarm) async {
    try {
      await _alarmService.addAlarm(alarm);
      await loadAlarms(); // Reload to get updated list
      _logger.i('Added alarm: ${alarm.name}');
    } catch (e) {
      _logger.e('Error adding alarm: $e');
    }
  }

  Future<void> updateAlarm(AlarmModel alarm) async {
    try {
      await _alarmService.updateAlarm(alarm);
      await loadAlarms(); // Reload to get updated list
      _logger.i('Updated alarm: ${alarm.name}');
    } catch (e) {
      _logger.e('Error updating alarm: $e');
    }
  }

  Future<void> deleteAlarm(String alarmId) async {
    try {
      await _alarmService.deleteAlarm(alarmId);
      await loadAlarms(); // Reload to get updated list
      _logger.i('Deleted alarm: $alarmId');
    } catch (e) {
      _logger.e('Error deleting alarm: $e');
    }
  }

  Future<void> toggleAlarmActive(String alarmId) async {
    try {
      final alarm = _alarms.firstWhere((a) => a.id == alarmId);
      final updatedAlarm = alarm.copyWith(isActive: !alarm.isActive);
      await updateAlarm(updatedAlarm);
      _logger.i('Toggled alarm active state: ${alarm.name}');
    } catch (e) {
      _logger.e('Error toggling alarm: $e');
    }
  }
}
