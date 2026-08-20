import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../config/ad_config.dart';

/// Loads and shows AdMob interstitials and rewarded ads.
class AdService {
  AdService._();

  static final AdService instance = AdService._();

  Future<void>? _initFuture;
  InterstitialAd? _interstitial;
  Future<void>? _loadFuture;
  RewardedAd? _rewarded;
  Future<void>? _rewardedLoadFuture;

  Future<void> ensureInitialized() {
    _initFuture ??= MobileAds.instance.initialize().then((_) {});
    return _initFuture!;
  }

  Future<void> preloadInterstitial() async {
    await ensureInitialized();
    if (_interstitial != null) {
      return Future.value();
    }
    if (_loadFuture != null) {
      return _loadFuture!;
    }

    final completer = Completer<void>();
    _loadFuture = completer.future;

    InterstitialAd.load(
      adUnitId: AdConfig.interstitialUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitial = ad;
          if (!completer.isCompleted) completer.complete();
        },
        onAdFailedToLoad: (_) {
          _interstitial = null;
          if (!completer.isCompleted) completer.complete();
        },
      ),
    );

    return completer.future.whenComplete(() {
      _loadFuture = null;
    });
  }

  /// Shows an interstitial if ready, then runs [onFinished] after it closes.
  Future<void> showInterstitial({VoidCallback? onFinished}) async {
    if (_interstitial == null) {
      await preloadInterstitial();
    }

    final ad = _interstitial;
    if (ad == null) {
      onFinished?.call();
      return;
    }

    _interstitial = null;
    final completer = Completer<void>();

    void finish() {
      if (!completer.isCompleted) {
        onFinished?.call();
        completer.complete();
      }
    }

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (dismissed) {
        dismissed.dispose();
        preloadInterstitial();
        finish();
      },
      onAdFailedToShowFullScreenContent: (failed, _) {
        failed.dispose();
        preloadInterstitial();
        finish();
      },
    );
    ad.show();
    await completer.future;
  }

  Future<void> preloadRewarded() async {
    await ensureInitialized();
    if (_rewarded != null) {
      return Future.value();
    }
    if (_rewardedLoadFuture != null) {
      return _rewardedLoadFuture!;
    }

    final completer = Completer<void>();
    _rewardedLoadFuture = completer.future;

    RewardedAd.load(
      adUnitId: AdConfig.rewardedUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewarded = ad;
          if (!completer.isCompleted) completer.complete();
        },
        onAdFailedToLoad: (_) {
          _rewarded = null;
          if (!completer.isCompleted) completer.complete();
        },
      ),
    );

    return completer.future.whenComplete(() {
      _rewardedLoadFuture = null;
    });
  }

  /// Shows a rewarded ad if ready. [onRewardEarned] runs when the user earns
  /// the reward; returns whether the reward callback was invoked.
  Future<bool> showRewardedAd({required VoidCallback onRewardEarned}) async {
    if (_rewarded == null) {
      await preloadRewarded();
    }

    final ad = _rewarded;
    if (ad == null) {
      return false;
    }

    _rewarded = null;
    final completer = Completer<bool>();
    var rewardEarned = false;

    void finish(bool earned) {
      if (!completer.isCompleted) {
        completer.complete(earned);
      }
    }

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (dismissed) {
        dismissed.dispose();
        preloadRewarded();
        finish(rewardEarned);
      },
      onAdFailedToShowFullScreenContent: (failed, _) {
        failed.dispose();
        preloadRewarded();
        finish(false);
      },
    );

    ad.show(
      onUserEarnedReward: (_, __) {
        rewardEarned = true;
        onRewardEarned();
      },
    );

    return completer.future;
  }
}
