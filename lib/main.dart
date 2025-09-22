import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'firebase_options.dart';
import 'pages/splash_page.dart';
import 'models/playlist_provider.dart';
import 'models/history_provider.dart';
import 'theme/theme_provider.dart';
import 'services/auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.example.flutter_application_1.channel.audio',
    androidNotificationChannelName: 'Audio playback',
    androidNotificationOngoing: true,
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => ThemeProvider()),
        ChangeNotifierProvider(create: (context) => HistoryProvider()),
        ChangeNotifierProxyProvider<HistoryProvider, PlaylistProvider>(
          create: (context) => PlaylistProvider(
            historyProvider: Provider.of<HistoryProvider>(context, listen: false),
          ),
          update: (context, historyProvider, previous) => previous ?? PlaylistProvider(
            historyProvider: historyProvider,
          ),
        ),
        Provider(create: (context) => AuthService()), // Ensure this is present
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MusicVerse',
      debugShowCheckedModeBanner: false,
      theme: Provider.of<ThemeProvider>(context).themeData,
      home: const SplashPage(),
    );
  }
}