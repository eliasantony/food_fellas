import { onRequest } from "firebase-functions/v2/https";
import { jwtVerify, createRemoteJWKSet } from "jose";
import { URL } from "url";
import admin from "firebase-admin";

const bundleId = process.env.APPLE_BUNDLE_ID || 'com.example.foodFellas';

// Initialize Firebase if not already
if (!admin.apps.length) {
  admin.initializeApp();
}

// Apple JWK URL
const appleJwkUrl = new URL("https://api.storekit.itunes.apple.com/in-app-purchase/publicKeys");
const jwks = createRemoteJWKSet(appleJwkUrl);

export const appleSubscriptionWebhook = onRequest(
  { invoker: "public" },
  async (req, res) => {
    console.log("🔔 Received Apple subscription event");

    // Only accept POST from Apple
    if (req.method !== "POST") {
      return res.status(405).send("Method Not Allowed");
    }

    const signedJWT = req.body?.data?.signedTransactionInfo;
    if (!signedJWT) {
      console.error("❌ No signedTransactionInfo found:", req.body);
      return res.status(400).send("Missing data");
    }

    try {
      const { payload } = await jwtVerify(signedJWT, jwks, {
        issuer: "https://apple.com",
        audience: bundleId,
      });

      const userId = payload.appAccountToken;
      const productId = payload.productId;
      const status = req.body.notificationType;

      if (!userId) {
        console.error("❌ appAccountToken missing in JWT payload:", payload);
        return res.status(400).send("Invalid user");
      }

      const subscribed = ["SUBSCRIBED", "DID_RENEW"].includes(status);

      await admin
        .firestore()
        .collection("users")
        .doc(userId)
        .set(
          {
            subscribed,
            lastVerifiedProduct: productId,
            lastStatus: status,
            updatedAt: admin.firestore.Timestamp.now(),
          },
          { merge: true }
        );

      console.log(`✅ User ${userId} updated: subscribed = ${subscribed}`);
      return res.status(200).send("OK");
    } catch (err) {
      console.error("❌ JWT verification failed:", err);
      return res.status(401).send("Invalid signature");
    }
  }
);