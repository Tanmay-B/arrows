import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Loads and shows AdMob interstitials (test units in debug).
class AdService {
  AdService._();

  static final AdService instance = AdService._();

  InterstitialAd? _interstitial;
  bool _loading = false;

  static String get _interstitialUnitId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-3940256099942544/1033173712';
    }
    if (Platform.isIOS) {
      return 'ca-app-pub-3940256099942544/4411468910';
    }
    return 'ca-app-pub-3940256099942544/1033173712';
  }

  Future<void> preloadInterstitial() async {
    if (_interstitial != null || _loading) return;
    _loading = true;

    await InterstitialAd.load(
      adUnitId: _interstitialUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitial = ad;
          _loading = false;
        },
        onAdFailedToLoad: (_) {
          _interstitial = null;
          _loading = false;
        },
      ),
    );
  }

  /// Shows an interstitial if ready, then runs [onFinished] after it closes.
  Future<void> showInterstitial({VoidCallback? onFinished}) async {
    final ad = _interstitial;
    if (ad == null) {
      await preloadInterstitial();
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
