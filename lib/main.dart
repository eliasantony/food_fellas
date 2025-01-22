import 'package:app_links/app_links.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_gemini/flutter_gemini.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:food_fellas/providers/bottomNavBarProvider.dart';
import 'package:food_fellas/providers/chatProvider.dart';
import 'package:food_fellas/providers/ingredientProvider.dart';
import 'package:food_fellas/providers/recipeProvider.dart';
import 'package:food_fellas/providers/searchProvider.dart';
import 'package:food_fellas/providers/tagProvider.dart';
import 'package:food_fellas/providers/themeProvider.dart';
import 'package:food_fellas/providers/userProvider.dart';
import 'package:food_fellas/src/views/recipeDetails_screen.dart';
import 'package:food_fellas/src/views/settings_screen.dart';
import 'package:food_fellas/src/views/shoppingList_screen.dart';
import 'package:food_fellas/src/widgets/recipeList_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';
import 'src/views/auth/login_screen.dart';
import 'src/views/home_screen.dart';
import 'src/views/discover_screen.dart';
import 'src/views/aichat_screen.dart';
import 'src/views/profile_screen.dart';
import 'src/views/auth/signup_screen.dart';
import 'src/widgets/initializer_widget.dart';

final GlobalKey<NavigatorState> globalNavigatorKey =
    GlobalKey<NavigatorState>();
final GlobalKey<_MainPageState> mainPageKey = GlobalKey<_MainPageState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: ".env");

  Gemini.init(apiKey: dotenv.env['GEMINI_API_KEY']!);

  await Firebase.initializeApp(
    name: 'FoodFellas',
    options: DefaultFirebaseOptions.currentPlatform,
  );

  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
  );

  final appLinks = AppLinks();

  // Check for an initial link
  final initialUri = await appLinks.getInitialLink();
  if (initialUri != null) {
    // Delay the handling until after the widget tree is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handleIncomingLink(initialUri);
    });
  }

  // Listen for subsequent links while the app is running
  appLinks.uriLinkStream.listen((Uri? uri) {
    if (uri != null) {
      _handleIncomingLink(uri);
    }
  });

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => RecipeProvider()),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
        ChangeNotifierProvider(create: (_) => TagProvider()),
        ChangeNotifierProvider(create: (_) => IngredientProvider()),
        ChangeNotifierProvider(create: (_) => BottomNavBarProvider()),
        ChangeNotifierProvider(create: (_) => SearchProvider()),
        ChangeNotifierProvider(create: (_) => UserDataProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: MainApp(),
    ),
  );
}

void _handleIncomingLink(Uri uri) {
  // Just a debug print so you know it's being triggered.
  print('Deep link triggered for: $uri');

  final pathSegments = uri.pathSegments;

  // Check if the URL starts with "share"
  if (pathSegments.isNotEmpty && pathSegments[0] == 'share') {
    if (pathSegments.length > 2) {
      final contentType = pathSegments[1];
      final contentId = pathSegments[2];

      // 3. Use the global navigator to push the route:
      final nav = globalNavigatorKey.currentState;
      if (nav != null) {
        switch (contentType) {
          case 'recipe':
            nav.push(
              MaterialPageRoute(
                builder: (_) => RecipeDetailScreen(recipeId: contentId),
              ),
            );
            break;
          case 'profile':
            nav.push(
              MaterialPageRoute(
                builder: (_) => ProfileScreen(userId: contentId),
              ),
            );
            break;
          case 'collection':
            nav.push(
              MaterialPageRoute(
                builder: (_) => RecipesListScreen(
                  isCollection: true,
                  collectionId: contentId,
                ),
              ),
            );
            break;
          default:
            _showError('Unknown content type: $contentType');
        }
      } else {
        print('NavigatorState is null. Could not push.');
      }
    } else {
      _showError('Invalid share link: Missing content type or ID');
    }
  } else {
    _showError('Link does not start with "share"');
  }
}

void _showError(String message) {
  print('ERROR: $message');

  // Optionally show a dialog or snack bar if context is available:
  final ctx = globalNavigatorKey.currentContext;
  if (ctx != null) {
    ScaffoldMessenger.of(ctx).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
      ),
    );
  }
}

class MainApp extends StatefulWidget {
  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  bool isDarkMode = false;
  late final SharedPreferences prefs;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      title: 'FoodFellas',
      debugShowCheckedModeBanner: false,
      navigatorKey: globalNavigatorKey,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1A8100),
          brightness: Brightness.light,
        ).copyWith(
          primary: const Color(0xFF1A8100),
          secondary: const Color(0xFFFEB47B),
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1A8100),
          brightness: Brightness.dark,
        ).copyWith(
          primary: const Color(0xFF1A8100),
          secondary: const Color(0xFFFEB47B),
        ),
      ),
      themeMode: themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: InitializerWidget(),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/signup': (context) => const SignUpScreen(),
        '/mainPage': (context) => MainPage(),
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
