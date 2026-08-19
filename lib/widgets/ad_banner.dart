import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../config/ad_config.dart';

/// Standard bottom banner ad slot.
class AdBanner extends StatefulWidget {
  const AdBanner({super.key});

  @override
  State<AdBanner> createState() => _AdBannerState();
}

class _AdBannerState extends State<AdBanner> {
  BannerAd? _bannerAd;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  void _loadAd() {
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
        onAdFailedToLoad: (ad, _) {
          ad.dispose();
          if (mounted) setState(() => _loaded = false);
        },
      ),
    );
    banner.load();
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
