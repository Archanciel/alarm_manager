import 'package:audioplayers/audioplayers.dart';
import 'package:logger/logger.dart';

class AudioService {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final Logger _logger = Logger();

  Future<void> playAlarm(String audioFile) async {
    try {
      _logger.i('Playing alarm sound: $audioFile');
      await _audioPlayer.play(AssetSource('sounds/$audioFile'));
    } catch (e) {
      _logger.e('Error playing alarm sound: $e');
    }
  }

  Future<void> stopAlarm() async {
    try {
      await _audioPlayer.stop();
      _logger.i('Stopped alarm sound');
    } catch (e) {
      _logger.e('Error stopping alarm sound: $e');
    }
  }

  void dispose() {
    _audioPlayer.dispose();
  }
}
