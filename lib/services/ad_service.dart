import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Loads and shows AdMob interstitials (test units in debug).
class AdService {
  AdService._();

  static final AdService instance = AdService._();

  InterstitialAd? _interstitial;
  Future<void>? _loadFuture;

  static String get _interstitialUnitId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-3940256099942544/1033173712';
    }
    if (Platform.isIOS) {
      return 'ca-app-pub-3940256099942544/4411468910';
    }
    return 'ca-app-pub-3940256099942544/1033173712';
  }

  Future<void> preloadInterstitial() {
    if (_interstitial != null) {
      return Future.value();
    }
    if (_loadFuture != null) {
      return _loadFuture!;
    }

    final completer = Completer<void>();
    _loadFuture = completer.future;

    InterstitialAd.load(
      adUnitId: _interstitialUnitId,
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
}
