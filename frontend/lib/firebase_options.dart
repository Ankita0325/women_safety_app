import 'package:firebase_core/firebase_core.dart';

class DefaultFirebaseOptions {
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'demo-api-key',
    appId: 'demo-app-id',
    messagingSenderId: 'demo-sender-id',
    projectId: 'women-safety-demo',
    authDomain: 'women-safety-demo.firebaseapp.com',
    storageBucket: 'women-safety-demo.appspot.com',
  );

  static FirebaseOptions get currentPlatform {
    return web;
  }
}