// lib/views/add_alarm_view.dart - With dynamic audio list and enhanced test
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:logger/logger.dart';
import '../view_models/alarm_view_model.dart';
import '../models/alarm_model.dart';
import '../services/alarm_service.dart';
import '../services/audio_service.dart';

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
  final AudioService _audioService = AudioService();

  TimeOfDay _selectedTime = TimeOfDay.now();
  DateTime _selectedDate = DateTime.now();
  String _selectedAudioFile = '';
  List<String> _audioFiles = [];
  bool _isLoadingAudio = true;

  @override
  void initState() {
    super.initState();
    _loadAudioFiles();
  }

  Future<void> _loadAudioFiles() async {
    try {
      _logger.i('📂 Loading audio files from assets/sounds directory...');
      final files = await AudioService.getAvailableAudioFiles();
      
      setState(() {
        _audioFiles = files;
        _selectedAudioFile = files.isNotEmpty ? files.first : '';
        _isLoadingAudio = false;
      });
      
      _logger.i('✅ Loaded ${files.length} audio files');
    } catch (e) {
      _logger.e('❌ Error loading audio files: $e');
      setState(() {
        _audioFiles = [
          'arroser la plante softer.mp3',
          'arroser la plante soft.mp3',
          'arroser la plante normal.mp3',
          'pianist_s8 softer.mp3',
          'pianist_s8 soft.mp3',
          'pianist_s8 normal.mp3',
        ];
        _selectedAudioFile = _audioFiles.first;
        _isLoadingAudio = false;
      });
    }
  }

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
              
              // Audio selection section
              if (_isLoadingAudio)
                const Row(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(width: 16),
                    Text('Loading audio files...'),
                  ],
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.audiotrack, color: Colors.blue),
                        const SizedBox(width: 8),
                        Text(
                          'Audio Files (${_audioFiles.length} found)',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _selectedAudioFile.isEmpty ? null : _selectedAudioFile,
                            decoration: const InputDecoration(
                              labelText: 'Select Audio File',
                              border: OutlineInputBorder(),
                            ),
                            items: _audioFiles.map((file) {
                              return DropdownMenuItem(
                                value: file,
                                child: Tooltip(
                                  message: file,
                                  child: Text(
                                    file,
                                    style: const TextStyle(fontSize: 12),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              );
                            }).toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() {
                                  _selectedAudioFile = value;
                                });
                              }
                            },
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please select an audio file';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          children: [
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: _selectedAudioFile.isEmpty ? null : _testAudio,
                              icon: Icon(
                                _audioService.isTestPlaying ? Icons.stop : Icons.play_arrow,
                                size: 18,
                              ),
                              label: Text(''),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _audioService.isTestPlaying ? Colors.red : Colors.green,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              '100% Vol',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            _audioService.stopTestSound(); // Stop any playing test
            Navigator.of(context).pop();
          },
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _saveAlarm,
          child: const Text('Add'),
        ),
      ],
    );
  }

  void _testAudio() async {
    try {
      if (_audioService.isTestPlaying) {
        // Stop current test
        await _audioService.stopTestSound();
        _logger.i('⏹️ Stopped audio test');
        setState(() {}); // Refresh button state
      } else {
        // Start new test
        _logger.i('🧪 Testing audio at 100% volume: $_selectedAudioFile');
        await _audioService.testSound(_selectedAudioFile);
        setState(() {}); // Refresh button state
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Testing: $_selectedAudioFile (100% volume, full duration)'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      _logger.e('Error testing audio: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error testing audio: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
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
      // Stop any test audio before saving
      _audioService.stopTestSound();
      
      final periodicity = AlarmPeriodicity(
        days: int.parse(_daysController.text),
        hours: int.parse(_hoursController.text),
        minutes: int.parse(_minutesController.text),
      );

      final nextAlarmDateTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime.hour,
        _selectedTime.minute,
      );

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
      
      _logger.i('New alarm created: ${alarm.name} with audio: $_selectedAudioFile');
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
    _audioService.stopTestSound(); // Stop any playing test
    _audioService.dispose();
    super.dispose();
  }
}