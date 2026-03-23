import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

/// Firebase options configuradas para sacdia-app.
///
/// Nota: este archivo reemplaza temporalmente la generación automática de
/// FlutterFire CLI para evitar errores de inicialización durante setup local.
///
/// SECURITY NOTE — Firebase API keys are PUBLIC identifiers, not secrets.
/// They are required in the compiled app binary and cannot be hidden.
/// Security is enforced through:
///   1. Firebase Security Rules (Firestore / Storage / RTDB)
///   2. API key restrictions in Google Cloud Console:
///      - Android key: restrict to SHA-1 fingerprint(s) of the app
///      - iOS key: restrict to the iOS bundle ID (com.sacdia.app)
///   3. Firebase App Check (recommended for production)
/// See: https://firebase.google.com/docs/projects/api-keys
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'DefaultFirebaseOptions no está configurado para Web en este proyecto.',
      );
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        throw UnsupportedError(
          'DefaultFirebaseOptions no está configurado para esta plataforma.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBmVb8eTW8p_Yk1qXjmj1jx3URQq4WIiJ8',
    appId: '1:124214864269:android:6edeef4b62436543cd75c4',
    messagingSenderId: '124214864269',
    projectId: 'sacdia-dev',
    storageBucket: 'sacdia-dev.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCND8N7kBwf4HpdEs7xlMatnVMuLUr04Pk',
    appId: '1:124214864269:ios:cfc678d229a6ac98cd75c4',
    messagingSenderId: '124214864269',
    projectId: 'sacdia-dev',
    storageBucket: 'sacdia-dev.firebasestorage.app',
    iosBundleId: 'com.sacdia.app',
  );
}
