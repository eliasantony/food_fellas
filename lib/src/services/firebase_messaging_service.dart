import 'package:firebase_messaging/firebase_messaging.dart';
import 'dart:developer';

// This function must be a top-level function or static method.
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // If you're going to use other Firebase services in the background,
  // such as Firestore, you must call `initializeApp` again (only if not already initialized).
  print('Handling a background message: ${message.messageId}');
}
