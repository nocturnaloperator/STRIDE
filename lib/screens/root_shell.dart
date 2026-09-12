import 'package:flutter/material.dart';
 
import 'activities_screen.dart';
import 'home_screen.dart';
import 'profile_screen.dart';
 
/// The app's persistent bottom-nav container — the single screen that
/// `main.dart` actually launches. Everything else lives "inside" this.
class RootShell extends StatefulWidget {
  const RootShell({super.key});
 
  @override
  State<RootShell> createState() => _RootShellState();
}
 
class _RootShellState extends State<RootShell> {
  int _index = 0;
 
  // A fixed const list, built once — not regenerated on every setState.
  static const _tabs = [
    HomeScreen(),
    ActivitiesScreen(),
    ProfileScreen(userId: 'me'),
  ];
 
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // IndexedStack keeps all three tabs mounted in the widget tree and
      // just toggles which one is visible. This is the detail basic
      // generated code usually skips: if you instead wrote
      // `body: _tabs[_index]`, Flutter would tear down and rebuild the
      // whole tab on every switch — your profile screen would re-fetch
      // from the repository (and lose scroll position) every single
      // time you tapped back to it.
      body: IndexedStack(index: _index, children: _tabs),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.directions_run_outlined),
            selectedIcon: Icon(Icons.directions_run),
            label: 'Activities',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
 