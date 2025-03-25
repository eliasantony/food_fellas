const { getTypesenseClient } = require('./typesenseClient');
const { getFirestore } = require('firebase-admin/firestore');

const COLLECTION = 'recipes';

function sanitizeRecipeData(id, data) {
  return {
    id,
    title: data.title || '',
    description: data.description || '',
    cookingSteps: Array.isArray(data.cookingSteps) ? data.cookingSteps : [],
    ingredientNames: Array.isArray(data.ingredientNames) ? data.ingredientNames : [],
    tagNames: Array.isArray(data.tagNames) ? data.tagNames : [],
    authorId: data.authorId || '',
    createdAt: Number(data.createdAt || 0),
    updatedAt: Number(data.updatedAt || 0),
    averageRating: typeof data.averageRating === 'number' ? data.averageRating : 0,
    cookTime: Number(data.cookTime || 0),
    prepTime: Number(data.prepTime || 0),
    totalTime: Number(data.totalTime || 0),
    createdByAI: Boolean(data.createdByAI),
    viewsCount: Number(data.viewsCount || 0),
    ratingsCount: Number(data.ratingsCount || 0),
    calories: Number(data.calories || 0),
    embeddings: Array.isArray(data.embeddings) ? data.embeddings.map(Number) : undefined,
  };
}

exports.indexRecipeOnWrite = async (event) => {

  // Grab the before/after snapshots
  const beforeSnap = event.data.before;
  const afterSnap = event.data.after;

  const recipeId = event.params.recipeId;
  const typesense = await getTypesenseClient();

  // If doc was deleted => afterSnap.exists = false
  if (!afterSnap.exists) {
    await typesense.collections(COLLECTION).documents(recipeId).delete();
    return;
  }

  // Otherwise, new or updated doc => upsert
  const newData = afterSnap.data();
  const sanitized = sanitizeRecipeData(recipeId, newData);
  await typesense.collections(COLLECTION).documents().upsert(sanitized);
};

exports.backfillRecipes = async (req, res) => {
  const firestore = getFirestore();
  const snapshot = await firestore.collection(COLLECTION).get();
  const typesense = await getTypesenseClient();

  const docs = snapshot.docs.map((doc) =>
    sanitizeRecipeData(doc.id, doc.data())
  );

  try {
    const result = await typesense
      .collections(COLLECTION)
      .documents()
      .import(docs, { action: 'upsert' });

    console.log(result);
    res.send('Backfilled recipes!');
  } catch (error) {
    console.error('Backfill failed:', error.importResults || error.message);
    res.status(500).send('Backfill failed');
  }
};