import 'dart:io';

import 'package:flutter/foundation.dart';

/// AdMob app and unit IDs for Arrow Maze.
class AdConfig {
  AdConfig._();

  // Production — Android
  static const androidAppId = 'ca-app-pub-9666719034050097~1870693828';
  static const androidBannerUnitId = 'ca-app-pub-9666719034050097/5304290341';
  static const androidInterstitialUnitId =
      'ca-app-pub-9666719034050097/7262621306';
  static const androidRewardedUnitId = 'ca-app-pub-9666719034050097/5757967945';

  // Google test IDs — used in debug builds only.
  static const testAndroidAppId = 'ca-app-pub-3940256099942544~3347511713';
  static const testIosAppId = 'ca-app-pub-3940256099942544~1458002511';
  static const testAndroidBannerUnitId =
      'ca-app-pub-3940256099942544/6300978111';
  static const testIosBannerUnitId = 'ca-app-pub-3940256099942544/2934735716';
  static const testAndroidInterstitialUnitId =
      'ca-app-pub-3940256099942544/1033173712';
  static const testIosInterstitialUnitId =
      'ca-app-pub-3940256099942544/4411468910';
  static const testAndroidRewardedUnitId =
      'ca-app-pub-3940256099942544/5224354917';
  static const testIosRewardedUnitId =
      'ca-app-pub-3940256099942544/1712485313';

  static String get bannerUnitId {
    if (kDebugMode) {
      return Platform.isIOS ? testIosBannerUnitId : testAndroidBannerUnitId;
    }
    if (Platform.isIOS) return testIosBannerUnitId;
    return androidBannerUnitId;
  }

  static String get interstitialUnitId {
    if (kDebugMode) {
      return Platform.isIOS
          ? testIosInterstitialUnitId
          : testAndroidInterstitialUnitId;
    }
    if (Platform.isIOS) return testIosInterstitialUnitId;
    return androidInterstitialUnitId;
  }

  static String get rewardedUnitId {
    if (kDebugMode) {
      return Platform.isIOS ? testIosRewardedUnitId : testAndroidRewardedUnitId;
    }
    if (Platform.isIOS) return testIosRewardedUnitId;
    return androidRewardedUnitId;
  }
}
