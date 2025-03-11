import 'package:flutter/material.dart';
import 'dashboard_screen.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:appsflyer_sdk/appsflyer_sdk.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unity_ads_plugin/unity_ads_plugin.dart';
import '../services/ads_service.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  bool _attRequested = false;

  @override
  void initState() {
    super.initState();
    _requestATTPermission();
  }

  Future<void> _requestATTPermission() async {
    // Check if ATT is already requested or if show_att is false
    try {
      final remoteConfig = FirebaseRemoteConfig.instance;
      final showAtt = remoteConfig.getBool('show_att');
      
      if (!showAtt) {
        print('ATT request disabled via Remote Config');
        // Still initialize AppsFlyer but with limited tracking
        await _initializeAppsFlyer(false);
        return;
      }
      
      // Check current status
      final status = await AppTrackingTransparency.trackingAuthorizationStatus;
      if (status != TrackingStatus.notDetermined) {
        print('ATT already determined: $status');
        await _initializeAppsFlyer(status == TrackingStatus.authorized);
        return;
      }
      
      // Wait briefly
      await Future.delayed(const Duration(seconds: 1));
      
      // Request permission
      if (!mounted) return;
      final result = await AppTrackingTransparency.requestTrackingAuthorization();
      print('ATT status after request: $result');
      
      setState(() {
        _attRequested = true;
      });
      
      // Initialize AppsFlyer with appropriate tracking settings
      await _initializeAppsFlyer(result == TrackingStatus.authorized);
    } catch (e) {
      print('Error requesting ATT: $e');
      // Still initialize AppsFlyer even on error, but with limited tracking
      await _initializeAppsFlyer(false);
    }
  }
  
  Future<void> _initializeAppsFlyer(bool isTrackingAllowed) async {
    try {
      final devKey = await _fetchDevKeyFromRemoteConfig();
      
      print("Initializing AppsFlyer with dev key: $devKey");
      
      final AppsFlyerOptions options = AppsFlyerOptions(
        afDevKey: devKey,
        appId: "6741470168",
        showDebug: true,
        timeToWaitForATTUserAuthorization: 1,
      );
      
      final appsflyerSdk = AppsflyerSdk(options);
      
      // Setup callbacks
      appsflyerSdk.onInstallConversionData((res) {
        print("AppsFlyer Install Conversion Data: $res");
        final data = res["data"];
        if (data != null) {
          final isFirstLaunch = data["is_first_launch"];
          if (isFirstLaunch != null && isFirstLaunch.toString() == "true") {
            print("This is a new AppsFlyer install!");
          }
          
          final mediaSource = data["media_source"];
          if (mediaSource != null) {
            print("Install attributed to: $mediaSource");
          }
          
          final campaign = data["campaign"];
          if (campaign != null) {
            print("Campaign: $campaign");
          }
        }
      });
      
      appsflyerSdk.onAppOpenAttribution((res) {
        print("AppsFlyer App Open Attribution: $res");
      });
      
      // Initialize and start SDK
      appsflyerSdk.initSdk(
        registerConversionDataCallback: true,
        registerOnAppOpenAttributionCallback: true,
        registerOnDeepLinkingCallback: true
      );
      
      appsflyerSdk.startSDK(
        onSuccess: () async {
          print("AppsFlyer SDK initialized successfully.");
          
          if (isTrackingAllowed) {
            final userType = await _getUserTypeAsync();
            appsflyerSdk.logEvent("user_session_started", {
              "session_start_time": DateTime.now().toIso8601String(),
              "tracking_permission_granted": true,
              "user_type": userType,
              "screen": "welcome_screen"
            });
          }
        },
        onError: (int errorCode, String errorMessage) => 
          print("Error initializing AppsFlyer SDK: Code $errorCode - $errorMessage"),
      );
      
      // Log limited events even with restricted tracking
      appsflyerSdk.logEvent("app_opened", {
        "open_time": DateTime.now().toIso8601String(),
        "tracking_enabled": isTrackingAllowed,
      });
      
    } catch (e) {
      print('Error initializing AppsFlyer: $e');
    }
  }
  
  Future<String> _getUserTypeAsync() async {
    try {
      final prefInstance = await SharedPreferences.getInstance();
      final firstOpen = prefInstance.getBool('first_open') ?? true;
      if (firstOpen) {
        await prefInstance.setBool('first_open', false);
        return "new_user";
      } else {
        return "returning_user";
      }
    } catch (e) {
      print("Error determining user type: $e");
      return "unknown";
    }
  }
  
  Future<String> _fetchDevKeyFromRemoteConfig() async {
    try {
      final remoteConfig = FirebaseRemoteConfig.instance;
      return remoteConfig.getString('dev_key');
    } catch (e) {
      print('Error fetching dev key: $e');
      return 'TVuiYiPd4Bu5wzUuZwTymX';
    }
  }

  Future<void> _checkPermissions(BuildContext context) async {
    final contactsStatus = await Permission.contacts.request();
    
    if (contactsStatus.isDenied) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Contacts permission is required for the app to function properly')),
      );
      return;
    }

    // Show interstitial ad before navigating (no loading indicator)
    final adsService = AdsService();
    await adsService.showInterstitialAtTransition(force: true);

    if (!context.mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => const DashboardScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('lib/assets/images/background.png'),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(
              Colors.black26,
              BlendMode.darken,
            ),
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Welcome to',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const Text(
                      'Caller ID Plus',
                      style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: Colors.lightBlue,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Manage your contacts and calls with ease',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        onPressed: () => _checkPermissions(context),
                        child: const Text(
                          'Get Started',
                          style: TextStyle(fontSize: 18),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 