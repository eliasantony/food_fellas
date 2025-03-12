import 'package:cloud_firestore/cloud_firestore.dart';

// Returns a string like "2025-03-06" (YYYY-MM-DD) for today's date.
String getTodayDocId() {
  final now = DateTime.now();
  return "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
}

// Retrieves today's token usage for a given user.
Future<int> getDailyTokenUsage(String userId) async {
  final todayId = getTodayDocId();
  final usageRef = FirebaseFirestore.instance
      .collection('users')
      .doc(userId)
      .collection('daily_usage')
      .doc(todayId);

  final usageSnapshot = await usageRef.get();
  if (!usageSnapshot.exists) return 0;
  final totalTokensUsed = usageSnapshot.data()?['totalTokensUsed'] ?? 0;
  return totalTokensUsed;
}

// Updates today's token usage by incrementing it by usedTokens.
Future<void> updateDailyTokenUsage(String userId, int usedTokens) async {
  final todayId = getTodayDocId();
  final usageRef = FirebaseFirestore.instance
      .collection('users')
      .doc(userId)
      .collection('daily_usage')
      .doc(todayId);

  await usageRef.set({
    'totalTokensUsed': FieldValue.increment(usedTokens),
    'updatedAt': FieldValue.serverTimestamp(),
  }, SetOptions(merge: true));
}

// Checks whether the user is allowed to use AI chat given newTokens,
// using a different limit for free vs. premium users.
Future<bool> canUseAiChat(
    String userId, bool isSubscribed, int newTokens) async {
  // Set limits: free daily limit vs. premium daily limit.
  const freeLimit = 30000;
  const premiumLimit = 750000;
  final limit = isSubscribed ? premiumLimit : freeLimit;
  final currentUsage = await getDailyTokenUsage(userId);
  return (currentUsage + newTokens) <= limit;
}


