import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:metadata_god/metadata_god.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'song.dart';

enum PlayMode { sequential, shuffle, repeat, loop }

class PlaylistProvider extends ChangeNotifier {
  List<Song> _playlist = [];
  Map<String, List<Song>> _categories = {'Favorites': []};
  int? _currentSongIndex;
  AudioPlayer? _audioPlayer;
  Duration _currentDuration = Duration.zero;
  Duration _totalDuration = Duration.zero;
  bool _isPlaying = false;
  bool _isLoading = false;
  String? _errorMessage;
  bool _metadataInitialized = false;
  List<String> _importedSongPaths = [];
  Map<String, Map<String, String>> _editedMetadata = {};
  Map<String, List<String>> _tags = {'Favorites': []};
  PlayMode _playMode = PlayMode.sequential;

  PlaylistProvider() {
    _initializeAudio();
    _initializeMetadataGod();
    _loadImportedSongs();
  }

  Future<void> _initializeAudio() async {
    try {
      print('Initializing audio player...');
      _audioPlayer = AudioPlayer();
      _audioPlayer!.positionStream.listen((position) {
        _currentDuration = position;
        notifyListeners();
      });
      _audioPlayer!.durationStream.listen((duration) {
        _totalDuration = duration ?? Duration.zero;
        notifyListeners();
      });
      _audioPlayer!.playerStateStream.listen((state) {
        _isPlaying = state.playing;
        if (state.processingState == ProcessingState.completed) {
          _playNextSong();
        }
        notifyListeners();
      });
      print('Audio player initialized successfully');
    } catch (e) {
      print('Error initializing audio: $e');
      _errorMessage = 'Failed to initialize audio: $e';
      notifyListeners();
    }
  }

  Future<void> _initializeMetadataGod() async {
    try {
      print('Initializing MetadataGod...');
      await MetadataGod.initialize();
      _metadataInitialized = true;
      print('MetadataGod initialized successfully');
    } catch (e) {
      print('Failed to initialize MetadataGod: $e');
      _errorMessage = 'Metadata extraction limited due to native library issue.';
      _metadataInitialized = false;
      notifyListeners();
    }
  }

  Future<void> _loadImportedSongs() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final songsFile = File('${directory.path}/imported_songs.json');
      if (await songsFile.exists()) {
        _importedSongPaths = List<String>.from(jsonDecode(await songsFile.readAsString()));
        print('Loaded imported songs: $_importedSongPaths');
      }
      final metadataFile = File('${directory.path}/song_metadata.json');
      if (await metadataFile.exists()) {
        final rawMetadata = jsonDecode(await metadataFile.readAsString()) as Map<String, dynamic>;
        _editedMetadata = rawMetadata.map((key, value) => MapEntry(
          key,
          (value as Map).map((k, v) => MapEntry(k, v.toString())),
        ));
        print('Loaded edited metadata: $_editedMetadata');
      }
      final tagsFile = File('${directory.path}/tags.json');
      if (await tagsFile.exists()) {
        final rawTags = jsonDecode(await tagsFile.readAsString()) as Map<String, dynamic>;
        _tags = rawTags.map((key, value) => MapEntry(key, List<String>.from(value)));
        print('Loaded tags: $_tags');
      }
      await loadLocalSongs();
    } catch (e) {
      print('Error loading imported songs: $e');
      _errorMessage = 'Failed to load imported songs';
      notifyListeners();
    }
  }

  Future<void> _saveImportedSongs() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/imported_songs.json');
      await file.writeAsString(jsonEncode(_importedSongPaths));
      print('Saved imported songs: $_importedSongPaths');
    } catch (e) {
      print('Error saving imported songs: $e');
    }
  }

  Future<void> _saveEditedMetadata() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/song_metadata.json');
      await file.writeAsString(jsonEncode(_editedMetadata));
      print('Saved edited metadata: $_editedMetadata');
    } catch (e) {
      print('Error saving edited metadata: $e');
    }
  }

  Future<void> _saveTags() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/tags.json');
      await file.writeAsString(jsonEncode(_tags));
      print('Saved tags: $_tags');
      _categories.removeWhere((key, value) => _tags.containsKey(key));
      for (var tag in _tags.keys) {
        _categories[tag] = _playlist.where((song) => _tags[tag]!.contains(song.audioPath)).toList();
      }
      notifyListeners();
    } catch (e) {
      print('Error saving tags: $e');
    }
  }

  void addTagToSong(Song song, String tag) {
    if (!_tags.containsKey(tag)) {
      _tags[tag] = [];
    }
    if (!_tags[tag]!.contains(song.audioPath)) {
      _tags[tag]!.add(song.audioPath);
      _saveTags();
    }
  }

  void removeTagFromSong(Song song, String tag) {
    if (_tags.containsKey(tag)) {
      _tags[tag]!.remove(song.audioPath);
      if (_tags[tag]!.isEmpty) {
        _tags.remove(tag);
      }
      _saveTags();
    }
  }

  bool hasTag(Song song, String tag) {
    return _tags[tag]?.contains(song.audioPath) ?? false;
  }

  void toggleFavorite(Song song) {
    if (hasTag(song, 'Favorites')) {
      removeTagFromSong(song, 'Favorites');
    } else {
      addTagToSong(song, 'Favorites');
    }
  }

  bool isFavorite(Song song) => hasTag(song, 'Favorites');

  Map<String, List<String>> get tags => _tags;

  Future<bool> _requestPermissions() async {
    try {
      print('Requesting permissions...');
      var audioStatus = await Permission.audio.status;
      var imagesStatus = await Permission.photos.status;
      var videosStatus = await Permission.videos.status;
      var notificationStatus = await Permission.notification.status;
      var storageStatus = await Permission.storage.status;
      print('Initial statuses: audio=$audioStatus, images=$imagesStatus, videos=$videosStatus, notification=$notificationStatus, storage=$storageStatus');

      if (!audioStatus.isGranted) audioStatus = await Permission.audio.request();
      if (!imagesStatus.isGranted) imagesStatus = await Permission.photos.request();
      if (!videosStatus.isGranted) videosStatus = await Permission.videos.request();
      if (!notificationStatus.isGranted) notificationStatus = await Permission.notification.request();
      if (!storageStatus.isGranted) storageStatus = await Permission.storage.request();

      if (audioStatus.isGranted || imagesStatus.isGranted || videosStatus.isGranted || notificationStatus.isGranted || storageStatus.isGranted) {
        print('At least one permission granted');
        return true;
      }

      if (audioStatus.isPermanentlyDenied || imagesStatus.isPermanentlyDenied || videosStatus.isPermanentlyDenied || notificationStatus.isPermanentlyDenied || storageStatus.isPermanentlyDenied) {
        print('Permissions permanently denied');
        _errorMessage = 'Permissions permanently denied. Please enable in settings.';
        await openAppSettings();
        return false;
      }

      print('All permissions denied');
      _errorMessage = 'Permissions denied. Please enable in settings.';
      return false;
    } catch (e) {
      print('Error requesting permissions: $e');
      _errorMessage = 'Failed to request permissions: $e';
      return false;
    }
  }

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
      _categories = {'Favorites': []};

      for (var dirPath in musicDirs) {
        print('Scanning directory: $dirPath');
        final directory = Directory(dirPath);
        if (await directory.exists()) {
          final files = directory.listSync(recursive: true);
          print('Found ${files.length} files in $dirPath');
          for (var file in files) {
            if (file is File && (file.path.endsWith('.mp3') || file.path.endsWith('.m4a'))) {
              await _addSong(file);
            }
          }
        } else {
          print('Directory $dirPath does not exist');
        }
      }

      for (var path in _importedSongPaths) {
        final file = File(path);
        if (await file.exists()) {
          await _addSong(file);
        } else {
          print('Imported file no longer exists: $path');
        }
      }

      for (var tag in _tags.keys) {
        _categories[tag] = _playlist.where((song) => _tags[tag]!.contains(song.audioPath)).toList();
      }
    } catch (e) {
      print('Error scanning files: $e');
      _errorMessage = 'Failed to scan files: $e';
    }

    _isLoading = false;
    notifyListeners();
    print('Scan complete. Playlist size: ${_playlist.length}');
  }

  Future<String> _computeFileHash(File file) async {
    try {
      final bytes = await file.readAsBytes();
      return md5.convert(bytes).toString();
    } catch (e) {
      print('Error computing hash for ${file.path}: $e');
      return '';
    }
  }

  Future<void> _addSong(File file) async {
    try {
      print('Processing file: ${file.path}');
      final fileName = file.path.split('/').last;
      final fileHash = await _computeFileHash(file);

      if (_playlist.any((s) => s.audioPath.split('/').last == fileName && s.fileHash == fileHash)) {
        print('Duplicate song detected: $fileName');
        return;
      }

      Song song;
      final path = file.path;
      if (_editedMetadata.containsKey(path)) {
        final metadata = _editedMetadata[path]!;
        song = Song(
          songName: metadata['songName'] ?? fileName.replaceAll('.mp3', '').replaceAll('.m4a', ''),
          artistName: metadata['artistName'] ?? 'Unknown Artist',
          albumArtImagePath: metadata['albumArtImagePath'] ?? 'assets/images/default_art.png',
          audioPath: path,
          album: metadata['album'] ?? 'Unknown Album',
          genre: metadata['genre'] ?? 'Unknown',
          fileHash: fileHash,
        );
      } else if (_metadataInitialized) {
        final metadata = await MetadataGod.readMetadata(file: path);
        song = Song(
          songName: metadata.title ?? fileName.replaceAll('.mp3', '').replaceAll('.m4a', ''),
          artistName: metadata.artist ?? 'Unknown Artist',
          albumArtImagePath: metadata.picture != null
              ? await _saveAlbumArt(metadata.picture!, path)
              : 'assets/images/default_art.png',
          audioPath: path,
          album: metadata.album ?? 'Unknown Album',
          genre: metadata.genre ?? 'Unknown',
          fileHash: fileHash,
        );
      } else {
        song = Song(
          songName: fileName.replaceAll('.mp3', '').replaceAll('.m4a', ''),
          artistName: 'Unknown Artist',
          albumArtImagePath: 'assets/images/default_art.png',
          audioPath: path,
          album: 'Unknown Album',
          genre: 'Unknown',
          fileHash: fileHash,
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

  Future<String> saveCustomAlbumArt(String sourcePath) async {
    try {
      final dir = await getTemporaryDirectory();
      final artPath = '${dir.path}/${sourcePath.hashCode}.png';
      await File(sourcePath).copy(artPath);
      print('Saved custom album art: $artPath');
      notifyListeners();
      return artPath;
    } catch (e) {
      print('Error saving custom album art: $e');
      return 'assets/images/default_art.png';
    }
  }

  Future<void> importSong(String path) async {
    try {
      print('Importing file: $path');
      final file = File(path);
      if (!await file.exists()) {
        print('File does not exist: $path');
        throw Exception('Selected file does not exist: $path');
      }
      final fileName = path.split('/').last;
      final fileHash = await _computeFileHash(file);

      if (_importedSongPaths.any((p) => p.split('/').last == fileName) ||
          _playlist.any((s) => s.fileHash == fileHash)) {
        print('Song already imported: $fileName');
        throw Exception('Song "$fileName" is already imported');
      }

      final directory = await getApplicationDocumentsDirectory();
      final newPath = '${directory.path}/$fileName';
      await file.copy(newPath);
      await _addSong(File(newPath));
      _importedSongPaths.add(newPath);
      await _saveImportedSongs();
      print('Imported song: $fileName, Playlist size: ${_playlist.length}');
      notifyListeners();
    } catch (e) {
      print('Error importing file $path: $e');
      throw Exception(e.toString());
    }
  }

  Future<void> updateSong(Song oldSong, String newName, String newGenre, String newArtist, String? newAlbumArtPath) async {
    final index = _playlist.indexWhere((s) => s.audioPath == oldSong.audioPath);
    if (index != -1) {
      final oldGenre = _playlist[index].genre;
      final newAlbumArt = newAlbumArtPath ?? _playlist[index].albumArtImagePath;
      _playlist[index] = Song(
        songName: newName,
        artistName: newArtist,
        albumArtImagePath: newAlbumArt,
        audioPath: _playlist[index].audioPath,
        album: _playlist[index].album ?? 'Unknown Album',
        genre: newGenre,
        fileHash: _playlist[index].fileHash,
      );
      if (oldGenre != newGenre) {
        _categories[oldGenre]?.removeWhere((s) => s.audioPath == oldSong.audioPath);
        if (_categories[oldGenre]?.isEmpty ?? false) {
          _categories.remove(oldGenre);
        }
        if (!_categories.containsKey(newGenre)) {
          _categories[newGenre] = [];
        }
        _categories[newGenre]!.add(_playlist[index]);
      }
      _editedMetadata[oldSong.audioPath] = {
        'songName': newName,
        'artistName': newArtist,
        'genre': newGenre,
        'album': _playlist[index].album ?? 'Unknown Album',
        'albumArtImagePath': newAlbumArt,
      };
      await _saveEditedMetadata();
      for (var tag in _tags.keys) {
        if (_tags[tag]!.contains(oldSong.audioPath)) {
          _categories[tag]?.removeWhere((s) => s.audioPath == oldSong.audioPath);
          _categories[tag]?.add(_playlist[index]);
        }
      }
      notifyListeners();
    }
  }

  List<Song> searchSongs(String query) {
    if (query.isEmpty) return _playlist;
    return _playlist
        .where((song) =>
    song.songName.toLowerCase().contains(query.toLowerCase()) ||
        song.artistName.toLowerCase().contains(query.toLowerCase()))
        .toList();
  }

  List<Song> getRecommendations(Song currentSong) {
    return _playlist
        .where((song) =>
    song != currentSong &&
        (song.genre == currentSong.genre || song.artistName == currentSong.artistName))
        .take(5)
        .toList();
  }

  List<Song> get playlist => _playlist;
  Map<String, List<Song>> get categories => _categories;
  int? get currentSongIndex => _currentSongIndex;
  bool get isPlaying => _isPlaying;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  Duration get currentDuration => _currentDuration;
  Duration get totalDuration => _totalDuration;
  PlayMode get playMode => _playMode;

  set currentSongIndex(int? newIndex) {
    _currentSongIndex = newIndex;
    if (newIndex != null) {
      play();
    }
    notifyListeners();
  }

  set playMode(PlayMode mode) {
    _playMode = mode;
    notifyListeners();
  }

  Future<void> play() async {
    try {
      if (_audioPlayer == null) {
        print('Audio player not initialized, attempting reinitialization...');
        await _initializeAudio();
        if (_audioPlayer == null) {
          print('Failed to reinitialize audio player');
          _errorMessage = 'Audio player initialization failed';
          notifyListeners();
          return;
        }
      }
      if (_currentSongIndex == null || _playlist.isEmpty) {
        print('No song selected or playlist is empty');
        _errorMessage = 'No song selected';
        notifyListeners();
        return;
      }
      if (!await Permission.audio.isGranted) {
        print('Audio permission not granted');
        _errorMessage = 'Audio permission required';
        await Permission.audio.request();
        if (!await Permission.audio.isGranted) {
          await openAppSettings();
          notifyListeners();
          return;
        }
      }
      final song = _playlist[_currentSongIndex!];
      print('Setting audio source: ${song.audioPath}');
      _currentDuration = Duration.zero;
      await _audioPlayer!.seek(Duration.zero);
      await _audioPlayer!.setAudioSource(
        AudioSource.uri(
          Uri.file(song.audioPath),
          tag: MediaItem(
            id: song.audioPath,
            title: song.songName,
            artist: song.artistName,
            album: song.album,
            artUri: song.albumArtImagePath.startsWith('assets')
                ? null
                : Uri.file(song.albumArtImagePath),
          ),
        ),
      );
      print('Playing: ${song.audioPath}');
      await _audioPlayer!.play();
      _isPlaying = true;
      notifyListeners();
    } catch (e) {
      print('Error playing song: $e');
      _errorMessage = 'Failed to play song: $e';
      notifyListeners();
    }
  }

  void pause() async {
    if (_audioPlayer == null) return;
    print('Pausing playback');
    await _audioPlayer!.pause();
    _isPlaying = false;
    notifyListeners();
  }

  void resume() async {
    if (_audioPlayer == null) return;
    print('Resuming playback');
    await _audioPlayer!.play();
    _isPlaying = true;
    notifyListeners();
  }

  void pauseOrResume() async {
    if (_audioPlayer == null) return;
    if (_isPlaying) {
      pause();
    } else {
      resume();
    }
  }

  void seek(Duration position) async {
    if (_audioPlayer == null) return;
    print('Seeking to: $position');
    await _audioPlayer!.seek(position);
    notifyListeners();
  }

  void _playNextSong() {
    if (_currentSongIndex == null) return;
    print('Playing next song, current mode: $_playMode');
    switch (_playMode) {
      case PlayMode.sequential:
        if (_currentSongIndex! < _playlist.length - 1) {
          currentSongIndex = _currentSongIndex! + 1;
        }
        break;
      case PlayMode.shuffle:
        currentSongIndex = Random().nextInt(_playlist.length);
        break;
      case PlayMode.repeat:
        play();
        break;
      case PlayMode.loop:
        if (_currentSongIndex! < _playlist.length - 1) {
          currentSongIndex = _currentSongIndex! + 1;
        } else {
          currentSongIndex = 0;
        }
        break;
    }
  }

  void playNextSong() {
    if (_playMode == PlayMode.repeat) {
      play();
    } else {
      _playNextSong();
    }
  }

  void playPreviousSong() async {
    if (_audioPlayer == null) return;
    if (_currentDuration.inSeconds > 2) {
      seek(Duration.zero);
    } else if (_currentSongIndex != null) {
      if (_playMode == PlayMode.shuffle) {
        currentSongIndex = Random().nextInt(_playlist.length);
      } else if (_currentSongIndex! > 0) {
        currentSongIndex = _currentSongIndex! - 1;
      } else {
        currentSongIndex = _playlist.length - 1;
      }
    }
  }
}