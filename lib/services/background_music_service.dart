import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BackgroundMusicService {
  static final AudioPlayer _audioPlayer = AudioPlayer();
  static bool _isPlaying = false;
  static bool _isMusicEnabled = true;
  static bool _isPaused = false;
  static const String _musicEnabledKey = 'music_enabled';

  static Future<void> init() async {
    await _audioPlayer.setReleaseMode(ReleaseMode.loop); // Loop the music
    await _audioPlayer.setVolume(0.8); // 80% volume

    // Load saved preference
    final prefs = await SharedPreferences.getInstance();
    _isMusicEnabled = prefs.getBool(_musicEnabledKey) ?? true;
  }

  static Future<void> play() async {
    if (!_isPlaying && _isMusicEnabled) {
      try {
        await _audioPlayer.play(AssetSource('music/bgmusic.mp3'));
        _isPlaying = true;
      } catch (e) {
        // Error playing background music
      }
    }
  }

  static Future<void> stop() async {
    await _audioPlayer.stop();
    _isPlaying = false;
    _isPaused = false;
  }

  static Future<void> pause() async {
    if (_isPlaying) {
      await _audioPlayer.pause();
      _isPaused = true;
    }
  }

  static Future<void> resume() async {
    if (_isPaused && _isMusicEnabled) {
      await _audioPlayer.resume();
      _isPaused = false;
    }
  }

  static Future<void> setVolume(double volume) async {
    await _audioPlayer.setVolume(volume); // 0.0 to 1.0
  }

  static Future<void> setMusicEnabled(bool enabled) async {
    _isMusicEnabled = enabled;

    // Save preference
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_musicEnabledKey, enabled);

    if (enabled) {
      await play();
    } else {
      await stop();
    }
  }

  static bool get isPlaying => _isPlaying;
  static bool get isMusicEnabled => _isMusicEnabled;
  static bool get isPaused => _isPaused;
}
