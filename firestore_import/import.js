const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json'); // Assurez-vous que le chemin est correct
const data = require('./data.json'); // Assurez-vous que le chemin est correct

// Initialiser Firebase Admin
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function importData() {
  console.log("Début de l'importation des données dans Firestore...");

  for (const collectionName in data) {
    if (Object.prototype.hasOwnProperty.call(data, collectionName)) {
      const collectionData = data[collectionName];
      console.log(`Traitement de la collection : ${collectionName}`);

      for (const docId in collectionData) {
        if (Object.prototype.hasOwnProperty.call(collectionData, docId)) {
          const docData = collectionData[docId];
          const docRef = db.collection(collectionName).doc(docId);

          try {
            await docRef.set(docData);
            console.log(`  Document "${docId}" ajouté/mis à jour dans "${collectionName}"`);
          } catch (error) {
            console.error(`  Erreur lors de l'ajout du document "${docId}" :`, error);
          }
        }
      }
    }
  }
  console.log("Importation terminée.");
}

importData().catch(console.error);
