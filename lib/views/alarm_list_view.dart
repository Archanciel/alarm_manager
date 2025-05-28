// lib/views/alarm_list_view.dart - Enhanced with auto-refresh
import 'package:alarm_manager/services/background_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:logger/logger.dart';
import 'dart:async';
import '../view_models/alarm_view_model.dart';
import '../models/alarm_model.dart';
import '../services/alarm_service.dart';
import 'add_alarm_view.dart';
import 'edit_alarm_dialog.dart';

class AlarmListView extends StatefulWidget {
  const AlarmListView({super.key});

  @override
  State<AlarmListView> createState() => _AlarmListViewState();
}

class _AlarmListViewState extends State<AlarmListView> with WidgetsBindingObserver {
  final Logger _logger = Logger();
  Timer? _refreshTimer;
  bool _isAppInForeground = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AlarmViewModel>().loadAlarms();
      _startAutoRefresh();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    switch (state) {
      case AppLifecycleState.resumed:
        _logger.i('📱 App resumed - starting auto-refresh');
        _isAppInForeground = true;
        _startAutoRefresh();
        // Immediate refresh when app comes to foreground
        context.read<AlarmViewModel>().loadAlarms();
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        _logger.i('📱 App backgrounded - stopping auto-refresh');
        _isAppInForeground = false;
        _stopAutoRefresh();
        break;
      case AppLifecycleState.hidden:
        break;
    }
  }

  void _startAutoRefresh() {
    _stopAutoRefresh(); // Cancel any existing timer
    
    if (!_isAppInForeground) return;
    
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (timer) async {
      if (!_isAppInForeground || !mounted) {
        timer.cancel();
        return;
      }
      
      _logger.i('🔄 Auto-refreshing alarm list');
      try {
        await context.read<AlarmViewModel>().loadAlarms();
      } catch (e) {
        _logger.e('Error during auto-refresh: $e');
      }
    });
    
    _logger.i('✅ Auto-refresh started (every 15 seconds)');
  }

  void _stopAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
    _logger.i('⏹️ Auto-refresh stopped');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF5C4FFF),
      appBar: AppBar(
        title: const Text(
          'Alarm Manager',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF5C4FFF),
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () async {
              _logger.i('🔄 Manual refresh triggered');
              await context.read<AlarmViewModel>().loadAlarms();
            },
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Refresh Alarms',
          ),
          IconButton(
            onPressed: _showDebugDialog,
            icon: const Icon(Icons.bug_report, color: Colors.white),
            tooltip: 'Debug Tools',
          ),
        ],
      ),
      body: Consumer<AlarmViewModel>(
        builder: (context, viewModel, child) {
          if (viewModel.isLoading) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.white),
            );
          }

          if (viewModel.alarms.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.alarm_off, size: 64, color: Colors.white70),
                  SizedBox(height: 16),
                  Text(
                    'No alarms yet',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Tap + to add your first alarm!',
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              // Auto-refresh indicator
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    Icon(
                      _refreshTimer?.isActive == true ? Icons.autorenew : Icons.pause,
                      color: Colors.white70,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _refreshTimer?.isActive == true 
                          ? 'Auto-refresh: ON (15s)'
                          : 'Auto-refresh: OFF',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'Last updated: ${_formatTime(DateTime.now())}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: viewModel.alarms.length,
                  itemBuilder: (context, index) {
                    final alarm = viewModel.alarms[index];
                    return _buildAlarmCard(context, alarm, viewModel);
                  },
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddAlarmDialog(context),
        backgroundColor: Colors.white,
        child: const Icon(Icons.add, color: Color(0xFF5C4FFF)),
      ),
    );
  }

  Widget _buildAlarmCard(
    BuildContext context,
    AlarmModel alarm,
    AlarmViewModel viewModel,
  ) {
    final now = DateTime.now();
    final isPastDue = now.isAfter(alarm.nextAlarmDateTime);
    final timeDiff = alarm.nextAlarmDateTime.difference(now);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    alarm.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF5C4FFF),
                    ),
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Switch(
                      value: alarm.isActive,
                      onChanged: (value) {
                        viewModel.toggleAlarmActive(alarm.id);
                      },
                      activeColor: const Color(0xFF5C4FFF),
                    ),
                    PopupMenuButton<String>(
                      onSelected: (value) {
                        switch (value) {
                          case 'edit':
                            _showEditAlarmDialog(context, alarm);
                            break;
                          case 'test':
                            _testAlarm(alarm);
                            break;
                          case 'refresh':
                            _refreshSingleAlarm(alarm);
                            break;
                          case 'delete':
                            _showDeleteConfirmation(context, alarm, viewModel);
                            break;
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit, color: Colors.blue),
                              SizedBox(width: 8),
                              Text('Edit'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'test',
                          child: Row(
                            children: [
                              Icon(Icons.play_arrow, color: Colors.green),
                              SizedBox(width: 8),
                              Text('Test Now'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'refresh',
                          child: Row(
                            children: [
                              Icon(Icons.refresh, color: Colors.orange),
                              SizedBox(width: 8),
                              Text('Refresh This'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete, color: Colors.red),
                              SizedBox(width: 8),
                              Text('Delete'),
                            ],
                          ),
                        ),
                      ],
                      child: const Icon(Icons.more_vert),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Time status indicator
            if (isPastDue && alarm.isActive)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.warning, color: Colors.red[700], size: 16),
                    const SizedBox(width: 4),
                    Text(
                      'OVERDUE by ${timeDiff.abs().inDays}d ${timeDiff.abs().inHours % 24}h ${timeDiff.abs().inMinutes % 60}m',
                      style: TextStyle(
                        color: Colors.red[700],
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              )
            else if (alarm.isActive)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.schedule, color: Colors.green[700], size: 16),
                    const SizedBox(width: 4),
                    Text(
                      'in ${timeDiff.inDays}d ${timeDiff.inHours % 24}h ${timeDiff.inMinutes % 60}m',
                      style: TextStyle(
                        color: Colors.green[700],
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 8),

            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  if (alarm.realAlarmDateTime != null)
                    _buildAlarmDetail(
                      'Real triggered alarm:',
                      _formatDateTime(alarm.realAlarmDateTime!),
                    ),
                  if (alarm.lastAlarmDateTime != null)
                    _buildAlarmDetail(
                      'Last set alarm:',
                      _formatDateTime(alarm.lastAlarmDateTime!),
                    ),
                  _buildAlarmDetail(
                    'Next set alarm:',
                    _formatDateTime(alarm.nextAlarmDateTime),
                    isBold: true,
                  ),
                  _buildAlarmDetail(
                    'Periodicity:',
                    alarm.periodicity.formattedString,
                  ),
                  _buildAlarmDetail('Audio file:', alarm.audioFile),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  alarm.isActive ? Icons.check_circle : Icons.cancel,
                  color: alarm.isActive ? Colors.green : Colors.red,
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  alarm.isActive ? 'Active' : 'Inactive',
                  style: TextStyle(
                    color: alarm.isActive ? Colors.green : Colors.red,
                    fontWeight: FontWeight.w500,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlarmDetail(String label, String value, {bool isBold = false}) {
    TextStyle textStyle = TextStyle(
      fontWeight: (isBold) ? FontWeight.bold : FontWeight.w500,
      fontSize: 13,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 140, child: Text(label, style: textStyle)),
          Expanded(child: Text(value, style: textStyle)),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day.toString().padLeft(2, '0')}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  String _formatTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}:${dateTime.second.toString().padLeft(2, '0')}';
  }

  void _refreshSingleAlarm(AlarmModel alarm) async {
    _logger.i('🔄 Refreshing single alarm: ${alarm.name}');
    await context.read<AlarmViewModel>().loadAlarms();
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Refreshed "${alarm.name}"'),
        backgroundColor: Colors.blue,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showAddAlarmDialog(BuildContext context) {
    showDialog(context: context, builder: (context) => const AddAlarmDialog());
  }

  void _showEditAlarmDialog(BuildContext context, AlarmModel alarm) {
    showDialog(
      context: context,
      builder: (context) => EditAlarmDialog(alarm: alarm),
    );
  }

  void _testAlarm(AlarmModel alarm) async {
    try {
      _logger.i('Testing alarm: ${alarm.name}');
      final alarmService = AlarmService();
      await alarmService.triggerAlarmNow(alarm.id);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Testing alarm "${alarm.name}"'),
          backgroundColor: Colors.green,
        ),
      );
      
      // Refresh after test to show updated fields
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          context.read<AlarmViewModel>().loadAlarms();
        }
      });
    } catch (e) {
      _logger.e('Error testing alarm: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error testing alarm: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showDeleteConfirmation(
    BuildContext context,
    AlarmModel alarm,
    AlarmViewModel viewModel,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Alarm'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to delete this alarm?'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Name: ${alarm.name}',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  Text('Next: ${_formatDateTime(alarm.nextAlarmDateTime)}'),
                  Text('Periodicity: ${alarm.periodicity.formattedString}'),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              viewModel.deleteAlarm(alarm.id);
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Alarm "${alarm.name}" deleted'),
                  backgroundColor: Colors.red,
                ),
              );
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showDebugDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Debug Tools'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.search),
              title: const Text('Check All Alarms'),
              subtitle: const Text('Manually check if any alarms should trigger'),
              onTap: () async {
                Navigator.of(context).pop();
                final alarmService = AlarmService();
                await alarmService.checkAndTriggerAlarms();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Alarm check completed - check logs'),
                    backgroundColor: Colors.blue,
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.timer),
              title: const Text('Force Trigger Overdue'),
              subtitle: const Text('Trigger all overdue alarms now'),
              onTap: () async {
                Navigator.of(context).pop();
                await _forceCheckOverdueAlarms();
              },
            ),
            ListTile(
              leading: Icon(_refreshTimer?.isActive == true ? Icons.pause : Icons.play_arrow),
              title: Text(_refreshTimer?.isActive == true ? 'Stop Auto-Refresh' : 'Start Auto-Refresh'),
              subtitle: Text('Currently: ${_refreshTimer?.isActive == true ? 'ON' : 'OFF'}'),
              onTap: () {
                Navigator.of(context).pop();
                if (_refreshTimer?.isActive == true) {
                  _stopAutoRefresh();
                } else {
                  _startAutoRefresh();
                }
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Auto-refresh ${_refreshTimer?.isActive == true ? 'started' : 'stopped'}'),
                    backgroundColor: Colors.blue,
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.info),
              title: const Text('Current Time'),
              subtitle: Text(DateTime.now().toString()),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _forceCheckOverdueAlarms() async {
    try {
      _logger.i('🔍 Force checking overdue alarms');
      final viewModel = context.read<AlarmViewModel>();
      final alarmService = AlarmService();

      final alarms = viewModel.alarms;
      final now = DateTime.now();
      int triggeredCount = 0;

      for (final alarm in alarms) {
        if (alarm.isActive && now.isAfter(alarm.nextAlarmDateTime)) {
          _logger.i('⏰ Force triggering overdue alarm: ${alarm.name}');
          await alarmService.triggerAlarmNow(alarm.id);
          triggeredCount++;
        }
      }

      // Reload alarms to show updates
      await viewModel.loadAlarms();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Triggered $triggeredCount overdue alarms'),
          backgroundColor: triggeredCount > 0 ? Colors.green : Colors.orange,
        ),
      );
    } catch (e) {
      _logger.e('Error force checking alarms: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }
}