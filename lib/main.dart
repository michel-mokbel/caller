import 'package:flutter/material.dart';
import 'screens/welcome_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:appsflyer_sdk/appsflyer_sdk.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:app_tracking_transparency/app_tracking_transparency.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    initPlugin();
  }

  Future<void> initPlugin() async {
    try {
      final status = await AppTrackingTransparency.trackingAuthorizationStatus;
      
      // If not determined, request permission
      if (status == TrackingStatus.notDetermined) {
        // Show tracking dialog
        await Future.delayed(const Duration(milliseconds: 200));
        final newStatus = await AppTrackingTransparency.requestTrackingAuthorization();
        
        final isTrackingAllowed = newStatus == TrackingStatus.authorized;
        if (isTrackingAllowed) {
          String devKey = await fetchDevKeyFromRemoteConfig();
          initAppsFlyer(devKey, isTrackingAllowed);
        }
      } else {
        final isTrackingAllowed = status == TrackingStatus.authorized;
        if (isTrackingAllowed) {
          String devKey = await fetchDevKeyFromRemoteConfig();
          initAppsFlyer(devKey, isTrackingAllowed);
        }
      }
    } catch (e) {
      print("Error initializing tracking: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vault Book',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.lightBlue),
        useMaterial3: true,
      ),
      debugShowCheckedModeBanner: false,
      home: const WelcomeScreen(),
    );
  }
}

Future<String> fetchDevKeyFromRemoteConfig() async {
  final FirebaseRemoteConfig remoteConfig = FirebaseRemoteConfig.instance;
  try {
    await remoteConfig.setDefaults(<String, dynamic>{
      'dev_key': 'TVuiYiPd4Bu5wzUuZwTymX', // Default value if Remote Config fails
    });
    await remoteConfig.fetchAndActivate();
    String devKey = remoteConfig.getString('dev_key');
    print('Fetched dev_key: $devKey');
    return devKey;
  } catch (e) {
    print('Error fetching dev_key from Remote Config: $e');
    return 'TVuiYiPd4Bu5wzUuZwTymX'; // Fallback dev key
  }
}

void initAppsFlyer(String devKey, bool isTrackingAllowed) {
  // Set timeToWaitForATTUserAuthorization based on tracking permission
  final double timeToWait = isTrackingAllowed ? 10 : 0;

  final AppsFlyerOptions options = AppsFlyerOptions(
      afDevKey: devKey,
      appId: "6741470168",
      showDebug: true,
      timeToWaitForATTUserAuthorization: timeToWait,
      manualStart: false);

  final appsflyerSdk = AppsflyerSdk(options);

  if (isTrackingAllowed) {
    appsflyerSdk.initSdk(
        registerConversionDataCallback: true,
        registerOnAppOpenAttributionCallback: true,
        registerOnDeepLinkingCallback: true);
    appsflyerSdk.startSDK(
      onSuccess: () => print("AppsFlyer SDK initialized successfully."),
      onError: (int errorCode, String errorMessage) => print(
          "Error initializing AppsFlyer SDK: Code $errorCode - $errorMessage"),
    );
  } else {
    print("Tracking denied, skipping AppsFlyer initialization.");
  }
}
