import 'package:flutter/material.dart';

class Song {
  final String songName;
  final String artistName;
  final String albumArtImagePath;
  final String audioPath; // Now: Firebase Storage download URL
  final String? videoPath; // Now: Firebase Storage download URL for video
  final String? album;
  final String? genre;
  final String? lyrics;
  final String fileHash; // Keep for duplicate detection
  final Duration? duration;
  final String? firestoreId; // New: Firestore document ID for metadata

  Song({
    required this.songName,
    required this.artistName,
    required this.albumArtImagePath,
    required this.audioPath,
    this.videoPath,
    this.album,
    this.genre,
    this.lyrics,
    required this.fileHash,
    this.duration,
    this.firestoreId,
  });

  Song.empty()
      : songName = '',
        artistName = '',
        albumArtImagePath = 'assets/images/default_art.png',
        audioPath = '',
        videoPath = null,
        album = null,
        genre = null,
        lyrics = null,
        fileHash = '',
        duration = null,
        firestoreId = null;

  // New: Convert to Firestore map for saving metadata
  Map<String, dynamic> toFirestoreMap() {
    return {
      'songName': songName,
      'artistName': artistName,
      'albumArtImagePath': albumArtImagePath,
      'audioPath': audioPath, // Storage URL
      'videoPath': videoPath,
      'album': album,
      'genre': genre,
      'fileHash': fileHash,
      'duration': duration?.inMilliseconds,
      'createdAt': DateTime.now(), // Timestamp for sorting
    };
  }
}