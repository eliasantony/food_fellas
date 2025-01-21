const fs = require('fs');
const admin = require("firebase-admin");

const serviceAccount = require("./serviceAccountKey.json");

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: "food-fellas-rts94q"
});
const db = admin.firestore();

async function exportDocument(collection, documentId) {
  try {
    const doc = await db.collection(collection).doc(documentId).get();

    const subcollections = await db.collection(collection).doc(documentId).listCollections();
    const subcollectionData = {};

    for (const subcollection of subcollections) {
      const subcollectionDocs = await subcollection.get();
      subcollectionData[subcollection.id] = subcollectionDocs.docs.map(doc => ({ id: doc.id, ...doc.data() }));
    }

    const data = doc.data();
    data.subcollections = subcollectionData;

    if (!doc.exists) {
      console.log('Document not found!');
      return;
    }


    // Dokument in eine JSON-Datei speichern
    fs.writeFileSync(`${collection}-${documentId}.json`, JSON.stringify(data, null, 2));
    console.log(`Exported ${collection}/${documentId} to ${collection}-${documentId}.json`);
  } catch (error) {
    console.error('Error exporting document:', error);
  }
}

// Hier die Collection und Document ID eingeben
exportDocument('recipes', 'LFpLQrlrbNfn3HkMlmcn');
//exportDocument('users', 'r8zp6y3A05N4GRtH19q4efLipR93');
