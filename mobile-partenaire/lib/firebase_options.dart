import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Après renommage du bundle iOS/Android en `com.livraison.partenaire`, enregistrez
/// les apps dans Firebase Console (même bundle / package) et exécutez
/// `flutterfire configure`, ou remplacez manuellement les `appId` et
/// `ios/Runner/GoogleService-Info.plist` par ceux fournis par Firebase.
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
    appId: '1:813551314699:ios:ff5db41bd34066b01ce40e',
    messagingSenderId: '813551314699',
    projectId: 'sonaiyaa',
    storageBucket: 'sonaiyaa.firebasestorage.app',
    iosBundleId: 'com.livraison.partenaire',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyBnncDS1edVZpUkARvkfJIKMmz26SWkqms',
    appId: '1:813551314699:ios:ff5db41bd34066b01ce40e',
    messagingSenderId: '813551314699',
    projectId: 'sonaiyaa',
    storageBucket: 'sonaiyaa.firebasestorage.app',
    iosBundleId: 'com.livraison.partenaire',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDuEDOpkRn2Xy7W3ucES7QZ1LSB254nclw',
    appId: '1:813551314699:android:488d72cd8944a8891ce40e',
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