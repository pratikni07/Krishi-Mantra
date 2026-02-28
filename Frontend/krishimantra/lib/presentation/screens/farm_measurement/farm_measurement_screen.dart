// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:get/get.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/constants/colors.dart';
import '../../../core/utils/home_localizations.dart';
import '../../../core/utils/translation_manager.dart';
import '../../../data/services/language_service.dart';
import '../../controllers/farm_measurement_controller.dart';

class FarmMeasurementScreen extends StatefulWidget {
  const FarmMeasurementScreen({super.key});

  @override
  State<FarmMeasurementScreen> createState() => _FarmMeasurementScreenState();
}

class _FarmMeasurementScreenState extends State<FarmMeasurementScreen>
    with TickerProviderStateMixin {
  final FarmMeasurementController _controller =
      Get.put(FarmMeasurementController());
  final MapController _mapController = MapController();
  String _languageCode = '';
  bool _showGuide = true;
  bool _isLocating = false;

  // Esri World Imagery – free, no API key
  static const String _satelliteUrl =
      'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}';

  // Esri labels overlay – shows village/city/road names on satellite view
  static const String _labelsUrl =
      'https://server.arcgisonline.com/ArcGIS/rest/services/Reference/World_Boundaries_and_Places/MapServer/tile/{z}/{y}/{x}';

  // OpenStreetMap for street view
  static const String _streetUrl =
      'https://tile.openstreetmap.org/{z}/{y}/{x}.png';

  @override
  void initState() {
    super.initState();
    _syncLanguageCode();
    TranslationManager.instance.addLanguageChangeListener(_onLanguageChanged);
    // Auto-dismiss guide after 5s
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted && _showGuide) setState(() => _showGuide = false);
    });
  }

  Future<void> _syncLanguageCode() async {
    final ls = await LanguageService.getInstance();
    if (!mounted) return;
    setState(() => _languageCode = ls.getLanguageCode());
  }

  Future<void> _onLanguageChanged() async => _syncLanguageCode();

  String _t(String key) {
    if (_languageCode.isEmpty) return '';
    return HomeLocalizations.text(key, _languageCode);
  }

  @override
  void dispose() {
    TranslationManager.instance
        .removeLanguageChangeListener(_onLanguageChanged);
    super.dispose();
  }

  // ── Locate the user ──────────────────────────────────────────
  Future<void> _goToCurrentLocation() async {
    setState(() => _isLocating = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _snack(_t('fm_enable_location'));
        return;
      }
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
        if (perm == LocationPermission.denied) {
          _snack(_t('fm_permission_denied'));
          return;
        }
      }
      if (perm == LocationPermission.deniedForever) {
        _snack(_t('fm_permission_denied'));
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      _mapController.move(LatLng(pos.latitude, pos.longitude), 18);
    } catch (e) {
      _snack(_t('fm_location_error'));
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 2)));
  }

  // ── Build ─────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // ── Map ──────────────────────────────────────────────
          Obx(() {
            final points = _controller.polygonPoints.toList();
            return FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: const LatLng(20.5937, 78.9629), // India center
                initialZoom: 5,
                maxZoom: 22,
                onTap: (tapPos, latLng) {
                  _controller.addPoint(latLng);
                  if (_showGuide) setState(() => _showGuide = false);
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: _controller.isSatelliteView.value
                      ? _satelliteUrl
                      : _streetUrl,
                  userAgentPackageName: 'com.krishimantra.app',
                  maxNativeZoom: 18,
                  maxZoom: 22,
                ),
                // Labels overlay (village/city names) on satellite view
                if (_controller.isSatelliteView.value)
                  TileLayer(
                    urlTemplate: _labelsUrl,
                    userAgentPackageName: 'com.krishimantra.app',
                    maxNativeZoom: 18,
                    maxZoom: 22,
                  ),
                // Polygon fill
                if (points.length >= 3)
                  PolygonLayer(
                    polygons: [
                      Polygon(
                        points: points,
                        color: AppColors.green.withOpacity(0.25),
                        borderColor: AppColors.green,
                        borderStrokeWidth: 3,
                        isFilled: true,
                      ),
                    ],
                  ),
                // Lines connecting points (when < 3 or always)
                if (points.length >= 2)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: [...points, if (points.length >= 3) points.first],
                        color: AppColors.green,
                        strokeWidth: 3,
                      ),
                    ],
                  ),
                // Markers for each vertex
                MarkerLayer(
                  markers: List.generate(points.length, (i) {
                    final isFirst = i == 0;
                    return Marker(
                      point: points[i],
                      width: isFirst ? 28 : 22,
                      height: isFirst ? 28 : 22,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isFirst
                              ? Colors.orange
                              : AppColors.white,
                          border: Border.all(
                            color: AppColors.green,
                            width: 3,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: isFirst
                            ? const Icon(Icons.flag, size: 14, color: Colors.white)
                            : null,
                      ),
                    );
                  }),
                ),
              ],
            );
          }),

          // ── Top Bar ──────────────────────────────────────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.6),
                    Colors.transparent,
                  ],
                ),
              ),
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 8,
                left: 8,
                right: 8,
                bottom: 16,
              ),
              child: Row(
                children: [
                  _circleButton(
                    icon: Icons.arrow_back,
                    onTap: () => Get.back(),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _t('measure_farm'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        shadows: [
                          Shadow(blurRadius: 8, color: Colors.black54),
                        ],
                      ),
                    ),
                  ),
                  Obx(() => _circleButton(
                        icon: _controller.isSatelliteView.value
                            ? Icons.map
                            : Icons.satellite_alt,
                        onTap: () => _controller.toggleMapType(),
                        tooltip: _controller.isSatelliteView.value
                            ? _t('fm_street_view')
                            : _t('fm_satellite_view'),
                      )),
                ],
              ),
            ),
          ),

          // ── Right-side action buttons ────────────────────────
          Positioned(
            right: 16,
            bottom: 260,
            child: Column(
              children: [
                _fab(
                  icon: _isLocating
                      ? Icons.hourglass_top
                      : Icons.my_location,
                  onTap: _isLocating ? null : _goToCurrentLocation,
                  tooltip: _t('fm_my_location'),
                  heroTag: 'loc',
                ),
                const SizedBox(height: 10),
                Obx(() => _fab(
                      icon: Icons.undo,
                      onTap: _controller.polygonPoints.isEmpty
                          ? null
                          : () => _controller.undoLastPoint(),
                      tooltip: _t('fm_undo'),
                      heroTag: 'undo',
                    )),
                const SizedBox(height: 10),
                Obx(() => _fab(
                      icon: Icons.delete_outline,
                      onTap: _controller.polygonPoints.isEmpty
                          ? null
                          : () => _controller.clearPoints(),
                      tooltip: _t('fm_clear'),
                      heroTag: 'clear',
                      color: _controller.polygonPoints.isEmpty
                          ? Colors.grey
                          : AppColors.error,
                    )),
              ],
            ),
          ),

          // ── Point counter badge ──────────────────────────────
          Positioned(
            left: 16,
            bottom: 260,
            child: Obx(() {
              final count = _controller.polygonPoints.length;
              return AnimatedOpacity(
                opacity: count > 0 ? 1 : 0,
                duration: const Duration(milliseconds: 300),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.75),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.location_on,
                          color: Colors.orange, size: 18),
                      const SizedBox(width: 6),
                      Text(
                        '$count ${_t('fm_points')}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),

          // ── Bottom area panel ────────────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Obx(() => _buildAreaPanel()),
          ),

          // ── First-time guide overlay ─────────────────────────
          if (_showGuide)
            Positioned.fill(
              child: GestureDetector(
                onTap: () => setState(() => _showGuide = false),
                child: Container(
                  color: Colors.black.withOpacity(0.55),
                  child: Center(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 32),
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.15),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.green.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.touch_app,
                                size: 48, color: AppColors.green),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _t('fm_guide_title'),
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textDark,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _t('fm_guide_body'),
                            style: TextStyle(
                              fontSize: 15,
                              color: AppColors.textLight,
                              height: 1.5,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () =>
                                  setState(() => _showGuide = false),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.green,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0,
                              ),
                              child: Text(
                                _t('fm_got_it'),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Area info panel ───────────────────────────────────────────
  Widget _buildAreaPanel() {
    final area = _controller.areaInSqMeters.value;
    final hasArea = area > 0;
    final minPoints = _controller.polygonPoints.length < 3;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag handle
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 12),

                // Hint when < 3 points
                if (minPoints) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.info_outline,
                          size: 18, color: AppColors.textLight),
                      const SizedBox(width: 8),
                      Text(
                        _t('fm_min_points'),
                        style: TextStyle(
                          color: AppColors.textLight,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ],

                // Area result
                if (hasArea) ...[
                  // Primary area in acres
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.straighten, color: AppColors.green, size: 22),
                      const SizedBox(width: 8),
                      Text(
                        _controller.formattedAcres,
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: AppColors.green,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Secondary units grid
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.green.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppColors.green.withOpacity(0.15),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _unitChip(_t('fm_hectares'), _controller.formattedHectares),
                        _divider(),
                        _unitChip(_t('fm_sq_meters'), _controller.formattedSqMeters),
                        _divider(),
                        _unitChip(_t('fm_bigha'), _controller.formattedBigha),
                        _divider(),
                        _unitChip(_t('fm_guntha'), _controller.formattedGuntha),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 4),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _unitChip(String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: AppColors.textLight,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _divider() {
    return Container(
      width: 1,
      height: 32,
      color: AppColors.borderLight,
    );
  }

  // ── Helper widgets ────────────────────────────────────────────
  Widget _circleButton({
    required IconData icon,
    required VoidCallback onTap,
    String? tooltip,
  }) {
    final btn = GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.45),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white30),
        ),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
    return tooltip != null ? Tooltip(message: tooltip, child: btn) : btn;
  }

  Widget _fab({
    required IconData icon,
    VoidCallback? onTap,
    String? tooltip,
    required String heroTag,
    Color? color,
  }) {
    final isDisabled = onTap == null;
    return FloatingActionButton.small(
      heroTag: heroTag,
      onPressed: onTap,
      tooltip: tooltip,
      backgroundColor:
          isDisabled ? Colors.grey[400] : (color ?? AppColors.green),
      elevation: isDisabled ? 1 : 4,
      child: Icon(icon, color: Colors.white, size: 20),
    );
  }
}
