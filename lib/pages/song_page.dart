import 'package:flutter/material.dart';
import 'package:flutter_application_1/components/neu_box.dart';
import 'package:flutter_application_1/models/playlist_provider.dart';
import 'package:provider/provider.dart';

class SongPage extends StatelessWidget {
  const SongPage({super.key});

  //covert sec into min:sec
  String formatTime(Duration duration) {
    String twoDigitsSeconds = duration.inSeconds
        .remainder(60)
        .toString()
        .padLeft(2, '0');
    String formattedTime = "${duration.inMinutes}:$twoDigitsSeconds";

    return formattedTime;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PlaylistProvider>(
      builder: (context, value, child) {
        //get playlist
        final playlist = value.playlist;

        //get current song
        final currentSong = playlist[value.currentSongIndex ?? 0];
        // 添加非空和范围检查
        if (value.currentSongIndex == null ||
            value.currentSongIndex! < 0 ||
            value.currentSongIndex! >= playlist.length) {
          return Center(child: Text("No song selected"));
        }
        //return scaffold ui
        return Scaffold(
          backgroundColor: Theme.of(context).colorScheme.surface,
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(left: 25, right: 25, bottom: 25),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  //app bar
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      //back btn
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back),
                      ),
                      //title
                      const Text("PLAYLIST"),

                      //menu btn
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(Icons.menu),
                      ),
                    ],
                  ),

                  SizedBox(height: 30),
                  //album artwork
                  NeuBox(
                    child: Column(
                      children: [
                        //img
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.asset(currentSong.albumArtImagePath),
                        ),

                        Padding(
                          padding: EdgeInsets.all(15.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              //Song & artis name
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    currentSong.songName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 20,
                                    ),
                                  ),
                                  Text(currentSong.artisName),
                                ],
                              ),
                              //heart icon
                              const Icon(Icons.favorite, color: Colors.red),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 25),

                  //song duration progress
                  Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 25.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            //start time
                            Text(formatTime(value.currentDuration)),

                            //suffle icon
                            Icon(Icons.shuffle),

                            //repeat icon
                            Icon(Icons.repeat),

                            //end time
                            Text(formatTime(value.totalDuration)),
                          ],
                        ),
                      ),

                      //song duration progress
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 0,
                          ),
                        ),
                        child: Slider(
                          min: 0,
                          max: value.totalDuration.inSeconds.toDouble(),
                          value: value.currentDuration.inSeconds.toDouble(),
                          activeColor: Colors.green,
                          onChanged: (double double) {
                            //during when the user is sliding around
                          },
                          onChangeEnd: (double double) {
                            //sliding has finished, go to that position in song duration
                            value.seek(Duration(seconds: double.toInt()));
                          },
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 25),

                  //playback controls
                  Row(
                    children: [
                      //skip previous
                      Expanded(
                        child: GestureDetector(
                          onTap: value.playPreviousSong,
                          child: NeuBox(child: Icon(Icons.skip_previous)),
                        ),
                      ),

                      //gap
                      const SizedBox(width: 20),

                      //play pause
                      Expanded(
                        flex: 2,
                        child: GestureDetector(
                          onTap: value.pauseOrResume,
                          child: NeuBox(
                            child: Icon(
                              value.isPlaying ? Icons.pause : Icons.play_arrow,
                            ),
                          ),
                        ),
                      ),

                      //gap
                      const SizedBox(width: 20),

                      //skip forward
                      Expanded(
                        child: GestureDetector(
                          onTap: value.playNextSong,
                          child: NeuBox(child: Icon(Icons.skip_next)),
                        ),
                      ),
                    ],
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
