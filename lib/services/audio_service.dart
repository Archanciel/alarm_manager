// lib/services/audio_service.dart - Enhanced with better control
import 'package:audioplayers/audioplayers.dart';
import 'package:logger/logger.dart';

class AudioService {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final Logger _logger = Logger();
  bool _isPlaying = false;
  String? _currentAlarmFile;

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

  bool get isPlaying => _isPlaying;
  String? get currentAlarmFile => _currentAlarmFile;

  Future<void> testSound(String audioFile) async {
    try {
      _logger.i('🧪 Testing sound: $audioFile');
      
      // Create a separate player for testing to avoid interfering with active alarms
      final testPlayer = AudioPlayer();
      
      await testPlayer.setVolume(0.7); // Slightly lower volume for testing
      await testPlayer.play(AssetSource('sounds/$audioFile'));
      
      // Auto-stop test sound after 3 seconds
      Future.delayed(const Duration(seconds: 3), () {
        testPlayer.stop();
        testPlayer.dispose();
        _logger.i('✅ Test sound completed: $audioFile');
      });
      
    } catch (e) {
      _logger.e('❌ Error testing sound: $e');
    }
  }

  void dispose() {
    _audioPlayer.dispose();
    _isPlaying = false;
    _currentAlarmFile = null;
  }
}