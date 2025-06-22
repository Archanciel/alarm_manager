// lib/services/background_service.dart - SILENT background service
import 'package:logger/logger.dart';
import 'dart:async';
import '../constants.dart';
import 'alarm_service.dart';

class BackgroundService {
  final Logger _logger = Logger();
  Timer? _foregroundTimer;

  Future<void> initialize() async {
    try {
      // NO AndroidAlarmManager - only foreground timer
      _startForegroundTimer();
      
      _logger.i('🔇 SILENT background service initialized (foreground timer only)');
      _logger.i('🚫 NO AndroidAlarmManager = NO system alarm sounds');
    } catch (e) {
      _logger.e('Error initializing background service: $e');
    }
  }

  void _startForegroundTimer() {
    _foregroundTimer?.cancel();

    // Check every kAlarmCheckIntervalSeconds when app is in foreground
    _foregroundTimer = Timer.periodic(Duration(seconds: kAlarmCheckIntervalSeconds), (timer) async {
      _logger.i('🔄 Silent foreground timer check - ${DateTime.now()}');
      
      try {
        final alarmService = AlarmService();
        await alarmService.checkAndTriggerAlarms();
      } catch (e) {
        _logger.e('Error in silent foreground timer: $e');
      }
    });
    
    _logger.i('✅ Started SILENT foreground timer - checking every 30 seconds');
    _logger.i('🔇 This will trigger ONLY custom MP3 sounds');
  }

  Future<void> scheduleOneTimeCheck({Duration delay = const Duration(minutes: 1)}) async {
    try {
      // Use simple timer instead of AndroidAlarmManager
      Timer(delay, () async {
        _logger.i("⏰ Silent one-time check executed at ${DateTime.now()}");
        
        try {
          final alarmService = AlarmService();
          await alarmService.checkAndTriggerAlarms();
          _logger.i('Silent one-time alarm check completed');
        } catch (e) {
          _logger.e('Error in silent one-time check: $e');
        }
      });
      
      _logger.i('Scheduled silent one-time check in ${delay.inMinutes} minutes');
    } catch (e) {
      _logger.e('Error scheduling silent one-time check: $e');
    }
  }

  Future<void> cancelAllTasks() async {
    try {
      _foregroundTimer?.cancel();
      _logger.i('All silent background tasks cancelled');
    } catch (e) {
      _logger.e('Error cancelling silent background tasks: $e');
    }
  }

  Future<void> restartPeriodicCheck() async {
    try {
      // Restart foreground timer
      _startForegroundTimer();
      
      _logger.i('Silent background check restarted');
    } catch (e) {
      _logger.e('Error restarting silent background check: $e');
    }
  }

  void dispose() {
    _foregroundTimer?.cancel();
    _logger.i('🔇 Silent background service disposed');
  }

  /// Check if the background service is properly initialized
  Future<bool> isInitialized() async {
    return _foregroundTimer?.isActive ?? false;
  }
}