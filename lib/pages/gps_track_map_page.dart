import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../core/app_theme.dart';
import '../widgets/pro_widgets.dart';

class GpsTrackMapPage extends StatefulWidget {
  final String date;
  final List<Map<String, dynamic>> points;

  const GpsTrackMapPage({super.key, required this.date, required this.points});

  @override
  State<GpsTrackMapPage> createState() => _GpsTrackMapPageState();
}

class _GpsTrackMapPageState extends State<GpsTrackMapPage> {
  final MapController _mapController = MapController();
  bool _mapReady = false;

  static const LatLng _dhakaCenter = LatLng(23.7104, 90.4074);

  @override
  Widget build(BuildContext context) {
    final validPoints = widget.points.where(_isValidPoint).toList();
    final routeLatLng = validPoints.map(_toLatLng).toList();
    final startTime = validPoints.isEmpty ? '-' : _timeOnly(validPoints.first['tracking_time']);
    final endTime = validPoints.isEmpty ? '-' : _timeOnly(validPoints.last['tracking_time']);
    final distanceKm = _totalDistanceKm(validPoints);

    return Scaffold(
      appBar: AppBar(title: Text('GPS Movement - ${widget.date}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ProCard(
            gradient: const LinearGradient(colors: [AppColors.primary, AppColors.secondary]),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Logged User Movement', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              Text('Full GPS route history for ${widget.date}', style: TextStyle(color: Colors.white.withOpacity(.86), fontWeight: FontWeight.w700)),
            ]),
          ),
          const SizedBox(height: 14),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.7,
            children: [
              ProInfoTile(icon: Icons.location_on_rounded, title: 'GPS Points', value: '${validPoints.length}', color: AppColors.danger),
              ProInfoTile(icon: Icons.route_rounded, title: 'Distance', value: '${distanceKm.toStringAsFixed(2)} KM', color: AppColors.primary),
              ProInfoTile(icon: Icons.play_arrow_rounded, title: 'Start Time', value: startTime, color: AppColors.success),
              ProInfoTile(icon: Icons.flag_rounded, title: 'End Time', value: endTime, color: AppColors.secondary),
            ],
          ),
          const SizedBox(height: 16),
          const SectionTitle('Movement Map', subtitle: 'Pinch, zoom, drag and control the full GPS movement route.'),
          ProCard(
            padding: EdgeInsets.zero,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: Container(
                height: 440,
                color: const Color(0xFFE0F2FE),
                child: validPoints.isEmpty
                    ? const Center(child: Text('No valid Bangladesh GPS point found for map'))
                    : Stack(
                        children: [
                          FlutterMap(
                            mapController: _mapController,
                            options: MapOptions(
                              initialCenter: routeLatLng.isEmpty ? _dhakaCenter : routeLatLng.first,
                              initialZoom: _initialZoom(routeLatLng),
                              interactionOptions: const InteractionOptions(flags: InteractiveFlag.all),
                              onMapReady: () {
                                _mapReady = true;
                                _fitRoute(routeLatLng);
                              },
                            ),
                            children: [
                              TileLayer(
                                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                userAgentPackageName: 'com.agrani.erp.mobile',
                              ),
                              if (routeLatLng.length > 1)
                                PolylineLayer(
                                  polylines: [
                                    Polyline(
                                      points: routeLatLng,
                                      color: AppColors.primary,
                                      strokeWidth: 5,
                                    ),
                                  ],
                                ),
                              MarkerLayer(
                                markers: [
                                  Marker(
                                    point: routeLatLng.first,
                                    width: 88,
                                    height: 58,
                                    alignment: Alignment.topCenter,
                                    child: const _MapMarker(label: 'START', color: AppColors.success),
                                  ),
                                  Marker(
                                    point: routeLatLng.last,
                                    width: 88,
                                    height: 58,
                                    alignment: Alignment.topCenter,
                                    child: const _MapMarker(label: 'END', color: AppColors.danger),
                                  ),
                                  ..._middlePointMarkers(routeLatLng),
                                ],
                              ),
                            ],
                          ),
                          Positioned(
                            right: 12,
                            top: 12,
                            child: Column(
                              children: [
                                _MapControlButton(icon: Icons.add_rounded, onTap: _zoomIn),
                                const SizedBox(height: 8),
                                _MapControlButton(icon: Icons.remove_rounded, onTap: _zoomOut),
                                const SizedBox(height: 8),
                                _MapControlButton(icon: Icons.center_focus_strong_rounded, onTap: () => _fitRoute(routeLatLng)),
                              ],
                            ),
                          ),
                          Positioned(
                            left: 12,
                            bottom: 12,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(.92),
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [BoxShadow(color: Colors.black.withOpacity(.08), blurRadius: 16, offset: const Offset(0, 8))],
                              ),
                              child: const Text(
                                'Drag • Pinch Zoom • Double Tap',
                                style: TextStyle(fontSize: 11, color: AppColors.muted, fontWeight: FontWeight.w800),
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const SectionTitle('Location History'),
          if (validPoints.isEmpty)
            const ProCard(child: Center(child: Padding(padding: EdgeInsets.all(24), child: Text('No valid GPS history found'))))
          else
            ...validPoints.map(_pointCard),
        ],
      ),
    );
  }

  void _zoomIn() {
    if (!_mapReady) return;
    final camera = _mapController.camera;
    _mapController.move(camera.center, camera.zoom + 1);
  }

  void _zoomOut() {
    if (!_mapReady) return;
    final camera = _mapController.camera;
    _mapController.move(camera.center, camera.zoom - 1);
  }

  void _fitRoute(List<LatLng> routeLatLng) {
    if (!_mapReady || routeLatLng.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final center = _safeCenter(routeLatLng);
      if (routeLatLng.length == 1 || _isVerySmallRoute(routeLatLng)) {
        _mapController.move(center, 17);
        return;
      }
      try {
        final bounds = LatLngBounds.fromPoints(routeLatLng);
        _mapController.fitCamera(
          CameraFit.bounds(
            bounds: bounds,
            padding: const EdgeInsets.all(52),
          ),
        );
      } catch (_) {
        _mapController.move(center, 16);
      }
    });
  }

  static bool _isValidPoint(Map<String, dynamic> row) {
    final lat = double.tryParse('${row['latitude']}');
    final lng = double.tryParse('${row['longitude']}');
    if (lat == null || lng == null) return false;
    if (!lat.isFinite || !lng.isFinite) return false;
    if (lat == 0 || lng == 0) return false;
    return _isBangladeshLocation(lat, lng);
  }

  static bool _isBangladeshLocation(double lat, double lng) {
    return lat >= 20.50 && lat <= 26.90 && lng >= 88.00 && lng <= 92.80;
  }

  static LatLng _toLatLng(Map<String, dynamic> row) {
    return LatLng(
      double.tryParse('${row['latitude']}') ?? _dhakaCenter.latitude,
      double.tryParse('${row['longitude']}') ?? _dhakaCenter.longitude,
    );
  }

  static LatLng _safeCenter(List<LatLng> rows) {
    if (rows.isEmpty) return _dhakaCenter;
    final lat = rows.map((e) => e.latitude).reduce((a, b) => a + b) / rows.length;
    final lng = rows.map((e) => e.longitude).reduce((a, b) => a + b) / rows.length;
    if (!lat.isFinite || !lng.isFinite) return _dhakaCenter;
    return LatLng(lat, lng);
  }

  static bool _isVerySmallRoute(List<LatLng> rows) {
    if (rows.length <= 1) return true;
    final latitudes = rows.map((e) => e.latitude).toList();
    final longitudes = rows.map((e) => e.longitude).toList();
    final latRange = latitudes.reduce(math.max) - latitudes.reduce(math.min);
    final lngRange = longitudes.reduce(math.max) - longitudes.reduce(math.min);
    return latRange.abs() < 0.00002 && lngRange.abs() < 0.00002;
  }

  static double _initialZoom(List<LatLng> rows) {
    if (rows.length <= 1 || _isVerySmallRoute(rows)) return 17;
    final latitudes = rows.map((e) => e.latitude).toList();
    final longitudes = rows.map((e) => e.longitude).toList();
    final latRange = latitudes.reduce(math.max) - latitudes.reduce(math.min);
    final lngRange = longitudes.reduce(math.max) - longitudes.reduce(math.min);
    final maxRange = math.max(latRange.abs(), lngRange.abs());
    if (!maxRange.isFinite || maxRange <= 0) return 17;
    if (maxRange < .001) return 16;
    if (maxRange < .005) return 15;
    if (maxRange < .02) return 13;
    if (maxRange < .08) return 11;
    return 9;
  }

  static List<Marker> _middlePointMarkers(List<LatLng> routeLatLng) {
    if (routeLatLng.length < 8) return [];
    final markers = <Marker>[];
    final step = math.max(1, (routeLatLng.length / 8).ceil());
    for (int i = step; i < routeLatLng.length - 1; i += step) {
      markers.add(
        Marker(
          point: routeLatLng[i],
          width: 18,
          height: 18,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.primary, width: 3),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(.12), blurRadius: 8, offset: const Offset(0, 3))],
            ),
          ),
        ),
      );
    }
    return markers;
  }

  static String _timeOnly(dynamic value) {
    final text = '$value';
    if (text.length >= 16) return text.substring(11, 16);
    return text;
  }

  static double _totalDistanceKm(List<Map<String, dynamic>> rows) {
    if (rows.length < 2) return 0;
    double total = 0;
    for (int i = 1; i < rows.length; i++) {
      final aLat = double.tryParse('${rows[i - 1]['latitude']}') ?? 0;
      final aLng = double.tryParse('${rows[i - 1]['longitude']}') ?? 0;
      final bLat = double.tryParse('${rows[i]['latitude']}') ?? 0;
      final bLng = double.tryParse('${rows[i]['longitude']}') ?? 0;
      final km = _haversineKm(aLat, aLng, bLat, bLng);
      if (km.isFinite) total += km;
    }
    return total.isFinite ? total : 0;
  }

  static double _haversineKm(double lat1, double lon1, double lat2, double lon2) {
    const earthRadiusKm = 6371.0;
    final dLat = _degToRad(lat2 - lat1);
    final dLon = _degToRad(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degToRad(lat1)) * math.cos(_degToRad(lat2)) * math.sin(dLon / 2) * math.sin(dLon / 2);
    final safeA = a.clamp(0.0, 1.0);
    final c = 2 * math.atan2(math.sqrt(safeA), math.sqrt(1 - safeA));
    final value = earthRadiusKm * c;
    return value.isFinite ? value : 0;
  }

  static double _degToRad(double deg) => deg * (math.pi / 180.0);

  Widget _pointCard(Map<String, dynamic> row) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: ProCard(
          child: Row(children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(color: AppColors.primary.withOpacity(.12), borderRadius: BorderRadius.circular(16)),
              child: const Icon(Icons.my_location_rounded, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${row['tracking_time']}', style: const TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text('${row['latitude']}, ${row['longitude']}', style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(
                  'Accuracy: ${_displayValue(row['accuracy'])} • Speed: ${_displayValue(row['speed'])} • Battery: ${_batteryText(row['battery_percent'])}',
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ]),
            ),
          ]),
        ),
      );

  static String _displayValue(dynamic value) {
    if (value == null || '$value'.trim().isEmpty || '$value' == 'null') return '-';
    return '$value';
  }

  static String _batteryText(dynamic value) {
    if (value == null || '$value'.trim().isEmpty || '$value' == 'null') return '-';
    final parsed = double.tryParse('$value');
    if (parsed == null) return '$value%';
    return '${parsed.round()}%';
  }
}

class _MapMarker extends StatelessWidget {
  final String label;
  final Color color;

  const _MapMarker({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(.96),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(.12), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w900)),
        ),
        const SizedBox(height: 4),
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 5),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(.2), blurRadius: 10, offset: const Offset(0, 5))],
          ),
        ),
      ],
    );
  }
}

class _MapControlButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _MapControlButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      elevation: 4,
      shadowColor: Colors.black.withOpacity(.18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          width: 42,
          height: 42,
          child: Icon(icon, color: AppColors.primary, size: 25),
        ),
      ),
    );
  }
}
