// lib/services/audio_service.dart - Enhanced with 100% volume and full duration test
import 'dart:convert';

import 'package:audioplayers/audioplayers.dart';
import 'package:logger/logger.dart';
import 'package:flutter/services.dart';

class AudioService {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final Logger _logger = Logger();
  bool _isPlaying = false;
  String? _currentAlarmFile;

  // Test player management
  AudioPlayer? _testPlayer;
  bool _isTestPlaying = false;

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

  // Callback for test completion
  Function()? _onTestComplete;

  Future<void> testSound(String audioFile, {Function()? onComplete}) async {
    // Stop any existing test
    await stopTestSound();

    // Store the completion callback
    _onTestComplete = onComplete;

    // CREATE a new test player (this was missing!)
    _testPlayer = AudioPlayer();

    // Configure and play
    await _testPlayer!.setVolume(1.0);
    await _testPlayer!.play(AssetSource('sounds/$audioFile'));
    _isTestPlaying = true;

    // Listen for completion
    _testPlayer!.onPlayerComplete.listen((_) {
      // Handle completion and notify UI
    });
  }

  Future<void> stopTestSound() async {
    try {
      if (_isTestPlaying && _testPlayer != null) {
        await _testPlayer!.stop();
        _logger.i('⏹️ Stopped test sound');
      }
      _isTestPlaying = false;
      _testPlayer?.dispose();
      _testPlayer = null;
    } catch (e) {
      _logger.e('Error stopping test sound: $e');
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
      final audioFiles =
          manifestMap.keys
              .where((String key) => key.startsWith('assets/sounds/'))
              .map((String key) => key.replaceFirst('assets/sounds/', ''))
              .where(
                (String fileName) =>
                    fileName.endsWith('.mp3') ||
                    fileName.endsWith('.wav') ||
                    fileName.endsWith('.m4a') ||
                    fileName.endsWith('.aac'),
              )
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
    _audioPlayer.dispose();
    _testPlayer?.dispose();
    _isPlaying = false;
    _isTestPlaying = false;
    _currentAlarmFile = null;
    _testPlayer = null;
  }
}
