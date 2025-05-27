import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:logger/logger.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:workmanager/workmanager.dart';
import 'views/alarm_list_view.dart';
import 'view_models/alarm_view_model.dart';
import 'services/alarm_service.dart';
import 'services/notification_service.dart';

final Logger logger = Logger();

void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    logger.i("Background task executed: $task");
    final alarmService = AlarmService();
    await alarmService.checkAndTriggerAlarms();
    return Future.value(true);
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize background work manager
  await Workmanager().initialize(callbackDispatcher);
  
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
}

class AlarmManagerApp extends StatelessWidget {
  const AlarmManagerApp({Key? key}) : super(key: key);

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
