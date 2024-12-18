const admin = require("firebase-admin");

const serviceAccount = require("./serviceAccountKey.json");

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: "food-fellas-rts94q" // Replace with your Project ID
});

async function backfillData() {
  const db = admin.firestore();

  console.log("Starting backfill for recipes...");

  // Backfill for recipes
  const recipesSnapshot = await db.collection("recipes").get();
  for (const recipeDoc of recipesSnapshot.docs) {
    const data = recipeDoc.data();

    // Extract ingredient names
    const ingredients = data.ingredients || [];
    const ingredientNames = ingredients.map(
      (ing) => ing.ingredient?.ingredientName || ""
    ).filter(name => name.trim() !== ""); // Remove empty strings

    // Extract tag names
    const tags = data.tags || [];
    const tagNames = tags.map((tag) => tag.name || "").filter((name) => name.trim() !== "");

    await recipeDoc.ref.set(
      {
        ingredientNames: ingredientNames,
        tagNames: tagNames,
      },
      { merge: true }
    );
    console.log(`Updated recipe: ${recipeDoc.id}`);
  }

  console.log("Backfill for recipes completed!");

  console.log("Starting backfill for users...");

  // Backfill for users
  const usersSnapshot = await db.collection("users").get();
  for (const userDoc of usersSnapshot.docs) {
    const userId = userDoc.id;

    const recipesSnapshot = await db
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

    const recipeCount = recipesSnapshot.size;
    const averageRating = totalReviews > 0 ? totalRating / totalReviews : 0.0;

    await userDoc.ref.set(
      {
        recipeCount: recipeCount, // Consistent naming
        averageRating: averageRating,
      },
      { merge: true }
    );
    console.log(`Updated user: ${userId}`);
  }

  console.log("Backfill for users completed!");
}

backfillData().catch(console.error);