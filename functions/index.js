/* eslint-disable indent */
const functions = require('firebase-functions/v2');
const { onRequest, onCall, HttpsError } = require("firebase-functions/v2/https");
const { onDocumentWritten, onDocumentCreated } = require("firebase-functions/v2/firestore");
const { onObjectFinalized } = require("firebase-functions/v2/storage");
const admin = require("firebase-admin");
const { getMessaging } = require("firebase-admin/messaging");
const axios = require("axios");
const uuidv4 = require("uuid").v4;
const Sentiment = require("sentiment");
const fs = require("fs");
const { GoogleGenerativeAI } = require("@google/generative-ai");
const { GoogleAIFileManager } = require("@google/generative-ai/server");
const sentiment = new Sentiment();

if (!admin.apps.length) {
    admin.initializeApp();
}

const { indexRecipeOnWrite, backfillRecipes } = require('./recipesSync');
const { indexUserOnWrite, backfillUsers } = require('./usersSync');

exports.indexRecipesOnWrite = onDocumentWritten(
  {
    document: "recipes/{recipeId}",
    region: "europe-west1",
    secrets: ["TYPESENSE_API_KEY"],
  },
  indexRecipeOnWrite
);
exports.backfillRecipesHttp = onRequest(
  {
    region: "europe-west1",
    secrets: ["TYPESENSE_API_KEY"],
  },
  backfillRecipes
);
exports.indexUsersOnWrite = onDocumentWritten(
  {
    document: "users/{userId}",
    region: "europe-west1",
    secrets: ["TYPESENSE_API_KEY"],
  },
  indexUserOnWrite
);
exports.backfillUsersHttp = onRequest(
  {
    region: "europe-west1",
    secrets: ["TYPESENSE_API_KEY"],
  },
  backfillUsers
);


const { appleSubscriptionWebhook } = require("./appleSubscription");
const { checkGoogleSubscription } = require("./googleSubscription");

exports.appleSubscriptionWebhook = appleSubscriptionWebhook;
exports.checkGoogleSubscription = checkGoogleSubscription;

exports.calculateWeeklyRecommendations = onRequest(
  {
    region: "europe-west1",
    timeoutSeconds: 300,
    availableMemoryMb: 1024, // 1GB
    secrets: ["GEMINI_API_KEY"],
  },
  async (req, res) => {
    const apiKey = process.env.GEMINI_API_KEY;
    if (!apiKey) {
      throw new Error("Missing Gemini API key");
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

      // 1. Filter for users that have weekly recommendations turned on
      const usersWithRecsEnabled = users.filter(
        (u) => u.notifications?.weeklyRecommendations && u.fcmToken
      );

      // 2. Send notifications in batches
      const messages = usersWithRecsEnabled.map((u) => ({
        token: u.fcmToken,
        notification: {
          title: "FoodFellas'",
          body: "Check out your new weekly recipe recommendations. 📆"
        },
        data: {
          type: "weekly_recommendations",
          click_action: "FLUTTER_NOTIFICATION_CLICK",
        },
      }));

      if (messages.length > 0) {
        const sendMessages = async () => {
          for (const msg of messages) {
            try {
              const response = await getMessaging().send(msg);
              console.log(`Message sent successfully to ${msg.token}:`, response);
            } catch (error) {
              console.error(`Error sending to ${msg.token}:`, error);
            }
          }
        };
        sendMessages(); 
        console.log(`${response.successCount} weekly recommendation notifications sent.`);
      }
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

exports.preprocessRecipe = onDocumentWritten(
  { 
    document: "recipes/{recipeId}",
    region: "europe-west1", 
    triggerRegion: "eur3",
  },
  async (event) => {
    const change = event.data;
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

exports.analyzeCommentSentiment = onDocumentCreated(
  {
    document: "recipes/{recipeId}/comments/{commentId}",
    region: "europe-west1",
    triggerRegion: "eur3",
  },
  async (event) => {
    const snap = event.data;
    const commentData = snap.data();
    const commentText = commentData.comment || "";
    const commentAuthorName = commentData.userName || "Someone";
    const recipeId = event.params.recipeId;
    const commentId = event.params.commentId;

    // 1. Only analyze sentiment if we actually have text
    //    (Alternatively, if you have 'photoOnly' flag, you can check that too.)
    if (commentText.trim().length > 0) {
      const result = sentiment.analyze(commentText);
      const sentimentScore = result.score;
      await snap.ref.set({ sentimentScore }, { merge: true });
    }

    // 2. Get the recipe doc to figure out who the author is
    const recipeRef = admin.firestore().collection("recipes").doc(recipeId);
    const recipeDoc = await recipeRef.get();
    if (!recipeDoc.exists) return;
    const recipeData = recipeDoc.data();
    const authorId = recipeData.authorId;
    if (!authorId) return;

    // 3. Get author user doc & check if notifications are enabled
    const authorDoc = await admin.firestore().collection("users").doc(authorId).get();
    if (!authorDoc.exists) return;

    const authorData = authorDoc.data();
    const notificationsEnabled = authorData.notifications?.newComment;
    const authorToken = authorData.fcmToken;

    if (!notificationsEnabled || !authorToken) return;

    // 4. Decide the notification body:
    //    If there's no text, let's assume it's a photo-only post
    let notificationBody;
    if (commentText.trim().length === 0) {
      notificationBody = `${commentAuthorName} just shared a new photo on your recipe! 📸`;
    } else {
      notificationBody = `${commentAuthorName} just commented on your recipe: "${commentText}"`;
    }

    // 5. Build the message
    const message = {
      data: {
        type: "new_comment",
        recipeId,
        commentId,
      },
      notification: {
        title: "FoodFellas",
        body: notificationBody,
      },
      token: authorToken,
    };

    // 6. Send
    getMessaging()
      .send(message)
      .then((response) => {
        console.log("Successfully sent message:", response);
      })
      .catch((error) => {
        console.error("Error sending message:", error);
      });
  }
);

// Function to update recipe's average rating when a rating is altered

exports.updateRecipeRating = onDocumentWritten(
  { 
    document: "recipes/{recipeId}/ratings/{userId}",
    region: "europe-west1",
    triggerRegion: "eur3",
  },
  async (event) => {
    const change = event.data;
    const recipeId = event.params.recipeId;
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

exports.generateImage = onCall(
  { 
    region: "europe-west1", 
    secrets: ["GETIMGAI_API_KEY"] 
  },
  async (data, context) => {
  
  const apiKey = process.env.GETIMGAI_API_KEY;
  if (!apiKey) {
    throw new HttpsError("internal", "Missing getimg.ai API key");
  }

  const prompt = data.data && data.data.prompt ? data.data.prompt : data.prompt;

  if (!prompt) {
    throw new HttpsError(
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
    throw new HttpsError("internal", error.message);
  }
});

exports.notifyOnNewFollower = onDocumentCreated(
  { 
    document: "users/{followedUid}/followers/{followerUid}",
    region: "europe-west1",     
    triggerRegion: "eur3", 
  },
  async (event) => {
    const snap = event.data;
    const followedUid = event.params.followedUid;
    const followerUid = event.params.followerUid;

    try {
      // 1. Fetch the followed user (the user who is receiving the follower)
      const followedUserDoc = await admin.firestore()
        .collection("users")
        .doc(followedUid)
        .get();
      if (!followedUserDoc.exists) return;

      const followedUserData = followedUserDoc.data();

      // 2. Check if notifications are enabled for "newFollower"
      if (!followedUserData.notifications?.newFollower) {
        return; // user disabled "new follower" notifications
      }

      // 3. Get followedUser's FCM token
      const fcmToken = followedUserData.fcmToken;
      if (!fcmToken) return;

      // 4. Get the follower's display name
      const followerUserDoc = await admin.firestore()
        .collection("users")
        .doc(followerUid)
        .get();

      const followerName = followerUserDoc.exists
        ? followerUserDoc.data().display_name || "Someone"
        : "Someone";

      // 5. Construct the notification
      const message = {
        data: {
          type: "new_follower",
          followerUid: followerUid,
          click_action: "FLUTTER_NOTIFICATION_CLICK",
        },
        notification: {
          title: "FoodFellas'",
          body: `You got a new Fella! ${followerName} just started following you. 🎉`,
        },
        token: fcmToken,
      };

      // 6. Send the push
      getMessaging().send(message)
      .then((response) => {
        console.log("Successfully sent message:", response);
      })
      .catch((error) => {
        console.error("Error sending message:", error);
      });
    } catch (error) {
      console.error("Error sending new follower notification:", error);
    }
  });

exports.notifyOnNewRecipe = onDocumentCreated(
  { 
    document: "recipes/{recipeId}",
    region: "europe-west1",
    triggerRegion: "eur3",
  },
  async (event) => {
    const snap = event.data;
    const newRecipe = snap.data();
    const authorId = newRecipe.authorId;
    const authorDoc = await admin.firestore().collection("users").doc(authorId).get();
    const authorName = authorDoc.exists ? authorDoc.data().display_name || "Someone" : "Someone";

    try {
      // 1. Fetch all the followers of this author
      const followersSnap = await admin.firestore()
        .collection("users")
        .doc(authorId)
        .collection("followers")
        .get();

      if (followersSnap.empty) return;

      // 2. For each follower, check notifications setting & FCM token
      const tokensToSend = [];
      for (const doc of followersSnap.docs) {
        const followerId = doc.id;
        const followerDoc = await admin.firestore()
          .collection("users")
          .doc(followerId)
          .get();

        if (!followerDoc.exists) continue;

        const followerData = followerDoc.data();
        const notifyEnabled = followerData.notifications?.newRecipeFromFollowing;
        const token = followerData.fcmToken;

        if (notifyEnabled && token) {
          tokensToSend.push(token);
        }
      }

      if (tokensToSend.length === 0) return;

      // 3. Build and send notifications individually
      const sendNotifications = async () => {
        for (const token of tokensToSend) {
          try {
            const message = {
              token,
              notification: {
              title: "FoodFellas'",
              body: `${authorName} just posted a new recipe. Take a look! 🍽️`,
              },
              data: {
              type: "new_recipe",
              recipeId: snap.id,
              click_action: "FLUTTER_NOTIFICATION_CLICK",
              },
            };

            const response = await getMessaging().send(message);
            console.log(`Notification sent successfully to ${token}:`, response);
          } catch (error) {
            console.error(`Error sending notification to ${token}:`, error);
          }
        }
      };

      await sendNotifications();
    } catch (error) {
      console.error("Error sending new recipe notification:", error);
    }
  });

async function uploadToGemini(path, mimeType, apiKey) {
  const fileManager = new GoogleAIFileManager(apiKey);
  const uploadResult = await fileManager.uploadFile(path, { mimeType, displayName: path });
  const file = uploadResult.file;
  console.log(`Uploaded file ${file.displayName} as: ${file.name}`);
  return file;
}

async function waitForFilesActive(files) {
  console.log("Waiting for file processing...");
  for (const name of files.map((file) => file.name)) {
    let file = await fileManager.getFile(name);
    while (file.state === "PROCESSING") {
      process.stdout.write(".");
      await new Promise((resolve) => setTimeout(resolve, 10000)); // 10 seconds delay
      file = await fileManager.getFile(name);
    }
    if (file.state !== "ACTIVE") {
      throw Error(`File ${file.name} failed to process`);
    }
  }
  console.log("...all files ready\n");
}


exports.processPdfForRecipes = onObjectFinalized(
  {
    region: "europe-west1",
    secrets: ["GEMINI_API_KEY"], 
  },
  async (object) => {
    const apiKey = process.env.GEMINI_API_KEY;
    if (!apiKey) {
      throw new Error("GEMINI_API_KEY is missing!");
    }

    // Create the clients here
    const genAI = new GoogleGenerativeAI(apiKey);
    const fileManager = new GoogleAIFileManager(apiKey);

    const filePath = object.name;
    if (!filePath || !filePath.startsWith("pdf_uploads/") || !filePath.endsWith(".pdf")) {
      console.log("Not a PDF in pdf_uploads folder. Skipping.");
      return;
    }

    const bucketName = object.bucket;
    const bucket = admin.storage().bucket(bucketName);
    const tempFilePath = `/tmp/${Date.now()}-temp.pdf`;

    // Step 1: Download the PDF
    await bucket.file(filePath).download({ destination: tempFilePath });

    // Step 2: Upload the PDF to Gemini
    const uploadedFile = await uploadToGemini(tempFilePath, "application/pdf", apiKey);

    // Step 3: Wait for the file to be active
    await waitForFilesActive([uploadedFile]);

    // Step 4: Start a chat session and process the PDF
    const model = genAI.getGenerativeModel({
      model: "gemini-2.0-flash",
      systemInstruction: `
      You are a smart cooking assistant for FoodFellas. The user will provide one or more PDF Files of recipes. Your goal is to accurately translate them to english, extract the recipes and transform them into one json Object! Provide a valid JSON response in the following format:

      {
      "title": "String",
      "description": "String",
      "cookTime": int,
      "prepTime": int,
      "totalTime": int,
      "ingredients": [
        {
        "ingredient": {
          "ingredientName": "String",
          "category": "String"
        },
        "baseAmount": int,
        "unit": "String",
        "servings": int
        }
      ],
      "calories": int,
      "protein": int,
      "carbs": int,
      "fat": int,
      "initialServings": int,
      "cookingSteps": [
        "String"
      ],
      "tags": [
        {"id": "String", "name": "String", "icon": "Emoji", "category": "String"}
      ],
      }

      Example of one Full Recipe JSON:

      {
      "title": "Chicken Alfredo Pasta 🍲",
      "description": "A creamy and delicious pasta dish with grilled chicken and Alfredo sauce.",
      "cookTime": 10,
      "prepTime": 20,
      "totalTime": 30,
      "ingredients": [
        {
        "ingredient": {
          "ingredientName": "Penne Pasta",
          "category": "Pasta"
        },
        "baseAmount": 250,
        "unit": "g",
        "servings": 2
        },
        {
        "ingredient": {
          "ingredientName": "Chicken Breast",
          "category": "Poultry"
        },
        "baseAmount": 200,
        "unit": "g",
        "servings": 2
        },
        ...
      ],
      "calories": 550,
      "protein": 31,
      "carbs": 46,
      "fat": 13,
      "initialServings": 2,
      "cookingSteps": [
        "Cook the penne pasta according to package instructions.",
        ...
      ],
      "tags": [
        {"id": "tag1", "name": "Vegetarian", "icon": "🥕", "category": "Dietary Preferences"},
        {"id": "tag2", "name": "Italian", "icon": "🍕", "category": "Cuisines"}
      ],
      }

      If the user provided multiple recipes in one PDF file, you should return an array of JSON objects, one for each recipe.

      Additional Requirements:
      • Make sure the recipe is in English.
      • Only use following Categories for the Ingredients: "Vegetable","Fruit","Grain","Protein","Dairy","Spice & Seasoning","Fat & Oil","Herb","Seafood","Condiment","Nuts & Seeds","Legume","Other". Try finding the most suitable category for each ingredient.
      • Use metric units for measurements ("g","kg","ml","pieces","slices","tbsp","tsp","pinch","unit","bottle","can","other",).
      • Use spices and seasonings accurately.
      • Try to make the recipe as good tasting as possible.
      • If the macro values (calories (kcal), protein, carbs, fat) are not stated in the recipe, try to figure them out exactly for 1 serving by looking at the ingredients.
      • These are the available Tags you can use: "Breakfast", "Lunch", "Dinner", "Snack", "Dessert", "Appetizer", "Beverage", "Brunch", "Side Dish", "Soup", "Salad", "Under 15 minutes", "Under 30 minutes", "Under 1 hour", "Over 1 hour", "Slow Cook", "Quick & Easy", "Easy", "Medium", "Hard", "Beginner Friendly", "Intermediate", "Expert", "Vegetarian", "Vegan", "Gluten-Free", "Dairy-Free", "Nut-Free", "Halal", "Kosher", "Paleo", "Keto", "Pescatarian", "Low-Carb", "Low-Fat", "High-Protein", "Sugar-Free", "Italian", "Mexican", "Chinese", "Indian", "Japanese", "Mediterranean", "American", "Thai", "French", "Greek", "Korean", "Vietnamese", "Spanish", "Middle Eastern", "Caribbean", "African", "German", "Brazilian", "Peruvian", "Turkish", "Other", "Grilling", "Baking", "Stir-Frying", "Steaming", "Roasting", "Slow Cooking", "Raw", "Frying", "Pressure Cooking", "No-Cook", "Party", "Picnic", "Holiday", "Casual", "Formal", "Date Night", "Family Gathering", "Game Day", "BBQ", "Healthy", "Comfort Food", "Spicy", "Sweet", "Savory", "Budget-Friendly", "Kids Friendly", "High Fiber", "Low Sodium", "Seasonal", "Organic", "Gourmet"
      • Try to add as many relevant tags as possible to make the recipe more discoverable.
      `,
    });

    const chatSession = model.startChat({
      history: [
        {
          role: "user",
          parts: [
            {
              fileData: {
                mimeType: uploadedFile.mimeType,
                fileUri: uploadedFile.uri,
              },
            },
          ],
        },
      ],
    });

    const result = await chatSession.sendMessage("Process the uploaded PDF and extract recipes.");
    let responseText = result.response.text();
    responseText = responseText.replace(/^```json\s*/i, "").replace(/\s*```$/, "").trim();

    // Step 5: Parse and save the response to Firestore
    let parsedJson;
    try {
      parsedJson = JSON.parse(responseText);
    } catch (err) {
      console.error("Could not parse model response as JSON:", err);
      return;
    }

    const recipeArray = Array.isArray(parsedJson) ? parsedJson : [parsedJson];

    const metadata = object.metadata || {};
    const batchId = metadata.batchId || "defaultBatch";

    const resultsRef = admin
      .firestore()
      .collection("pdfProcessingResults")
      .doc(batchId)
      .collection("files")
      .doc(object.name.replace(/\//g, "_"));

    await resultsRef.set({
      fileName: filePath,
      processedAt: admin.firestore.FieldValue.serverTimestamp(),
      recipes: recipeArray,
      imported: false,
    });

    console.log("Recipes saved successfully!");

    // Step 6: Notify the user
    const uploaderUid = object.metadata?.uploaderUid;
    if (uploaderUid) {
      await notifyUserPdfDone(uploaderUid, filePath);
    }
  });

async function notifyUserPdfDone(uploaderUid, fileName) {
  const userDoc = await admin.firestore().collection("users").doc(uploaderUid).get();
  if (!userDoc.exists) return;
  const userData = userDoc.data();

  const fcmToken = userData.fcmToken;
  if (!fcmToken) return;

  try {
    const message = {
      token: fcmToken,
      notification: {
        title: "FoodFellas'",
        body: `Your PDF ${fileName} has been converted to recipes!`,
      },
      data: {
        type: "pdf_processing_done",
        fileName: fileName,
        click_action: "FLUTTER_NOTIFICATION_CLICK",
      },
    };

    const response = await getMessaging().send(message);
    console.log(`PDF notification sent successfully to ${fcmToken}:`, response);
  } catch (error) {
    console.error(`Error sending PDF notification to ${fcmToken}:`, error);
  }
}