import 'package:flutter/material.dart';

class IconDescription {
  final IconData icon;
  final String description;

  IconDescription(this.icon, this.description);
}

List<IconDescription> iconDescriptions = [
  IconDescription(Icons.add, 'Add a new song to the playlist'),
  IconDescription(Icons.refresh, 'Refresh the playlist'),
  IconDescription(Icons.play_arrow, 'Play the current song'),
  IconDescription(Icons.pause, 'Pause the current song'),
  IconDescription(Icons.skip_next, 'Skip to the next song'),
  IconDescription(Icons.skip_previous, 'Skip to the previous song'),
  IconDescription(Icons.shuffle, 'Shuffle the playlist'),
  IconDescription(Icons.repeat, 'Repeat the current song'),
  IconDescription(Icons.loop, 'Loop the playlist'),
  IconDescription(Icons.queue_music, 'Play songs sequentially'),
  IconDescription(Icons.edit, 'Edit song details'),
  IconDescription(Icons.favorite, 'Add/remove song from favorites'),
];