// lib/services/background_service.dart - Enhanced with foreground checking
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:logger/logger.dart';
import 'dart:async';
import 'alarm_service.dart';

class BackgroundService {
  static const int _periodicAlarmId = 999999;
  static const int _foregroundCheckId = 888888;
  final Logger _logger = Logger();
  Timer? _foregroundTimer;

  Future<void> initialize() async {
    try {
      // Initialize Android Alarm Manager
      await AndroidAlarmManager.initialize();
      
      // Register periodic task to check alarms every 5 minutes
      await AndroidAlarmManager.periodic(
        const Duration(minutes: 5),
        _periodicAlarmId,
        _periodicAlarmCallback,
        exact: false,
        wakeup: true,
        rescheduleOnReboot: true,
      );
      
      // Start foreground timer for immediate checking (every 30 seconds)
      _startForegroundTimer();
      
      _logger.i('Background service initialized with both background and foreground checking');
    } catch (e) {
      _logger.e('Error initializing background service: $e');
    }
  }

  void _startForegroundTimer() {
    _foregroundTimer?.cancel();
    
    _foregroundTimer = Timer.periodic(const Duration(seconds: 30), (timer) async {
      _logger.i('🔄 Foreground timer check - ${DateTime.now()}');
      
      try {
        final alarmService = AlarmService();
        await alarmService.checkAndTriggerAlarms();
      } catch (e) {
        _logger.e('Error in foreground timer: $e');
      }
    });
    
    _logger.i('Started foreground timer - checking every 30 seconds');
  }

  @pragma('vm:entry-point')
  static void _periodicAlarmCallback(int id, Map<String, dynamic>? params) async {
    final logger = Logger();
    logger.i("📱 Periodic background task executed with id: $id at ${DateTime.now()}");
    
    try {
      final alarmService = AlarmService();
      await alarmService.checkAndTriggerAlarms();
      logger.i('Periodic alarm check completed successfully');
    } catch (e) {
      logger.e('Error in periodic background task: $e');
    }
  }

  Future<void> scheduleOneTimeCheck({Duration delay = const Duration(minutes: 1)}) async {
    try {
      await AndroidAlarmManager.oneShot(
        delay,
        _foregroundCheckId,
        _oneTimeAlarmCallback,
        exact: true,
        wakeup: true,
      );
      
      _logger.i('Scheduled one-time alarm check in ${delay.inMinutes} minutes');
    } catch (e) {
      _logger.e('Error scheduling one-time check: $e');
    }
  }

  @pragma('vm:entry-point')
  static void _oneTimeAlarmCallback(int id, Map<String, dynamic>? params) async {
    final logger = Logger();
    logger.i("⏰ One-time background task executed with id: $id at ${DateTime.now()}");
    
    try {
      final alarmService = AlarmService();
      await alarmService.checkAndTriggerAlarms();
      logger.i('One-time alarm check completed successfully');
    } catch (e) {
      logger.e('Error in one-time background task: $e');
    }
  }

  Future<void> cancelAllTasks() async {
    try {
      await AndroidAlarmManager.cancel(_periodicAlarmId);
      await AndroidAlarmManager.cancel(_foregroundCheckId);
      _foregroundTimer?.cancel();
      _logger.i('All background tasks cancelled');
    } catch (e) {
      _logger.e('Error cancelling background tasks: $e');
    }
  }

  Future<void> restartPeriodicCheck() async {
    try {
      // Cancel existing periodic check
      await AndroidAlarmManager.cancel(_periodicAlarmId);
      
      // Restart periodic check
      await AndroidAlarmManager.periodic(
        const Duration(minutes: 15),
        _periodicAlarmId,
        _periodicAlarmCallback,
        exact: false,
        wakeup: true,
        rescheduleOnReboot: true,
      );
      
      // Restart foreground timer
      _startForegroundTimer();
      
      _logger.i('Periodic background check restarted');
    } catch (e) {
      _logger.e('Error restarting periodic check: $e');
    }
  }

  void dispose() {
    _foregroundTimer?.cancel();
  }

  /// Check if the background service is properly initialized
  Future<bool> isInitialized() async {
    try {
      const int testAlarmId = 777777;
      
      await AndroidAlarmManager.oneShot(
        const Duration(seconds: 1),
        testAlarmId,
        _testCallback,
        exact: false,
        wakeup: false,
      );
      
      await AndroidAlarmManager.cancel(testAlarmId);
      
      return true;
    } catch (e) {
      _logger.e('Background service not initialized: $e');
      return false;
    }
  }

  @pragma('vm:entry-point')
  static void _testCallback(int id, Map<String, dynamic>? params) {
    // This is just a test callback, does nothing
  }
}