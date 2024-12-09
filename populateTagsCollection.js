const admin = require("firebase-admin");
const serviceAccount = require("C:/Users/Elias Antony/Downloads/food-fellas-rts94q-firebase-adminsdk-pscw6-68ffc8610e.json");

// Initialize Firebase Admin SDK
admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    databaseURL: "https://food-fellas-rts94q.firebaseio.com",
});

const db = admin.firestore();

// Define all tags
const tags = [
  {
    name: "Breakfast",
    category: "Meal Types",
    icon: "🍳",
  },
  {
    name: "Lunch",
    category: "Meal Types",
    icon: "🥪",
  },
  {
    name: "Dinner",
    category: "Meal Types",
    icon: "🍽️",
  },
  {
    name: "Snack",
    category: "Meal Types",
    icon: "🍿",
  },
  {
    name: "Dessert",
    category: "Meal Types",
    icon: "🍰",
  },
  {
    name: "Appetizer",
    category: "Meal Types",
    icon: "🥟",
  },
  {
    name: "Beverage",
    category: "Meal Types",
    icon: "☕️",
  },
  {
    name: "Brunch",
    category: "Meal Types",
    icon: "🥞",
  },
  {
    name: "Side Dish",
    category: "Meal Types",
    icon: "🍟",
  },
  {
    name: "Soup",
    category: "Meal Types",
    icon: "🍲",
  },
  {
    name: "Salad",
    category: "Meal Types",
    icon: "🥗",
  },
  {
    name: "Under 15 minutes",
    category: "Cooking Time",
    icon: "⏱️",
  },
  {
    name: "Under 30 minutes",
    category: "Cooking Time",
    icon: "⏱️",
  },
  {
    name: "Under 1 hour",
    category: "Cooking Time",
    icon: "⏱️",
  },
  {
    name: "Over 1 hour",
    category: "Cooking Time",
    icon: "⏳",
  },
  {
    name: "Slow Cook",
    category: "Cooking Time",
    icon: "🐢",
  },
  {
    name: "Quick & Easy",
    category: "Cooking Time",
    icon: "⚡️",
  },
  {
    name: "Easy",
    category: "Difficulty Levels",
    icon: "🙂",
  },
  {
    name: "Medium",
    category: "Difficulty Levels",
    icon: "😐",
  },
  {
    name: "Hard",
    category: "Difficulty Levels",
    icon: "😅",
  },
  {
    name: "Beginner Friendly",
    category: "Difficulty Levels",
    icon: "🥄",
  },
  {
    name: "Intermediate",
    category: "Difficulty Levels",
    icon: "🍳",
  },
  {
    name: "Expert",
    category: "Difficulty Levels",
    icon: "👩‍🍳",
  },
  {
    name: "Vegetarian",
    category: "Dietary Preferences",
    icon: "🥕",
  },
  {
    name: "Vegan",
    category: "Dietary Preferences",
    icon: "🌱",
  },
  {
    name: "Gluten-Free",
    category: "Dietary Preferences",
    icon: "🚫🍞",
  },
  {
    name: "Dairy-Free",
    category: "Dietary Preferences",
    icon: "🥛❌",
  },
  {
    name: "Nut-Free",
    category: "Dietary Preferences",
    icon: "🥜❌",
  },
  {
    name: "Halal",
    category: "Dietary Preferences",
    icon: "🕌",
  },
  {
    name: "Kosher",
    category: "Dietary Preferences",
    icon: "✡️",
  },
  {
    name: "Paleo",
    category: "Dietary Preferences",
    icon: "🍖",
  },
  {
    name: "Keto",
    category: "Dietary Preferences",
    icon: "🥩",
  },
  {
    name: "Pescatarian",
    category: "Dietary Preferences",
    icon: "🐟",
  },
  {
    name: "Low-Carb",
    category: "Dietary Preferences",
    icon: "🥦",
  },
  {
    name: "Low-Fat",
    category: "Dietary Preferences",
    icon: "🍏",
  },
  {
    name: "High-Protein",
    category: "Dietary Preferences",
    icon: "🍗",
  },
  {
    name: "Sugar-Free",
    category: "Dietary Preferences",
    icon: "🍬❌",
  },
  {
    name: "Italian",
    category: "Cuisines",
    icon: "🍕",
  },
  {
    name: "Mexican",
    category: "Cuisines",
    icon: "🌮",
  },
  {
    name: "Chinese",
    category: "Cuisines",
    icon: "🥡",
  },
  {
    name: "Indian",
    category: "Cuisines",
    icon: "🍛",
  },
  {
    name: "Japanese",
    category: "Cuisines",
    icon: "🍣",
  },
  {
    name: "Mediterranean",
    category: "Cuisines",
    icon: "🥙",
  },
  {
    name: "American",
    category: "Cuisines",
    icon: "🍔",
  },
  {
    name: "Thai",
    category: "Cuisines",
    icon: "🍜",
  },
  {
    name: "French",
    category: "Cuisines",
    icon: "🥐",
  },
  {
    name: "Greek",
    category: "Cuisines",
    icon: "🥗",
  },
  {
    name: "Korean",
    category: "Cuisines",
    icon: "🍱",
  },
  {
    name: "Vietnamese",
    category: "Cuisines",
    icon: "🍜",
  },
  {
    name: "Spanish",
    category: "Cuisines",
    icon: "🥘",
  },
  {
    name: "Middle Eastern",
    category: "Cuisines",
    icon: "🥙",
  },
  {
    name: "Caribbean",
    category: "Cuisines",
    icon: "🍹",
  },
  {
    name: "African",
    category: "Cuisines",
    icon: "🍲",
  },
  {
    name: "German",
    category: "Cuisines",
    icon: "🥨",
  },
  {
    name: "Brazilian",
    category: "Cuisines",
    icon: "🍖",
  },
  {
    name: "Peruvian",
    category: "Cuisines",
    icon: "🍤",
  },
  {
    name: "Turkish",
    category: "Cuisines",
    icon: "🍢",
  },
  {
    name: "Other",
    category: "Cuisines",
    icon: "🌍",
  },
  {
    name: "Grilling",
    category: "Cooking Methods",
    icon: "🔥",
  },
  {
    name: "Baking",
    category: "Cooking Methods",
    icon: "🧁",
  },
  {
    name: "Stir-Frying",
    category: "Cooking Methods",
    icon: "🍳",
  },
  {
    name: "Steaming",
    category: "Cooking Methods",
    icon: "♨️",
  },
  {
    name: "Roasting",
    category: "Cooking Methods",
    icon: "🍖",
  },
  {
    name: "Slow Cooking",
    category: "Cooking Methods",
    icon: "🐢",
  },
  {
    name: "Raw",
    category: "Cooking Methods",
    icon: "🥗",
  },
  {
    name: "Frying",
    category: "Cooking Methods",
    icon: "🍤",
  },
  {
    name: "Pressure Cooking",
    category: "Cooking Methods",
    icon: "🍲",
  },
  {
    name: "No-Cook",
    category: "Cooking Methods",
    icon: "❄️",
  },
  {
    name: "Party",
    category: "Occasions",
    icon: "🎉",
  },
  {
    name: "Picnic",
    category: "Occasions",
    icon: "🧺",
  },
  {
    name: "Holiday",
    category: "Occasions",
    icon: "🎄",
  },
  {
    name: "Casual",
    category: "Occasions",
    icon: "👕",
  },
  {
    name: "Formal",
    category: "Occasions",
    icon: "🎩",
  },
  {
    name: "Date Night",
    category: "Occasions",
    icon: "❤️",
  },
  {
    name: "Family Gathering",
    category: "Occasions",
    icon: "👨‍👩‍👧‍👦",
  },
  {
    name: "Game Day",
    category: "Occasions",
    icon: "🏈",
  },
  {
    name: "BBQ",
    category: "Occasions",
    icon: "🍖",
  },
  {
    name: "Healthy",
    category: "Other Tags",
    icon: "💪",
  },
  {
    name: "Comfort Food",
    category: "Other Tags",
    icon: "🍝",
  },
  {
    name: "Spicy",
    category: "Other Tags",
    icon: "🌶️",
  },
  {
    name: "Sweet",
    category: "Other Tags",
    icon: "🍭",
  },
  {
    name: "Savory",
    category: "Other Tags",
    icon: "🧀",
  },
  {
    name: "Budget-Friendly",
    category: "Other Tags",
    icon: "💰",
  },
  {
    name: "Kids Friendly",
    category: "Other Tags",
    icon: "🧒",
  },
  {
    name: "High Fiber",
    category: "Other Tags",
    icon: "🌾",
  },
  {
    name: "Low Sodium",
    category: "Other Tags",
    icon: "🧂❌",
  },
  {
    name: "Seasonal",
    category: "Other Tags",
    icon: "🍂",
  },
  {
    name: "Organic",
    category: "Other Tags",
    icon: "🥬",
  },
  {
    name: "Gourmet",
    category: "Other Tags",
    icon: "🍷",
  },
];

// Function to add tags to Firestore
const populateTags = async () => {
  const batch = db.batch(); // Use batch for better performance when writing multiple documents

  tags.forEach((tag) => {
    const tagRef = db.collection("tags").doc(); // Create a new document in the "tags" collection
    batch.set(tagRef, tag); // Add data to the batch
  });

  try {
    await batch.commit(); // Commit all writes in the batch
    console.log("Tags populated successfully!");
  } catch (error) {
    console.error("Error adding tags: ", error);
  }
};

// Execute the function
populateTags();
