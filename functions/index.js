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

/* eslint-disable indent */

const functions = require("firebase-functions");
const admin = require("firebase-admin");
const axios = require("axios");
const uuidv4 = require("uuid").v4;
const Sentiment = require("sentiment");

admin.initializeApp();
const sentiment = new Sentiment();

exports.preprocessRecipe = functions.firestore
  .document("recipes/{recipeId}")
  .onWrite(async (change) => {
    const data = change.after.data();

    if (!data) return; // Exit if document is deleted

    // Extract ingredient names
    const ingredients = data.ingredients || [];
    const ingredientNames = ingredients.map(
      (ing) => ing.ingredient?.ingredientName || ""
    ).filter(name => name.trim() !== ""); // Remove empty strings

    // Extract tag names
    const tags = data.tags || [];
    const tagNames = tags.map((tag) => tag.name || "").filter((name) => name.trim() !== "");

    // Ensure averageRating has a default value
    const averageRating = data.averageRating || 0;

    await change.after.ref.set(
      {
        ingredientNames: ingredientNames, // Simple array of strings
        tagNames: tagNames, // Simple array of tag names
        averageRating: averageRating,
      },
      { merge: true }
    );

    // Update the author's recipeCount and averageRating
    const authorId = data.authorId;
    if (authorId) {
      await updateUserRecipeStats(authorId);
    }
  });

/**
 * Function to update user's recipe count and average rating.
 * @param {string} userId - The user's ID.
 * @return {Promise<void>}
 */
async function updateUserRecipeStats(userId) {
  const recipesSnapshot = await admin
    .firestore()
    .collection("recipes")
    .where("authorId", "==", userId)
    .get();

  let totalRating = 0;
  let totalReviews = 0;

  recipesSnapshot.forEach((doc) => {
    const data = doc.data();
    const recipeAverage = data.averageRating || 0;
    const recipeReviews = data.ratingsCount || 0;

    totalRating += recipeAverage * recipeReviews;
    totalReviews += recipeReviews;
  });

  const userRecipeCount = recipesSnapshot.size;
  const userAverageRating = totalReviews > 0 ? totalRating / totalReviews : 0.0;

  // Update the user's document
  await admin.firestore().collection("users").doc(userId).set(
    {
      recipeCount: userRecipeCount,
      averageRating: userAverageRating,
    },
    { merge: true }
  );
}

// Analyze sentiment of a comment when it is added
exports.analyzeCommentSentiment = functions.firestore
  .document("recipes/{recipeId}/comments/{commentId}")
  .onCreate(async (snap) => {
    const commentData = snap.data();
    const commentText = commentData.comment;

    if (commentText) {
      const result = sentiment.analyze(commentText);
      const sentimentScore = result.score;

      // Update the comment document with the sentiment score
      await snap.ref.set(
        {
          sentimentScore: sentimentScore,
        },
        {merge: true},
      );
    }
  });

// Function to update recipe's average rating when a rating is altered
exports.updateRecipeRating = functions.firestore
  .document("recipes/{recipeId}/ratings/{userId}")
  .onWrite(async (change, context) => {
    const recipeId = context.params.recipeId;
    const recipeRef = admin.firestore().collection("recipes").doc(recipeId);
    const ratingsRef = recipeRef.collection("ratings");

    // Get all ratings for the recipe
    const ratingsSnapshot = await ratingsRef.get();

    const ratingsCount = ratingsSnapshot.size;
    let totalRating = 0;
    const ratingCounts = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0};

    ratingsSnapshot.forEach((doc) => {
      const rating = doc.data().rating;
      totalRating += rating;
      ratingCounts[rating] = (ratingCounts[rating] || 0) + 1;
    });

    const averageRating = ratingsCount === 0 ? 0 : totalRating / ratingsCount;

    // Update the recipe document with new average rating and counts
    await recipeRef.update({
      averageRating,
      ratingsCount,
      ratingCounts,
    });

    // Get the author ID from the recipe document
    const recipeDoc = await recipeRef.get();
    const recipeData = recipeDoc.data();
    const authorId = recipeData.authorId;

    // Update the user's average rating
    await updateUserAverageRating(authorId);

    return null;
  });

/**
 * Function to update user's average rating based on all their recipes.
 * @param {string} userId - The user's ID.
 * @return {Promise<void>}
 */
async function updateUserAverageRating(userId) {
  const recipesSnapshot = await admin.firestore()
    .collection("recipes")
    .where("authorId", "==", userId)
    .get();

  let totalRating = 0;
  let totalReviews = 0;

  recipesSnapshot.forEach((doc) => {
    const data = doc.data();
    const recipeAverage = data.averageRating || 0;
    const recipeReviews = data.ratingsCount || 0;

    totalRating += recipeAverage * recipeReviews;
    totalReviews += recipeReviews;
  });

  const userAverageRating = totalReviews > 0 ? totalRating / totalReviews : 0;

  // Update the user's document
  await admin.firestore().collection("users").doc(userId).update({
    averageRating: userAverageRating,
    totalReviews: totalReviews,
  });
}

/**
 * Function to generate an image using getimg.ai API.
 * @param {object} data - The data containing the prompt.
 * @param {functions.https.CallableContext} context - The callable context.
 * @returns {Promise<object>}
 */
exports.generateImage = functions.https.onCall(async (data) => {
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
      const errorMessage =
        (response.data && response.data.error && response.data.error.message) ||
        "Unknown error";
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
    return {
      url: downloadUrl,
    };
  } catch (error) {
    console.error("Error generating image:", error);
    throw new functions.https.HttpsError("internal", error.message);
  }
});
