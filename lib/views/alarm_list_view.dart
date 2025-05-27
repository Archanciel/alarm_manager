import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:logger/logger.dart';
import '../view_models/alarm_view_model.dart';
import '../models/alarm_model.dart';
import 'add_alarm_view.dart';

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
              child: Text(
                'No alarms yet. Tap + to add one!',
                style: TextStyle(color: Colors.white, fontSize: 16),
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
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  alarm.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF5C4FFF),
                  ),
                ),
                Row(
                  children: [
                    Switch(
                      value: alarm.isActive,
                      onChanged: (value) {
                        viewModel.toggleAlarmActive(alarm.id);
                      },
                      activeColor: const Color(0xFF5C4FFF),
                    ),
                    IconButton(
                      onPressed: () => _showDeleteConfirmation(context, alarm, viewModel),
                      icon: const Icon(Icons.delete, color: Colors.red),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
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
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(value),
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

  void _showDeleteConfirmation(BuildContext context, AlarmModel alarm, AlarmViewModel viewModel) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Alarm'),
        content: Text('Are you sure you want to delete "${alarm.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              viewModel.deleteAlarm(alarm.id);
              Navigator.of(context).pop();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
