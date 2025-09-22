import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../models/playlist_provider.dart';
import '../pages/playlist_page.dart';
import '../pages/settings_page.dart';
import '../pages/login.dart';
import '../services/auth_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../pages/home_page.dart';
import '../pages/history_page.dart';

class MyDrawer extends StatefulWidget {
  const MyDrawer({super.key});

  @override
  _MyDrawerState createState() => _MyDrawerState();
}

class _MyDrawerState extends State<MyDrawer> {
  Future<Map<String, dynamic>?> _fetchUserProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      return userDoc.data();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load profile: $e')),
      );
      return null;
    }
  }

  Future<bool> _requestPermissions() async {
    final audioStatus = await Permission.audio.request();
    final imagesStatus = await Permission.photos.request();
    final videosStatus = await Permission.videos.request();
    final notificationStatus = await Permission.notification.request();

    if (audioStatus.isGranted || imagesStatus.isGranted || videosStatus.isGranted || notificationStatus.isGranted) {
      return true;
    }
    if (audioStatus.isPermanentlyDenied ||
        imagesStatus.isPermanentlyDenied ||
        videosStatus.isPermanentlyDenied ||
        notificationStatus.isPermanentlyDenied) {
      await openAppSettings();
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final playlistProvider = Provider.of<PlaylistProvider>(context, listen: false);
    final user = FirebaseAuth.instance.currentUser;

    return Drawer(
      backgroundColor: Theme.of(context).colorScheme.surface,
      child: Column(
        children: [
          FutureBuilder<Map<String, dynamic>?>(
            future: _fetchUserProfile(),
            builder: (context, snapshot) {
              String? photoURL;
              String? displayName;

              if (snapshot.connectionState == ConnectionState.waiting) {
                return const DrawerHeader(
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasData) {
                photoURL = snapshot.data?['photoURL'] ?? user?.photoURL;
                displayName = snapshot.data?['name'] ?? user?.displayName ?? user?.email;
              }

              return DrawerHeader(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundImage: photoURL != null
                          ? NetworkImage(photoURL!)
                          : const AssetImage('assets/images/app_icon.png') as ImageProvider,
                      child: photoURL == null
                          ? Icon(
                        Icons.person,
                        size: 30,
                        color: Theme.of(context).colorScheme.secondary,
                      )
                          : null,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      user != null ? 'Hi👋, ${displayName ?? user.email}' : 'Hi👋, Guest',
                      style: GoogleFonts.raleway(
                        textStyle: TextStyle(
                          color: Theme.of(context).colorScheme.inversePrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.only(left: 25.0, top: 25),
            child: ListTile(
              title: const Text("H O M E"),
              leading: const Icon(Icons.home),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const HomePage()),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 25.0, top: 0),
            child: ListTile(
              title: const Text("P L A Y L I S T"),
              leading: const Icon(Icons.playlist_play),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const PlaylistPage()),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 25.0, top: 0),
            child: ListTile(
              title: const Text("H I S T O R Y"),
              leading: const Icon(Icons.history),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const HistoryPage()),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 25.0, top: 0),
            child: ListTile(
              title: const Text("S E T T I N G S"),
              leading: const Icon(Icons.settings),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushReplacement(
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
                Navigator.pop(context);
                try {
                  if (!await _requestPermissions()) {
                    scaffoldMessenger.showSnackBar(
                      const SnackBar(
                        content: Text('Audio, images, videos, or notification permission required.'),
                        action: SnackBarAction(
                          label: 'Settings',
                          onPressed: openAppSettings,
                        ),
                      ),
                    );
                    return;
                  }
                  final result = await FilePicker.platform.pickFiles(
                    type: FileType.custom,
                    allowedExtensions: ['mp3', 'm4a', 'mp4'],
                    allowMultiple: true,
                  );
                  if (result != null) {
                    final paths = result.files.map((file) => file.path!).toList();
                    for (var path in paths) {
                      await playlistProvider.importSong(path);
                    }
                    scaffoldMessenger.showSnackBar(
                      const SnackBar(content: Text('Files imported successfully')),
                    );
                  } else {
                    scaffoldMessenger.showSnackBar(
                      const SnackBar(content: Text('No files selected')),
                    );
                  }
                } catch (e) {
                  scaffoldMessenger.showSnackBar(
                    SnackBar(content: Text('Failed to import files: $e')),
                  );
                }
              },
            ),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.only(left: 25.0, bottom: 25.0),
            child: ListTile(
              title: Text(user != null ? "L O G O U T" : "L O G I N"),
              leading: Icon(user != null ? Icons.logout : Icons.login),
              onTap: () async {
                Navigator.pop(context);
                if (user != null) {
                  await AuthService().signout(context: context);
                  scaffoldMessenger.showSnackBar(
                    const SnackBar(content: Text('Logged out successfully')),
                  );
                } else {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => Login()),
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