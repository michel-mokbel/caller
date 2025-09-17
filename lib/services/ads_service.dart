import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:unity_ads_plugin/unity_ads_plugin.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

/// Banner position enum for more readable code
enum BannerPosition {
  top,
  bottom,
}

class AdsService {
  // Unity Ads Game IDs
  static const String _androidGameId = '5811625';  // Android Game ID
  static const String _iosGameId = '5811624';      // iOS Game ID
  
  // Ad Unit IDs
  static const String _rewardedAdUnitId = 'Rewarded_iOS';  // Updated for Unity Ads
  static const String _interstitialAdUnitId = 'Interstitial_iOS'; // Updated for Unity Ads
  static const String _bannerAdUnitId = 'Banner_iOS'; // Added Banner Ad Unit ID
  
  
  // Singleton pattern
  static final AdsService _instance = AdsService._internal();
  factory AdsService() => _instance;
  AdsService._internal();
  
  // Service state
  bool _isInitialized = false;
  bool _isRewardedAdReady = false;
  bool _isInterstitialAdReady = false;
  bool _isBannerAdReady = false;
  bool _adsEnabled = true; // Can be toggled dynamically
  
  // Session counters
  int _rewardedAdsShownThisSession = 0;
  int _interstitialAdsShownThisSession = 0;
  
  // Getters
  bool get isInitialized => _isInitialized;
  bool get adsEnabled => _adsEnabled;
  
  // Ad cooldown management
  DateTime? _lastRewardedAdShown;
  DateTime? _lastInterstitialAdShown;
  static const int _adCooldownSeconds = 30;  // Cooldown period between ads
  
  /// Reset session counters when app starts
  void resetSessionCounters() {
    _rewardedAdsShownThisSession = 0;
    _interstitialAdsShownThisSession = 0;
    debugPrint('Ad session counters reset');
  }
  
  /// Initialize Unity Ads SDK
  Future<bool> initialize() async {
    if (_isInitialized) {
      debugPrint('Unity Ads already initialized');
      return true;
    }
    
    try {
      debugPrint('Initializing Unity Ads');
      
      // Determine the correct Game ID based on platform
      const gameId = _iosGameId;
      
      final completer = Completer<bool>();
      
      // Add timeout to prevent infinite waiting
      Timer(const Duration(seconds: 10), () {
        if (!completer.isCompleted) {
          debugPrint('Unity Ads initialization timeout');
          completer.complete(false);
        }
      });
      
      UnityAds.init(
        gameId: gameId,
        testMode: false,
        onComplete: () {
          debugPrint('Unity Ads initialization complete');
          if (!completer.isCompleted) {
            _isInitialized = true;
            // Load all ad types immediately after initialization
            _loadAds();
            completer.complete(true);
          }
        },
        onFailed: (error, message) {
          debugPrint('Unity Ads initialization failed: $error - $message');
          if (!completer.isCompleted) {
            completer.complete(false);
          }
        },
      );
      
      return completer.future;
    } catch (e) {
      debugPrint('Exception during Unity Ads initialization: $e');
      return false;
    }
  }
  
  /// Initialize with fallback - tries to initialize but doesn't block the app
  Future<void> initializeWithFallback() async {
    try {
      final success = await initialize();
      if (!success) {
        debugPrint('Unity Ads initialization failed, continuing without ads');
        _adsEnabled = false;
      }
    } catch (e) {
      debugPrint('Unity Ads initialization error, continuing without ads: $e');
      _adsEnabled = false;
    }
  }
  
  /// Load all ad types
  void _loadAds() {
    debugPrint('Loading all ad types');
    _loadRewardedAd();
    _loadInterstitialAd();
    // Banner ads are loaded when shown, not preloaded
  }
  
  /// Load a rewarded ad
  void _loadRewardedAd() {
    if (_isRewardedAdReady) {
      debugPrint('Rewarded ad already loaded, skipping load');
      return;
    }
    
    final adUnitId = getRewardedAdUnitId();
    debugPrint('Loading rewarded ad: $adUnitId');
    UnityAds.load(
      placementId: adUnitId,
      onComplete: (placementId) {
        debugPrint('Rewarded ad loaded successfully: $placementId');
        _isRewardedAdReady = true;
      },
      onFailed: (placementId, error, message) {
        debugPrint('Rewarded ad load failed: $placementId, $error, $message');
        _isRewardedAdReady = false;
        // Retry after a delay
        Future.delayed(const Duration(seconds: 15), _loadRewardedAd);
      },
    );
  }
  
  /// Load an interstitial ad
  void _loadInterstitialAd() {
    if (_isInterstitialAdReady) {
      debugPrint('Interstitial ad already loaded, skipping load');
      return;
    }
    
    final adUnitId = getInterstitialAdUnitId();
    debugPrint('Loading interstitial ad: $adUnitId');
    UnityAds.load(
      placementId: adUnitId,
      onComplete: (placementId) {
        debugPrint('Interstitial ad loaded successfully: $placementId');
        _isInterstitialAdReady = true;
      },
      onFailed: (placementId, error, message) {
        debugPrint('Interstitial ad load failed: $placementId, $error, $message');
        _isInterstitialAdReady = false;
        // Retry after a delay
        Future.delayed(const Duration(seconds: 15), _loadInterstitialAd);
      },
    );
  }
  
  /// Show a rewarded ad
  /// Returns true if the user earned a reward, false otherwise
  Future<bool> showRewardedAd() async {
    if (!_isInitialized) {
      debugPrint('Unity Ads not initialized yet');
      await initialize();
    }
    
    // Check cooldown period
    if (_lastRewardedAdShown != null) {
      final timeSinceLastAd = DateTime.now().difference(_lastRewardedAdShown!);
      if (timeSinceLastAd.inSeconds < _adCooldownSeconds) {
        debugPrint('Rewarded ad in cooldown period, seconds remaining: ${_adCooldownSeconds - timeSinceLastAd.inSeconds}');
        // Still return true as if user got a reward when in cooldown
        return true;
      }
    }
    
    // Check if rewarded ad is loaded - don't block if not ready
    if (!_isRewardedAdReady) {
      debugPrint('Rewarded ad not ready, starting load for next time');
      // Start loading for next time in background
      _loadRewardedAd();
      return false;
    }
    
    // Prepare for ad result
    Completer<bool> rewardCompleter = Completer<bool>();
    bool wasAdShown = false;
    
    try {
      final adUnitId = getRewardedAdUnitId();
      debugPrint('Showing rewarded ad: $adUnitId');
      
      UnityAds.showVideoAd(
        placementId: adUnitId,
        onStart: (placementId) {
          debugPrint('Rewarded ad started: $placementId');
          wasAdShown = true;
          _rewardedAdsShownThisSession++;
        },
        onComplete: (placementId) {
          debugPrint('Rewarded ad completed: $placementId');
          _lastRewardedAdShown = DateTime.now();
          _isRewardedAdReady = false;
          _loadRewardedAd();  // Load next ad
          
          // User earned reward
          if (!rewardCompleter.isCompleted) {
            rewardCompleter.complete(true);
          }
        },
        onFailed: (placementId, error, message) {
          debugPrint('Rewarded ad failed: $placementId, $error, $message');
          _isRewardedAdReady = false;
          _loadRewardedAd();  // Try to load again
          
          if (!rewardCompleter.isCompleted) {
            rewardCompleter.complete(false);
          }
        },
        onSkipped: (placementId) {
          debugPrint('Rewarded ad skipped: $placementId');
          _lastRewardedAdShown = DateTime.now();
          _isRewardedAdReady = false;
          _loadRewardedAd();  // Load next ad
          
          // User skipped, no reward
          if (!rewardCompleter.isCompleted) {
            rewardCompleter.complete(false);
          }
        },
      );
      
      // Set a timeout in case ad never completes
      Timer(const Duration(seconds: 30), () {
        if (!rewardCompleter.isCompleted) {
          debugPrint('Rewarded ad timed out');
          rewardCompleter.complete(false);
        }
      });
    } catch (e) {
      debugPrint('Exception showing rewarded ad: $e');
      if (!rewardCompleter.isCompleted) {
        rewardCompleter.complete(false);
      }
    }
    
    // Save ad viewing history
    if (wasAdShown) {
      _updateAdViewingHistory('rewarded');
    }
    
    return rewardCompleter.future;
  }
  
  /// Show an interstitial ad
  Future<bool> showInterstitialAd() async {
    if (!_isInitialized) {
      debugPrint('Unity Ads not initialized yet');
      await initialize();
    }
    
    // Check cooldown period
    if (_lastInterstitialAdShown != null) {
      final timeSinceLastAd = DateTime.now().difference(_lastInterstitialAdShown!);
      if (timeSinceLastAd.inSeconds < _adCooldownSeconds) {
        debugPrint('Interstitial ad in cooldown period, seconds remaining: ${_adCooldownSeconds - timeSinceLastAd.inSeconds}');
        return false;
      }
    }
    
    // Check if interstitial ad is loaded - don't block if not ready
    if (!_isInterstitialAdReady) {
      debugPrint('Interstitial ad not ready, starting load for next time');
      // Start loading for next time in background
      _loadInterstitialAd();
      return false;
    }
    
    // Prepare for ad result
    Completer<bool> showCompleter = Completer<bool>();
    bool wasAdShown = false;
    
    try {
      final adUnitId = getInterstitialAdUnitId();
      debugPrint('Showing interstitial ad: $adUnitId');
      
      UnityAds.showVideoAd(
        placementId: adUnitId,
        onStart: (placementId) {
          debugPrint('Interstitial ad started: $placementId');
          wasAdShown = true;
          _interstitialAdsShownThisSession++;
        },
        onComplete: (placementId) {
          debugPrint('Interstitial ad completed: $placementId');
          _lastInterstitialAdShown = DateTime.now();
          _isInterstitialAdReady = false;
          _loadInterstitialAd();  // Load next ad
          
          if (!showCompleter.isCompleted) {
            showCompleter.complete(true);
          }
        },
        onFailed: (placementId, error, message) {
          debugPrint('Interstitial ad failed: $placementId, $error, $message');
          _isInterstitialAdReady = false;
          _loadInterstitialAd();  // Try to load again
          
          if (!showCompleter.isCompleted) {
            showCompleter.complete(false);
          }
        },
        onSkipped: (placementId) {
          debugPrint('Interstitial ad skipped: $placementId');
          _lastInterstitialAdShown = DateTime.now();
          _isInterstitialAdReady = false;
          _loadInterstitialAd();  // Load next ad
          
          if (!showCompleter.isCompleted) {
            showCompleter.complete(true);  // Count as shown even if skipped
          }
        },
      );
      
      // Set a timeout in case ad never completes
      Timer(const Duration(seconds: 30), () {
        if (!showCompleter.isCompleted) {
          debugPrint('Interstitial ad timed out');
          showCompleter.complete(false);
        }
      });
    } catch (e) {
      debugPrint('Exception showing interstitial ad: $e');
      if (!showCompleter.isCompleted) {
        showCompleter.complete(false);
      }
    }
    
    // Save ad viewing history
    if (wasAdShown) {
      _updateAdViewingHistory('interstitial');
    }
    
    return showCompleter.future;
  }
  
  /// Track ad viewing history in SharedPreferences
  Future<void> _updateAdViewingHistory(String adType) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Update total count
      int totalCount = prefs.getInt('ad_view_count_$adType') ?? 0;
      await prefs.setInt('ad_view_count_$adType', totalCount + 1);
      
      // Update daily count
      String today = DateTime.now().toIso8601String().split('T')[0];
      String lastRecordedDay = prefs.getString('ad_view_last_day_$adType') ?? '';
      
      if (today == lastRecordedDay) {
        int dailyCount = prefs.getInt('ad_view_daily_count_$adType') ?? 0;
        await prefs.setInt('ad_view_daily_count_$adType', dailyCount + 1);
      } else {
        await prefs.setString('ad_view_last_day_$adType', today);
        await prefs.setInt('ad_view_daily_count_$adType', 1);
      }
      
      debugPrint('Updated $adType ad view history: total=${totalCount + 1}');
    } catch (e) {
      debugPrint('Error updating ad view history: $e');
    }
  }
  
  /// Check if an ad type is ready to show
  bool isAdReady(String adType) {
    switch (adType) {
      case 'rewarded':
        return _isRewardedAdReady;
      case 'interstitial':
        return _isInterstitialAdReady;
      default:
        return false;
    }
  }
  
  /// Modified to be non-blocking - returns current status immediately if needed
  /// and initiates a load in the background if the ad isn't ready
  Future<bool> ensureAdLoaded(String adType, {Duration timeout = const Duration(seconds: 5), bool blockUntilLoaded = false}) async {
    // If ad is already ready, return immediately
    if (isAdReady(adType)) {
      return true;
    }
    
    // Start loading in background
    debugPrint('Starting $adType ad load in background');
    if (adType == 'rewarded') {
      _loadRewardedAd();
    } else if (adType == 'interstitial') {
      _loadInterstitialAd();
    } else {
      return false;
    }
    
    // If non-blocking mode requested, return current status immediately
    if (!blockUntilLoaded) {
      return isAdReady(adType);
    }
    
    // Otherwise, wait for the ad to be ready with timeout
    final Completer<bool> completer = Completer<bool>();
    
    // Create a timer for the timeout
    final timer = Timer(timeout, () {
      if (!completer.isCompleted) {
        debugPrint('Timeout waiting for $adType ad to be loaded');
        completer.complete(isAdReady(adType));
      }
    });
    
    // Poll status until ready or timeout
    void checkStatus() {
      if (!completer.isCompleted) {
        if (isAdReady(adType)) {
          debugPrint('$adType ad is now ready');
          timer.cancel();
          completer.complete(true);
        } else {
          // Check again after a short delay
          Future.delayed(const Duration(milliseconds: 500), checkStatus);
        }
      }
    }
    
    // Start checking
    checkStatus();
    
    return completer.future;
  }
  
  /// Show a banner ad at the specified placement (top or bottom)
  /// Returns true if the banner was shown successfully
  Future<bool> showBannerAd(BannerPosition position) async {
    if (!_isInitialized) {
      debugPrint('Unity Ads not initialized yet');
      await initialize();
    }
    
    try {
      debugPrint('Preparing banner ad at ${position.toString()}');
      _isBannerAdReady = true;
      return true;
    } catch (e) {
      debugPrint('Exception preparing banner ad: $e');
      return false;
    }
  }
  
  /// Get the banner ad placement ID
  static String getBannerAdUnitId() {
    return _bannerAdUnitId;
  }
  
  /// Hide the currently displayed banner ad
  Future<void> hideBannerAd() async {
    _isBannerAdReady = false;
    debugPrint('Banner ad marked as hidden');
  }
  
  /// Check if banner ad is ready
  bool isBannerAdReady() {
    return _isBannerAdReady;
  }
  
  /// Show an interstitial ad at appropriate transition points
  /// Returns true if the ad was shown and completed, false otherwise
  Future<bool> showInterstitialAtTransition({bool force = false}) async {
    // Skip if in cooldown period unless forced
    if (!force && _lastInterstitialAdShown != null) {
      final timeSinceLastAd = DateTime.now().difference(_lastInterstitialAdShown!);
      if (timeSinceLastAd.inSeconds < _adCooldownSeconds) {
        debugPrint('Interstitial ad skipped due to cooldown (${_adCooldownSeconds - timeSinceLastAd.inSeconds}s remaining)');
        return false;
      }
    }
    
    // Only show interstitial ~30% of the time unless forced, to prevent user frustration
    if (!force && (DateTime.now().millisecondsSinceEpoch % 10 > 3)) {
      debugPrint('Interstitial ad randomly skipped to prevent user frustration');
      return false;
    }
    
    // Show the ad
    return showInterstitialAd();
  }
  
  /// Get the appropriate ad unit ID based on platform
  static String getRewardedAdUnitId() {
    return _rewardedAdUnitId;
  }
  
  static String getInterstitialAdUnitId() {
    return _interstitialAdUnitId;
  }
}