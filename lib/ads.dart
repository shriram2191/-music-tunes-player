import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Replace the test IDs below with your real ad unit IDs from admob.google.com
/// before release, or ads will earn nothing.
class AdIds {
  static String get banner => Platform.isAndroid
      ? 'ca-app-pub-3940256099942544/6300978111'   // Android test banner
      : 'ca-app-pub-3940256099942544/2934735716';  // iOS test banner
}

class BannerAdWidget extends StatefulWidget {
  const BannerAdWidget({super.key});
  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  BannerAd? _banner;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _banner = BannerAd(
      adUnitId: AdIds.banner,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) => setState(() => _loaded = true),
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          _banner = null;
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _banner?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final b = _banner;
    if (b == null || !_loaded) return const SizedBox.shrink();
    return Container(
      color: Colors.black,
      width: b.size.width.toDouble(),
      height: b.size.height.toDouble(),
      alignment: Alignment.center,
      child: AdWidget(ad: b),
    );
  }
}
