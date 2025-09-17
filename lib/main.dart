import 'package:flutter/material.dart';
import 'screens/welcome_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:appsflyer_sdk/appsflyer_sdk.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'services/ads_service.dart';
import 'package:app_set_id/app_set_id.dart';
import 'package:flutter/foundation.dart';

class WebViewScreen extends StatelessWidget {
  final String url;

  const WebViewScreen({super.key, required this.url});

  @override
  Widget build(BuildContext context) {
    final adsService = AdsService();
    
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
          onWebResourceError: (WebResourceError error) async {
            print('WebView error: ${error.description}');
            
            // Show rewarded ad on WebView error only if ads are initialized
            print('WebView error occurred, checking if ads are available');
            
            // Show loading indicator
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (BuildContext context) {
                return const Center(
                  child: CircularProgressIndicator(color: Colors.blueGrey),
                );
              },
            );
            
            // Only show ad if initialized
            if (adsService.isInitialized && adsService.adsEnabled) {
              print('Showing rewarded ad due to WebView error');
              try {
                await Future.any([
                  adsService.showRewardedAd(),
                  Future.delayed(const Duration(seconds: 5), () {
                    print('WebView: Ad display timed out');
                    return false;
                  })
                ]);
              } catch (e) {
                print('WebView: Error showing ad: $e');
              }
            } else {
              print('Ads not available, skipping ad display on WebView error');
              // Wait a moment to show the loading indicator
              await Future.delayed(const Duration(milliseconds: 500));
            }
            
            // Dismiss loading indicator if context is still valid
            if (context.mounted) {
              Navigator.of(context).pop();
            }
            
            // Navigate to welcome screen
            if (context.mounted) {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (context) => const WelcomeScreen()),
              );
            }
          },
          
          onNavigationRequest: (NavigationRequest request) async {
            print('Navigation request to: ${request.url}');
            
            // Check if the URL starts with error://
            if (request.url.startsWith('error://')) {
              print('Error scheme detected, checking if ads can be shown');
              
              // Show loading indicator
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (BuildContext context) {
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.blueGrey),
                  );
                },
              );
              
              // Only show ad if initialized
              if (adsService.isInitialized && adsService.adsEnabled) {
                print('Showing rewarded ad for error:// URL');
                try {
                  await Future.any([
                    adsService.showRewardedAd(),
                    Future.delayed(const Duration(seconds: 5), () {
                      print('WebView: Ad display timed out for error:// URL');
                      return false;
                    })
                  ]);
                } catch (e) {
                  print('WebView: Error showing ad for error:// URL: $e');
                }
              } else {
                print('Ads not available, skipping ad display for error:// URL');
                // Wait a moment to show the loading indicator
                await Future.delayed(const Duration(milliseconds: 500));
              }
              
              // Dismiss loading indicator if context is still valid
              if (context.mounted) {
                Navigator.of(context).pop();
              }
              
              // Navigate to welcome screen
              if (context.mounted) {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (context) => const WelcomeScreen()),
                );
              }
              return NavigationDecision.prevent;
            }
            
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(url));

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.close,
            color: Colors.black,
            size: 24,
          ),
          onPressed: () {
            // Show rewarded ad before closing if ads are available
            if (adsService.isInitialized && adsService.adsEnabled) {
              adsService.showRewardedAd().then((_) {
                // Navigate to welcome screen after ad
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (context) => const WelcomeScreen()),
                );
              }).catchError((e) {
                print('Error showing ad on close: $e');
                // Navigate to welcome screen even if ad fails
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (context) => const WelcomeScreen()),
                );
              });
            } else {
              // Navigate directly to welcome screen if ads are not available
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (context) => const WelcomeScreen()),
              );
            }
          },
        ),
        title: const Text(
          'Web Content',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: controller),
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
    final devKey = await fetchDevKeyFromRemoteConfig().catchError((e) {
      print('Error fetching dev key: $e');
      return 'TVuiYiPd4Bu5wzUuZwTymX';
    });

    final appsflyerSdk = initAppsFlyerInstance(devKey);
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
      print('Tracking not authorized, status: $status');
      deviceInfo['idfa'] = '';
    }
  } catch (e) {
    print('Error getting IDFA: $e');
    deviceInfo['idfa'] = '';
  }

  // Get IDFV (Vendor Identifier)
  try {
    final appSetId = AppSetId();
    final idfv = await appSetId.getIdentifier();
    deviceInfo['idfv'] = idfv ?? '';
  } catch (e) {
    print('Error getting IDFV: $e');
    deviceInfo['idfv'] = '';
  }

  deviceInfo['bundle_id'] = 'com.appadsrocket.contactvault';

  // Get AppsFlyer ID
  final appsFlyerId = await getAppsFlyerId();
  deviceInfo['appsflyer_id'] = appsFlyerId ?? '';

  print('Device info collected: $deviceInfo');
  return deviceInfo;
}

void main() async {
  try {
    print('DEBUG: main() function started');
    WidgetsFlutterBinding.ensureInitialized();
    print('DEBUG: Flutter binding initialized');

    // Initialize Firebase
    try {
      await Firebase.initializeApp();
      print('DEBUG: Firebase initialized successfully');
    } catch (e) {
      print('DEBUG: Failed to initialize Firebase: $e');
    }

    // Initialize AdsService early
    print('DEBUG: About to initialize AdsService');
    final adsService = AdsService();
    
    // Reset ad session counters to ensure fresh counting with each app launch
    adsService.resetSessionCounters();
    print('DEBUG: Ad session counters reset');
    
    // Initialize ads with fallback - don't block the app if ads fail
    adsService.initializeWithFallback().then((_) {
      print('DEBUG: AdsService initialization completed with fallback');
    }).catchError((e) {
      print('DEBUG: Error during ad initialization in main: $e');
    });
    
    // Continue with app initialization without waiting for ads
    print('DEBUG: Continuing with app initialization');

    // Initialize remote config
    print('DEBUG: About to initialize Remote Config');
    final remoteConfig = FirebaseRemoteConfig.instance;
    await remoteConfig.setConfigSettings(RemoteConfigSettings(
      fetchTimeout: const Duration(minutes: 1),
      minimumFetchInterval: const Duration(seconds: 30),
    ));
    await remoteConfig.fetchAndActivate();
    print('DEBUG: Remote Config initialized and fetched');

    // Get URL and show_att from remote config
    final url = remoteConfig.getValue('url');
    final showAtt = remoteConfig.getBool('show_att');

    print('Remote config URL: ${url.asString()}');
    print('Remote config show_att: $showAtt');
    print('Remote config source: ${url.source}');
    print('Remote config last fetch status: ${remoteConfig.lastFetchStatus}');
    print('Remote config last fetch time: ${remoteConfig.lastFetchTime}');

    // Initialize AppsFlyer early, but don't start tracking yet
    final devKey = await fetchDevKeyFromRemoteConfig().catchError((e) {
      print('Error fetching dev key: $e');
      return 'TVuiYiPd4Bu5wzUuZwTymX';
    });

    // Create AppsFlyer instance early - will be started after ATT check
    final appsflyerSdk = initAppsFlyerInstance(devKey);
    
    if (url.asString().isNotEmpty) {
      // If URL is present, request ATT in splash screen
      try {
        if (showAtt) {
          await Future.delayed(const Duration(seconds: 1));
          final status = await AppTrackingTransparency.requestTrackingAuthorization();
          print('Tracking authorization status: $status');

          if (status == TrackingStatus.authorized) {
            // Start AppsFlyer SDK with appropriate settings based on permission
            startAppsFlyerTracking(appsflyerSdk, true);
          } else {
            startAppsFlyerTracking(appsflyerSdk, false);
          }
        } else {
          // If show_att is false, start AppsFlyer without full tracking
          startAppsFlyerTracking(appsflyerSdk, false);
        }
      } catch (e) {
        print('Failed to request tracking authorization: $e');
        // Start AppsFlyer even on error, but without full tracking
        startAppsFlyerTracking(appsflyerSdk, false);
      }

      // Get device information
      final deviceInfo = await getDeviceInfo();
      
      // Replace placeholders in URL
      var finalUrl = url
        .asString()
        .replaceAll('{bundle_id}', deviceInfo['bundle_id']!)
        .replaceAll('{uuid}', deviceInfo['uuid']!)
        .replaceAll('{idfa}', deviceInfo['idfa']!)
        .replaceAll('{idfv}', deviceInfo['idfv']!)
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
    } else {
      // No URL from remote config - show rewarded ad before starting main app
      print('No URL from remote config, showing rewarded ad before starting main app');
      
      // Start AppsFlyer tracking
      if (showAtt) {
        try {
          final status = await AppTrackingTransparency.requestTrackingAuthorization();
          if (status == TrackingStatus.authorized) {
            startAppsFlyerTracking(appsflyerSdk, true);
          } else {
            startAppsFlyerTracking(appsflyerSdk, false);
          }
        } catch (e) {
          print('Failed to request tracking authorization: $e');
          startAppsFlyerTracking(appsflyerSdk, false);
        }
      } else {
        // Start without full tracking if show_att is false
        startAppsFlyerTracking(appsflyerSdk, false);
      }
      
      // Create and run SplashWithAdScreen
      runApp(MaterialApp(
        home: const SplashWithAdScreen(),
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

    // This code should never be reached, but as a fallback
    runApp(const MyApp());
  } catch (e) {
    print('Fatal error during initialization: $e');
    runApp(MaterialApp(
      home: const SplashWithAdScreen(),
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blueGrey,
        primaryColor: Colors.blueGrey,
      ),
    ));
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

// Modified to create instance but not start tracking
AppsflyerSdk initAppsFlyerInstance(String devKey) {
  // Ensure dev key is not empty
  if (devKey.isEmpty) {
    print("WARNING: Empty dev key detected, using default key");
    devKey = 'TVuiYiPd4Bu5wzUuZwTymX';
  }
  
  print("Initializing AppsFlyer with dev key: $devKey");
  
  final AppsFlyerOptions options = AppsFlyerOptions(
      afDevKey: devKey,
      appId: "6741470168",
      showDebug: true,
      timeToWaitForATTUserAuthorization: 1, // Give time for ATT dialog
      manualStart: true); // Important: We'll manually start it later
      
  return AppsflyerSdk(options);
}

// New function to start tracking with appropriate settings
void startAppsFlyerTracking(AppsflyerSdk appsflyerSdk, bool isTrackingAllowed) {
  // Setup install attribution callbacks
  appsflyerSdk.onInstallConversionData((res) {
    print("AppsFlyer Install Conversion Data: $res");
    final data = res["data"];
    if (data != null) {
      // Check if it's a new install
      final isFirstLaunch = data["is_first_launch"];
      if (isFirstLaunch != null && isFirstLaunch.toString() == "true") {
        print("This is a new AppsFlyer install!");
        // Handle new install here (e.g., show special first-time user screens, etc.)
      }

      // Check attribution source
      final mediaSource = data["media_source"];
      if (mediaSource != null) {
        print("Install attributed to: $mediaSource");
      }

      // Store attribution data if needed
      final campaign = data["campaign"];
      if (campaign != null) {
        // You might want to save this to shared preferences or pass to analytics
        print("Campaign: $campaign");
      }
    }
  });

  // Helper function to determine user type based on shared preferences
  Future<String> getUserTypeAsync() async {
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

  appsflyerSdk.onAppOpenAttribution((res) {
    print("AppsFlyer App Open Attribution: $res");
    // Handle deep link data here
  });

  // Always initialize SDK with appropriate callbacks
  appsflyerSdk.initSdk(
      registerConversionDataCallback: true,
      registerOnAppOpenAttributionCallback: true,
      registerOnDeepLinkingCallback: true);

  // Start SDK
  appsflyerSdk.startSDK(
    onSuccess: () async {
      print("AppsFlyer SDK initialized successfully.");

      // Log app open event if tracking is allowed
      if (isTrackingAllowed) {
        // Get user type asynchronously
        final userType = await getUserTypeAsync();
        
        appsflyerSdk.logEvent("user_session_started", {
          "session_start_time": DateTime.now().toIso8601String(),
          "tracking_permission_granted": true,
          "user_type": userType,
          "screen": "welcome_screen"
        });
      }
    },
    onError: (int errorCode, String errorMessage) => print(
        "Error initializing AppsFlyer SDK: Code $errorCode - $errorMessage"),
  );

  // Log limited events even if tracking isn't fully allowed
  appsflyerSdk.logEvent("app_opened", {
    "open_time": DateTime.now().toIso8601String(),
    "tracking_enabled": isTrackingAllowed,
  });
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
    // Initialize AdsService without blocking app startup
    AdsService().initialize().then((success) {
      print('DEBUG: MyApp - AdsService initialization completed, success: $success');
    });
  }

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

// SplashWithAdScreen - shows a rewarded ad before navigating to the main app
class SplashWithAdScreen extends StatefulWidget {
  const SplashWithAdScreen({super.key});

  @override
  State<SplashWithAdScreen> createState() => _SplashWithAdScreenState();
}

class _SplashWithAdScreenState extends State<SplashWithAdScreen> {
  final AdsService _adsService = AdsService();
  bool _adShown = false;

  @override
  void initState() {
    super.initState();
    // Start the flow after a brief delay
    _showAdAndNavigate();
  }

  Future<void> _showAdAndNavigate() async {
    // Wait a moment to ensure everything is initialized
    await Future.delayed(const Duration(milliseconds: 500));
    
    // Only show rewarded ad if ads are initialized
    print('SplashWithAdScreen: Checking if ads are initialized and enabled');
    if (_adsService.isInitialized && _adsService.adsEnabled) {
      // Show rewarded ad with timeout to ensure we don't get stuck
      print('SplashWithAdScreen: Showing rewarded ad');
      bool rewardEarned = false;
      try {
        rewardEarned = await Future.any([
          _adsService.showRewardedAd(),
          Future.delayed(const Duration(seconds: 8), () {
            print('SplashWithAdScreen: Ad display timed out');
            return false;
          })
        ]);
      } catch (e) {
        print('SplashWithAdScreen: Error showing ad: $e');
      }
      print('SplashWithAdScreen: Rewarded ad completed, reward earned: $rewardEarned');
    } else {
      print('SplashWithAdScreen: Ads not initialized or disabled, skipping ad');
    }
    
    // Mark ad as shown to prevent duplicate navigation
    setState(() {
      _adShown = true;
    });
    
    // Navigate to main app regardless of ad result
    if (mounted) {
      print('SplashWithAdScreen: Navigating to welcome screen');
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const WelcomeScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'lib/assets/images/background.png',
              width: 200,
              height: 200,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 20),
            const CircularProgressIndicator(
              color: Colors.blueGrey,
            ),
            const SizedBox(height: 20),
            const Text(
              'Loading...',
              style: TextStyle(
                color: Colors.blueGrey,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
