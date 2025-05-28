import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:logger/logger.dart';
import '../view_models/alarm_view_model.dart';
import '../models/alarm_model.dart';
import '../services/alarm_service.dart';

class AddAlarmDialog extends StatefulWidget {
  const AddAlarmDialog({super.key});

  @override
  State<AddAlarmDialog> createState() => _AddAlarmDialogState();
}

class _AddAlarmDialogState extends State<AddAlarmDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _daysController = TextEditingController(text: '00');
  final _hoursController = TextEditingController(text: '00');
  final _minutesController = TextEditingController(text: '00');
  final Logger _logger = Logger();

  TimeOfDay _selectedTime = TimeOfDay.now();
  DateTime _selectedDate = DateTime.now();
  String _selectedAudioFile = 'pianist_s8 soft.mp3';

  final List<String> _audioFiles = [
    'arroser la plante softer.mp3',
    'arroser la plante soft.mp3',
    'arroser la plante normal.mp3',
    'pianist_s8 softer.mp3',
    'pianist_s8 soft.mp3',
    'pianist_s8 normal.mp3',
  ];

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add New Alarm'),
      content: SizedBox(
        width: double.maxFinite,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ListTile(
                      title: const Text('Date'),
                      subtitle: Text(_formatDate(_selectedDate)),
                      onTap: _selectDate,
                    ),
                  ),
                  Expanded(
                    child: ListTile(
                      title: const Text('Time'),
                      subtitle: Text(_selectedTime.format(context)),
                      onTap: _selectTime,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'Periodicity (dd:hh:mm)',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _daysController,
                      decoration: const InputDecoration(
                        labelText: 'Days',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      validator: _validateNumber,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _hoursController,
                      decoration: const InputDecoration(
                        labelText: 'Hours',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) => _validateNumber(value, max: 23),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _minutesController,
                      decoration: const InputDecoration(
                        labelText: 'Minutes',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) => _validateNumber(value, max: 59),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedAudioFile,
                decoration: const InputDecoration(
                  labelText: 'Audio File',
                  border: OutlineInputBorder(),
                ),
                items: _audioFiles.map((file) {
                  return DropdownMenuItem(
                    value: file,
                    child: Text(file),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedAudioFile = value!;
                  });
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _saveAlarm,
          child: const Text('Add'),
        ),
      ],
    );
  }

  String? _validateNumber(String? value, {int? max}) {
    if (value == null || value.trim().isEmpty) {
      return 'Required';
    }
    
    final number = int.tryParse(value);
    if (number == null) {
      return 'Invalid number';
    }
    
    if (number < 0) {
      return 'Must be positive';
    }
    
    if (max != null && number > max) {
      return 'Max $max';
    }
    
    return null;
  }

  Future<void> _selectDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    
    if (date != null) {
      setState(() {
        _selectedDate = date;
      });
    }
  }

  Future<void> _selectTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    
    if (time != null) {
      setState(() {
        _selectedTime = time;
      });
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year}';
  }

  void _saveAlarm() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    try {
      final periodicity = AlarmPeriodicity(
        days: int.parse(_daysController.text),
        hours: int.parse(_hoursController.text),
        minutes: int.parse(_minutesController.text),
      );

      // Combine selected date and time
      final nextAlarmDateTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime.hour,
        _selectedTime.minute,
      );

      // If the selected time is in the past, move to next occurrence
      final alarmService = AlarmService();
      final calculatedNextAlarm = alarmService.calculateNextAlarmTime(
        nextAlarmDateTime,
        periodicity,
      );

      final alarm = AlarmModel(
        name: _nameController.text.trim(),
        nextAlarmDateTime: calculatedNextAlarm,
        periodicity: periodicity,
        audioFile: _selectedAudioFile,
      );

      context.read<AlarmViewModel>().addAlarm(alarm);
      Navigator.of(context).pop();
      
      _logger.i('New alarm created: ${alarm.name}');
    } catch (e) {
      _logger.e('Error creating alarm: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error creating alarm: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _daysController.dispose();
    _hoursController.dispose();
    _minutesController.dispose();
    super.dispose();
  }
}
