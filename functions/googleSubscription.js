const { google } = require("googleapis");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const admin = require("firebase-admin");

const playDeveloperApi = google.androidpublisher("v3");
const serviceAccountKey = require("./serviceAccountKey.json");

async function getGoogleClient() {
    const auth = new google.auth.GoogleAuth({
        credentials: serviceAccountKey,
        scopes: ["https://www.googleapis.com/auth/androidpublisher"],
    });
    return auth.getClient();
}

exports.checkGoogleSubscription = onSchedule("every 24 hours", async () => {
    console.log("Running scheduled Google subscription check");

    const usersSnapshot = await admin.firestore().collection("users").get();
    const authClient = await getGoogleClient();

    for (const userDoc of usersSnapshot.docs) {
        const userData = userDoc.data();
        if (!userData || !userData.receiptToken) continue;

        const packageName = "com.foodfellas.app";
        const subscriptionId = "premsub";
        const purchaseToken = userData.receiptToken;

        try {
            const response = await playDeveloperApi.purchases.subscriptions.get({
                auth: authClient,
                packageName,
                subscriptionId,
                token: purchaseToken,
            });

            const subscription = response.data;
            console.log(`Google Subscription Status for user ${userDoc.id}:`, subscription);

            // Check if subscription is valid
            const expiryTime = new Date(parseInt(subscription.expiryTimeMillis));
            const isActive = (subscription.autoRenewing || expiryTime > new Date()) && subscription.paymentState === 1;

            await admin.firestore().collection("users").doc(userDoc.id).update({
                subscribed: isActive,
            });

            console.log(`Updated Firestore: user ${userDoc.id} -> subscribed: ${isActive}`);
        } catch (error) {
            console.error(`Error checking Google subscription for user ${userDoc.id}:`, error);
        }
    }

    console.log("Google subscription check completed");
});