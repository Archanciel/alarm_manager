// lib/main.dart - Updated with AudioService initialization
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:logger/logger.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'views/alarm_list_view.dart';
import 'view_models/alarm_view_model.dart';
import 'services/notification_service.dart';
import 'services/background_service.dart';
import 'services/audio_service.dart';

final Logger logger = Logger();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Android alarm manager
  await AndroidAlarmManager.initialize();
  
  // Request permissions first
  await _requestPermissions();
  
  // Initialize services
  await NotificationService().initialize();
  
  // Initialize audio service with Documents directory setup
  final audioService = AudioService();
  await audioService.initialize();
  
  // Initialize background service
  final backgroundService = BackgroundService();
  await backgroundService.initialize();
  
  runApp(AlarmManagerApp(
    backgroundService: backgroundService,
    audioService: audioService,
  ));
}

Future<void> _requestPermissions() async {
  // Request all necessary permissions
  final permissions = [
    Permission.notification,
    Permission.audio,
    Permission.storage,
    Permission.scheduleExactAlarm,
    Permission.manageExternalStorage, // For Documents directory access
  ];

  logger.i('📋 Requesting permissions...');
  
  for (final permission in permissions) {
    final status = await permission.request();
    logger.i('Permission ${permission.toString()}: $status');
    
    if (status.isDenied) {
      logger.w('⚠️ Permission denied: $permission');
    }
  }
  
  // Check for manage external storage specifically (Android 11+)
  if (await Permission.manageExternalStorage.isDenied) {
    logger.w('⚠️ Manage External Storage permission is required for Documents access');
    logger.i('💡 You may need to enable it manually in Settings > Apps > Your App > Permissions');
  }
  
  logger.i('✅ Permission requests completed');
}

class AlarmManagerApp extends StatelessWidget {
  final BackgroundService backgroundService;
  final AudioService audioService;
  
  const AlarmManagerApp({
    super.key, 
    required this.backgroundService,
    required this.audioService,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AlarmViewModel(),
        ),
        Provider<BackgroundService>.value(value: backgroundService),
        Provider<AudioService>.value(value: audioService),
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