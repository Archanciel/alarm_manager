// lib/main.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:logger/logger.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'views/alarm_list_view.dart';
import 'view_models/alarm_view_model.dart';
import 'services/alarm_service.dart';
import 'services/notification_service.dart';

final Logger logger = Logger();

@pragma('vm:entry-point')
void alarmCallback() {
  logger.i("Background alarm callback executed");
  final alarmService = AlarmService();
  alarmService.checkAndTriggerAlarms();
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Android alarm manager
  await AndroidAlarmManager.initialize();
  
  // Initialize notification service
  await NotificationService().initialize();
  
  // Request permissions
  await _requestPermissions();
  
  runApp(const AlarmManagerApp());
}

Future<void> _requestPermissions() async {
  await Permission.notification.request();
  await Permission.audio.request();
  await Permission.storage.request();
  await Permission.scheduleExactAlarm.request();
}

class AlarmManagerApp extends StatelessWidget {
  const AlarmManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AlarmViewModel(),
        ),
      ],
      child: MaterialApp(
        title: 'Alarm Manager',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          useMaterial3: true,
        ),
        home: const AlarmListView(),
      ),
    );
  }
}