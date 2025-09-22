import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:metadata_god/metadata_god.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:video_player/video_player.dart';
import 'package:ffmpeg_kit_flutter_new/ffprobe_kit.dart';
import 'history_provider.dart';
import '../services/cloud_storage_service.dart';
import '../models/song.dart';

enum PlayMode { sequential, shuffle, repeat, loop }
enum PlaybackMode { audio, video }

class PlaylistProvider extends ChangeNotifier {
  List<Song> _playlist = [];
  Map<String, List<Song>> _categories = {'Favorites': []};
  int? _currentSongIndex;
  AudioPlayer? _audioPlayer;
  VideoPlayerController? _videoPlayerController;
  PlaybackMode _playbackMode = PlaybackMode.audio;
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
  final HistoryProvider historyProvider;
  final CloudStorageService _cloudService = CloudStorageService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  PlaylistProvider({required this.historyProvider}) {
    _initializeAudio();
    _initializeMetadataGod();
    _loadImportedSongs();
  }

  Future<void> _initializeAudio() async {
    try {
      print('Initializing audio player...');
      _audioPlayer = AudioPlayer();
      _audioPlayer!.positionStream.listen((position) {
        if (_playbackMode == PlaybackMode.audio) {
          final maxDuration = _totalDuration.inSeconds > 0 ? _totalDuration : Duration(seconds: 1);
          _currentDuration = position.inSeconds > maxDuration.inSeconds
              ? maxDuration
              : position.inSeconds < 0
              ? Duration.zero
              : position;
          notifyListeners();
        }
      });
      _audioPlayer!.playerStateStream.listen((state) {
        if (_playbackMode == PlaybackMode.audio) {
          _isPlaying = state.playing;
          if (state.processingState == ProcessingState.completed) {
            _playNextSong();
          }
          notifyListeners();
        }
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
      await loadSongsFromCloud();
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

  void createPlaylist(String playlistName) {
    if (!_tags.containsKey(playlistName)) {
      _tags[playlistName] = [];
      _categories[playlistName] = [];
      _saveTags();
      notifyListeners();
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
      print('Initial statuses: audio=$audioStatus, images=$imagesStatus, videos=$videosStatus, notification=$notificationStatus');

      if (!audioStatus.isGranted) audioStatus = await Permission.audio.request();
      if (!imagesStatus.isGranted) imagesStatus = await Permission.photos.request();
      if (!videosStatus.isGranted) videosStatus = await Permission.videos.request();
      if (!notificationStatus.isGranted) notificationStatus = await Permission.notification.request();

      if (audioStatus.isGranted || imagesStatus.isGranted || videosStatus.isGranted || notificationStatus.isGranted) {
        print('At least one permission granted');
        return true;
      }

      if (audioStatus.isPermanentlyDenied || imagesStatus.isPermanentlyDenied || videosStatus.isPermanentlyDenied || notificationStatus.isPermanentlyDenied) {
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

  Future<void> loadSongsFromCloud() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      if (_auth.currentUser == null) {
        await _auth.signInAnonymously();
      }
      _playlist = await _cloudService.fetchSongsFromCloud();
      _categories = {'Favorites': []};

      for (var tag in _tags.keys) {
        _categories[tag] = _playlist.where((song) => _tags[tag]!.contains(song.audioPath)).toList();
      }
    } catch (e) {
      print('Error loading songs from cloud: $e');
      _errorMessage = 'Failed to load songs from cloud: $e';
    }

    _isLoading = false;
    notifyListeners();
    print('Cloud load complete. Playlist size: ${_playlist.length}');
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

  Future<Map<String, dynamic>> getMediaMetadata(String filePath) async {
    try {
      final session = await FFprobeKit.getMediaInformation(filePath);
      final information = await session.getMediaInformation();

      if (information == null) {
        print('Error extracting metadata with FFprobe for $filePath');
        return {'error': 'Failed to extract metadata using FFprobe'};
      }

      Map<String, dynamic> metadata = {};
      final streams = information.getStreams() ?? [];

      for (var stream in streams) {
        String? codecType = stream.getStringProperty('codec_type');

        if (codecType == 'video') {
          metadata['video'] = {
            'time_base': stream.getStringProperty('time_base') ?? 'N/A',
            'duration_ts': stream.getNumberProperty('duration_ts') ?? 'N/A',
            'r_frame_rate': stream.getStringProperty('r_frame_rate') ?? 'N/A',
            'avg_frame_rate': stream.getStringProperty('avg_frame_rate') ?? 'N/A',
            'start_pts': stream.getNumberProperty('start_pts') ?? 'N/A',
            'duration': information.getDuration() ?? 0.0,
          };
        } else if (codecType == 'audio') {
          metadata['audio'] = {
            'time_base': stream.getStringProperty('time_base') ?? 'N/A',
            'duration_ts': stream.getNumberProperty('duration_ts') ?? 'N/A',
            'sample_rate': stream.getStringProperty('sample_rate') ?? 'N/A',
            'duration': information.getDuration() ?? 0.0,
          };
        }
      }

      metadata['overall_duration'] = information.getDuration() ?? 0.0;

      print('Extracted metadata for $filePath: $metadata');
      return metadata;
    } catch (e) {
      print('Error extracting metadata with FFprobe for $filePath: $e');
      return {'error': 'Failed to extract metadata: $e'};
    }
  }

  Future<void> _addSong(File file, {bool isVideo = false}) async {
    try {
      print('Processing file for cloud: ${file.path}');
      final fileName = file.path.split('/').last;
      final fileHash = await _computeFileHash(file);

      if (_playlist.any((s) => s.fileHash == fileHash)) {
        print('Duplicate file detected: $fileName');
        return;
      }

      final uploadResult = await _cloudService.uploadFile(file, fileName, isVideo);

      Song song;
      if (_editedMetadata.containsKey(uploadResult['downloadUrl'])) {
        final metadata = _editedMetadata[uploadResult['downloadUrl']]!;
        song = Song(
          songName: (metadata['songName'] as String?) ?? uploadResult['songName'],
          artistName: (metadata['artistName'] as String?) ?? uploadResult['artistName'],
          albumArtImagePath: (metadata['albumArtImagePath'] as String?) ?? 'assets/images/default_art.png',
          audioPath: uploadResult['downloadUrl'],
          videoPath: isVideo ? uploadResult['downloadUrl'] : null,
          album: (metadata['album'] as String?) ?? 'Unknown Album',
          genre: (metadata['genre'] as String?) ?? uploadResult['genre'],
          fileHash: fileHash,
          duration: uploadResult['duration'],
          firestoreId: uploadResult['firestoreId'],
        );
      } else {
        song = Song(
          songName: uploadResult['songName'],
          artistName: uploadResult['artistName'],
          albumArtImagePath: 'assets/images/default_art.png',
          audioPath: uploadResult['downloadUrl'],
          videoPath: isVideo ? uploadResult['downloadUrl'] : null,
          album: 'Unknown Album',
          genre: uploadResult['genre'],
          fileHash: fileHash,
          duration: uploadResult['duration'],
          firestoreId: uploadResult['firestoreId'],
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
      throw e;
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
      print('Importing file to cloud: $path');
      final file = File(path);
      if (!await file.exists()) {
        print('File does not exist: $path');
        throw Exception('Selected file does not exist: $path');
      }
      final fileHash = await _computeFileHash(file);

      if (_playlist.any((s) => s.fileHash == fileHash)) {
        print('Song already imported: $path');
        throw Exception('Song with identical content already imported');
      }

      final isVideo = path.endsWith('.mp4');
      await _addSong(file, isVideo: isVideo);
      _importedSongPaths.add(path);
      await _saveImportedSongs();
      print('Imported song to cloud: ${path.split('/').last}, Playlist size: ${_playlist.length}');
      notifyListeners();
    } catch (e) {
      print('Error importing file $path: $e');
      _errorMessage = 'Failed to import file: $e';
      notifyListeners();
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
        videoPath: _playlist[index].videoPath,
        album: _playlist[index].album ?? 'Unknown Album',
        genre: newGenre,
        fileHash: _playlist[index].fileHash,
        duration: _playlist[index].duration,
        firestoreId: _playlist[index].firestoreId,
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
      if (_playlist[index].firestoreId != null) {
        await _firestore.collection('songs').doc(_playlist[index].firestoreId).update({
          'songName': newName,
          'artistName': newArtist,
          'genre': newGenre,
          'album': _playlist[index].album,
          'albumArtImagePath': newAlbumArt,
        });
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
  PlaybackMode get playbackMode => _playbackMode;
  VideoPlayerController? get videoPlayerController => _videoPlayerController;

  set currentSongIndex(int? newIndex) {
    _currentSongIndex = newIndex;
    if (_videoPlayerController != null) {
      _videoPlayerController!.dispose();
      _videoPlayerController = null;
    }
    if (_audioPlayer != null) {
      _audioPlayer!.pause();
      _audioPlayer!.stop();
    }
    _currentDuration = Duration.zero;
    _totalDuration = Duration.zero;
    _errorMessage = null;
    if (newIndex != null) {
      final song = _playlist[newIndex];
      if (_playbackMode == PlaybackMode.video && song.videoPath == null) {
        _playbackMode = PlaybackMode.audio;
      }
      _totalDuration = song.duration ?? Duration(seconds: 1);
      play();
    }
    notifyListeners();
  }

  set playMode(PlayMode mode) {
    _playMode = mode;
    notifyListeners();
  }

  set playbackMode(PlaybackMode mode) {
    if (_playbackMode != mode) {
      Duration tempProgress = _currentDuration;
      _playbackMode = mode;
      _isPlaying = false;
      if (_currentSongIndex != null) {
        final song = _playlist[_currentSongIndex!];
        _totalDuration = song.duration ?? Duration.zero;
        if (_totalDuration == Duration.zero) {
          _totalDuration = Duration(seconds: 1);
        }
        if (_audioPlayer != null) {
          _audioPlayer!.pause();
          _audioPlayer!.stop();
        }
        if (mode == PlaybackMode.video && song.videoPath != null) {
          _initializeVideo(song.videoPath!, seekTo: tempProgress);
        } else {
          disposeVideoPlayer();
          _audioPlayer!.setAudioSource(
            AudioSource.uri(
              Uri.parse(song.audioPath),
              tag: MediaItem(
                id: song.audioPath,
                title: song.songName,
                artist: song.artistName,
                album: song.album,
                artUri: song.albumArtImagePath.startsWith('assets')
                    ? null
                    : Uri.parse(song.albumArtImagePath),
              ),
            ),
          );
          if (tempProgress.inSeconds <= _totalDuration.inSeconds) {
            _audioPlayer!.seek(tempProgress);
          }
          if (_isPlaying) {
            _audioPlayer!.play();
          }
        }
      }
      _errorMessage = null;
      notifyListeners();
    }
  }

  Future<void> _initializeVideo(String videoPath, {Duration? seekTo}) async {
    try {
      print('Initializing video player for: $videoPath');
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();
      if (_videoPlayerController != null) {
        await _videoPlayerController!.dispose();
        _videoPlayerController = null;
      }
      _videoPlayerController = VideoPlayerController.network(videoPath);
      await _videoPlayerController!.initialize();
      final song = _playlist[_currentSongIndex!];
      _totalDuration = song.duration ?? _videoPlayerController!.value.duration;
      if (_totalDuration.inSeconds == 0) {
        _totalDuration = Duration(seconds: 1);
      }
      if (seekTo != null && seekTo.inSeconds <= _totalDuration.inSeconds) {
        _videoPlayerController!.seekTo(seekTo);
        _currentDuration = seekTo;
        notifyListeners();
      }
      _videoPlayerController!.addListener(() {
        if (_playbackMode == PlaybackMode.video && _videoPlayerController != null) {
          if (_videoPlayerController!.value.isInitialized) {
            final position = _videoPlayerController!.value.position;
            final maxDuration = _totalDuration.inSeconds > 0 ? _totalDuration : Duration(seconds: 1);
            _currentDuration = position.inSeconds > maxDuration.inSeconds
                ? maxDuration
                : position.inSeconds < 0
                ? Duration.zero
                : position;
            _isPlaying = _videoPlayerController!.value.isPlaying;
            if (_currentDuration >= _totalDuration && _totalDuration.inSeconds > 0) {
              _playNextSong();
            }
            notifyListeners();
          }
        }
      });
      if (_isPlaying) {
        await _videoPlayerController!.play();
      }
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      print('Error initializing video: $e');
      _errorMessage = 'Failed to initialize video. Ensure the file is a supported MP4 (H.264/AAC): $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  void disposeVideoPlayer() {
    if (_videoPlayerController != null) {
      _videoPlayerController!.dispose();
      _videoPlayerController = null;
      _isLoading = false;
      _errorMessage = null;
      notifyListeners();
    }
  }

  Future<void> playVideo() async {
    if (_videoPlayerController != null && _currentSongIndex != null) {
      final song = _playlist[_currentSongIndex!];
      if (song.videoPath != null && _videoPlayerController!.value.isInitialized) {
        if (_currentDuration.inSeconds <= _totalDuration.inSeconds) {
          _videoPlayerController!.seekTo(_currentDuration);
          _currentDuration = _currentDuration;
        }
        await _videoPlayerController!.play();
        _isPlaying = true;
        _errorMessage = null;
        historyProvider.addToHistory(
          song.audioPath,
          song.songName,
          song.artistName,
          song.albumArtImagePath,
        );
        notifyListeners();
      }
    }
  }

  Future<void> pauseVideo() async {
    if (_videoPlayerController != null && _videoPlayerController!.value.isInitialized) {
      await _videoPlayerController!.pause();
      _isPlaying = false;
      notifyListeners();
    }
  }

  Future<void> seekVideo(Duration position) async {
    if (_videoPlayerController != null && _videoPlayerController!.value.isInitialized) {
      if (position.inSeconds <= _totalDuration.inSeconds) {
        _videoPlayerController!.seekTo(position);
        _currentDuration = position;
        notifyListeners();
      }
    }
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
      _totalDuration = song.duration ?? Duration.zero;
      if (_totalDuration == Duration.zero) {
        _totalDuration = Duration(seconds: 1);
      }
      print('Setting media source: ${song.audioPath}');
      if (_playbackMode == PlaybackMode.video && song.videoPath != null) {
        await _initializeVideo(song.videoPath!, seekTo: _currentDuration);
      } else {
        disposeVideoPlayer();
        await _audioPlayer!.setAudioSource(
          AudioSource.uri(
            Uri.parse(song.audioPath),
            tag: MediaItem(
              id: song.audioPath,
              title: song.songName,
              artist: song.artistName,
              album: song.album,
              artUri: song.albumArtImagePath.startsWith('assets')
                  ? null
                  : Uri.parse(song.albumArtImagePath),
            ),
          ),
        );
        if (_currentDuration.inSeconds <= _totalDuration.inSeconds) {
          await _audioPlayer!.seek(_currentDuration);
        }
        print('Playing audio: ${song.audioPath}');
        await _audioPlayer!.play();
        _isPlaying = true;
        _errorMessage = null;
        historyProvider.addToHistory(
          song.audioPath,
          song.songName,
          song.artistName,
          song.albumArtImagePath,
        );
        notifyListeners();
      }
    } catch (e) {
      print('Error playing media: $e');
      _errorMessage = 'Failed to play media: $e';
      notifyListeners();
    }
  }

  Future<void> pause() async {
    if (_audioPlayer == null) return;
    print('Pausing audio playback');
    await _audioPlayer!.pause();
    _isPlaying = false;
    notifyListeners();
  }

  Future<void> resume() async {
    if (_audioPlayer == null) return;
    print('Resuming audio playback');
    if (_currentDuration.inSeconds <= _totalDuration.inSeconds) {
      await _audioPlayer!.seek(_currentDuration);
    }
    await _audioPlayer!.play();
    _isPlaying = true;
    _errorMessage = null;
    notifyListeners();
  }

  void pauseOrResume() async {
    if (_playbackMode == PlaybackMode.video && _videoPlayerController != null && _videoPlayerController!.value.isInitialized) {
      if (_isPlaying) {
        await pauseVideo();
      } else {
        await playVideo();
      }
    } else {
      if (_audioPlayer == null) return;
      if (_isPlaying) {
        await pause();
      } else {
        await resume();
      }
    }
  }

  void seek(Duration position) async {
    if (position.inSeconds <= _totalDuration.inSeconds) {
      _currentDuration = position;
      if (_playbackMode == PlaybackMode.video && _videoPlayerController != null && _videoPlayerController!.value.isInitialized) {
        await seekVideo(position);
      } else if (_audioPlayer != null) {
        print('Seeking audio to: $position');
        bool wasPlaying = _isPlaying;
        if (wasPlaying) {
          await _audioPlayer!.pause();
        }
        await _audioPlayer!.seek(position);
        if (wasPlaying) {
          await _audioPlayer!.play();
        }
      }
      notifyListeners();
    }
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
    if (_currentSongIndex == null) return;
    if (_currentDuration.inSeconds > 2) {
      seek(Duration.zero);
    } else {
      if (_playMode == PlayMode.shuffle) {
        currentSongIndex = Random().nextInt(_playlist.length);
      } else if (_currentSongIndex! > 0) {
        currentSongIndex = _currentSongIndex! - 1;
      } else {
        currentSongIndex = _playlist.length - 1;
      }
    }
  }

  @override
  void dispose() {
    _audioPlayer?.dispose();
    _videoPlayerController?.dispose();
    super.dispose();
  }
}