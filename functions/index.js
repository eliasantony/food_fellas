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

exports.calculateWeeklyRecommendations = functions
  .runWith({ memory: "1GB", timeoutSeconds: 300 }) // tune if needed
  .region("europe-west1")
  .https.onRequest(async (req, res) => {
    const apiKey = req.query.apiKey || req.headers["x-api-key"];
    if (apiKey !== functions.config().app.secure_api_key) {
      return res.status(403).send("Unauthorized");
    }
    try {
      // 1. Fetch all users with pagination
      console.log("Fetching users...");
      const users = await fetchCollectionWithPagination("users");
      console.log(`Fetched ${users.length} users`);

      // 2. Fetch all recipes with pagination
      console.log("Fetching recipes...");
      const recipes = await fetchCollectionWithPagination("recipes");
      console.log(`Fetched ${recipes.length} recipes`);

      // 3. For each user, compute top recommendations
      for (const user of users) {
        console.log(`Calculating recommendations for user ${user.id}`);
        const userRecommendations = [];

        for (const recipe of recipes) {
          // Compute a score for each recipe for this user
          const score = computeRecipeScore(user, recipe);
          userRecommendations.push({ recipeId: recipe.id, score });
        }

        // 4. Sort the user’s recommended recipes descending by score
        userRecommendations.sort((a, b) => b.score - a.score);

        // 5. Take top 5–10
        const topRecommendations = userRecommendations.slice(0, 10);

        // 6. Save to Firestore, e.g., a subcollection or field
        const recsRef = admin
          .firestore()
          .collection("users")
          .doc(user.id)
          .collection("recommendations");

        // Clear old recommendations if desired
        console.log(`Clearing old recommendations for user ${user.id}`);
        const oldRecsSnap = await recsRef.get();
        const batch = admin.firestore().batch();
        oldRecsSnap.forEach((doc) => batch.delete(doc.ref));
        await batch.commit();

        // Write new recommendations
        console.log(`Saving ${topRecommendations.length} recommendations for user ${user.id}`);
        const newBatch = admin.firestore().batch();
        topRecommendations.forEach((rec) => {
          const docRef = recsRef.doc(rec.recipeId);
          newBatch.set(docRef, {
            score: rec.score,
            recipeId: rec.recipeId,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
          });
        });
        await newBatch.commit();
      }

      console.log("Recommendations calculation complete.");
      res.status(200).send("Weekly recommendations calculated.");
    } catch (error) {
      console.error("Error calculating recommendations:", error);
      res.status(500).send("Error");
    }
  });

/**
 * Fetch a Firestore collection with pagination.
 */
async function fetchCollectionWithPagination(collectionName, limit = 100) {
  let data = [];
  let lastVisible = null;

  // Determine the field to order by
  const orderByField = collectionName === "users" ? "created_time" : "createdAt";

  do {
    console.log(`Querying ${collectionName} starting after:`, lastVisible);
    const query = admin
      .firestore()
      .collection(collectionName)
      .orderBy(orderByField)
      .startAfter(lastVisible || 0)
      .limit(limit);

    const snap = await query.get();
    console.log(`Fetched ${snap.size} documents from ${collectionName}`);

    if (!snap.empty) {
      data = data.concat(snap.docs.map((doc) => ({ id: doc.id, ...doc.data() })));
      lastVisible = snap.docs[snap.docs.length - 1];
    } else {
      console.log(`No more documents found in ${collectionName}`);
      lastVisible = null;
    }
  } while (lastVisible);

  return data;
}

/**
 * Enhanced scoring function with additional logic.
 */
function computeRecipeScore(user, recipe) {
  let score = 0;

  // 1. Dietary preference matches
  const userDietPrefs = user.dietaryPreferences || [];
  const recipeTags = recipe.tagNames || [];
  for (const pref of userDietPrefs) {
    if (recipeTags.includes(pref)) {
      score += 5; // or any weighting logic
    }
  }

  // 2. Favorite cuisines
  const userFavCuisines = user.favoriteCuisines || [];
  for (const favCuisine of userFavCuisines) {
    if (recipeTags.includes(favCuisine)) {
      score += 5;
    }
  }

  // 3. Recently viewed recipes
  const viewedRecently = user.subcollections?.interactionHistory?.map((i) => i.recipeId) || [];
  if (viewedRecently.includes(recipe.id)) {
    score += 2;
  }

  // 4. Recipes in user collections
  const collectionRecipes = user.subcollections?.collections?.flatMap((c) => c.recipes) || [];
  if (collectionRecipes.includes(recipe.id)) {
    score += 3;
  }

  // 5. Recipe from a followed author
  const followingAuthors = user.subcollections?.following?.map((f) => f.uid) || [];
  if (followingAuthors.includes(recipe.authorId)) {
    score += 3;
  }

  // 6. Popularity factor
  if (recipe.averageRating >= 4 && recipe.ratingsCount > 10) {
    score += 5;
  }

  return score;
}

exports.preprocessRecipe = functions
  .region("europe-west1")
  .firestore
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
exports.analyzeCommentSentiment = functions
  .region("europe-west1")
  .firestore
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
exports.updateRecipeRating = functions
  .region("europe-west1")
  .firestore
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
exports.generateImage = functions.region("europe-west1").https.onCall(async (data) => {
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
