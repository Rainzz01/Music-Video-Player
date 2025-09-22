import 'dart:io';
import 'package:flutter/material.dart';
import 'package:marquee/marquee.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_application_1/models/playlist_provider.dart';
import 'package:flutter_application_1/pages/playlist_page.dart';
import 'package:flutter_application_1/pages/song_page.dart';
import 'package:flutter_application_1/pages/settings_page.dart';
import 'package:flutter_application_1/components/neu_box.dart';
import 'package:google_fonts/google_fonts.dart';

import '../components/my_drawer.dart';
import '../services/auth_service.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<PlaylistProvider>(
      builder: (context, provider, child) {
        final currentSong = provider.currentSongIndex != null
            ? provider.playlist[provider.currentSongIndex!]
            : null;
        final recommendations = currentSong != null
            ? provider.getRecommendations(currentSong)
            : [];

        return Scaffold(
          backgroundColor: Theme.of(context).colorScheme.surface,
          appBar: AppBar(
            title: const Text('M U S I C V E R S E'),
            actions: [
              IconButton(
                icon: const Icon(Icons.settings),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const SettingsPage()),
                  );
                },
              ),
            ],
          ),
          drawer: const MyDrawer(),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const PlaylistPage()),
                      );
                    },
                    child: NeuBox(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            const Icon(Icons.library_music, size: 40),
                            const SizedBox(width: 16),
                            Text(
                              'Go to Playlist',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.inversePrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (currentSong != null) ...[
                    Text(
                      'Currently Playing',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.inversePrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const SongPage()),
                        );
                      },
                      child: NeuBox(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            children: [
                              currentSong.albumArtImagePath.startsWith('assets')
                                  ? Image.asset(
                                currentSong.albumArtImagePath,
                                width: 50,
                                height: 50,
                                fit: BoxFit.cover,
                              )
                                  : Image.file(
                                File(currentSong.albumArtImagePath),
                                key: ValueKey(currentSong.albumArtImagePath),
                                width: 50,
                                height: 50,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    Image.asset(
                                      'assets/images/default_art.png',
                                      width: 50,
                                      height: 50,
                                      fit: BoxFit.cover,
                                    ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      currentSong.songName.length > 20
                                          ? '${currentSong.songName.substring(0, 17)}...'
                                          : currentSong.songName,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(context).colorScheme.inversePrimary,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      currentSong.artistName,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Theme.of(context).colorScheme.secondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: Icon(
                                  provider.isPlaying ? Icons.pause : Icons.play_arrow,
                                  color: Theme.of(context).colorScheme.inversePrimary,
                                ),
                                onPressed: provider.pauseOrResume,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Recommended',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.inversePrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 80,
                      child: recommendations.isEmpty
                          ? Center(
                        child: Text(
                          'No recommendations available',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.inversePrimary,
                          ),
                        ),
                      )
                          : ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: recommendations.length,
                        itemBuilder: (context, index) {
                          final song = recommendations[index];
                          return GestureDetector(
                            onTap: () {
                              provider.currentSongIndex =
                                  provider.playlist.indexOf(song);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const SongPage(),
                                ),
                              );
                            },
                            child: Container(
                              width: 100,
                              margin: const EdgeInsets.only(right: 8.0),
                              child: Column(
                                children: [
                                  Flexible(
                                    child: NeuBox(
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(4.0),
                                        child: song.albumArtImagePath.startsWith('assets')
                                            ? Image.asset(
                                          song.albumArtImagePath,
                                          width: 50,
                                          height: 50,
                                          fit: BoxFit.cover,
                                        )
                                            : Image.file(
                                          File(song.albumArtImagePath),
                                          key: ValueKey(song.albumArtImagePath),
                                          width: 50,
                                          height: 50,
                                          fit: BoxFit.cover,
                                          errorBuilder:
                                              (context, error, stackTrace) =>
                                              Image.asset(
                                                'assets/images/default_art.png',
                                                width: 50,
                                                height: 50,
                                                fit: BoxFit.cover,
                                              ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  SizedBox(
                                    height: 14,
                                    child: Marquee(
                                      text: song.songName,
                                      style: TextStyle(
                                        color: Theme.of(context).colorScheme.inversePrimary,
                                        fontSize: 11,
                                      ),
                                      scrollAxis: Axis.horizontal,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      blankSpace: 20.0,
                                      velocity: 20.0,
                                      pauseAfterRound: const Duration(seconds: 1),
                                      startPadding: 10.0,
                                      accelerationDuration: const Duration(seconds: 1),
                                      accelerationCurve: Curves.linear,
                                      decelerationDuration: const Duration(milliseconds: 500),
                                      decelerationCurve: Curves.easeOut,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}