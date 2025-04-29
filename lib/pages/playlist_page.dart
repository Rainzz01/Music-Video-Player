import 'dart:io'; // Added import for File
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../components/neu_box.dart';
import '../models/playlist_provider.dart';
import '../models/song.dart';
import 'song_page.dart';

class PlaylistPage extends StatelessWidget {
  const PlaylistPage({super.key});

  // Show dialog to edit song metadata
  void _showEditDialog(BuildContext context, Song song) {
    final playlistProvider = Provider.of<PlaylistProvider>(context, listen: false);
    final nameController = TextEditingController(text: song.songName);
    final artistController = TextEditingController(text: song.artistName);
    final genreController = TextEditingController(text: song.genre);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Song'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Song Name'),
            ),
            TextField(
              controller: artistController,
              decoration: const InputDecoration(labelText: 'Artist'),
            ),
            TextField(
              controller: genreController,
              decoration: const InputDecoration(labelText: 'Genre'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              playlistProvider.updateSong(
                song,
                nameController.text.trim(),
                artistController.text.trim(),
                genreController.text.trim(),
              );
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PlaylistProvider>(
      builder: (context, value, child) {
        final playlist = value.playlist;
        return Scaffold(
          backgroundColor: Theme.of(context).colorScheme.surface,
          appBar: AppBar(
            title: const Text('P L A Y L I S T'),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () {
                  value.loadLocalSongs();
                },
              ),
            ],
          ),
          body: value.isLoading
              ? const Center(child: CircularProgressIndicator())
              : value.errorMessage != null
              ? Center(child: Text(value.errorMessage!))
              : playlist.isEmpty
              ? const Center(child: Text('No songs found'))
              : ListView.builder(
            itemCount: playlist.length,
            itemBuilder: (context, index) {
              final song = playlist[index];
              return ListTile(
                leading: song.albumArtImagePath.startsWith('assets')
                    ? Image.asset(song.albumArtImagePath, width: 50, height: 50)
                    : Image.file(File(song.albumArtImagePath), width: 50, height: 50),
                title: Text(
                  song.songName.length > 20
                      ? '${song.songName.substring(0, 17)}...'
                      : song.songName,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(song.artistName),
                onTap: () {
                  value.currentSongIndex = index;
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const SongPage()),
                  );
                },
                onLongPress: () => _showEditDialog(context, song),
              );
            },
          ),
        );
      },
    );
  }
}