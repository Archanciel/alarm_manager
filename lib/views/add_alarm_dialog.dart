// lib/views/add_alarm_dialog.dart - Enhanced with Documents directory support
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:logger/logger.dart';
import 'dart:async';
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
  
  // Add FocusNode for the name field
  final FocusNode _nameFocusNode = FocusNode();

  TimeOfDay _selectedTime = TimeOfDay.now();
  DateTime _selectedDate = DateTime.now();
  String _selectedAudioFile = '';
  List<String> _audioFiles = [];
  bool _isLoadingAudio = true;
  bool _isTestPlaying = false;
  StreamSubscription<bool>? _testStateSubscription;
  AudioService? _audioService;

  @override
  void initState() {
    super.initState();
    _audioService = context.read<AudioService>();
    _loadAudioFiles();
    
    // Auto-focus and select the name field when dialog opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _nameFocusNode.requestFocus();
    });
    
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
      _logger.i('📂 Loading audio files from Documents/alarm_manager directory...');
      final files = await AudioService.getAvailableAudioFiles();
      
      setState(() {
        _audioFiles = files;
        _selectedAudioFile = files.isNotEmpty ? files.first : '';
        _isLoadingAudio = false;
      });
      
      _logger.i('✅ Loaded ${files.length} audio files from Documents');
    } catch (e) {
      _logger.e('❌ Error loading audio files: $e');
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
    
    _logger.i('🔄 Refreshing audio files...');
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
                focusNode: _nameFocusNode, // Add focus node
                decoration: const InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(),
                  hintText: 'Enter alarm name', // Add helpful hint
                ),
                textInputAction: TextInputAction.next, // Show "Next" button on keyboard
                onFieldSubmitted: (_) {
                  // Move focus to next logical field (could be time/date)
                  FocusScope.of(context).nextFocus();
                },
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
              
              // Audio selection section with Documents info
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
                              '1. Check if Documents/alarm_manager directory exists\n'
                              '2. Place .mp3/.wav files in that directory\n'
                              '3. Tap refresh button above',
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
                      
                    // Instructions for adding custom audio files
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        border: Border.all(color: Colors.blue.shade200),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.info, color: Colors.blue, size: 16),
                              SizedBox(width: 4),
                              Text(
                                'Add Your Own Audio Files:',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: Colors.blue,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 4),
                          Text(
                            '• Copy .mp3/.wav files to Documents/alarm_manager/\n'
                            '• Use file manager or connect via USB\n'
                            '• Tap refresh button to see new files',
                            style: TextStyle(fontSize: 11, color: Colors.blue),
                          ),
                        ],
                      ),
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
            _audioService?.stopTestSound(); // Stop any playing test
            Navigator.of(context).pop();
          },
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _audioFiles.isEmpty ? null : _saveAlarm,
          child: const Text('Add'),
        ),
      ],
    );
  }

  void _testAudio() async {
    try {
      if (_isTestPlaying) {
        // Stop current test
        _logger.i('⏹️ User stopping audio test');
        await _audioService?.stopTestSound();
      } else {
        // Start new test
        _logger.i('🧪 User starting audio test from Documents: $_selectedAudioFile');
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
      
      _logger.i('New alarm created: ${alarm.name} with Documents audio: $_selectedAudioFile');
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Alarm "${alarm.name}" created with Documents audio!'),
          backgroundColor: Colors.green,
        ),
      );
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
    _nameFocusNode.dispose(); // Dispose focus node
    _testStateSubscription?.cancel();
    _audioService?.stopTestSound(); // Stop any playing test
    super.dispose();
  }
}