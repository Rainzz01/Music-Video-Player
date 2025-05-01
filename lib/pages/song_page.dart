import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/painting.dart';
import 'package:marquee/marquee.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../components/icon_descriptions.dart';
import '../components/my_drawer.dart';
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

  void _showAddToPlaylistDialog(BuildContext context, PlaylistProvider provider, Song song) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add to Playlist'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: provider.tags.keys.map((tag) {
              return CheckboxListTile(
                title: Text(tag),
                value: provider.hasTag(song, tag),
                onChanged: (value) {
                  if (value == true) {
                    provider.addTagToSong(song, tag);
                  } else {
                    provider.removeTagFromSong(song, tag);
                  }
                },
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PlaylistProvider>(
      builder: (context, provider, child) {
        final song = provider.currentSongIndex != null
            ? provider.playlist[provider.currentSongIndex!]
            : null;

        if (song == null) {
          return Scaffold(
            backgroundColor: Theme.of(context).colorScheme.surface,
            appBar: AppBar(title: const Text('No Song Selected')),
            body: Center(
              child: Text(
                'Please select a song',
                style: TextStyle(color: Theme.of(context).colorScheme.inversePrimary),
              ),
            ),
          );
        }

        final recommendations = provider.getRecommendations(song);

        return Scaffold(
          backgroundColor: Theme.of(context).colorScheme.surface,
          appBar: AppBar(
            title: const Text('S O N G'),
            actions: [
              Tooltip(
                message: iconDescriptions
                    .firstWhere((desc) => desc.icon == Icons.favorite)
                    .description,
                child: IconButton(
                  icon: Icon(
                    provider.isFavorite(song) ? Icons.favorite : Icons.favorite_border,
                    color: provider.isFavorite(song)
                        ? Colors.red
                        : Theme.of(context).colorScheme.inversePrimary,
                  ),
                  onPressed: () => provider.toggleFavorite(song),
                ),
              ),
              Tooltip(
                message: 'Add to playlist',
                child: IconButton(
                  icon: const Icon(Icons.playlist_add),
                  onPressed: () => _showAddToPlaylistDialog(context, provider, song),
                ),
              ),
              Tooltip(
                message: iconDescriptions
                    .firstWhere((desc) => desc.icon == Icons.edit)
                    .description,
                child: IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () => _showEditDialog(context, provider, song),
                ),
              ),
            ],
          ),
          drawer: const MyDrawer(),
          body: SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    NeuBox(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: song.albumArtImagePath.startsWith('assets')
                            ? Image.asset(
                          song.albumArtImagePath,
                          height: 250,
                          width: 250,
                          fit: BoxFit.cover,
                        )
                            : Image.file(
                          File(song.albumArtImagePath),
                          key: ValueKey(song.albumArtImagePath),
                          height: 250,
                          width: 250,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              Image.asset('assets/images/default_art.png'),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Column(
                      children: [
                        SizedBox(
                          height: 30,
                          child: song.songName.length < 20
                              ? Text(
                            song.songName,
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.inversePrimary,
                            ),
                            textAlign: TextAlign.center,
                          )
                              : Marquee(
                            text: song.songName,
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.inversePrimary,
                            ),
                            scrollAxis: Axis.horizontal,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            blankSpace: 20.0,
                            velocity: 30.0,
                            pauseAfterRound: const Duration(seconds: 1),
                            startPadding: 10.0,
                            accelerationDuration: const Duration(seconds: 1),
                            accelerationCurve: Curves.linear,
                            decelerationDuration: const Duration(milliseconds: 500),
                            decelerationCurve: Curves.easeOut,
                          ),
                        ),
                        Text(
                          song.artistName,
                          style: TextStyle(
                            fontSize: 18,
                            color: Theme.of(context).colorScheme.secondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    NeuBox(
                      child: Column(
                        children: [
                          Slider(
                            value: provider.totalDuration.inSeconds == 0
                                ? 0.0
                                : (provider.currentDuration.inSeconds /
                                provider.totalDuration.inSeconds)
                                .clamp(0.0, 1.0),
                            min: 0.0,
                            max: 1.0,
                            onChanged: (value) {
                              if (provider.totalDuration.inSeconds > 0) {
                                final position = Duration(
                                    seconds:
                                    (value * provider.totalDuration.inSeconds).toInt());
                                provider.seek(position);
                              }
                            },
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  formatTime(provider.currentDuration),
                                  style: TextStyle(
                                      color: Theme.of(context).colorScheme.inversePrimary),
                                ),
                                Text(
                                  formatTime(provider.totalDuration),
                                  style: TextStyle(
                                      color: Theme.of(context).colorScheme.inversePrimary),
                                ),
                              ],
                            ),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Tooltip(
                                message: iconDescriptions
                                    .firstWhere((desc) => desc.icon == Icons.skip_previous)
                                    .description,
                                child: IconButton(
                                  icon: const Icon(Icons.skip_previous),
                                  iconSize: 36,
                                  onPressed: provider.playPreviousSong,
                                ),
                              ),
                              Tooltip(
                                message: iconDescriptions
                                    .firstWhere((desc) =>
                                desc.icon ==
                                    (provider.isPlaying
                                        ? Icons.pause
                                        : Icons.play_arrow))
                                    .description,
                                child: IconButton(
                                  icon: Icon(provider.isPlaying
                                      ? Icons.pause
                                      : Icons.play_arrow),
                                  iconSize: 48,
                                  onPressed: provider.pauseOrResume,
                                ),
                              ),
                              Tooltip(
                                message: iconDescriptions
                                    .firstWhere((desc) => desc.icon == Icons.skip_next)
                                    .description,
                                child: IconButton(
                                  icon: const Icon(Icons.skip_next),
                                  iconSize: 36,
                                  onPressed: provider.playNextSong,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Tooltip(
                                message: iconDescriptions
                                    .firstWhere((desc) => desc.icon == Icons.shuffle)
                                    .description,
                                child: IconButton(
                                  icon: Icon(
                                    Icons.shuffle,
                                    color: provider.playMode == PlayMode.shuffle
                                        ? Theme.of(context).colorScheme.primary
                                        : Theme.of(context).colorScheme.secondary,
                                  ),
                                  onPressed: () {
                                    provider.playMode = PlayMode.shuffle;
                                  },
                                ),
                              ),
                              Tooltip(
                                message: iconDescriptions
                                    .firstWhere((desc) => desc.icon == Icons.repeat)
                                    .description,
                                child: IconButton(
                                  icon: Icon(
                                    Icons.repeat,
                                    color: provider.playMode == PlayMode.repeat
                                        ? Theme.of(context).colorScheme.primary
                                        : Theme.of(context).colorScheme.secondary,
                                  ),
                                  onPressed: () {
                                    provider.playMode = PlayMode.repeat;
                                  },
                                ),
                              ),
                              Tooltip(
                                message: iconDescriptions
                                    .firstWhere((desc) => desc.icon == Icons.loop)
                                    .description,
                                child: IconButton(
                                  icon: Icon(
                                    Icons.loop,
                                    color: provider.playMode == PlayMode.loop
                                        ? Theme.of(context).colorScheme.primary
                                        : Theme.of(context).colorScheme.secondary,
                                  ),
                                  onPressed: () {
                                    provider.playMode = PlayMode.loop;
                                  },
                                ),
                              ),
                              Tooltip(
                                message: iconDescriptions
                                    .firstWhere((desc) => desc.icon == Icons.queue_music)
                                    .description,
                                child: IconButton(
                                  icon: Icon(
                                    Icons.queue_music,
                                    color: provider.playMode == PlayMode.sequential
                                        ? Theme.of(context).colorScheme.primary
                                        : Theme.of(context).colorScheme.secondary,
                                  ),
                                  onPressed: () {
                                    provider.playMode = PlayMode.sequential;
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Recommended Songs',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Theme.of(context).colorScheme.inversePrimary,
                      ),
                    ),
                    recommendations.isEmpty
                        ? Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        'No recommendations available',
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.inversePrimary),
                      ),
                    )
                        : ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: recommendations.length,
                      itemBuilder: (context, index) {
                        final recSong = recommendations[index];
                        return ListTile(
                          leading: NeuBox(
                            child: recSong.albumArtImagePath.startsWith('assets')
                                ? Image.asset(
                              recSong.albumArtImagePath,
                              width: 50,
                              height: 50,
                              fit: BoxFit.cover,
                            )
                                : Image.file(
                              File(recSong.albumArtImagePath),
                              key: ValueKey(recSong.albumArtImagePath),
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
                          ),
                          title: SizedBox(
                            height: 20,
                            child: Marquee(
                              text: recSong.songName,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.inversePrimary,
                                fontSize: 16,
                              ),
                              scrollAxis: Axis.horizontal,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              blankSpace: 20.0,
                              velocity: 30.0,
                              pauseAfterRound: const Duration(seconds: 1),
                              startPadding: 10.0,
                              accelerationDuration: const Duration(seconds: 1),
                              accelerationCurve: Curves.linear,
                              decelerationDuration: const Duration(milliseconds: 500),
                              decelerationCurve: Curves.easeOut,
                            ),
                          ),
                          subtitle: Text(
                            recSong.artistName,
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.secondary),
                          ),
                          trailing: IconButton(
                            icon: Icon(
                              provider.isFavorite(recSong)
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              color: provider.isFavorite(recSong)
                                  ? Colors.red
                                  : Theme.of(context).colorScheme.inversePrimary,
                            ),
                            onPressed: () => provider.toggleFavorite(recSong),
                          ),
                          onTap: () {
                            provider.currentSongIndex =
                                provider.playlist.indexOf(recSong);
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showEditDialog(BuildContext context, PlaylistProvider provider, Song song) {
    String? newAlbumArtPath = song.albumArtImagePath;

    showDialog(
      context: context,
      builder: (context) {
        final nameController = TextEditingController(text: song.songName);
        final artistController = TextEditingController(text: song.artistName);
        final genreController = TextEditingController(text: song.genre ?? 'Unknown');

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Edit Song'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: () async {
                        final result = await FilePicker.platform.pickFiles(
                          type: FileType.image,
                        );
                        if (result != null && result.files.single.path != null) {
                          newAlbumArtPath = await provider.saveCustomAlbumArt(result.files.single.path!);
                          imageCache.clear();
                          imageCache.clearLiveImages();
                          setState(() {});
                        }
                      },
                      child: NeuBox(
                        child: newAlbumArtPath!.startsWith('assets')
                            ? Image.asset(
                          newAlbumArtPath!,
                          width: 100,
                          height: 100,
                          fit: BoxFit.cover,
                        )
                            : Image.file(
                          File(newAlbumArtPath!),
                          key: ValueKey(newAlbumArtPath),
                          width: 100,
                          height: 100,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Image.asset(
                            'assets/images/default_art.png',
                            width: 100,
                            height: 100,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
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
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    provider.updateSong(
                      song,
                      nameController.text.trim(),
                      genreController.text.trim(),
                      artistController.text.trim(),
                      newAlbumArtPath,
                    );
                    Navigator.pop(context);
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}