import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../config/ad_config.dart';
import '../services/ad_service.dart';

bool _isFlutterTest() =>
    !kIsWeb && Platform.environment['FLUTTER_TEST'] == 'true';

/// Standard bottom banner ad slot.
class AdBanner extends StatefulWidget {
  const AdBanner({super.key});

  @override
  State<AdBanner> createState() => _AdBannerState();
}

class _AdBannerState extends State<AdBanner> {
  BannerAd? _bannerAd;
  bool _loaded = false;
  int _loadAttempts = 0;
  static const _maxLoadAttempts = 4;

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  Future<void> _loadAd() async {
    if (_isFlutterTest()) return;

    await AdService.instance.ensureInitialized();
    if (!mounted) return;

    _bannerAd?.dispose();
    _bannerAd = null;
    _loaded = false;

    final banner = BannerAd(
      adUnitId: AdConfig.bannerUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (!mounted) {
            ad.dispose();
            return;
          }
          setState(() {
            _bannerAd = ad as BannerAd;
            _loaded = true;
          });
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          if (kDebugMode) {
            debugPrint('Banner ad failed to load: ${error.message}');
          }
          if (!mounted) return;
          setState(() => _loaded = false);
          _scheduleRetry();
        },
      ),
    );
    _bannerAd = banner;
    banner.load();
  }

  void _scheduleRetry() {
    if (_loadAttempts >= _maxLoadAttempts || !mounted) return;
    _loadAttempts++;
    Future<void>.delayed(Duration(seconds: _loadAttempts * 2), () {
      if (mounted) _loadAd();
    });
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final height = AdSize.banner.height.toDouble();

    if (!_loaded || _bannerAd == null) {
      return SizedBox(
        height: height,
        width: double.infinity,
        child: const ColoredBox(
          color: Color(0xFFEDE4D8),
          child: Center(
            child: Text(
              'Ad',
              style: TextStyle(
                color: Color(0xFF998B7E),
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: height,
      width: double.infinity,
      child: AdWidget(ad: _bannerAd!),
    );
  }
}
