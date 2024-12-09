import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_gemini/flutter_gemini.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:food_fellas/providers/bottomNavBarProvider.dart';
import 'package:food_fellas/providers/chatProvider.dart';
import 'package:food_fellas/providers/ingredientProvider.dart';
import 'package:food_fellas/providers/recipeProvider.dart';
import 'package:food_fellas/providers/tagProvider.dart';
import 'package:food_fellas/src/views/shoppingList_screen.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'src/views/auth/login_screen.dart';
import 'src/views/home_screen.dart';
import 'src/views/discover_screen.dart';
import 'src/views/aichat_screen.dart';
import 'src/views/profile_screen.dart';
import 'src/views/auth/signup_screen.dart';
import 'src/widgets/initializer_widget.dart';

final GlobalKey<_MainPageState> mainPageKey = GlobalKey<_MainPageState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: ".env");

  Gemini.init(apiKey: dotenv.env['GEMINI_API_KEY']!);

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => RecipeProvider()),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
        ChangeNotifierProvider(create: (_) => TagProvider()),
        ChangeNotifierProvider(create: (_) => IngredientProvider()),
        ChangeNotifierProvider(create: (_) => BottomNavBarProvider()),
      ],
      child: const MainApp(),
    ),
  );
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FoodFellas',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
      ),
      home: const InitializerWidget(),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/signup': (context) => const SignUpScreen(),
        '/mainPage': (context) => MainPage(key: mainPageKey),
      },
    );
  }
}

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _selectedIndex = 0;

  final List<Widget> _widgetOptions = <Widget>[
    HomeScreen(),
    DiscoverScreen(),
    //CommunityScreen(),
    ShoppingListScreen(),
    const AIChatScreen(),
    ProfileScreen(),
  ];

  void onItemTapped(int index) {
    Provider.of<BottomNavBarProvider>(context, listen: false).setIndex(index);
  }

  @override
  Widget build(BuildContext context) {
    int _selectedIndex =
        Provider.of<BottomNavBarProvider>(context).selectedIndex;
    return Scaffold(
      body: Center(
        child: _widgetOptions.elementAt(_selectedIndex),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.search),
            label: 'Discover',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_cart),
            label: 'Shopping List',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat),
            label: 'AI Chat',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Theme.of(context).colorScheme.onSurface,
        onTap: onItemTapped,
      ),
    );
  }
}
