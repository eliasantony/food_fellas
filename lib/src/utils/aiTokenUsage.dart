import 'package:cloud_firestore/cloud_firestore.dart';

Future<void> updateUserTokenUsage(String userId, int usedTokens) async {
  // Determine "YYYY-MM" as the doc ID, so usage is tracked monthly
  final now = DateTime.now();
  final yearMonth = "${now.year}-${now.month.toString().padLeft(2, '0')}";

  final usageRef = FirebaseFirestore.instance
      .collection('users')
      .doc(userId)
      .collection('usage')
      .doc(yearMonth);

  await usageRef.set({
    'totalTokensUsed': FieldValue.increment(usedTokens),
    'updatedAt': FieldValue.serverTimestamp(),
  }, SetOptions(merge: true));
}

Future<bool> checkLimitExceeded(String userId) async {
  const tokenLimit = 250000;

  // Fetch user role
  final userRef = FirebaseFirestore.instance.collection('users').doc(userId);
  final userSnapshot = await userRef.get();
  final userRole = userSnapshot.data()?['role'] ?? 'user';

  // If user is admin, return false
  if (userRole == 'admin') {
    return false;
  }

  final now = DateTime.now();
  final yearMonth = "${now.year}-${now.month.toString().padLeft(2, '0')}";

  final usageRef = FirebaseFirestore.instance
      .collection('users')
      .doc(userId)
      .collection('usage')
      .doc(yearMonth);

  final usageSnapshot = await usageRef.get();
  if (!usageSnapshot.exists) return false; // no usage yet => not exceeded

  final totalTokensUsed = usageSnapshot.data()?['totalTokensUsed'] ?? 0;
  return totalTokensUsed > tokenLimit;
}
