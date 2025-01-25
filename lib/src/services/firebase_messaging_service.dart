import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'dart:developer';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:food_fellas/main.dart';
import 'package:food_fellas/src/views/profile_screen.dart';
import 'package:food_fellas/src/views/recipeDetails_screen.dart';

/// Request notification permissions for iOS.
Future<void> requestNotificationPermissions() async {
  print('Requesting notification permissions...');
  FirebaseMessaging messaging = FirebaseMessaging.instance;

  NotificationSettings settings = await messaging.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  print('User granted permission: ${settings.authorizationStatus}');
}

// This function must be a top-level function or static method.
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // If you're going to use other Firebase services in the background,
  // such as Firestore, you must call `initializeApp` again (only if not already initialized).
  print('Handling a background message: ${message.messageId}');
}

Future<void> saveTokenToDatabase() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user != null) {
    final token = await FirebaseMessaging.instance.getToken();
    if (token != null) {
      // Store the token
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({'fcmToken': token});
    }
  }
}

Future<void> initLocalNotifications() async {
  // Standard initialization
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('app_icon');
  final DarwinInitializationSettings initializationSettingsIOS =
      DarwinInitializationSettings(
    requestAlertPermission: true,
    requestBadgePermission: true,
    requestSoundPermission: true,
  );
  final InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
    iOS: initializationSettingsIOS,
  );
  await flutterLocalNotificationsPlugin.initialize(initializationSettings);

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

Future<void> showNotification(String? title, String? body) async {
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
  );
}

void handleNotificationNavigation(Map<String, dynamic> data) {
  final nav = globalNavigatorKey.currentState;
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
      // Possibly navigate to a "Recommendations" screen
      // nav.push(...)
      break;

    default:
      print("No matching notification type found: $type");
      break;
  }
}
