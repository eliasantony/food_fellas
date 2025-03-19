const { onRequest } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");

exports.appleSubscriptionWebhook = onRequest(async (req, res) => {
    console.log("Received Apple subscription event:", req.body);

    if (!req.body || !req.body.data) {
        console.error("Invalid Apple event payload.");
        return res.status(400).send("Invalid data");
    }

    try {
        const userId = req.body.data.signedTransactionInfo?.appAccountToken;
        if (!userId) {
            console.error("Missing user ID in Apple event.");
            return res.status(400).send("Invalid user data");
        }

        const status = req.body.notificationType; // "SUBSCRIBED", "EXPIRED", etc.
        const subscribed = status === "SUBSCRIBED" || status === "DID_RENEW";

        await admin.firestore().collection("users").doc(userId).update({ subscribed });
        console.log(`Updated Firestore for user ${userId}: subscribed = ${subscribed}`);

        res.status(200).send("OK");
    } catch (error) {
        console.error("Error processing Apple webhook:", error);
        res.status(500).send("Internal Server Error");
    }
});