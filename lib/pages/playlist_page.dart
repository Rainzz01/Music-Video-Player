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
import 'song_page.dart';

class PlaylistPage extends StatefulWidget {
  const PlaylistPage({super.key});

  @override
  _PlaylistPageState createState() => _PlaylistPageState();
}

class _PlaylistPageState extends State<PlaylistPage> {
  final TextEditingController _searchController = TextEditingController();
  String? _selectedCategory;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PlaylistProvider>(
      builder: (context, provider, child) {
        final playlist = _searchController.text.isEmpty && (_selectedCategory == null || _selectedCategory == 'All Genres')
            ? provider.playlist
            : provider.searchSongs(_searchController.text).where((song) {
          if (_selectedCategory == null || _selectedCategory == 'All Genres') {
            return true;
          }
          return provider.categories[_selectedCategory]?.contains(song) ?? false;
        }).toList();

        return Scaffold(
          backgroundColor: Theme.of(context).colorScheme.surface,
          appBar: AppBar(
            title: const Text('P L A Y L I S T'),
            actions: [
              Tooltip(
                message: iconDescriptions
                    .firstWhere((desc) => desc.icon == Icons.refresh)
                    .description,
                child: IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: provider.loadSongsFromCloud,
                ),
              ),
              Tooltip(
                message: 'Create new playlist',
                child: IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: () => _showCreatePlaylistDialog(context, provider),
                ),
              ),
            ],
          ),
          drawer: const MyDrawer(),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: NeuBox(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search songs...',
                      prefixIcon: const Icon(Icons.search),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    style: TextStyle(color: Theme.of(context).colorScheme.inversePrimary),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: NeuBox(
                  child: DropdownButton<String>(
                    value: _selectedCategory ?? 'All Genres',
                    isExpanded: true,
                    underline: const SizedBox(),
                    items: [
                      'All Genres',
                      ...provider.categories.keys,
                    ].map((category) => DropdownMenuItem(
                      value: category,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Text(category),
                      ),
                    )).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedCategory = value == 'All Genres' ? null : value;
                      });
                    },
                  ),
                ),
              ),
              Expanded(
                child: provider.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : provider.errorMessage != null
                    ? Center(
                  child: Text(
                    provider.errorMessage!,
                    style: const TextStyle(color: Colors.red),
                  ),
                )
                    : playlist.isEmpty
                    ? Center(
                  child: Text(
                    'No songs found',
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.inversePrimary),
                  ),
                )
                    : ListView.builder(
                  itemCount: playlist.length,
                  itemBuilder: (context, index) {
                    final song = playlist[index];
                    return ListTile(
                      leading: NeuBox(
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
                      title: Text(
                        song.songName.length > 20
                            ? '${song.songName.substring(0, 17)}...'
                            : song.songName,
                        style: TextStyle(
                            color:
                            Theme.of(context).colorScheme.inversePrimary),
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        song.artistName,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.secondary),
                      ),
                      trailing: IconButton(
                        icon: Icon(
                          provider.isFavorite(song)
                              ? Icons.favorite
                              : Icons.favorite_border,
                          color: provider.isFavorite(song)
                              ? Colors.red
                              : Theme.of(context).colorScheme.inversePrimary,
                        ),
                        onPressed: () => provider.toggleFavorite(song),
                      ),
                      onTap: () {
                        provider.currentSongIndex = provider.playlist.indexOf(song);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const SongPage()),
                        );
                      },
                      onLongPress: () => _showEditDialog(context, provider, song),
                    );
                  },
                ),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () async {
              try {
                final result = await FilePicker.platform.pickFiles(
                  type: FileType.custom,
                  allowedExtensions: ['mp3', 'm4a', 'mp4'], // Allow MP3, M4A, MP4
                );
                if (result != null && result.files.single.path != null) {
                  await provider.importSong(result.files.single.path!);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('File imported successfully')),
                  );
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to import file: ${e.toString().replaceFirst('Exception: ', '')}')),
                );
              }
            },
            child: Tooltip(
              message: iconDescriptions
                  .firstWhere((desc) => desc.icon == Icons.add)
                  .description,
              child: const Icon(Icons.add),
            ),
          ),
        );
      },
    );
  }

  void _showCreatePlaylistDialog(BuildContext context, PlaylistProvider provider) {
    final TextEditingController playlistController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create New Playlist'),
        content: TextField(
          controller: playlistController,
          decoration: const InputDecoration(labelText: 'Playlist Name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final name = playlistController.text.trim();
              if (name.isNotEmpty && !provider.tags.containsKey(name)) {
                provider.createPlaylist(name); // Use the new method
                Navigator.pop(context);
                setState(() {});
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
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