import 'dart:io';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'dart:async';

class AdService {
  static String get rewardedAdUnitId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-3940256099942544/5354046379'; // Android 테스트 보상형 전면광고 ID
    } else if (Platform.isIOS) {
      return 'ca-app-pub-3940256099942544/6978759866'; // iOS 테스트 보상형 전면광고 ID
    } else {
      throw UnsupportedError('Unsupported platform');
    }
  }

  RewardedInterstitialAd? _rewardedAd;
  bool _isAdLoading = false;

  Future<void> loadRewardedAd() async {
    if (_rewardedAd != null || _isAdLoading) {
      print(
          'Ad loading skipped: ${_rewardedAd != null ? "Ad already loaded" : "Loading in progress"}');
      return;
    }

    print('Starting to load rewarded interstitial ad...');
    _isAdLoading = true;

    try {
      await RewardedInterstitialAd.load(
        adUnitId: rewardedAdUnitId,
        request: const AdRequest(),
        rewardedInterstitialAdLoadCallback: RewardedInterstitialAdLoadCallback(
          onAdLoaded: (ad) {
            print('Rewarded interstitial ad loaded successfully');
            _rewardedAd = ad;
            _isAdLoading = false;

            // Set up full screen content callback
            ad.fullScreenContentCallback = FullScreenContentCallback(
              onAdShowedFullScreenContent: (ad) {
                print('Ad showed fullscreen content');
              },
              onAdDismissedFullScreenContent: (ad) {
                print('Ad dismissed');
                ad.dispose();
                _rewardedAd = null;
                loadRewardedAd(); // Reload after dismissal
              },
              onAdFailedToShowFullScreenContent: (ad, error) {
                print(
                    'Failed to show ad: ${error.message} (Error code: ${error.code})');
                ad.dispose();
                _rewardedAd = null;
                // Immediate retry on show failure
                loadRewardedAd();
              },
              onAdImpression: (ad) {
                print('Ad impression recorded');
              },
            );
          },
          onAdFailedToLoad: (error) {
            print(
                'Failed to load rewarded interstitial ad: ${error.message} (Error code: ${error.code})');
            _rewardedAd = null;
            _isAdLoading = false;
            // Retry after delay on load failure
            Future.delayed(const Duration(seconds: 30), loadRewardedAd);
          },
        ),
      );
    } catch (e) {
      print('Error loading ad: $e');
      _isAdLoading = false;
      _rewardedAd = null;
      // Retry after delay on exception
      Future.delayed(const Duration(seconds: 30), loadRewardedAd);
    }
  }

  Future<bool> showRewardedAd() async {
    if (_rewardedAd == null) {
      print('No ad available, attempting to load...');
      await loadRewardedAd();
      // Wait a bit for the ad to load
      await Future.delayed(const Duration(seconds: 2));
      if (_rewardedAd == null) {
        print('Failed to load ad for immediate showing');
        return false;
      }
    }

    bool isRewarded = false;
    final Completer<bool> adCompleter = Completer<bool>();

    try {
      print('Showing rewarded interstitial ad...');

      // Set up callbacks before showing the ad
      _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          print('Ad dismissed, rewarded: $isRewarded');
          ad.dispose();
          _rewardedAd = null;
          adCompleter.complete(isRewarded);
          loadRewardedAd(); // Preload next ad
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          print(
              'Failed to show ad: ${error.message} (Error code: ${error.code})');
          ad.dispose();
          _rewardedAd = null;
          adCompleter.complete(false);
          loadRewardedAd(); // Retry loading
        },
        onAdShowedFullScreenContent: (ad) {
          print('Ad showed full screen content');
        },
      );

      await _rewardedAd!.show(
        onUserEarnedReward: (_, reward) {
          print('User earned reward: ${reward.amount} ${reward.type}');
          isRewarded = true;
        },
      );

      return await adCompleter.future;
    } catch (e) {
      print('Error showing ad: $e');
      _rewardedAd?.dispose();
      _rewardedAd = null;
      return false;
    }
  }

  void dispose() {
    _rewardedAd?.dispose();
    _rewardedAd = null;
  }
}
