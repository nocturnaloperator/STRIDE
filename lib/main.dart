import 'package:flutter/material.dart';
 
void main() {
  runApp(const StrideApp());
}
 
class StrideApp extends StatelessWidget {
  const StrideApp({super.key});
 
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Stride',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF0D1B1E), // deep midnight teal
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFB6FF3B),   // electric lime accent
          secondary: Color(0xFF1F3A3D), // muted teal
          surface: Color(0xFF15282B),
        ),
        fontFamily: 'Roboto',
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0D1B1E),
          elevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Color(0xFF15282B),
          selectedItemColor: Color(0xFFB6FF3B),
          unselectedItemColor: Colors.white54,
        ),
      ),
      home: const HomeShell(),
    );
  }
}
 
/// Holds the bottom navigation and swaps between the three main screens.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
 
  @override
  State<HomeShell> createState() => _HomeShellState();
}
 
class _HomeShellState extends State<HomeShell> {
  int _currentIndex = 0;
 
  final List<Widget> _screens = const [
    FeedScreen(),
    TrackScreen(),
    ProfileScreen(),
  ];
 
  final List<String> _titles = const ['Stride', 'Track a Run', 'Profile'];
 
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_titles[_currentIndex])),
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dynamic_feed), label: 'Feed'),
          BottomNavigationBarItem(icon: Icon(Icons.add_circle_outline), label: 'Track'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Profile'),
        ],
      ),
    );
  }
}
 
/// Placeholder feed — will later show a list of ActivityCard widgets.
class FeedScreen extends StatelessWidget {
  const FeedScreen({super.key});
 
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Your training feed will appear here',
        style: TextStyle(color: Colors.white70, fontSize: 16),
      ),
    );
  }
}
 
/// Placeholder for the GPS tracking screen (built out in Week 2).
class TrackScreen extends StatelessWidget {
  const TrackScreen({super.key});
 
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.directions_run, size: 72, color: Color(0xFFB6FF3B)),
          const SizedBox(height: 16),
          const Text(
            'Map & GPS tracking\ncoming in Week 2',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFB6FF3B),
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            onPressed: () {
              // Will start GPS tracking once location_service.dart exists.
            },
            child: const Text(
              'Start Run',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }
}
 
/// Placeholder profile screen — training stats will live here.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});
 
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Training stats & PRs will appear here',
        style: TextStyle(color: Colors.white70, fontSize: 16),
      ),
    );
  }
}
 