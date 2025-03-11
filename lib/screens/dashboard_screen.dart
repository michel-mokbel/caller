import 'package:flutter/material.dart';
import 'dial_screen.dart';
import 'contacts_screen.dart';
import 'favorites_screen.dart';
import 'settings_screen.dart';
import 'package:unity_ads_plugin/unity_ads_plugin.dart';
import '../services/ads_service.dart';

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
  void initState() {
    super.initState();
    // Prepare banner ad
    AdsService().showBannerAd(BannerPosition.top);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Banner ad at the top
          UnityBannerAd(
            placementId: AdsService.getBannerAdUnitId(),
            onLoad: (placementId) => print('Banner loaded: $placementId'),
            onClick: (placementId) => print('Banner clicked: $placementId'),
            onFailed: (placementId, error, message) => 
              print('Banner failed: $placementId, $error, $message'),
          ),
          // Main content
          Expanded(
            child: _screens[_selectedIndex],
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) async {
          // Only show ad when changing tabs (not when tapping the current tab)
          if (index != _selectedIndex) {
            // Potentially show an interstitial ad
            await AdsService().showInterstitialAtTransition();
          }
          
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