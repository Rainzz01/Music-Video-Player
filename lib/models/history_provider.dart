import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../models/histroy_entry.dart';

class HistoryProvider extends ChangeNotifier {
  List<HistoryEntry> _history = [];
  static const int maxHistorySize = 50; // Limit to prevent unlimited growth

  HistoryProvider() {
    _loadHistory();
  }

  List<HistoryEntry> get history => _history;

  Future<void> _loadHistory() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/play_history.json');
      if (await file.exists()) {
        final jsonString = await file.readAsString();
        final List<dynamic> jsonList = jsonDecode(jsonString);
        _history = jsonList.map((json) => HistoryEntry.fromJson(json)).toList();
        print('Loaded play history: ${_history.length} entries');
      }
    } catch (e) {
      print('Error loading play history: $e');
    }
    notifyListeners();
  }

  Future<void> _saveHistory() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/play_history.json');
      final jsonList = _history.map((entry) => entry.toJson()).toList();
      await file.writeAsString(jsonEncode(jsonList));
      print('Saved play history: ${_history.length} entries');
    } catch (e) {
      print('Error saving play history: $e');
    }
  }

  void addToHistory(String audioPath, String songName, String artistName, String albumArtImagePath) {
    final now = DateTime.now();
    final newEntry = HistoryEntry(
      audioPath: audioPath,
      songName: songName,
      artistName: artistName,
      albumArtImagePath: albumArtImagePath,
      timestamp: now,
    );

    // Remove duplicates (if the same song was played recently, update timestamp)
    _history.removeWhere((entry) => entry.audioPath == audioPath);
    _history.insert(0, newEntry); // Add to the beginning (most recent first)

    // Trim if exceeds max size
    if (_history.length > maxHistorySize) {
      _history = _history.sublist(0, maxHistorySize);
    }

    _saveHistory();
    notifyListeners();
  }

  void clearHistory() {
    _history.clear();
    _saveHistory();
    notifyListeners();
  }
}