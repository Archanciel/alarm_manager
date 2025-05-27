import 'package:workmanager/workmanager.dart';
import 'package:logger/logger.dart';
import 'alarm_service.dart';

class BackgroundService {
  static const String _periodicTaskName = "alarm_check_task";
  final Logger _logger = Logger();

  Future<void> initialize() async {
    try {
      await Workmanager().initialize(
        callbackDispatcher,
        isInDebugMode: false,
      );
      
      // Register periodic task to check alarms every 15 minutes
      await Workmanager().registerPeriodicTask(
        "alarm_checker",
        _periodicTaskName,
        frequency: const Duration(minutes: 15),
        initialDelay: const Duration(minutes: 1),
        constraints: Constraints(
          networkType: NetworkType.not_required,
          requiresBatteryNotLow: false,
          requiresCharging: false,
          requiresDeviceIdle: false,
          requiresStorageNotLow: false,
        ),
      );
      
      _logger.i('Background service initialized');
    } catch (e) {
      _logger.e('Error initializing background service: $e');
    }
  }

  static void callbackDispatcher() {
    Workmanager().executeTask((task, inputData) async {
      final logger = Logger();
      logger.i("Background task executed: $task");
      
      try {
        final alarmService = AlarmService();
        await alarmService.checkAndTriggerAlarms();
        return Future.value(true);
      } catch (e) {
        logger.e('Error in background task: $e');
        return Future.value(false);
      }
    });
  }

  Future<void> cancelAllTasks() async {
    try {
      await Workmanager().cancelAll();
      _logger.i('All background tasks cancelled');
    } catch (e) {
      _logger.e('Error cancelling background tasks: $e');
    }
  }
}
