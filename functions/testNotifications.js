// testNotifications.js
const fs = require('fs');
const admin = require("firebase-admin");

// Load your service account key and initialize the admin SDK.
const serviceAccount = require("./serviceAccountKey.json");

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: "food-fellas-rts94q"
});

const db = admin.firestore();
const messaging = admin.messaging();

// Command-line arguments:
// process.argv[0] -> node
// process.argv[1] -> script name
// process.argv[2] -> notification types to send (comma-separated), default "all"
// process.argv[3] -> token
// process.argv[4] -> recipeId
// process.argv[5] -> commentId
// process.argv[6] -> followerUid
// process.argv[7] -> fileName
// process.argv[8] -> commentAuthorName

const requestedTypesArg = process.argv[2] || "all";
const requestedTypes = requestedTypesArg.split(",").map(s => s.trim().toLowerCase());

const token = process.argv[3] || 'dDd4B32OQuizNsplGIdnCL:APA91bFtnTFUes0nEv8JfR7TCYTCCXcH0wCEmjxW5h5SZV5j-RwMP5Bv79oyVEi7ySBjVmiS-40m8eF1Fa8O0PINodQVJJXYngeohpZyzyw50P6m5I_R91U';
const recipeId = process.argv[4] || '7lYvKQa6pq0dvCrWcYCU';
const commentId = process.argv[5] || '423ZhGcyNhD1ZkvXLRwA';
const followerUid = process.argv[6] || 'eW2mRlQLIffkpck4ku9O6nXn9ZV2';
const fileName = process.argv[7] || 'test_file.pdf';
const commentAuthorName = process.argv[8] || 'Test Commenter';

// Define a mapping for the notifications.
const notificationMapping = {
  "weekly_recommendations": {
    token: token,
    notification: {
      title: "FoodFellas'",
      body: "Check out your new weekly recipe recommendations. 📆"
    },
    data: {
      type: "weekly_recommendations",
      click_action: "FLUTTER_NOTIFICATION_CLICK"
    }
  },
  "new_comment": {
    token: token,
    notification: {
      title: "FoodFellas'",
      body: `${commentAuthorName} just left a comment on one of your recipes.`
    },
    data: {
      type: "new_comment",
      recipeId: recipeId,
      commentId: commentId,
      click_action: "FLUTTER_NOTIFICATION_CLICK"
    }
  },
  "new_follower": {
    token: token,
    notification: {
      title: "FoodFellas'",
      body: `You got a new Fella! ${followerUid} just started following you. 🎉`
    },
    data: {
      type: "new_follower",
      followerUid: followerUid,
      click_action: "FLUTTER_NOTIFICATION_CLICK"
    }
  },
  "new_recipe": {
    token: token,
    notification: {
      title: "FoodFellas'",
      body: `A new recipe has just been posted! Check it out! 🍽️`
    },
    data: {
      type: "new_recipe",
      recipeId: recipeId,
      click_action: "FLUTTER_NOTIFICATION_CLICK"
    }
  },
  "pdf_processing_done": {
    token: token,
    notification: {
      title: "FoodFellas'",
      body: `Your PDF ${fileName} has been converted to recipes!`
    },
    data: {
      type: "pdf_processing_done",
      fileName: fileName,
      click_action: "FLUTTER_NOTIFICATION_CLICK"
    }
  }
};

async function testNotifications() {
  let messages = [];

  // If "all" is requested, send all; otherwise, only send the requested types.
  if (requestedTypes.includes("all")) {
    messages = Object.values(notificationMapping);
  } else {
    for (const type of requestedTypes) {
      if (notificationMapping[type]) {
        messages.push(notificationMapping[type]);
      } else {
        console.warn(`Unknown notification type: ${type}`);
      }
    }
  }

  const errors = [];

  // Send each message sequentially.
  for (const msg of messages) {
    try {
      const responseMsg = await messaging.send(msg);
      console.log(`Notification (${msg.data.type}) sent with response: ${responseMsg}`);
    } catch (error) {
      console.error(`Error sending ${msg.data.type} message: ${error}`);
      errors.push(error.toString());
    }
  }

  if (errors.length > 0) {
    console.error("Some notifications failed: " + errors.join(", "));
  } else {
    console.log("Test notifications sent successfully.");
  }
}

// Run the test function.
testNotifications();