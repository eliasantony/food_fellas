# [FoodFellas](https://foodfellas.app)

## Cooking up more than connections!

**FoodFellas** is a vibrant, AI-powered platform for food lovers who want to share, explore, and connect over their passion for cuisine. Designed for a mobile-first generation, the app blends social interaction with smart cooking tools — helping users discover new recipes, plan their meals, and express themselves with custom avatars. Whether you're a student cooking on a budget or an aspiring home chef, FoodFellas makes cooking creative, personal, and social.

---

## 🎯 Target Audience

- Young adults (18–35) with a passion for food and creativity  
- University students looking for quick, affordable, and fun meals  
- Early-career professionals wanting to cook smarter and impress  
- Social media-savvy users who love sharing experiences  
- Anyone excited about AI, customization, and community-driven cooking  

---

## 🧠 Core Features (MVP)

- ✅ **User Authentication** (Email, Apple, Google via Firebase Auth)  
- ✅ **Recipe Discovery** (powered by full-text search with [Typesense](https://typesense.org))  
- ✅ **Personalized Recipe Recommendations** (based on interactions, tags, ratings)  
- ✅ **Conversational AI Chatbot** (meal ideas, cooking help – powered by GPT-4/Gemini)  
- ✅ **Image-to-Recipe AI** (upload a photo, get the recipe)  
- ✅ **AI-Generated Recipe Images** (based on dish name, ingredients, and style)  
- ✅ **User Profiles** (bio, picture, follower system, saved recipes)  
- ✅ **Custom Avatar Creator** (build expressive personas using Open Peeps library)
- ✅ **Community Feed** (recipes from users you follow)  
- ✅ **Rating & View Tracking** (to identify top-rated and trending recipes)

---

## 🛠 Technical Stack

- **Frontend**: Flutter (iOS, Android, Web)
- **Backend**: Firebase (Firestore, Authentication, Functions, Storage, Analytics)
- **Search Engine**: Typesense (self-hosted on Raspberry Pi 5 with Docker + Nginx)
- **AI Services**: Google Gemini for chat, image generation, and translation
- **Localization**: English
- **Cloud Functions**: Firebase v2 (Node.js), handling indexing, recommedation algorithm, rating aggregation, notifications, ...
- **Subscription Model**: In-app purchases via App Store & Google Play for premium features

---

## 💎 Premium Features ("FoodFellas+")

- Unlimited AI chat & image generations  
- More saved collections  
- Access to collaborative collections
- Priority access to new AI tools  

---

## 🔒 Privacy & Security

- All user data is securely stored via Firebase  
- GDPR-compliant terms and privacy policy  
- Minimal permissions, opt-in AI usage  

---

## 📅 Project Status

**Current phase:** Early-Public - launched in March 2025 (App Store & Google Play)  
**Next milestone:** Improve code and add more features

---

## 📸 Screenshots & Mockups

Coming soon – stay tuned on [Instagram](https://instagram.com/yourfoodfellas) for previews!
