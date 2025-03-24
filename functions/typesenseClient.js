const Typesense = require('typesense');

let typesense = null;

async function getTypesenseClient() {
  if (typesense) return typesense;

  const apiKey = process.env.TYPESENSE_API_KEY?.trim();
  if (!apiKey) {
    throw new Error("TYPESENSE_API_KEY is not set in environment variables");
  }

  typesense = new Typesense.Client({
    nodes: [
      {
        host: 'typesense.foodfellas.app',
        port: 443,
        protocol: 'https',
      },
    ],
    apiKey,
    connectionTimeoutSeconds: 5,
  });

  return typesense;
}

module.exports = { getTypesenseClient };