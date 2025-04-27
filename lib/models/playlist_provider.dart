import 'dart:io';
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:metadata_god/metadata_god.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'song.dart';

class PlaylistProvider extends ChangeNotifier {
  List<Song> _playlist = [];
  Map<String, List<Song>> _categories = {};
  int? _currentSongIndex;
  final AudioPlayer _audioPlayer = AudioPlayer();
  Duration _currentDuration = Duration.zero;
  Duration _totalDuration = Duration.zero;
  bool _isPlaying = false;
  bool _isLoading = false;
  String? _errorMessage;
  bool _metadataInitialized = false;

  PlaylistProvider() {
    _initializeMetadataGod();
    listenToDuration();
    loadLocalSongs();
  }

  // Initialize metadata_god
  Future<void> _initializeMetadataGod() async {
    try {
      await MetadataGod.initialize();
      _metadataInitialized = true;
      print('MetadataGod initialized');
    } catch (e) {
      print('Failed to initialize MetadataGod: $e');
      _errorMessage = 'Failed to initialize metadata. Using fallback.';
      _metadataInitialized = false;
      notifyListeners();
    }
  }

  // Request permissions with Android 13+ priority
  Future<bool> _requestPermissions() async {
    try {
      // Check current status
      var storageStatus = await Permission.storage.status;
      var audioStatus = await Permission.audio.status;
      var imagesStatus = await Permission.photos.status;
      var videosStatus = await Permission.videos.status;
      print('Initial storage status: $storageStatus');
      print('Initial audio status: $audioStatus');
      print('Initial images status: $imagesStatus');
      print('Initial videos status: $videosStatus');

      // Request permissions if not granted
      if (!audioStatus.isGranted) {
        audioStatus = await Permission.audio.request();
        print('Requested audio status: $audioStatus');
      }
      if (!imagesStatus.isGranted) {
        imagesStatus = await Permission.photos.request();
        print('Requested images status: $imagesStatus');
      }
      if (!videosStatus.isGranted) {
        videosStatus = await Permission.videos.request();
        print('Requested videos status: $videosStatus');
      }
      // Request storage last, as it's less critical on Android 13+
      if (!storageStatus.isGranted) {
        storageStatus = await Permission.storage.request();
        print('Requested storage status: $storageStatus');
      }

      // Check if any required permission is granted
      if (audioStatus.isGranted || imagesStatus.isGranted || videosStatus.isGranted) {
        print('At least one media permission granted');
        return true;
      }

      // Handle permanent denials
      if (audioStatus.isPermanentlyDenied ||
          imagesStatus.isPermanentlyDenied ||
          videosStatus.isPermanentlyDenied ||
          storageStatus.isPermanentlyDenied) {
        print('Permissions permanently denied');
        _errorMessage = 'Permissions permanently denied. Please enable in settings.';
        await openAppSettings();
        return false;
      }

      // Retry once
      print('Retrying permissions');
      if (!audioStatus.isGranted) {
        audioStatus = await Permission.audio.request();
        print('Retry audio status: $audioStatus');
      }
      if (!imagesStatus.isGranted) {
        imagesStatus = await Permission.photos.request();
        print('Retry images status: $imagesStatus');
      }
      if (!videosStatus.isGranted) {
        videosStatus = await Permission.videos.request();
        print('Retry videos status: $videosStatus');
      }
      if (!storageStatus.isGranted) {
        storageStatus = await Permission.storage.request();
        print('Retry storage status: $storageStatus');
      }

      if (audioStatus.isGranted || imagesStatus.isGranted || videosStatus.isGranted) {
        print('Permission granted on retry');
        return true;
      }

      print('All permissions denied');
      _errorMessage = 'Media or storage permission denied. Please enable in settings.';
      return false;
    } catch (e) {
      print('Error requesting permissions: $e');
      _errorMessage = 'Failed to request permissions: $e';
      return false;
    }
  }

  // Load songs from local storage
  Future<void> loadLocalSongs() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      if (!await _requestPermissions()) {
        _isLoading = false;
        notifyListeners();
        return;
      }

      const musicDirs = [
        '/storage/emulated/0/Music/',
        '/storage/emulated/0/Download/',
        '/storage/emulated/0/Downloads/',
        '/storage/emulated/0/DCIM/',
        '/storage/emulated/0/Documents/',
      ];
      _playlist.clear();
      _categories.clear();

      for (var dirPath in musicDirs) {
        print('Scanning directory: $dirPath');
        final directory = Directory(dirPath);
        if (await directory.exists()) {
          final files = directory.listSync(recursive: true);
          print('Found ${files.length} files in $dirPath');
          for (var file in files) {
            if (file is File && (file.path.endsWith('.mp3') || file.path.endsWith('.m4a'))) {
              try {
                print('Processing file: ${file.path}');
                Song song;
                if (_metadataInitialized) {
                  final metadata = await MetadataGod.readMetadata(file: file.path);
                  song = Song(
                    songName: metadata.title ??
                        file.path.split('/').last.replaceAll('.mp3', '').replaceAll('.m4a', ''),
                    artistName: metadata.artist ?? 'Unknown Artist',
                    albumArtImagePath: metadata.picture != null
                        ? await _saveAlbumArt(metadata.picture!, file.path)
                        : 'assets/images/default_art.png',
                    audioPath: file.path,
                    album: metadata.album ?? 'Unknown Album',
                    genre: metadata.genre ?? 'Unknown',
                  );
                } else {
                  song = Song(
                    songName: file.path.split('/').last.replaceAll('.mp3', '').replaceAll('.m4a', ''),
                    artistName: 'Unknown Artist',
                    albumArtImagePath: 'assets/images/default_art.png',
                    audioPath: file.path,
                    album: 'Unknown Album',
                    genre: 'Unknown',
                  );
                }
                _playlist.add(song);

                final genre = song.genre ?? 'Unknown';
                if (!_categories.containsKey(genre)) {
                  _categories[genre] = [];
                }
                _categories[genre]!.add(song);
                print('Added song: ${song.songName}');
              } catch (e) {
                print('Error processing file ${file.path}: $e');
              }
            }
          }
        } else {
          print('Directory $dirPath does not exist');
        }
      }
    } catch (e) {
      print('Error scanning files: $e');
      _errorMessage = 'Failed to scan files: $e';
    }

    _isLoading = false;
    notifyListeners();
    print('Scan complete. Playlist size: ${_playlist.length}');
  }

  // Save album art to local storage
  Future<String> _saveAlbumArt(Picture picture, String filePath) async {
    try {
      final dir = await getTemporaryDirectory();
      final artPath = '${dir.path}/${filePath.hashCode}.png';
      await File(artPath).writeAsBytes(picture.data);
      print('Saved album art: $artPath');
      return artPath;
    } catch (e) {
      print('Error saving album art for $filePath: $e');
      return 'assets/images/default_art.png';
    }
  }

  // Manual import via file picker
  Future<void> importSong(String path) async {
    try {
      print('Importing file: $path');
      final file = File(path);
      if (!await file.exists()) {
        print('File does not exist: $path');
        return;
      }
      Song song;
      if (_metadataInitialized) {
        final metadata = await MetadataGod.readMetadata(file: file.path);
        song = Song(
          songName: metadata.title ?? path.split('/').last.replaceAll('.mp3', '').replaceAll('.m4a', ''),
          artistName: metadata.artist ?? 'Unknown Artist',
          albumArtImagePath: metadata.picture != null
              ? await _saveAlbumArt(metadata.picture!, path)
              : 'assets/images/default_art.png',
          audioPath: path,
          album: metadata.album ?? 'Unknown Album',
          genre: metadata.genre ?? 'Unknown',
        );
      } else {
        song = Song(
          songName: path.split('/').last.replaceAll('.mp3', '').replaceAll('.m4a', ''),
          artistName: 'Unknown Artist',
          albumArtImagePath: 'assets/images/default_art.png',
          audioPath: path,
          album: 'Unknown Album',
          genre: 'Unknown',
        );
      }
      _playlist.add(song);

      final genre = song.genre ?? 'Unknown';
      if (!_categories.containsKey(genre)) {
        _categories[genre] = [];
      }
      _categories[genre]!.add(song);
      print('Imported song: ${song.songName}, Playlist size: ${_playlist.length}');
      notifyListeners();
    } catch (e) {
      print('Error importing file $path: $e');
      throw Exception('Failed to import song: $e'); // Throw to be caught in MyDrawer
    }
  }

  // Search songs
  List<Song> searchSongs(String query) {
    if (query.isEmpty) return _playlist;
    return _playlist
        .where((song) =>
    song.songName.toLowerCase().contains(query.toLowerCase()) ||
        song.artistName.toLowerCase().contains(query.toLowerCase()))
        .toList();
  }

  // Recommendations
  List<Song> getRecommendations(Song currentSong) {
    return _playlist
        .where((song) =>
    song != currentSong &&
        (song.genre == currentSong.genre || song.artistName == currentSong.artistName))
        .take(5)
        .toList();
  }

  // Getters
  List<Song> get playlist => _playlist;
  Map<String, List<Song>> get categories => _categories;
  int? get currentSongIndex => _currentSongIndex;
  bool get isPlaying => _isPlaying;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  Duration get currentDuration => _currentDuration;
  Duration get totalDuration => _totalDuration;

  // Setters
  set currentSongIndex(int? newIndex) {
    _currentSongIndex = newIndex;
    if (newIndex != null) {
      play();
    }
    notifyListeners();
  }

  // Playback methods
  void play() async {
    try {
      if (_currentSongIndex == null || _playlist.isEmpty) {
        print('No song selected or playlist is empty');
        _errorMessage = 'No song selected';
        notifyListeners();
        return;
      }
      final String path = _playlist[_currentSongIndex!].audioPath;
      print('Playing: $path');
      await _audioPlayer.stop();
      await _audioPlayer.play(DeviceFileSource(path));
      _isPlaying = true;
      notifyListeners();
    } catch (e) {
      print('Error playing song: $e');
      _errorMessage = 'Failed to play song: $e';
      notifyListeners();
    }
  }

  void pause() async {
    await _audioPlayer.pause();
    _isPlaying = false;
    notifyListeners();
  }

  void resume() async {
    await _audioPlayer.resume();
    _isPlaying = true;
    notifyListeners();
  }

  void pauseOrResume() async {
    if (_isPlaying) {
      pause();
    } else {
      resume();
    }
  }

  void seek(Duration position) async {
    await _audioPlayer.seek(position);
    notifyListeners();
  }

  void playNextSong() {
    if (_currentSongIndex != null) {
      if (_currentSongIndex! < _playlist.length - 1) {
        currentSongIndex = _currentSongIndex! + 1;
      } else {
        currentSongIndex = 0;
      }
    }
  }

  void playPreviousSong() async {
    if (_currentDuration.inSeconds > 2) {
      seek(Duration.zero);
    } else {
      if (_currentSongIndex! > 0) {
        currentSongIndex = _currentSongIndex! - 1;
      } else {
        currentSongIndex = _playlist.length - 1;
      }
    }
  }

  void listenToDuration() {
    _audioPlayer.onDurationChanged.listen((newDuration) {
      _totalDuration = newDuration;
      notifyListeners();
    });

    _audioPlayer.onPositionChanged.listen((newPosition) {
      _currentDuration = newPosition;
      notifyListeners();
    });

    _audioPlayer.onPlayerComplete.listen((event) {
      playNextSong();
    });
  }
}