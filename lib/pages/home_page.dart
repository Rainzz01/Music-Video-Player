import 'package:flutter/material.dart';
import 'package:flutter_application_1/components/my_drawer.dart';
import 'package:flutter_application_1/models/playlist_provider.dart';
import 'package:flutter_application_1/models/song.dart';
import 'package:flutter_application_1/pages/song_page.dart';
import 'package:provider/provider.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final dynamic playlistProvider;

  @override
  void initState() {
    super.initState();

    //get playlist provider
    playlistProvider = Provider.of<PlaylistProvider>(context, listen: false);
  }

  //goto song
  void goToSong(int songIndex) {
    playlistProvider.currentSongIndex = songIndex;

    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => SongPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(title: const Text("P L A Y L I S T")),
      drawer: const MyDrawer(),
      body: Consumer<PlaylistProvider>(
        builder: (context, value, child) {
          //get playlist
          final List<Song> playlist = value.playlist;

          // return list view ui
          return ListView.builder(
            itemCount: playlist.length,
            itemBuilder: (context, index) {
              //get individual song
              final Song song = playlist[index];

              //return list title ui
              return ListTile(
                title: Text(song.songName),
                subtitle: Text(song.artisName),
                leading: Image.asset(song.albumArtImagePath),
                onTap: () => goToSong(index),
              );
            },
          );
        },
      ),
    );
  }
}
