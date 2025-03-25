const { getTypesenseClient } = require('./typesenseClient');
const { getFirestore } = require('firebase-admin/firestore');

const COLLECTION = 'users';

function sanitizeUserData(id, data) {
  return {
    id,
    display_name: data.display_name || '',
    shortDescription: data.shortDescription || '',
    email: data.email || '',
    photo_url: data.photo_url || '',
    dietaryPreferences: Array.isArray(data.dietaryPreferences) ? data.dietaryPreferences : [],
    favoriteCuisines: Array.isArray(data.favoriteCuisines) ? data.favoriteCuisines : [],
    cookingSkillLevel: data.cookingSkillLevel || '',
    role: data.role || '',
    recipeCount: Number(data.recipeCount || 0),
    totalReviews: Number(data.totalReviews || 0),
    averageRating: typeof data.averageRating === 'number' ? data.averageRating : 0,
    created_time: Math.floor(Number(data.created_time) / 1000) || 0,
    last_active_time: Math.floor(Number(data.last_active_time) / 1000) || 0,
  };
}

exports.indexUserOnWrite = async (event) => {
  // Grab the before/after snapshots
  const beforeSnap = event.data.before;
  const afterSnap = event.data.after;

  const userId = event.params.userId;
  const typesense = await getTypesenseClient();

  // If doc was deleted => afterSnap.exists = false
  if (!afterSnap.exists) {
    console.log(`User doc ${userId} was deleted from Firestore. Removing from Typesense...`);
    await typesense.collections(COLLECTION).documents(userId).delete();
    return;
  }

  // Otherwise, new or updated doc => upsert
  const newData = afterSnap.data();
  const sanitized = sanitizeUserData(userId, newData);
  await typesense.collections(COLLECTION).documents().upsert(sanitized);
};

exports.backfillUsers = async (req, res) => {
  const firestore = getFirestore();
  const snapshot = await firestore.collection(COLLECTION).get();
  const typesense = await getTypesenseClient();

  const docs = snapshot.docs.map((doc) => sanitizeUserData(doc.id, doc.data()));

  try {
    const result = await typesense
      .collections(COLLECTION)
      .documents()
      .import(docs, { action: 'upsert' });

    console.log(result);
    res.send('Backfilled users!');
  } catch (error) {
    console.error('Backfill failed:', error.importResults || error.message);
    res.status(500).send('Backfill failed');
  }
};