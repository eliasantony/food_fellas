const admin = require("firebase-admin");
const fetch = (...args) => import('node-fetch').then(({default: fetch}) => fetch(...args));

const serviceAccount = require("./serviceAccountKey.json");

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: "food-fellas-rts94q", // Replace with your Project ID
});

const EMBEDDING_API_URL =
  "https://generativelanguage.googleapis.com/v1beta/models/text-embedding-004:embedContent?key=AIzaSyArlpTcKOjSfhia7IU19CB89qpk_wlBbjw"; // Replace with your API key

async function generateEmbedding(text) {
  const response = await fetch(EMBEDDING_API_URL, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      model: "models/text-embedding-004",
      content: {
        parts: [{ text: text }],
      },
    }),
  });

  if (!response.ok) {
    throw new Error(`Failed to generate embedding: ${await response.text()}`);
  }

  const result = await response.json();
  return result.embedding.values; // Extract the embedding values
}

async function backfillEmbeddings() {
  const db = admin.firestore();

  console.log("Starting embedding backfill for recipes...");

  // Fetch all recipes
  const recipesSnapshot = await db.collection("recipes").get();

  for (const recipeDoc of recipesSnapshot.docs) {
    const data = recipeDoc.data();

    // Skip recipes that already have embeddings
    if (data.embeddings) {
      console.log(`Skipping recipe ${recipeDoc.id} (already has embeddings)`);
      continue;
    }

    try {
      // Combine text for embedding
      const ingredientNames = (data.ingredientNames || []).join(", ");
      const tagNames = (data.tagNames || []).join(", ");
      const combinedText = [
        data.title, // Recipe title
        ingredientNames, // List of ingredient names
        tagNames, // List of tag names
      ].join(" ");

      console.log(`Generating embedding for recipe ${recipeDoc.id}: ${combinedText}`);

      // Generate embedding
      const embeddings = await generateEmbedding(combinedText);

      // Update Firestore with the generated embeddings
      await recipeDoc.ref.set(
        {
          embeddings: embeddings,
        },
        { merge: true } // Merge the new data into the existing document
      );

      console.log(`Updated recipe ${recipeDoc.id} with embeddings`);
    } catch (error) {
      console.error(`Failed to update recipe ${recipeDoc.id}:`, error);
    }
  }

  console.log("Backfill for recipes completed!");
}

backfillEmbeddings().catch(console.error);