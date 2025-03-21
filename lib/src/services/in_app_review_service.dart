import 'package:flutter/material.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class InAppReviewService {
  static final InAppReview _inAppReview = InAppReview.instance;

  /// Requests an in-app review if conditions are met
  static Future<void> requestReview() async {
    debugPrint('Requesting review...');
    final prefs = await SharedPreferences.getInstance();
    final int appOpens = prefs.getInt('app_opens') ?? 0;
    final bool hasReviewed = prefs.getBool('has_reviewed') ?? false;

    // Only increase app opens when conditions are met
    if (!hasReviewed) {
      prefs.setInt('app_opens', appOpens + 1); // Update app open count

      // Only ask if user hasn't reviewed & at the right intervals
      if ((appOpens == 4 || appOpens % 3 == 0)) {
        if (await _inAppReview.isAvailable()) {
          await _inAppReview.requestReview();
          // No longer setting `hasReviewed = true` immediately
        }
      }
    }
  }

  /// Opens the App Store / Play Store listing and marks as reviewed
  static Future<void> openStoreListing() async {
    await _inAppReview.openStoreListing(
      appStoreId: '6741926857', // iOS App Store ID
    );

    // Mark as reviewed when store listing is manually opened
    final prefs = await SharedPreferences.getInstance();
    prefs.setBool('has_reviewed', true);
  }

  /// Opens the Play Store listing for Android manually
  static Future<void> openPlayStore() async {
    const packageName = "com.foodfellas.app";
    final url = "https://play.google.com/store/apps/details?id=com.foodfellas.app";
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }
}
