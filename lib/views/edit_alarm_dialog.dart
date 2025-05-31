// lib/views/edit_alarm_dialog.dart - Enhanced with Documents directory support
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:logger/logger.dart';
import 'dart:async';
import '../view_models/alarm_view_model.dart';
import '../models/alarm_model.dart';
import '../services/alarm_service.dart';
import '../services/audio_service.dart';

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
  // Add FocusNode for the name field
  final FocusNode _nameFocusNode = FocusNode();

  late TimeOfDay _selectedTime;
  late DateTime _selectedDate;
  late String _selectedAudioFile;
  List<String> _audioFiles = [];
  bool _isLoadingAudio = true;
  bool _isTestPlaying = false;
  StreamSubscription<bool>? _testStateSubscription;
  AudioService? _audioService;

  @override
  void initState() {
    super.initState();
    
    // Auto-focus and select the name field when dialog opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _nameFocusNode.requestFocus();
    });
    
    _audioService = context.read<AudioService>();
    
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
    
    // Load audio files from Documents directory
    _loadAudioFiles();
    
    // Listen to test state changes
    _testStateSubscription = _audioService!.testStateStream.listen((isPlaying) {
      _logger.i('🔄 Test state changed: $isPlaying');
      if (mounted) {
        setState(() {
          _isTestPlaying = isPlaying;
        });
      }
    });
  }

  Future<void> _loadAudioFiles() async {
    try {
      _logger.i('📂 Loading audio files from Documents/alarm_manager directory for edit...');
      final files = await AudioService.getAvailableAudioFiles();
      
      setState(() {
        _audioFiles = files;
        
        // Check if the current alarm's audio file still exists
        if (!files.contains(_selectedAudioFile)) {
          _logger.w('⚠️ Current audio file not found in Documents: $_selectedAudioFile');
          if (files.isNotEmpty) {
            _selectedAudioFile = files.first;
            _logger.i('🔄 Defaulted to first available file: $_selectedAudioFile');
          } else {
            _selectedAudioFile = '';
            _logger.w('⚠️ No audio files available');
          }
        }
        
        _isLoadingAudio = false;
      });
      
      _logger.i('✅ Loaded ${files.length} audio files from Documents for editing');
    } catch (e) {
      _logger.e('❌ Error loading audio files for edit: $e');
      setState(() {
        _audioFiles = [];
        _selectedAudioFile = '';
        _isLoadingAudio = false;
      });
    }
  }

  Future<void> _refreshAudioFiles() async {
    setState(() {
      _isLoadingAudio = true;
    });
    
    _logger.i('🔄 Refreshing audio files in edit dialog...');
    await _loadAudioFiles();
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Refreshed: ${_audioFiles.length} audio files found'),
        backgroundColor: Colors.blue,
        duration: const Duration(seconds: 2),
      ),
    );
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
                focusNode: _nameFocusNode, // Add focus node
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
                
                // Audio selection section with Documents directory support
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
                          const Icon(Icons.folder, color: Colors.orange),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Audio Files from Documents (${_audioFiles.length} found)',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                const Text(
                                  '/storage/emulated/0/Documents/alarm_manager/',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: _refreshAudioFiles,
                            icon: const Icon(Icons.refresh, color: Colors.blue),
                            tooltip: 'Refresh audio files',
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      
                      if (_audioFiles.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.orange[50],
                            border: Border.all(color: Colors.orange),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.warning, color: Colors.orange),
                                  SizedBox(width: 8),
                                  Text(
                                    'No audio files found',
                                    style: TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              SizedBox(height: 8),
                              Text(
                                '1. Add .mp3/.wav files to Documents/alarm_manager\n'
                                '2. Tap refresh button above\n'
                                '3. Select a new audio file for this alarm',
                                style: TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        )
                      else
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: _selectedAudioFile.isEmpty || !_audioFiles.contains(_selectedAudioFile) 
                                    ? null 
                                    : _selectedAudioFile,
                                decoration: InputDecoration(
                                  labelText: 'Select Audio File',
                                  border: const OutlineInputBorder(),
                                  helperText: _audioFiles.contains(widget.alarm.audioFile) 
                                      ? null 
                                      : 'Original file missing: ${widget.alarm.audioFile}',
                                  helperStyle: const TextStyle(color: Colors.orange),
                                ),
                                items: _audioFiles.map((file) {
                                  return DropdownMenuItem(
                                    value: file,
                                    child: Tooltip(
                                      message: file,
                                      child: Text(
                                        file,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: file == widget.alarm.audioFile 
                                              ? FontWeight.bold 
                                              : FontWeight.normal,
                                          color: file == widget.alarm.audioFile 
                                              ? Colors.blue 
                                              : null,
                                        ),
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
                                    _isTestPlaying ? Icons.stop : Icons.play_arrow,
                                    size: 18,
                                  ),
                                  label: const Text(''),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _isTestPlaying ? Colors.red : Colors.green,
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
          onPressed: () {
            _audioService?.stopTestSound(); // Stop any playing test
            Navigator.of(context).pop();
          },
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _audioFiles.isEmpty ? null : _saveChanges,
          child: const Text('Save Changes'),
        ),
      ],
    );
  }

  void _testAudio() async {
    try {
      if (_isTestPlaying) {
        // Stop current test
        _logger.i('⏹️ User stopping audio test in edit dialog');
        await _audioService?.stopTestSound();
      } else {
        // Start new test
        _logger.i('🧪 User starting audio test in edit dialog: $_selectedAudioFile');
        await _audioService?.testSound(_selectedAudioFile);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Testing: $_selectedAudioFile (from Documents, 100% volume)'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      _logger.e('Error testing audio in edit dialog: $e');
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
    _logger.i('Date selector tapped in edit dialog');
    
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 1)), // Allow today
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    
    if (date != null) {
      _logger.i('New date selected in edit dialog: $date');
      setState(() {
        _selectedDate = date;
      });
    } else {
      _logger.i('Date selection cancelled in edit dialog');
    }
  }

  Future<void> _selectTime() async {
    _logger.i('Time selector tapped in edit dialog');
    
    final time = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    
    if (time != null) {
      _logger.i('New time selected in edit dialog: $time');
      setState(() {
        _selectedTime = time;
      });
    } else {
      _logger.i('Time selection cancelled in edit dialog');
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year}';
  }

  void _saveChanges() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_audioFiles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No audio files available. Please add audio files to Documents/alarm_manager/'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      // Stop any test audio before saving
      _audioService?.stopTestSound();
      
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
      
      _logger.i('Alarm updated: ${updatedAlarm.name} with Documents audio: $_selectedAudioFile');
      
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Alarm "${updatedAlarm.name}" updated with Documents audio!'),
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
    _nameFocusNode.dispose();
    _testStateSubscription?.cancel();
    _audioService?.stopTestSound(); // Stop any playing test
    super.dispose();
  }
}