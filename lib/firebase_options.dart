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
    apiKey: 'AIzaSyDEqqcY5778KkFGeeD59DdxaVJmyWl6Kpw',
    appId: '1:545320934186:web:ebf4aa8fb734539ec99c53',
    messagingSenderId: '545320934186',
    projectId: 'bmspro-pink-v2-staging',
    authDomain: 'bmspro-pink-v2-staging.firebaseapp.com',
    storageBucket: 'bmspro-pink-v2-staging.firebasestorage.app',
    measurementId: 'G-5TJLX869X9',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDDREBZtiOPjHzbxkTzUIf3I7C0THvtd6k',
    appId: '1:545320934186:android:a7508af5354986d8c99c53',
    messagingSenderId: '545320934186',
    projectId: 'bmspro-pink-v2-staging',
    storageBucket: 'bmspro-pink-v2-staging.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyA_Kv-oO_-KPlz6yaPYi1Yqx8K035nNWmY',
    appId: '1:545320934186:ios:9f2b0234bb99ec40c99c53',
    messagingSenderId: '545320934186',
    projectId: 'bmspro-pink-v2-staging',
    storageBucket: 'bmspro-pink-v2-staging.firebasestorage.app',
    iosBundleId: 'com.bmspros.pink.staging',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyA_Kv-oO_-KPlz6yaPYi1Yqx8K035nNWmY',
    appId: '1:545320934186:ios:9f2b0234bb99ec40c99c53',
    messagingSenderId: '545320934186',
    projectId: 'bmspro-pink-v2-staging',
    storageBucket: 'bmspro-pink-v2-staging.firebasestorage.app',
    iosBundleId: 'com.bmspros.pink.staging',
  );
}

