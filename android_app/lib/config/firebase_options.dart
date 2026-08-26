import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static const String databaseURL =
      'https://weather-monitor-f4248-default-rtdb.asia-southeast1.firebasedatabase.app';
  static const String projectId = 'weather-monitor-f4248';
  static const String apiKey = 'AIzaSyDwj9XVfQ5UNBbeVEbPc6JXfVmiASvlxVk';
  static const String appId = '1:810819107820:web:e2d07aaac099c9fd551ec9';
  static const String messagingSenderId = '810819107820';
  static const String storageBucket = 'weather-monitor-f4248.firebasestorage.app';

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
        return linux;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not configured for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: apiKey,
    appId: appId,
    messagingSenderId: messagingSenderId,
    projectId: projectId,
    authDomain: 'weather-monitor-f4248.firebaseapp.com',
    databaseURL: databaseURL,
    storageBucket: storageBucket,
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: apiKey,
    appId: appId,
    messagingSenderId: messagingSenderId,
    projectId: projectId,
    databaseURL: databaseURL,
    storageBucket: storageBucket,
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: apiKey,
    appId: appId,
    messagingSenderId: messagingSenderId,
    projectId: projectId,
    databaseURL: databaseURL,
    storageBucket: storageBucket,
    iosBundleId: 'com.meteorologus.androidApp',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: apiKey,
    appId: appId,
    messagingSenderId: messagingSenderId,
    projectId: projectId,
    databaseURL: databaseURL,
    storageBucket: storageBucket,
    iosBundleId: 'com.meteorologus.androidApp',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: apiKey,
    appId: appId,
    messagingSenderId: messagingSenderId,
    projectId: projectId,
    authDomain: 'weather-monitor-f4248.firebaseapp.com',
    databaseURL: databaseURL,
    storageBucket: storageBucket,
  );

  static const FirebaseOptions linux = FirebaseOptions(
    apiKey: apiKey,
    appId: appId,
    messagingSenderId: messagingSenderId,
    projectId: projectId,
    authDomain: 'weather-monitor-f4248.firebaseapp.com',
    databaseURL: databaseURL,
    storageBucket: storageBucket,
  );
}
