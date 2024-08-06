import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'src/views/home_screen.dart';
import 'src/views/discover_screen.dart';
import 'src/views/community_screen.dart';
import 'src/views/aichat_screen.dart';
import 'src/views/profile_screen.dart';
void main() {
  dotenv.load(fileName: ".env");
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FoodFellas',
      theme: ThemeData(
        useMaterial3: true, // Enable Material 3
        // Generate a color scheme with a seed color
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
      ),
      home: const MainPage(),
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
    CommunityScreen(),
    AIChatScreen(),
    ProfileScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
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
            icon: Icon(Icons.group),
            label: 'Community',
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
        onTap: _onItemTapped,
      ),
    );
  }
}


class BottomNavBarMallika1 extends StatelessWidget {
  const BottomNavBarMallika1({Key? key}) : super(key: key);

  final orangeColor = const Color(0xffFF8527);

  @override
  Widget build(BuildContext context) {
    return BottomAppBar(
        color: Colors.white,
        child: SizedBox(
          height: 56,
          width: MediaQuery.of(context).size.width,
          child: Padding(
            padding: const EdgeInsets.only(left: 25.0, right: 25.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconBottomBar(
                    text: "Home",
                    icon: Icons.home_outlined,
                    selected: true,
                    onPressed: () {}),
                IconBottomBar(
                    text: "Search",
                    icon: Icons.search_outlined,
                    selected: false,
                    onPressed: () {}),
                IconBottomBar2(
                    text: "Add",
                    icon: Icons.add_outlined,
                    selected: false,
                    onPressed: () {}),
                IconBottomBar(
                    text: "Cart",
                    icon: Icons.local_grocery_store_outlined,
                    selected: false,
                    onPressed: () {}),
                IconBottomBar(
                    text: "Calendar",
                    icon: Icons.date_range_outlined,
                    selected: false,
                    onPressed: () {})
              ],
            ),
          ),
        ),
    );
  }
}