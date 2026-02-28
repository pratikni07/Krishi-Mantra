import 'package:get/get.dart';
import 'package:latlong2/latlong.dart';
import 'package:maps_toolkit/maps_toolkit.dart' as mt;

class FarmMeasurementController extends GetxController {
  final polygonPoints = <LatLng>[].obs;
  final areaInSqMeters = 0.0.obs;
  final isSatelliteView = true.obs;

  void addPoint(LatLng point) {
    polygonPoints.add(point);
    _recalculate();
  }

  void undoLastPoint() {
    if (polygonPoints.isNotEmpty) {
      polygonPoints.removeLast();
      _recalculate();
    }
  }

  void clearPoints() {
    polygonPoints.clear();
    areaInSqMeters.value = 0.0;
  }

  void toggleMapType() {
    isSatelliteView.toggle();
  }

  void _recalculate() {
    if (polygonPoints.length < 3) {
      areaInSqMeters.value = 0.0;
      return;
    }
    // Use maps_toolkit for geodesic area calculation
    final mtPoints = polygonPoints
        .map((p) => mt.LatLng(p.latitude, p.longitude))
        .toList();
    areaInSqMeters.value =
        mt.SphericalUtil.computeArea(mtPoints).toDouble().abs();
  }

  // ── Unit conversions ──────────────────────────────────────────

  double get acres => areaInSqMeters.value / 4046.8564224;
  double get hectares => areaInSqMeters.value / 10000.0;
  double get bigha => areaInSqMeters.value / 2529.2853;  // Rajasthani bigha
  double get guntha => areaInSqMeters.value / 101.171;

  String get formattedArea {
    final sq = areaInSqMeters.value;
    if (sq <= 0) return '—';
    if (sq < 1000) return '${sq.toStringAsFixed(1)} sq m';
    return '${(sq / 10000).toStringAsFixed(3)} ha';
  }

  String get formattedAcres {
    if (acres <= 0) return '—';
    return '${acres.toStringAsFixed(3)} acres';
  }

  String get formattedHectares {
    if (hectares <= 0) return '—';
    return '${hectares.toStringAsFixed(3)} ha';
  }

  String get formattedSqMeters {
    if (areaInSqMeters.value <= 0) return '—';
    return '${areaInSqMeters.value.toStringAsFixed(1)} m²';
  }

  String get formattedBigha {
    if (bigha <= 0) return '—';
    return '${bigha.toStringAsFixed(3)} bigha';
  }

  String get formattedGuntha {
    if (guntha <= 0) return '—';
    return '${guntha.toStringAsFixed(2)} guntha';
  }
}
