/* eslint-disable indent */

/**
 * Import function triggers from their respective submodules:
 *
 * const {onCall} = require("firebase-functions/v2/https");
 * const {onDocumentWritten} = require("firebase-functions/v2/firestore");
 *
 * See a full list of supported triggers at https://firebase.google.com/docs/functions
 */

// const {onRequest} = require("firebase-functions/v2/https");
// const logger = require("firebase-functions/logger");

// Create and deploy your first functions
// https://firebase.google.com/docs/functions/get-started

// exports.helloWorld = onRequest((request, response) => {
//   logger.info("Hello logs!", {structuredData: true});
//   response.send("Hello from Firebase!");
// });

const functions = require("firebase-functions");
const admin = require("firebase-admin");
const axios = require("axios");
const uuidv4 = require("uuid").v4;
admin.initializeApp();

exports.updateRecipeRating = functions.firestore
  .document("recipes/{recipeId}/ratings/{userId}")
  .onWrite(async (change, context) => {
    const recipeId = context.params.recipeId;
    const recipeRef = admin.firestore().collection("recipes").doc(recipeId);
    const ratingsRef = recipeRef.collection("ratings");

    const ratingsSnapshot = await ratingsRef.get();

    const ratingsCount = ratingsSnapshot.size;
    let totalRating = 0;

    ratingsSnapshot.forEach((doc) => {
      totalRating += doc.data().rating;
    });

    const averageRating = ratingsCount === 0 ? 0 : totalRating / ratingsCount;

    await recipeRef.update({
      averageRating: averageRating,
      ratingsCount: ratingsCount,
    });

    return null;
  });

  exports.generateImage = functions.https.onCall(async (data, context) => {
    const apiKey = functions.config().getimgai.apikey;
    const prompt = data.prompt;
    if (!prompt) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "The function must be called with a prompt.",
      );
    }
    try {
      // Call getimg.ai API
      const response = await axios.post(
        "https://api.getimg.ai/v1/stable-diffusion-xl/text-to-image",
        {
          model: "stable-diffusion-xl-v1-0",
          prompt: prompt,
          response_format: "url",
          width: 1024,
          height: 1024,
          // Include other parameters as needed, e.g., steps, guidance, etc.
        },
        {
          headers: {
            "Content-Type": "application/json",
            "Accept": "application/json",
            "Authorization": `Bearer ${apiKey}`,
          },
        },
      );
      if (response.status !== 200) {
        const errorMessage = (response.data.error.message) || "Unknown error";
        throw new Error(`getimg.ai API error: ${errorMessage}`);
      }
      const imageUrl = response.data.url;
      if (!imageUrl) {
        throw new Error("No image URL returned from getimg.ai API.");
      }
      // Download the image
      const imageResponse = await axios.get(imageUrl, {
        responseType: "arraybuffer",
      });
      const imageBuffer = imageResponse.data;
      // Upload the image to Firebase Storage
      const bucket = admin.storage().bucket();
      const fileName = `generated_images/${uuidv4()}.png`;
      const file = bucket.file(fileName);
      const token = uuidv4(); // Generate a UUID for the token
      await file.save(imageBuffer, {
        metadata: {
          contentType: "image/png",
          metadata: {
            firebaseStorageDownloadTokens: token,
          },
        },
      });
      // Construct the download URL
      const downloadUrl = `https://firebasestorage.googleapis.com/v0/b/${bucket.name}/o/${encodeURIComponent(fileName)}?alt=media&token=${token}`;
      return {url: downloadUrl};
    } catch (error) {
      console.error("Error generating image:", error);
      throw new functions.https.HttpsError("internal", error.message);
    }
  });
