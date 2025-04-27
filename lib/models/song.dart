// lib/models/song.dart
class Song {
  final String songName;
  final String artistName;
  final String albumArtImagePath;
  final String audioPath;
  final String? album;
  final String? genre;

  Song({
    required this.songName,
    required this.artistName,
    required this.albumArtImagePath,
    required this.audioPath,
    this.album,
    this.genre,
  });
}