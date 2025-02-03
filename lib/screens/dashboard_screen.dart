import 'package:flutter/material.dart';
import 'dial_screen.dart';
import 'contacts_screen.dart';
import 'favorites_screen.dart';
import 'settings_screen.dart';


class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;
  
  final List<Widget> _screens = const [
    DialScreen(),
    // CallLogScreen(),
    // AnalyticsScreen(),
    ContactsScreen(),
    FavoritesScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dialpad),
            label: 'Dial',
          ),
          // NavigationDestination(
          //   icon: Icon(Icons.access_time),
          //   label: 'Call Log',
          // ),
          // NavigationDestination(
          //   icon: Icon(Icons.analytics),
          //   label: 'Analytics',
          // ),
          NavigationDestination(
            icon: Icon(Icons.contacts),
            label: 'Contacts',
          ),
          NavigationDestination(
            icon: Icon(Icons.star),
            label: 'Favorites',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
} 