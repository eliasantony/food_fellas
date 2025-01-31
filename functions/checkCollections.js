const admin = require("firebase-admin");

const serviceAccount = require("./serviceAccountKey.json");

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: "food-fellas-rts94q",
});

async function checkAllCollections() {
  const db = admin.firestore();
  const snap = await db.collectionGroup("collections").get();
  snap.forEach(doc => {
    const data = doc.data();
    if (data.contributors !== undefined) {
      console.log(`Doc: ${doc.ref.path} =>`, data.contributors);
    }
  });
}
checkAllCollections();