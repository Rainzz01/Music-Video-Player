// lib/pages/home_page.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../components/my_drawer.dart';
import '../models/playlist_provider.dart';
import '../models/song.dart';
import 'song_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final PlaylistProvider playlistProvider;
  final TextEditingController _searchController = TextEditingController();
  List<Song> _searchResults = [];

  @override
  void initState() {
    super.initState();
    playlistProvider = Provider.of<PlaylistProvider>(context, listen: false);
    _searchResults = playlistProvider.playlist;
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    setState(() {
      _searchResults = playlistProvider.searchSongs(_searchController.text);
    });
  }

  void goToSong(int songIndex) {
    playlistProvider.currentSongIndex = songIndex;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SongPage()),
    );
  }

  Future<void> _requestPermissionsManually() async {
    final storageStatus = await Permission.storage.request();
    final audioStatus = await Permission.audio.request();
    if (storageStatus.isGranted || audioStatus.isGranted) {
      playlistProvider.loadLocalSongs();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Permissions required. Please enable in settings.'),
          action: SnackBarAction(
            label: 'Settings',
            onPressed: openAppSettings,
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text("P L A Y L I S T"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => playlistProvider.loadLocalSongs(),
          ),
        ],
      ),
      drawer: const MyDrawer(),
      body: Consumer<PlaylistProvider>(
        builder: (context, value, child) {
          if (value.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (value.errorMessage != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(value.errorMessage!),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: value.errorMessage!.contains('permission')
                        ? _requestPermissionsManually
                        : () => value.loadLocalSongs(),
                    child: Text(
                        value.errorMessage!.contains('permission')
                            ? 'Request Permissions'
                            : 'Retry'),
                  ),
                  if (value.errorMessage!.contains('permission'))
                    ElevatedButton(
                      onPressed: openAppSettings,
                      child: const Text('Open Settings'),
                    ),
                ],
              ),
            );
          }
          if (value.playlist.isEmpty && _searchController.text.isEmpty) {
            return const Center(child: Text('No songs found. Try importing some!'));
          }

          final categories = value.categories;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search songs...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: _searchController.text.isNotEmpty
                    ? ListView.builder(
                  itemCount: _searchResults.length,
                  itemBuilder: (context, index) {
                    final song = _searchResults[index];
                    return ListTile(
                      title: Text(song.songName),
                      subtitle: Text(song.artistName),
                      leading: Image.file(
                        File(song.albumArtImagePath),
                        width: 50,
                        height: 50,
                        errorBuilder: (context, error, stackTrace) =>
                            Image.asset('assets/images/default_art.png'),
                      ),
                      onTap: () => goToSong(value.playlist.indexOf(song)),
                    );
                  },
                )
                    : ListView(
                  children: categories.entries.map((entry) {
                    final genre = entry.key;
                    final songs = entry.value;
                    return ExpansionTile(
                      title: Text(genre),
                      children: songs.map((song) {
                        return ListTile(
                          title: Text(song.songName),
                          subtitle: Text(song.artistName),
                          leading: Image.file(
                            File(song.albumArtImagePath),
                            width: 50,
                            height: 50,
                            errorBuilder: (context, error, stackTrace) =>
                                Image.asset('assets/images/default_art.png'),
                          ),
                          onTap: () => goToSong(value.playlist.indexOf(song)),
                        );
                      }).toList(),
                    );
                  }).toList(),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}