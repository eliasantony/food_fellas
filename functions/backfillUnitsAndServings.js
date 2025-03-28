const admin = require("firebase-admin");
const serviceAccount = require("./serviceAccountKey.json");

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: "food-fellas-rts94q",
});

async function backfillIngredients() {
  const db = admin.firestore();

  try {
    // Fetch all recipes
    const recipesSnapshot = await db.collection("recipes").get();

    if (recipesSnapshot.empty) {
      console.log("No recipes found in the database.");
      return;
    }

    console.log(`Found ${recipesSnapshot.size} recipes. Starting backfill...`);

    // Iterate over each recipe document
    const batch = db.batch(); // Use a batch to optimize writes
    recipesSnapshot.forEach((recipeDoc) => {
      const recipeRef = recipeDoc.ref;
      const recipe = recipeDoc.data();

      // Iterate over ingredients to backfill units and servings
      recipe.ingredients.forEach((ingredient, index) => {
        // Backfill unit if null or empty
        if (!ingredient.unit || ingredient.unit.trim() === "") {
          ingredient.unit = "g"; // Default to grams
        }

        // Backfill servings if null
        if (ingredient.servings === null || ingredient.servings === undefined) {
          ingredient.servings = recipe.initialServings || 1; // Use recipe's initialServings if available
        }

        // Update ingredient in the recipe
        batch.update(recipeRef, {
          [`ingredients.${index}`]: ingredient,
        });
      });
    });

    // Commit the batch
    await batch.commit();
    console.log("Backfill completed successfully!");

  } catch (error) {
    console.error("Error backfilling ingredients:", error);
  }
}

backfillIngredients().catch(console.error);