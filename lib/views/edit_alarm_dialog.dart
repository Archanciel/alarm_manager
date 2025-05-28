// lib/views/edit_alarm_dialog.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:logger/logger.dart';
import '../view_models/alarm_view_model.dart';
import '../models/alarm_model.dart';
import '../services/alarm_service.dart';

class EditAlarmDialog extends StatefulWidget {
  final AlarmModel alarm;
  
  const EditAlarmDialog({super.key, required this.alarm});

  @override
  State<EditAlarmDialog> createState() => _EditAlarmDialogState();
}

class _EditAlarmDialogState extends State<EditAlarmDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _daysController;
  late final TextEditingController _hoursController;
  late final TextEditingController _minutesController;
  final Logger _logger = Logger();

  late TimeOfDay _selectedTime;
  late DateTime _selectedDate;
  late String _selectedAudioFile;

  final List<String> _audioFiles = [
    'alarm_default.mp3',
    'alarm_bell.mp3',
    'alarm_rooster.mp3',
    'alarm_beep.mp3',
  ];

  @override
  void initState() {
    super.initState();
    
    // Initialize controllers with current alarm values
    _nameController = TextEditingController(text: widget.alarm.name);
    _daysController = TextEditingController(text: widget.alarm.periodicity.days.toString().padLeft(2, '0'));
    _hoursController = TextEditingController(text: widget.alarm.periodicity.hours.toString().padLeft(2, '0'));
    _minutesController = TextEditingController(text: widget.alarm.periodicity.minutes.toString().padLeft(2, '0'));
    
    // Initialize date/time with current alarm values
    _selectedDate = DateTime(
      widget.alarm.nextAlarmDateTime.year,
      widget.alarm.nextAlarmDateTime.month,
      widget.alarm.nextAlarmDateTime.day,
    );
    _selectedTime = TimeOfDay(
      hour: widget.alarm.nextAlarmDateTime.hour,
      minute: widget.alarm.nextAlarmDateTime.minute,
    );
    
    _selectedAudioFile = widget.alarm.audioFile;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Alarm'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
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
                      child: InkWell(
                        onTap: _selectDate,
                        borderRadius: BorderRadius.circular(4),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Date',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _formatDate(_selectedDate),
                                style: const TextStyle(fontSize: 16),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: InkWell(
                        onTap: _selectTime,
                        borderRadius: BorderRadius.circular(4),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Time',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _selectedTime.format(context),
                                style: const TextStyle(fontSize: 16),
                              ),
                            ],
                          ),
                        ),
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
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(
                      widget.alarm.isActive ? Icons.check_circle : Icons.cancel,
                      color: widget.alarm.isActive ? Colors.green : Colors.red,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Status: ${widget.alarm.isActive ? 'Active' : 'Inactive'}',
                      style: TextStyle(
                        color: widget.alarm.isActive ? Colors.green : Colors.red,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _saveChanges,
          child: const Text('Save Changes'),
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
    _logger.i('Date selector tapped');
    
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 1)), // Allow today
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    
    if (date != null) {
      _logger.i('New date selected: $date');
      setState(() {
        _selectedDate = date;
      });
    } else {
      _logger.i('Date selection cancelled');
    }
  }

  Future<void> _selectTime() async {
    _logger.i('Time selector tapped');
    
    final time = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    
    if (time != null) {
      _logger.i('New time selected: $time');
      setState(() {
        _selectedTime = time;
      });
    } else {
      _logger.i('Time selection cancelled');
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year}';
  }

  void _saveChanges() {
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

      final updatedAlarm = widget.alarm.copyWith(
        name: _nameController.text.trim(),
        nextAlarmDateTime: calculatedNextAlarm,
        periodicity: periodicity,
        audioFile: _selectedAudioFile,
      );

      context.read<AlarmViewModel>().updateAlarm(updatedAlarm);
      Navigator.of(context).pop();
      
      _logger.i('Alarm updated: ${updatedAlarm.name}');
      
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Alarm "${updatedAlarm.name}" updated successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      _logger.e('Error updating alarm: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating alarm: $e'),
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