const admin = require("firebase-admin");
const fetch = (...args) => import('node-fetch').then(({default: fetch}) => fetch(...args));

const serviceAccount = require("./serviceAccountKey.json");

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: "food-fellas-rts94q", // Replace with your Project ID
});

async function backfillNotifications() {
  const db = admin.firestore();

  try {
    // Fetch all users
    const usersSnapshot = await db.collection("users").get();

    if (usersSnapshot.empty) {
      console.log("No users found in the database.");
      return;
    }

    console.log(`Found ${usersSnapshot.size} users. Starting backfill...`);

    // Iterate over each user document
    const batch = db.batch(); // Use a batch to optimize writes
    usersSnapshot.forEach((userDoc) => {
      const userRef = userDoc.ref;

      // Update notifications data for each user
      batch.update(userRef, {
        notificationsEnabled: true,
        notifications: {
          newFollower: true,
          newRecipeFromFollowing: true,
          newComment: true,
          weeklyRecommendations: true,
        },
      });
    });

    // Commit the batch
    await batch.commit();
    console.log("Backfill completed successfully!");

  } catch (error) {
    console.error("Error backfilling notifications:", error);
  }
}

backfillNotifications().catch(console.error);