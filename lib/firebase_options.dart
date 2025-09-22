import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBUJJPYwTg0G25ZBwN1QvU8dp8jbftRr2k',
    appId: '1:388810117227:web:ed13aa0104b86793cd612e',
    messagingSenderId: '388810117227',
    projectId: 'test1-f7d89',
    authDomain: 'test1-f7d89.firebaseapp.com',
    storageBucket: 'test1-f7d89.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBDKBzoC4ok9dT9X3KgYH-BzKZ0MvzK1as',
    appId: '1:388810117227:android:d2a08d9337462bf2cd612e',
    messagingSenderId: '388810117227',
    projectId: 'test1-f7d89',
    storageBucket: 'test1-f7d89.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAQvfyW9CEBPhhh3XiPezbsMXE-16n3fLc',
    appId: '1:388810117227:ios:46a65dffac2bc7a1cd612e',
    messagingSenderId: '388810117227',
    projectId: 'test1-f7d89',
    storageBucket: 'test1-f7d89.firebasestorage.app',
    iosBundleId: 'com.example.flutterApplication1',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyAQvfyW9CEBPhhh3XiPezbsMXE-16n3fLc',
    appId: '1:388810117227:ios:46a65dffac2bc7a1cd612e',
    messagingSenderId: '388810117227',
    projectId: 'test1-f7d89',
    storageBucket: 'test1-f7d89.firebasestorage.app',
    iosBundleId: 'com.example.flutterApplication1',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyBUJJPYwTg0G25ZBwN1QvU8dp8jbftRr2k',
    appId: '1:388810117227:web:dd029ca737e29951cd612e',
    messagingSenderId: '388810117227',
    projectId: 'test1-f7d89',
    authDomain: 'test1-f7d89.firebaseapp.com',
    storageBucket: 'test1-f7d89.firebasestorage.app',
  );
}
