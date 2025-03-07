import '../../data/repositories/ads_repository.dart';

class AdsController {
  final AdsRepository _adsRepository;

  AdsController(this._adsRepository);

  Future<List<dynamic>> fetchHomeScreenAds() async {
    return await _adsRepository.getHomeScreenAds();
  }

  Future<dynamic> fetchHomeScreenAdById(String id) async {
    return await _adsRepository.getHomeScreenAdById(id);
  }

  Future<List<dynamic>> fetchSplashAds() async {
    return await _adsRepository.getSplashAds();
  }

  Future<List<dynamic>> fetchHomeScreenSlider() async {
    return await _adsRepository.getHomeScreenSlider();
  }
}
