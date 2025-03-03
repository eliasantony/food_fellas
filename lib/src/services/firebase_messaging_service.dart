import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:food_fellas/src/views/home_screen.dart';
import 'package:food_fellas/src/views/profile_screen.dart';
import 'package:food_fellas/src/views/recipeDetails_screen.dart';
import 'package:food_fellas/main.dart' show globalNavigatorKey;

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

/// Request notification permissions for iOS and Android (if needed).
Future<NotificationSettings> requestNotificationPermissions() async {
  if (kDebugMode) {
    print('Requesting notification permissions...');
  }
  FirebaseMessaging messaging = FirebaseMessaging.instance;

  NotificationSettings settings = await messaging.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  if (kDebugMode) {
    print('User granted permission: ${settings.authorizationStatus}');
  }
  return settings;
}

/// This function must be a top-level function or static method.
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // If you're going to use other Firebase services in the background,
  // such as Firestore, you must call `initializeApp` again (only if not already initialized).

  if (kDebugMode) {
    print('Handling a background message: ${message.messageId}');
  }
}

Future<void> saveTokenToDatabase() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    if (kDebugMode) {
      print('No user is currently signed in.');
    }
    return;
  }
  String? token = await FirebaseMessaging.instance.getToken();
  if (token == null) {
    if (kDebugMode) {
      print('Failed to obtain FCM token.');
    }
    return;
  }

  try {
    await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
      {
        'fcmToken': token,
      },
      SetOptions(merge: true),
    );
    if (kDebugMode) {
      print('FCM Token saved/updated successfully.');
    }
  } catch (e) {
    if (kDebugMode) {
      print('Error saving FCM Token: $e');
    }
  }
}

Future<void> removeTokenFromDatabase() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user != null) {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .update({'fcmToken': FieldValue.delete()});
    if (kDebugMode) {
      print("FCM Token removed from database.");
    }
  }
}

Future<void> initLocalNotifications() async {
  // Standard initialization
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('app_icon');
  final DarwinInitializationSettings initializationSettingsIOS =
      DarwinInitializationSettings(
    requestAlertPermission: false,
    requestBadgePermission: false,
    requestSoundPermission: false,
  );
  final InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
    iOS: initializationSettingsIOS,
  );
  await flutterLocalNotificationsPlugin.initialize(
    initializationSettings,
    onDidReceiveNotificationResponse: (NotificationResponse response) {
      debugPrint("Local notification tapped: ${response.payload}");
      if (response.payload != null && response.payload!.isNotEmpty) {
        final Map<String, dynamic> data = jsonDecode(response.payload!);
        handleNotificationNavigation(data);
      }
    },
  );

  // Only for Android:
  if (Platform.isAndroid) {
    const AndroidNotificationChannel socialChannel = AndroidNotificationChannel(
      'social_updates_channel', // ID
      'Social Updates', // Name
      description: 'For likes, follows, etc.',
      importance: Importance.defaultImportance,
    );

    const AndroidNotificationChannel recommendationChannel =
        AndroidNotificationChannel(
      'recommendations_channel',
      'Weekly Recommendations',
      description: 'Weekly tips or recommended recipes.',
      importance: Importance.defaultImportance,
    );

    const AndroidNotificationChannel generalChannel =
        AndroidNotificationChannel(
      'general_channel',
      'General Notifications',
      description: 'General app notifications.',
      importance: Importance.defaultImportance,
    );

    final androidImplementation =
        flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidImplementation != null) {
      await androidImplementation.createNotificationChannel(socialChannel);
      await androidImplementation
          .createNotificationChannel(recommendationChannel);
      await androidImplementation.createNotificationChannel(generalChannel);
    }
  }
}

Future<void> showNotification(
    String? title, String? body, Map<String, dynamic> data) async {
  debugPrint('Showing notification: $title, $body with data: $data');
  // Convert data to JSON string to use as payload.
  final String payload = jsonEncode(data);

  const AndroidNotificationDetails androidPlatformChannelSpecifics =
      AndroidNotificationDetails(
    'default_channel',
    'Default Channel',
    channelDescription: 'Used for important notifications.',
    importance: Importance.max,
    priority: Priority.high,
  );
  const NotificationDetails platformChannelSpecifics =
      NotificationDetails(android: androidPlatformChannelSpecifics);
  await flutterLocalNotificationsPlugin.show(
    0, // notification id
    title,
    body,
    platformChannelSpecifics,
    payload: payload,
  );

  // handleNotificationNavigation(data);
}

void handleNotificationNavigation(Map<String, dynamic> data) {
  debugPrint('Handling notification: $data');
  final nav = globalNavigatorKey.currentState;
  debugPrint('Navigator: $nav');
  if (nav == null) return;
  final type = data['type'];
  switch (type) {
    case 'new_recipe':
      final recipeId = data['recipeId'];
      if (recipeId != null) {
        nav.push(
          MaterialPageRoute(
            builder: (_) => RecipeDetailScreen(recipeId: recipeId),
          ),
        );
      }
      break;

    case 'new_comment':
      final recipeId = data['recipeId'];
      if (recipeId != null) {
        nav.push(
          MaterialPageRoute(
            builder: (_) => RecipeDetailScreen(recipeId: recipeId),
          ),
        );
      }
      break;

    case 'new_follower':
      // Possibly navigate to the follower's profile
      final followerUid = data['followerUid'];
      if (followerUid != null) {
        nav.push(
          MaterialPageRoute(
            builder: (_) => ProfileScreen(userId: followerUid),
          ),
        );
      }
      break;

    case 'weekly_recommendations':
      nav.push(
        MaterialPageRoute(
          builder: (_) => HomeScreen(),
        ),
      );
      break;

    default:
      if (kDebugMode) {
        print("No matching notification type found: $type");
      }
      break;
  }
}
