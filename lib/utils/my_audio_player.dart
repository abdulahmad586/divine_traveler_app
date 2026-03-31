import 'dart:async';
import 'dart:ui';

import 'package:just_audio/just_audio.dart';

class MyAudioPlayer {
  final AudioPlayer _audioPlayer = AudioPlayer();
  StreamSubscription<Duration>? _positionSubscription;
  Duration? duration;

  Function(Duration)? durationUpdate;
  Function(Object?)? handlePlaybackError;

  bool playing = false;
  bool initialisedPlayback = false;

  void Function(VoidCallback fn) setState;

  MyAudioPlayer(this.setState, {this.durationUpdate, this.handlePlaybackError});

  int get position => _audioPlayer.position.inSeconds;

  void play(String path, {int? startFrom}) async {
    try {
      duration = await _audioPlayer.setFilePath(path);
      _positionSubscription?.cancel();
      if (durationUpdate != null) {
        _positionSubscription = _audioPlayer
            .createPositionStream(
                minPeriod: const Duration(milliseconds: 500),
                maxPeriod: const Duration(milliseconds: 700))
            .listen(durationUpdate);
      }
      if (startFrom != null) {
        seekTo(startFrom);
      }
      _audioPlayer.play();
      setState(() {
        playing = true;
        initialisedPlayback = true;
      });
    } catch (e) {
      handlePlaybackError?.call(e);
    }
  }

  void pause() {
    _audioPlayer.pause();
    setState(() {
      playing = false;
    });
  }

  void resume() {
    _audioPlayer.play();
    setState(() {
      playing = true;
    });
  }

  // triggerRebuild: pass false when calling from deactivate() — deactivate()
  // can run during a parent's build phase, and calling setState() then throws
  // "setState() called during build".
  void stop({required bool Function()? isMounted, bool triggerRebuild = true}) {
    _positionSubscription?.cancel();
    _positionSubscription = null;
    _audioPlayer.stop();
    if (triggerRebuild && isMounted != null && isMounted()) {
      setState(() {
        playing = false;
        initialisedPlayback = false;
      });
    } else {
      playing = false;
      initialisedPlayback = false;
    }
  }

  void seekTo(int position) {
    _audioPlayer.seek(Duration(seconds: position));
  }

  void dispose() {
    _positionSubscription?.cancel();
    _audioPlayer.dispose();
  }
}
