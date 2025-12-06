// File generated manually - configuration might need update for native Android/iOS App IDs
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
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
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
    apiKey: 'AIzaSyD08qXcZjC1N_wX8EE5YGgN4sA-ZrJQICg',
    appId: '1:960634304944:web:9c9cb29b14b13924b73e75',
    messagingSenderId: '960634304944',
    projectId: 'bmspro-pink',
    authDomain: 'bmspro-pink.firebaseapp.com',
    storageBucket: 'bmspro-pink.firebasestorage.app',
    measurementId: 'G-M4XJKLN1Y2',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyD2q67hCjMyxb0N79zouXW1tzXDwAIwNFM',
    appId: '1:960634304944:android:fbfb092f36221831b73e75',
    messagingSenderId: '960634304944',
    projectId: 'bmspro-pink',
    storageBucket: 'bmspro-pink.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyD08qXcZjC1N_wX8EE5YGgN4sA-ZrJQICg',
    appId: '1:960634304944:web:9c9cb29b14b13924b73e75', // Using Web App ID as fallback
    messagingSenderId: '960634304944',
    projectId: 'bmspro-pink',
    storageBucket: 'bmspro-pink.firebasestorage.app',
    iosBundleId: 'com.example.bmsproPink',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyD08qXcZjC1N_wX8EE5YGgN4sA-ZrJQICg',
    appId: '1:960634304944:web:9c9cb29b14b13924b73e75', // Using Web App ID as fallback
    messagingSenderId: '960634304944',
    projectId: 'bmspro-pink',
    storageBucket: 'bmspro-pink.firebasestorage.app',
    iosBundleId: 'com.example.bmsproPink',
  );
}

