import 'package:flutter/material.dart'; // For potential use in UI

class HistoryEntry {
  final String audioPath; // Unique identifier (matches Song.audioPath)
  final String songName;
  final String artistName;
  final String albumArtImagePath;
  final DateTime timestamp;

  HistoryEntry({
    required this.audioPath,
    required this.songName,
    required this.artistName,
    required this.albumArtImagePath,
    required this.timestamp,
  });

  // Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'audioPath': audioPath,
      'songName': songName,
      'artistName': artistName,
      'albumArtImagePath': albumArtImagePath,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  // Create from JSON
  factory HistoryEntry.fromJson(Map<String, dynamic> json) {
    return HistoryEntry(
      audioPath: json['audioPath'],
      songName: json['songName'],
      artistName: json['artistName'],
      albumArtImagePath: json['albumArtImagePath'],
      timestamp: DateTime.parse(json['timestamp']),
    );
  }
}