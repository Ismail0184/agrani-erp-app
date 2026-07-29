import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import '../core/api_client.dart';
import '../models/outlet_master_model.dart';
import '../models/outlet_model.dart';
import '../models/territory_model.dart';
import '../models/route_model.dart';
import '../models/route_section_model.dart';

class LocationSearchResult {
  final String title;
  final String subtitle;
  final double latitude;
  final double longitude;

  const LocationSearchResult({required this.title, required this.subtitle, required this.latitude, required this.longitude});

  factory LocationSearchResult.fromMap(Map<String, dynamic> map) {
    final display = '${map['display_name'] ?? ''}';
    final parts = display.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    return LocationSearchResult(
      title: parts.isEmpty ? display : parts.first,
      subtitle: display,
      latitude: double.tryParse('${map['lat']}') ?? 0,
      longitude: double.tryParse('${map['lon']}') ?? 0,
    );
  }
}

class OutletCreateService {
  OutletCreateService._();
  static final OutletCreateService instance = OutletCreateService._();

  Future<List<TerritoryModel>> territories() async {
    final data = await ApiClient.instance.get('territory_list');
    final rows = data['rows'] as List? ?? [];
    return rows.map((e) => TerritoryModel.fromMap(Map<String, dynamic>.from(e as Map))).where((e) => e.territoryName.trim().isNotEmpty).toList();
  }

  Future<List<OutletRouteModel>> routes() async {
    final data = await ApiClient.instance.get('route_list');
    final rows = data['rows'] as List? ?? [];
    return rows.map((e) => OutletRouteModel.fromMap(Map<String, dynamic>.from(e as Map))).where((e) => e.displayName.trim().isNotEmpty).toList();
  }

  Future<List<RouteSectionModel>> routeSections(int routeId) async {
    final data = await ApiClient.instance.get('route_section_list', query: {'route_id': '$routeId'});
    final rows = data['rows'] as List? ?? [];
    return rows.map((e) => RouteSectionModel.fromMap(Map<String, dynamic>.from(e as Map))).where((e) => e.sectionName.trim().isNotEmpty).toList();
  }

  Future<List<OutletModel>> outletsByRoute(int routeId) async {
    final data = await ApiClient.instance.get('route_outlet_list', query: {'route_id': '$routeId'});
    final rows = data['rows'] as List? ?? [];
    return rows.map((e) => OutletModel.fromMap(Map<String, dynamic>.from(e as Map))).where((e) => e.outletName.trim().isNotEmpty).toList();
  }

  Future<List<OutletMasterModel>> outletList() async {
    final data = await ApiClient.instance.get('outlet_master_list');
    final rows = data['rows'] as List? ?? [];
    return rows.map((e) => OutletMasterModel.fromMap(Map<String, dynamic>.from(e as Map))).toList();
  }

  Future<List<OutletMasterModel>> existingOutletUpdateList() async {
    final data = await ApiClient.instance.get('existing_outlet_update_list');
    final rows = data['rows'] as List? ?? [];
    return rows.map((e) => OutletMasterModel.fromMap(Map<String, dynamic>.from(e as Map))).toList();
  }

  Future<void> updateExistingOutlet({
    required int outletId,
    required String locationText,
    required double latitude,
    required double longitude,
    required String shopImagePath,
  }) async {
    await ApiClient.instance.postMultipart(
      'existing_outlet_update',
      fields: {
        'outlet_id': '$outletId',
        'map_location_text': locationText,
        'latitude': '$latitude',
        'longitude': '$longitude',
        'location_source': 'GPS',
      },
      fileField: 'shop_image',
      filePath: shopImagePath,
    );
  }

  Future<void> createOutlet({
    required TerritoryModel territory,
    required OutletRouteModel route,
    required RouteSectionModel section,
    required String marketName,
    required String outletName,
    required String ownerName,
    required String contactNumber,
    required String shopAddress,
    required String locationText,
    required double latitude,
    required double longitude,
    String locationSource = 'Search',
    double? locationAccuracy,
    String? shopImagePath,
  }) async {
    await ApiClient.instance.postMultipart(
      'outlet_master_create',
      fields: {
        'territory_id': '${territory.id}',
        'territory_name': territory.territoryName,
        'route_id': '${route.routeId}',
        'route_name': route.routeName,
        'custom_route_id': route.customRouteId,
        'route_section_id': '${section.id}',
        'route_section_name': section.sectionName,
        'section_id': '${section.sectionId}',
        'market_name': marketName,
        'outlet_name': outletName,
        'owner_name': ownerName,
        'contact_number': contactNumber,
        'cluster_name': shopAddress,
        'map_location_text': locationText,
        'latitude': '$latitude',
        'longitude': '$longitude',
        'location_source': locationSource,
        if (locationAccuracy != null) 'location_accuracy': '$locationAccuracy',
      },
      fileField: 'shop_image',
      filePath: shopImagePath,
    );
  }

  Future<List<LocationSearchResult>> searchLocation(String query) async {
    final q = query.trim();
    if (q.isEmpty) return [];
    final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
      'format': 'json',
      'limit': '8',
      'countrycodes': 'bd',
      'q': '$q, Bangladesh',
    });
    final res = await http.get(uri, headers: const {
      'Accept': 'application/json',
      'User-Agent': 'AgraniERP-Mobile-App/1.0',
    }).timeout(const Duration(seconds: 20));
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Location search failed. Please try again.');
    }
    final decoded = jsonDecode(res.body);
    if (decoded is! List) return [];
    return decoded
        .whereType<Map>()
        .map((e) => LocationSearchResult.fromMap(Map<String, dynamic>.from(e)))
        .where((e) => _isBangladeshLocation(e.latitude, e.longitude))
        .toList();
  }

  Future<LocationSearchResult?> currentGpsLocation() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
    if (permission != LocationPermission.always && permission != LocationPermission.whileInUse) return null;
    final pos = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium, timeLimit: Duration(seconds: 15)),
    );
    if (!_isBangladeshLocation(pos.latitude, pos.longitude)) return null;
    return LocationSearchResult(
      title: 'Current GPS Location',
      subtitle: '${pos.latitude.toStringAsFixed(6)}, ${pos.longitude.toStringAsFixed(6)}',
      latitude: pos.latitude,
      longitude: pos.longitude,
    );
  }

  bool _isBangladeshLocation(double latitude, double longitude) {
    return latitude.isFinite && longitude.isFinite && latitude >= 20.50 && latitude <= 26.90 && longitude >= 88.00 && longitude <= 92.80;
  }
}
