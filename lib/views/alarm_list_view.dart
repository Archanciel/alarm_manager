// lib/views/alarm_list_view.dart - Enhanced with debugging
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:logger/logger.dart';
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

class _AlarmListViewState extends State<AlarmListView> {
  final Logger _logger = Logger();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AlarmViewModel>().loadAlarms();
    });
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
            onPressed: () {
              context.read<AlarmViewModel>().loadAlarms();
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
                  Icon(
                    Icons.alarm_off,
                    size: 64,
                    color: Colors.white70,
                  ),
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

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: viewModel.alarms.length,
            itemBuilder: (context, index) {
              final alarm = viewModel.alarms[index];
              return _buildAlarmCard(context, alarm, viewModel);
            },
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

  Widget _buildAlarmCard(BuildContext context, AlarmModel alarm, AlarmViewModel viewModel) {
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
                      'OVERDUE by ${timeDiff.abs().inMinutes} min',
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
                      'in ${timeDiff.inHours}h ${timeDiff.inMinutes % 60}m',
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
                  _buildAlarmDetail('Next alarm:', _formatDateTime(alarm.nextAlarmDateTime)),
                  if (alarm.lastAlarmDateTime != null)
                    _buildAlarmDetail('Last alarm:', _formatDateTime(alarm.lastAlarmDateTime!)),
                  if (alarm.realAlarmDateTime != null)
                    _buildAlarmDetail('Real alarm:', _formatDateTime(alarm.realAlarmDateTime!)),
                  _buildAlarmDetail('Periodicity:', alarm.periodicity.formattedString),
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

  Widget _buildAlarmDetail(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day.toString().padLeft(2, '0')}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  void _showAddAlarmDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const AddAlarmDialog(),
    );
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

  void _showDeleteConfirmation(BuildContext context, AlarmModel alarm, AlarmViewModel viewModel) {
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
}