import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';
import 'audius_service.dart';

/// Global Audius music player — survives page navigation.
/// Like WeChat mini-program: music keeps playing when you go back to chat.
///
/// iOS: UIBackgroundModes=audio is set in Info.plist.
/// audioplayers uses AVAudioSession.playback category by default,
/// which keeps audio playing when app goes to background/lock screen.
class AudiusPlayerService extends ChangeNotifier {
  static final AudiusPlayerService instance = AudiusPlayerService._();
  AudiusPlayerService._() {
    _setupListeners();
    // Set audio context for background playback
    _player.setAudioContext(AudioContext(
      iOS: AudioContextIOS(
        category: AVAudioSessionCategory.playback,
        options: {AVAudioSessionOptions.mixWithOthers},
      ),
      android: AudioContextAndroid(
        isSpeakerphoneOn: false,
        audioMode: AndroidAudioMode.normal,
        audioFocus: AndroidAudioFocus.gain,
      ),
    ));
  }

  final AudioPlayer _player = AudioPlayer();

  // Current state
  AudiusTrack? _currentTrack;
  PlayerState _playerState = PlayerState.stopped;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  // Queue
  List<AudiusTrack> _queue = [];

  // Getters
  AudiusTrack? get currentTrack => _currentTrack;
  PlayerState get playerState => _playerState;
  bool get isPlaying => _playerState == PlayerState.playing;
  bool get hasTrack => _currentTrack != null;
  Duration get position => _position;
  Duration get duration => _duration;
  List<AudiusTrack> get queue => List.unmodifiable(_queue);

  double get progress {
    if (_duration.inMilliseconds == 0) return 0;
    return (_position.inMilliseconds / _duration.inMilliseconds).clamp(0.0, 1.0);
  }

  void _setupListeners() {
    _player.onPlayerStateChanged.listen((state) {
      _playerState = state;
      notifyListeners();
    });
    _player.onPositionChanged.listen((pos) {
      _position = pos;
      notifyListeners();
    });
    _player.onDurationChanged.listen((dur) {
      _duration = dur;
      notifyListeners();
    });
    _player.onPlayerComplete.listen((_) {
      playNext();
    });
  }

  /// Play a track (and optionally set queue)
  Future<void> play(AudiusTrack track, {List<AudiusTrack>? trackList}) async {
    try {
      if (trackList != null) _queue = List.from(trackList);

      _currentTrack = track;
      _position = Duration.zero;
      _duration = Duration.zero;
      notifyListeners();

      await _player.stop();
      await _player.play(UrlSource(track.streamUrl));
    } catch (e) {
      if (kDebugMode) print('[AudiusPlayer] Play error: $e');
    }
  }

  /// Toggle play/pause
  Future<void> togglePlayPause() async {
    if (_playerState == PlayerState.playing) {
      await _player.pause();
    } else {
      await _player.resume();
    }
  }

  /// Play next track in queue
  Future<void> playNext() async {
    if (_currentTrack == null || _queue.isEmpty) {
      _playerState = PlayerState.stopped;
      notifyListeners();
      return;
    }
    final idx = _queue.indexOf(_currentTrack!);
    if (idx >= 0 && idx < _queue.length - 1) {
      await play(_queue[idx + 1]);
    } else {
      _playerState = PlayerState.stopped;
      notifyListeners();
    }
  }

  /// Play previous track in queue
  Future<void> playPrev() async {
    if (_currentTrack == null || _queue.isEmpty) return;
    final idx = _queue.indexOf(_currentTrack!);
    if (idx > 0) {
      await play(_queue[idx - 1]);
    } else {
      // Restart current track
      await _player.seek(Duration.zero);
      await _player.resume();
    }
  }

  /// Seek to position
  Future<void> seek(Duration pos) async {
    await _player.seek(pos);
  }

  /// Stop playback
  Future<void> stop() async {
    await _player.stop();
    _currentTrack = null;
    _playerState = PlayerState.stopped;
    _position = Duration.zero;
    _duration = Duration.zero;
    notifyListeners();
  }

  /// Check if a specific track is currently playing
  bool isTrackPlaying(AudiusTrack track) =>
      _currentTrack?.id == track.id && _playerState == PlayerState.playing;

  bool isTrackActive(AudiusTrack track) => _currentTrack?.id == track.id;
}
