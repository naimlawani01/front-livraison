import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Bundle / package natif : `com.livraison.livreur`. Vérifiez dans Firebase Console
/// que les apps iOS/Android sont enregistrées avec cet identifiant, puis
/// `flutterfire configure` ou mise à jour manuelle des `appId`.
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
      default:
        throw UnsupportedError('Platform not supported');
    }
  }

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBnncDS1edVZpUkARvkfJIKMmz26SWkqms',
    appId: '1:813551314699:ios:82a8c981d3c81ce21ce40e',
    messagingSenderId: '813551314699',
    projectId: 'sonaiyaa',
    storageBucket: 'sonaiyaa.firebasestorage.app',
    iosBundleId: 'com.livraison.livreur',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyBnncDS1edVZpUkARvkfJIKMmz26SWkqms',
    appId: '1:813551314699:ios:82a8c981d3c81ce21ce40e',
    messagingSenderId: '813551314699',
    projectId: 'sonaiyaa',
    storageBucket: 'sonaiyaa.firebasestorage.app',
    iosBundleId: 'com.livraison.livreur',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDuEDOpkRn2Xy7W3ucES7QZ1LSB254nclw',
    appId: '1:813551314699:android:ea2084daf440eff41ce40e',
    messagingSenderId: '813551314699',
    projectId: 'sonaiyaa',
    storageBucket: 'sonaiyaa.firebasestorage.app',
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDlr83o3RWIEjfno2kF4ufV1ywBedscasI',
    appId: '1:813551314699:web:d90fe450fd216b341ce40e',
    messagingSenderId: '813551314699',
    projectId: 'sonaiyaa',
    authDomain: 'sonaiyaa.firebaseapp.com',
    storageBucket: 'sonaiyaa.firebasestorage.app',
    measurementId: 'G-LJEZ2MKWNJ',
  );

}