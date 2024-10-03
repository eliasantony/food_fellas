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
