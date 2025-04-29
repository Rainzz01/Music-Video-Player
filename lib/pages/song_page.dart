// lib/pages/song_page.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../components/neu_box.dart';
import '../models/playlist_provider.dart';
import '../models/song.dart';

class SongPage extends StatelessWidget {
  const SongPage({super.key});

  String formatTime(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PlaylistProvider>(
      builder: (context, value, child) {
        final song = value.playlist[value.currentSongIndex ?? 0];
        final recommendations = value.getRecommendations(song);

        return Scaffold(
          backgroundColor: Theme.of(context).colorScheme.surface,
          appBar: AppBar(title: Text(song.songName)),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  NeuBox(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        File(song.albumArtImagePath),
                        height: 200,
                        width: 200,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            Image.asset('assets/images/default_art.png'),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Column(
                    children: [
                      Text(
                        song.songName,
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        song.artistName,
                        style: const TextStyle(fontSize: 18),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  NeuBox(
                    child: Column(
                      children: [
                        Slider(
                          value: value.currentDuration.inSeconds.toDouble(),
                          max: value.totalDuration.inSeconds.toDouble(),
                          onChanged: (newValue) {
                            value.seek(Duration(seconds: newValue.toInt()));
                          },
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(formatTime(value.currentDuration)),
                              Text(formatTime(value.totalDuration)),
                            ],
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.skip_previous),
                              onPressed: value.playPreviousSong,
                            ),
                            IconButton(
                              icon: Icon(
                                  value.isPlaying ? Icons.pause : Icons.play_arrow),
                              onPressed: value.pauseOrResume,
                            ),
                            IconButton(
                              icon: const Icon(Icons.skip_next),
                              onPressed: value.playNextSong,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Recommended Songs',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: recommendations.length,
                      itemBuilder: (context, index) {
                        final recSong = recommendations[index];
                        return ListTile(
                          title: Text(recSong.songName),
                          subtitle: Text(recSong.artistName),
                          leading: Image.file(
                            File(recSong.albumArtImagePath),
                            width: 50,
                            height: 50,
                            errorBuilder: (context, error, stackTrace) =>
                                Image.asset('assets/images/default_art.png'),
                          ),
                          onTap: () {
                            value.currentSongIndex = value.playlist.indexOf(recSong);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}