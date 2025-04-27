import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/models/song.dart';

class PlaylistProvider extends ChangeNotifier {
  //playlist of  songs
  final List<Song> _playlist = [
    //song1
    Song(
      songName: "Space Walk",
      artisName: "HoyoMix",
      albumArtImagePath: "assets/images/album_artwork_1.png",
      audioPath: "audio/Space Walk.mp3",
    ),

    //song2
    Song(
      songName: "樂園遊夢記",
      artisName: "耀佳音",
      albumArtImagePath: "assets/images/album_artwork_2.png",
      audioPath: "audio/樂園遊夢記.mp3",
    ),

    //song3
    Song(
      songName: "ABCD Walk",
      artisName: "HoyoMix",
      albumArtImagePath: "assets/images/album_artwork_1.png",
      audioPath: "audio/Space Walk.mp3",
    ),
  ];

  //current song playing index
  int? _currentSongIndex;

  //audio player
  final AudioPlayer _audioPlayer = AudioPlayer();

  //durations
  Duration _currentDuration = Duration.zero;
  Duration _totalDuration = Duration.zero;

  //construtor
  PlaylistProvider() {
    listenToDuration();
  }

  //initially not playing
  bool _isPlaying = false;

  //play song
  void play() async {
    final String path = _playlist[_currentSongIndex!].audioPath;
    await _audioPlayer.stop();
    await _audioPlayer.play(AssetSource(path)); // play the new song
    _isPlaying = true;
    notifyListeners();
  }

  //pause current song
  void pause() async {
    await _audioPlayer.pause();
    _isPlaying = false;
    notifyListeners();
  }

  //resume song
  void resume() async {
    await _audioPlayer.resume();
    _isPlaying = true;
    notifyListeners();
  }

  //pause or resume
  void pauseOrResume() async {
    if (_isPlaying) {
      pause();
    } else {
      resume();
    }
  }

  //seek to a specific position in the current song
  void seek(Duration position) async {
    await _audioPlayer.seek(position);
  }

  //play next song
  void playNextSong() {
    if (_currentSongIndex != null) {
      if (_currentSongIndex! < _playlist.length - 1) {
        //go to the next song if it's not the last song
        currentSongIndex = _currentSongIndex! + 1;
      } else {
        //if it's the last song, loop to 1st song
        currentSongIndex = 0;
      }
    }
  }

  //play pre. song
  void playPreviousSong() async {
    //if more than 2 sec have passed, restart the song
    if (_currentDuration.inSeconds > 2) {
      //if <2sec of the song, go to pre. song
      seek(Duration.zero);
    } else {
      if (_currentSongIndex! > 0) {
        currentSongIndex = _currentSongIndex! - 1;
      } else {
        //loop back to last song if it's 1st song
        currentSongIndex = _playlist.length - 1;
      }
    }
  }

  //listen to duration
  void listenToDuration() {
    //listen total duration
    _audioPlayer.onDurationChanged.listen((newDuration) {
      _totalDuration = newDuration;
      notifyListeners();
    });

    //listen current duration
    _audioPlayer.onPositionChanged.listen((newPosition) {
      _currentDuration = newPosition;
      notifyListeners();
    });

    //listen song completion
    _audioPlayer.onPlayerComplete.listen((event) {
      playNextSong();
    });
  }

  //dispose audio player

  //getters
  List<Song> get playlist => _playlist;
  int? get currentSongIndex => _currentSongIndex;
  bool get isPlaying => _isPlaying;
  Duration get currentDuration => _currentDuration;
  Duration get totalDuration => _totalDuration;

  //setters
  set currentSongIndex(int? newIndex) {
    //update song index
    _currentSongIndex = newIndex;

    if (newIndex != null) {
      play();
    }

    //update UI
    notifyListeners();
  }
}
