// lib/services/audio_service.dart - Enhanced with Documents directory support
import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:logger/logger.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class AudioService {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final Logger _logger = Logger();
  bool _isPlaying = false;
  String? _currentAlarmFile;

  // Test player management with stream controller for state changes
  AudioPlayer? _testPlayer;
  bool _isTestPlaying = false;
  StreamSubscription<void>? _testPlayerSubscription;
  
  // Stream controller to notify UI of test state changes
  final StreamController<bool> _testStateController = StreamController<bool>.broadcast();
  Stream<bool> get testStateStream => _testStateController.stream;

  // Documents directory path
  static const String _alarmManagerDirName = 'alarm_manager';
  String? _documentsAlarmPath;

  /// Initialize the AudioService and ensure Documents directory is set up
  Future<void> initialize() async {
    try {
      await _setupDocumentsDirectory();
      await _migrateAssetsToDocuments();
      _logger.i('✅ AudioService initialized with Documents directory support');
    } catch (e) {
      _logger.e('❌ Error initializing AudioService: $e');
    }
  }

  /// Set up the Documents/alarm_manager directory
  Future<void> _setupDocumentsDirectory() async {
    try {
      // Request permissions
      if (await Permission.storage.isDenied) {
        await Permission.storage.request();
      }
      if (await Permission.manageExternalStorage.isDenied) {
        await Permission.manageExternalStorage.request();
      }

      // Get Documents directory path
      final Directory? documentsDir = await getExternalStorageDirectory();
      if (documentsDir == null) {
        throw Exception('Could not access external storage');
      }

      // Create path: /storage/emulated/0/Documents/alarm_manager
      final String documentsPath = '/storage/emulated/0/Documents';
      _documentsAlarmPath = '$documentsPath/$_alarmManagerDirName';

      // Create directory if it doesn't exist
      final Directory alarmDir = Directory(_documentsAlarmPath!);
      if (!await alarmDir.exists()) {
        await alarmDir.create(recursive: true);
        _logger.i('📁 Created alarm_manager directory: $_documentsAlarmPath');
      } else {
        _logger.i('📁 Using existing alarm_manager directory: $_documentsAlarmPath');
      }

      // Verify directory is writable
      final testFile = File('${_documentsAlarmPath}/test_write.tmp');
      await testFile.writeAsString('test');
      await testFile.delete();
      
      _logger.i('✅ Documents directory setup complete: $_documentsAlarmPath');
    } catch (e) {
      _logger.e('❌ Error setting up Documents directory: $e');
      throw e;
    }
  }

  /// Copy audio files from assets to Documents directory (one-time migration)
  Future<void> _migrateAssetsToDocuments() async {
    try {
      if (_documentsAlarmPath == null) {
        throw Exception('Documents path not initialized');
      }

      // Get list of existing files in Documents directory
      final Directory documentsDir = Directory(_documentsAlarmPath!);
      final List<FileSystemEntity> existingFiles = await documentsDir.list().toList();
      final Set<String> existingFileNames = existingFiles
          .whereType<File>()
          .map((f) => f.path.split('/').last)
          .toSet();

      // Get asset files to copy
      final List<String> assetFiles = await _getAssetAudioFiles();
      
      _logger.i('🔄 Starting asset migration...');
      _logger.i('  - Assets to copy: ${assetFiles.length}');
      _logger.i('  - Existing files: ${existingFileNames.length}');

      int copiedCount = 0;
      int skippedCount = 0;

      for (final String assetFile in assetFiles) {
        final String targetPath = '$_documentsAlarmPath/$assetFile';
        
        if (existingFileNames.contains(assetFile)) {
          _logger.i('⏭️ Skipping existing file: $assetFile');
          skippedCount++;
          continue;
        }

        try {
          // Load asset file
          final ByteData assetData = await rootBundle.load('assets/sounds/$assetFile');
          final Uint8List bytes = assetData.buffer.asUint8List();
          
          // Write to Documents directory
          final File targetFile = File(targetPath);
          await targetFile.writeAsBytes(bytes);
          
          _logger.i('✅ Copied: $assetFile → Documents');
          copiedCount++;
        } catch (e) {
          _logger.e('❌ Error copying $assetFile: $e');
        }
      }

      _logger.i('🎵 Asset migration complete:');
      _logger.i('  - Copied: $copiedCount files');
      _logger.i('  - Skipped: $skippedCount files');
      _logger.i('  - Total available: ${copiedCount + skippedCount} files');
      
    } catch (e) {
      _logger.e('❌ Error during asset migration: $e');
    }
  }

  /// Get list of audio files from assets (for migration)
  Future<List<String>> _getAssetAudioFiles() async {
    try {
      final manifestContent = await rootBundle.loadString('AssetManifest.json');
      final Map<String, dynamic> manifestMap = jsonDecode(manifestContent);

      final audioFiles = manifestMap.keys
          .where((String key) => key.startsWith('assets/sounds/'))
          .map((String key) => key.replaceFirst('assets/sounds/', ''))
          .where((String fileName) => 
              fileName.endsWith('.mp3') ||
              fileName.endsWith('.wav') ||
              fileName.endsWith('.m4a') ||
              fileName.endsWith('.aac'))
          .toList();

      return audioFiles;
    } catch (e) {
      _logger.e('Error loading asset audio files: $e');
      return [
        'arroser la plante softer.mp3',
        'arroser la plante soft.mp3',
        'arroser la plante normal.mp3',
        'pianist_s8 softer.mp3',
        'pianist_s8 soft.mp3',
        'pianist_s8 normal.mp3',
      ];
    }
  }

  Future<void> playAlarm(String audioFile) async {
    try {
      // Stop any currently playing alarm
      await stopAlarm();

      _logger.i('🎵 Playing CUSTOM alarm sound from Documents: $audioFile');
      _currentAlarmFile = audioFile;

      // Configure audio player settings
      await _audioPlayer.setVolume(1.0); // Maximum volume

      // Play from Documents directory
      final String filePath = '$_documentsAlarmPath/$audioFile';
      await _audioPlayer.play(DeviceFileSource(filePath));
      _isPlaying = true;

      _logger.i('✅ Custom alarm sound started from Documents: $audioFile');

      // Optional: Auto-stop after 5 minutes to prevent infinite loop
      Future.delayed(const Duration(minutes: 5), () {
        if (_isPlaying && _currentAlarmFile == audioFile) {
          _logger.i('⏰ Auto-stopping alarm after 5 minutes');
          stopAlarm();
        }
      });
    } catch (e) {
      _logger.e('❌ Error playing custom alarm sound: $e');
      _isPlaying = false;
      _currentAlarmFile = null;
    }
  }

  Future<void> stopAlarm() async {
    try {
      if (_isPlaying) {
        await _audioPlayer.stop();
        _logger.i('⏹️ Stopped custom alarm sound: $_currentAlarmFile');
      }
      _isPlaying = false;
      _currentAlarmFile = null;
    } catch (e) {
      _logger.e('Error stopping alarm sound: $e');
    }
  }

  Future<void> pauseAlarm() async {
    try {
      if (_isPlaying) {
        await _audioPlayer.pause();
        _logger.i('⏸️ Paused custom alarm sound');
      }
    } catch (e) {
      _logger.e('Error pausing alarm sound: $e');
    }
  }

  Future<void> resumeAlarm() async {
    try {
      if (!_isPlaying && _currentAlarmFile != null) {
        await _audioPlayer.resume();
        _logger.i('▶️ Resumed custom alarm sound');
      }
    } catch (e) {
      _logger.e('Error resuming alarm sound: $e');
    }
  }

  Future<void> testSound(String audioFile) async {
    try {
      _logger.i('🧪 Testing sound at 100% volume from Documents: $audioFile');
      
      // Stop any existing test
      await stopTestSound();

      // Create a new test player
      _testPlayer = AudioPlayer();

      // Configure and play from Documents directory
      await _testPlayer!.setVolume(1.0); // 100% volume for testing
      final String filePath = '$_documentsAlarmPath/$audioFile';
      await _testPlayer!.play(DeviceFileSource(filePath));
      _isTestPlaying = true;
      
      // Notify UI of state change
      _testStateController.add(_isTestPlaying);
      
      _logger.i('✅ Test sound started from Documents (full duration): $audioFile');
      _logger.i('🎮 Test playing state: $_isTestPlaying');

      // Listen for completion
      _testPlayerSubscription = _testPlayer!.onPlayerComplete.listen((_) {
        _logger.i('🎵 Test sound completed naturally: $audioFile');
        _handleTestCompletion();
      });
      
      // Listen for player state changes
      _testPlayer!.onPlayerStateChanged.listen((PlayerState state) {
        _logger.i('🎵 Test player state changed: $state');
      });
      
    } catch (e) {
      _logger.e('❌ Error testing sound: $e');
      _handleTestCompletion();
    }
  }

  void _handleTestCompletion() {
    _logger.i('🧹 Handling test completion...');
    _logger.i('  - Current state: isTestPlaying=$_isTestPlaying');
    
    _isTestPlaying = false;
    _testPlayerSubscription?.cancel();
    _testPlayerSubscription = null;
    _testPlayer?.dispose();
    _testPlayer = null;
    
    // Notify UI of state change
    _testStateController.add(_isTestPlaying);
    
    _logger.i('🔔 Notified UI of test completion');
    _logger.i('🏁 Test completion handled. Final state: isTestPlaying=$_isTestPlaying');
  }

  Future<void> stopTestSound() async {
    try {
      _logger.i('⏹️ Stopping test sound manually...');
      if (_isTestPlaying && _testPlayer != null) {
        await _testPlayer!.stop();
        _logger.i('⏹️ Test sound stopped manually');
      }
      _handleTestCompletion();
    } catch (e) {
      _logger.e('Error stopping test sound: $e');
      _handleTestCompletion();
    }
  }

  /// Get list of available audio files from Documents/alarm_manager directory
  static Future<List<String>> getAvailableAudioFiles() async {
    final Logger logger = Logger();

    try {
      // Get the Documents/alarm_manager directory
      const String documentsPath = '/storage/emulated/0/Documents';
      const String alarmManagerPath = '$documentsPath/$_alarmManagerDirName';
      
      final Directory alarmDir = Directory(alarmManagerPath);
      
      if (!await alarmDir.exists()) {
        logger.w('⚠️ alarm_manager directory does not exist: $alarmManagerPath');
        return [];
      }

      // List all audio files in the directory
      final List<FileSystemEntity> entities = await alarmDir.list().toList();
      final List<String> audioFiles = entities
          .whereType<File>()
          .map((file) => file.path.split('/').last)
          .where((fileName) => 
              fileName.endsWith('.mp3') ||
              fileName.endsWith('.wav') ||
              fileName.endsWith('.m4a') ||
              fileName.endsWith('.aac'))
          .toList();

      audioFiles.sort(); // Sort alphabetically

      logger.i('🎵 Found ${audioFiles.length} audio files in Documents/alarm_manager:');
      for (final file in audioFiles) {
        logger.i('  - $file');
      }

      return audioFiles;
    } catch (e) {
      logger.e('❌ Error loading audio files from Documents: $e');
      
      // Fallback to default list
      return [
        'arroser la plante softer.mp3',
        'arroser la plante soft.mp3',
        'arroser la plante normal.mp3',
        'pianist_s8 softer.mp3',
        'pianist_s8 soft.mp3',
        'pianist_s8 normal.mp3',
      ];
    }
  }

  /// Refresh available audio files (useful after user adds new files)
  Future<List<String>> refreshAudioFiles() async {
    _logger.i('🔄 Refreshing audio files from Documents directory...');
    return await getAvailableAudioFiles();
  }

  /// Get the Documents/alarm_manager directory path
  String? get documentsAlarmPath => _documentsAlarmPath;

  /// Check if a specific audio file exists in Documents directory
  Future<bool> audioFileExists(String fileName) async {
    if (_documentsAlarmPath == null) return false;
    
    final File audioFile = File('$_documentsAlarmPath/$fileName');
    return await audioFile.exists();
  }

  /// Get file info for an audio file
  Future<Map<String, dynamic>?> getAudioFileInfo(String fileName) async {
    try {
      if (_documentsAlarmPath == null) return null;
      
      final File audioFile = File('$_documentsAlarmPath/$fileName');
      if (!await audioFile.exists()) return null;
      
      final FileStat stat = await audioFile.stat();
      return {
        'name': fileName,
        'path': audioFile.path,
        'size': stat.size,
        'modified': stat.modified,
      };
    } catch (e) {
      _logger.e('Error getting audio file info: $e');
      return null;
    }
  }

  bool get isPlaying => _isPlaying;
  bool get isTestPlaying => _isTestPlaying;
  String? get currentAlarmFile => _currentAlarmFile;

  void dispose() {
    _logger.i('🧹 Disposing AudioService...');
    _audioPlayer.dispose();
    _testPlayerSubscription?.cancel();
    _testPlayer?.dispose();
    _testStateController.close();
    _isPlaying = false;
    _isTestPlaying = false;
    _currentAlarmFile = null;
    _testPlayer = null;
    _testPlayerSubscription = null;
    _logger.i('✅ AudioService disposed');
  }
}