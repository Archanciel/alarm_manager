// lib/services/audio_service.dart - Simplified with direct state management
import 'dart:convert';
import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:logger/logger.dart';
import 'package:flutter/services.dart';

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

  Future<void> playAlarm(String audioFile) async {
    try {
      // Stop any currently playing alarm
      await stopAlarm();

      _logger.i('🎵 Playing CUSTOM alarm sound: $audioFile');
      _currentAlarmFile = audioFile;

      // Configure audio player settings
      await _audioPlayer.setVolume(1.0); // Maximum volume

      // Play the custom sound from assets
      await _audioPlayer.play(AssetSource('sounds/$audioFile'));
      _isPlaying = true;

      _logger.i('✅ Custom alarm sound started: $audioFile');

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
      _logger.i('🧪 Testing sound at 100% volume: $audioFile');
      
      // Stop any existing test
      await stopTestSound();

      // Create a new test player
      _testPlayer = AudioPlayer();

      // Configure and play
      await _testPlayer!.setVolume(1.0); // 100% volume for testing
      await _testPlayer!.play(AssetSource('sounds/$audioFile'));
      _isTestPlaying = true;
      
      // Notify UI of state change
      _testStateController.add(_isTestPlaying);
      
      _logger.i('✅ Test sound started (full duration): $audioFile');
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

  /// Get list of available audio files from assets/sounds directory
  static Future<List<String>> getAvailableAudioFiles() async {
    final Logger logger = Logger();

    try {
      // Get the manifest which contains all assets
      final manifestContent = await rootBundle.loadString('AssetManifest.json');
      final Map<String, dynamic> manifestMap =
          jsonDecode(manifestContent) as Map<String, dynamic>;

      // Filter for sounds directory
      final audioFiles = manifestMap.keys
          .where((String key) => key.startsWith('assets/sounds/'))
          .map((String key) => key.replaceFirst('assets/sounds/', ''))
          .where((String fileName) => 
              fileName.endsWith('.mp3') ||
              fileName.endsWith('.wav') ||
              fileName.endsWith('.m4a') ||
              fileName.endsWith('.aac'))
          .toList();

      audioFiles.sort(); // Sort alphabetically

      logger.i('🎵 Found ${audioFiles.length} audio files:');
      for (final file in audioFiles) {
        logger.i('  - $file');
      }

      return audioFiles;
    } catch (e) {
      logger.e('❌ Error loading audio files from assets: $e');

      // Fallback to your known files
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