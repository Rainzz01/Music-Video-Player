import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../models/playlist_provider.dart';
import '../pages/settings_page.dart';

class MyDrawer extends StatelessWidget {
  const MyDrawer({super.key});

  Future<bool> _requestPermissions() async {
    final storageStatus = await Permission.storage.request();
    final audioStatus = await Permission.audio.request();
    final imagesStatus = await Permission.photos.request();
    final videosStatus = await Permission.videos.request();
    if (storageStatus.isGranted || audioStatus.isGranted || imagesStatus.isGranted || videosStatus.isGranted) {
      return true;
    }
    if (storageStatus.isPermanentlyDenied ||
        audioStatus.isPermanentlyDenied ||
        imagesStatus.isPermanentlyDenied ||
        videosStatus.isPermanentlyDenied) {
      await openAppSettings();
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final scaffoldMessenger = ScaffoldMessenger.of(context); // Store ScaffoldMessengerState
    final playlistProvider = Provider.of<PlaylistProvider>(context, listen: false); // Store provider
    return Drawer(
      backgroundColor: Theme.of(context).colorScheme.surface,
      child: Column(
        children: [
          DrawerHeader(
            child: Center(
              child: Icon(
                Icons.music_note,
                size: 40,
                color: Theme.of(context).colorScheme.inversePrimary,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 25.0, top: 25),
            child: ListTile(
              title: const Text("H O M E"),
              leading: const Icon(Icons.home),
              onTap: () => Navigator.pop(context),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 25.0, top: 0),
            child: ListTile(
              title: const Text("S E T T I N G S"),
              leading: const Icon(Icons.settings),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SettingsPage()),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 25.0, top: 0),
            child: ListTile(
              title: const Text("I M P O R T"),
              leading: const Icon(Icons.folder),
              onTap: () async {
                Navigator.pop(context); // Close drawer first
                try {
                  if (!await _requestPermissions()) {
                    scaffoldMessenger.showSnackBar(
                      const SnackBar(
                        content: Text('Storage, audio, images, or video permission required to import.'),
                        action: SnackBarAction(
                          label: 'Settings',
                          onPressed: openAppSettings,
                        ),
                      ),
                    );
                    return;
                  }
                  final result = await FilePicker.platform.pickFiles(
                    type: FileType.audio,
                    allowMultiple: true,
                  );
                  if (result != null) {
                    final paths = result.files.map((file) => file.path!).toList();
                    for (var path in paths) {
                      await playlistProvider.importSong(path);
                    }
                    scaffoldMessenger.showSnackBar(
                      const SnackBar(content: Text('Songs imported successfully')),
                    );
                  } else {
                    scaffoldMessenger.showSnackBar(
                      const SnackBar(content: Text('No files selected')),
                    );
                  }
                } catch (e) {
                  scaffoldMessenger.showSnackBar(
                    SnackBar(content: Text('Failed to import songs: $e')),
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}