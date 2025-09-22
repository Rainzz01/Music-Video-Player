import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../components/my_drawer.dart';
import '../components/neu_box.dart';
import '../models/history_provider.dart';
import '../models/playlist_provider.dart';
import 'song_page.dart';

class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<HistoryProvider, PlaylistProvider>(
      builder: (context, historyProvider, playlistProvider, child) {
        final history = historyProvider.history;

        return Scaffold(
          backgroundColor: Theme.of(context).colorScheme.surface,
          appBar: AppBar(
            title: const Text('P L A Y   H I S T O R Y'),
            actions: [
              IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Clear History?'),
                      content: const Text('This will remove all play history.'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () {
                            historyProvider.clearHistory();
                            Navigator.pop(context);
                          },
                          child: const Text('Clear'),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
          drawer: const MyDrawer(),
          body: history.isEmpty
              ? Center(
            child: Text(
              'No play history yet',
              style: TextStyle(color: Theme.of(context).colorScheme.inversePrimary),
            ),
          )
              : ListView.builder(
            itemCount: history.length,
            itemBuilder: (context, index) {
              final entry = history[index];
              final formattedTime = DateFormat('MMM dd, yyyy - HH:mm').format(entry.timestamp);

              return ListTile(
                leading: NeuBox(
                  child: entry.albumArtImagePath.startsWith('assets')
                      ? Image.asset(
                    entry.albumArtImagePath,
                    width: 50,
                    height: 50,
                    fit: BoxFit.cover,
                  )
                      : Image.file(
                    File(entry.albumArtImagePath),
                    key: ValueKey(entry.albumArtImagePath),
                    width: 50,
                    height: 50,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Image.asset(
                      'assets/images/default_art.png',
                      width: 50,
                      height: 50,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                title: Text(
                  entry.songName,
                  style: TextStyle(color: Theme.of(context).colorScheme.inversePrimary),
                ),
                subtitle: Text(
                  '${entry.artistName} • Played: $formattedTime',
                  style: TextStyle(color: Theme.of(context).colorScheme.secondary),
                ),
                onTap: () {
                  // Find the song in playlist and play it
                  final songIndex = playlistProvider.playlist.indexWhere(
                        (song) => song.audioPath == entry.audioPath,
                  );
                  if (songIndex != -1) {
                    playlistProvider.currentSongIndex = songIndex;
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const SongPage()),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Song not found in playlist')),
                    );
                  }
                },
              );
            },
          ),
        );
      },
    );
  }
}