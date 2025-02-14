import 'dart:developer';
import 'dart:io';

import 'package:app_links/app_links.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_gemini/flutter_gemini.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:food_fellas/providers/bottomNavBarProvider.dart';
import 'package:food_fellas/providers/chatProvider.dart';
import 'package:food_fellas/providers/feedbackProvider.dart';
import 'package:food_fellas/providers/ingredientProvider.dart';
import 'package:food_fellas/providers/recipeProvider.dart';
import 'package:food_fellas/providers/searchProvider.dart';
import 'package:food_fellas/providers/tagProvider.dart';
import 'package:food_fellas/providers/themeProvider.dart';
import 'package:food_fellas/providers/userProvider.dart';
import 'package:food_fellas/src/services/firebase_messaging_service.dart';
import 'package:food_fellas/src/views/addRecipeForm/addRecipe_form.dart';
import 'package:food_fellas/src/views/auth/welcome_screen.dart';
import 'package:food_fellas/src/views/imageToRecipe_screen.dart';
import 'package:food_fellas/src/views/recipeDetails_screen.dart';
import 'package:food_fellas/src/views/recipeList_screen.dart';
import 'package:food_fellas/src/widgets/expandableFAB.dart';
import 'package:food_fellas/src/widgets/overlayExpandedFAB.dart';
import 'package:food_fellas/src/widgets/tutorialDialog.dart';
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

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();
final GlobalKey<NavigatorState> globalNavigatorKey =
    GlobalKey<NavigatorState>();
// ignore: library_private_types_in_public_api
final GlobalKey<_MainPageState> mainPageKey = GlobalKey<_MainPageState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  if (kDebugMode) {
    debugPrint('Initializing Firebase...');
  }
  try {
    await Firebase.initializeApp(
      name: 'FoodFellas',
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    if (kDebugMode) {
      debugPrint('Firebase initialization error: $e');
    }
  }

  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  //await requestNotificationPermissions();
  //await initLocalNotifications();

  if (Platform.isAndroid) {
    // On Android, it's safe to call getToken() right away
    String? token = await FirebaseMessaging.instance.getToken();
    saveTokenToDatabase();
    if (kDebugMode) {
      print("FCM Token on Android: $token");
    }
  } else if (Platform.isIOS) {
    // Avoid calling getToken() on a simulator
    bool isSimulator = !await _isPhysicalDevice();
    if (isSimulator) {
      if (kDebugMode) {
        print("Running on iOS Simulator. APNS token is not supported here.");
      }
    } else {
      // It's a real device, so you can safely call getToken()
      String? token = await FirebaseMessaging.instance.getToken();
      saveTokenToDatabase();
      if (kDebugMode) {
        print("FCM Token on iOS device: $token");
      }
    }
  }

  await dotenv.load(fileName: ".env");
  Gemini.init(apiKey: dotenv.env['GEMINI_API_KEY']!);

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
        ChangeNotifierProvider(create: (_) => FeedbackProvider()),
      ],
      child: MainApp(),
    ),
  );
}

Future<bool> _isPhysicalDevice() async {
  return !Platform.isIOS || !await FirebaseMessaging.instance.isSupported();
}

void _handleIncomingLink(Uri uri) {
  // Just a debug print so you know it's being triggered.
  if (kDebugMode) {
    print('Deep link triggered for: $uri');
  }

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
            final userId = uri.queryParameters['userId'] ?? '';
            log('CollectionId: $contentId');
            log('trying to push collection screen with params: $contentId, $userId');
            nav.push(
              MaterialPageRoute(
                builder: (_) => RecipesListScreen(
                  isCollection: true,
                  collectionId: contentId,
                  collectionUserId: userId,
                ),
              ),
            );
            break;
          default:
            _showError('Unknown content type: $contentType');
        }
      } else {
        if (kDebugMode) {
          print('NavigatorState is null. Could not push.');
        }
      }
    } else {
      _showError('Invalid share link: Missing content type or ID');
    }
  } else {
    _showError('Link does not start with "share"');
  }
}

void _showError(String message) {
  if (kDebugMode) {
    print('ERROR: $message');
  }

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
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  bool isDarkMode = false;
  late final SharedPreferences prefs;

  @override
  void initState() {
    super.initState();
    // Foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final notification = message.notification;
      debugPrint('onMessage event was published: ${message.data}');
      if (notification != null) {
        debugPrint('Showing notification with data: ${message.data}');
        showNotification(notification.title, notification.body, message.data);
      }
    });

    // App opened via notification
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('onMessageOpenedApp event was published: ${message.data}');
      handleNotificationNavigation(message.data);
    });

    FirebaseMessaging.instance
        .getInitialMessage()
        .then((RemoteMessage? message) {
      if (message != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          handleNotificationNavigation(message.data);
        });
      }
    });

    // Listen to token refresh
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({'fcmToken': newToken});
      }
    });

    saveTokenToDatabase();
    checkAndShowTutorial(context);
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
        '/welcome': (context) => const WelcomeScreen(),
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

  final List<Widget> _widgetOptions = <Widget>[
    HomeScreen(),
    DiscoverScreen(),
    AddRecipeForm(),
    const AIChatScreen(),
    ProfileScreen(),
  ];

  void onItemTapped(int index) {
    Provider.of<BottomNavBarProvider>(context, listen: false).setIndex(index);
  }

  @override
  Widget build(BuildContext context) {
    final bottomNavBarProvider = Provider.of<BottomNavBarProvider>(context);
    int selectedIndex = bottomNavBarProvider.selectedIndex;
    final userData = Provider.of<UserDataProvider>(context).userData;
    final isKeyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;

    final Widget? fab = (selectedIndex == 3 && isKeyboardVisible)
        ? null
        : MediaQuery(
            data: MediaQuery.of(context).removeViewInsets(removeBottom: true),
            child: _buildExpandableFAB(),
          );

    if (userData == null) {
      return Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return PopScope(
      canPop: selectedIndex == 0,
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        if (!didPop && selectedIndex != 0) {
          Provider.of<BottomNavBarProvider>(context, listen: false).setIndex(0);
        }
      },
      child: Scaffold(
        extendBody: true,
        resizeToAvoidBottomInset: selectedIndex == 3 ? true : false,
        body: _widgetOptions.elementAt(selectedIndex),
        floatingActionButton: fab,
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
        bottomNavigationBar: Stack(
          children: [
            // Touch-blocking layer (prevents clicks going through)
            Positioned.fill(
              child: GestureDetector(
                onTap: () {}, // Blocks taps from going through
                behavior: HitTestBehavior.opaque,
                child: Container(), // Invisible, but catches clicks
              ),
            ),
            BottomAppBar(
              shape: const CircularNotchedRectangle(),
              notchMargin: 8.0,
              color: Theme.of(context).brightness == Brightness.dark
                  ? Theme.of(context).colorScheme.surface
                  : Theme.of(context).colorScheme.surface,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildNavItem(Icons.home, 0, selectedIndex),
                  _buildNavItem(Icons.search, 1, selectedIndex),
                  const SizedBox(width: 48), // Spacer for FAB
                  _buildNavItem(Icons.chat, 3, selectedIndex),
                  _buildNavItem(Icons.person, 4, selectedIndex),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, int index, int selectedIndex) {
    bool isSelected = index == selectedIndex;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(
            icon,
            size: 32,
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Colors.grey,
          ),
          onPressed: () {
            Provider.of<BottomNavBarProvider>(context, listen: false)
                .setIndex(index);
          },
        ),
        // Line indicator for selected state
        if (isSelected)
          Container(
            height: 4,
            width: 30,
            color: Theme.of(context).colorScheme.primary,
          )
        else
          const SizedBox(height: 4),
      ],
    );
  }

  Widget _buildExpandableFAB() {
    return OverlayExpandableFab(
      distance: 100, // adjust as needed
      children: [
        ActionButton(
          onPressed: () {
            Provider.of<BottomNavBarProvider>(context, listen: false)
                .setIndex(3);
          },
          icon: const Icon(Icons.chat),
        ),
        ActionButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => AddRecipeForm()),
            );
          },
          icon: const Icon(Icons.create),
        ),
        ActionButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => ImageToRecipeScreen()),
            );
          },
          icon: const Icon(Icons.camera_alt),
        ),
      ],
    );
  }
}
