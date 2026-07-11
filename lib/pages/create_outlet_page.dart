import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../core/app_theme.dart';
import '../models/territory_model.dart';
import '../models/route_model.dart';
import '../models/route_section_model.dart';
import '../services/outlet_create_service.dart';
import '../widgets/pro_widgets.dart';

class CreateOutletPage extends StatefulWidget {
  const CreateOutletPage({super.key});

  @override
  State<CreateOutletPage> createState() => _CreateOutletPageState();
}

class _CreateOutletPageState extends State<CreateOutletPage> {
  final _formKey = GlobalKey<FormState>();
  final _market = TextEditingController();
  final _shop = TextEditingController();
  final _owner = TextEditingController();
  final _mobile = TextEditingController();
  final _address = TextEditingController();
  final _location = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  List<TerritoryModel> territories = [];
  List<OutletRouteModel> routes = [];
  List<RouteSectionModel> sections = [];
  TerritoryModel? territory;
  OutletRouteModel? route;
  RouteSectionModel? section;
  LocationSearchResult? selectedLocation;
  XFile? shopImage;
  bool loading = true;
  bool sectionLoading = false;
  bool searching = false;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    _loadMaster();
  }

  @override
  void dispose() {
    _market.dispose();
    _shop.dispose();
    _owner.dispose();
    _mobile.dispose();
    _address.dispose();
    _location.dispose();
    super.dispose();
  }

  Future<void> _loadMaster() async {
    setState(() => loading = true);
    try {
      final svc = OutletCreateService.instance;
      territories = await svc.territories();
      routes = await svc.routes();
    } catch (e) {
      if (mounted) _show('Master data load failed: $e', error: true);
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> _loadSections(OutletRouteModel selectedRoute) async {
    setState(() {
      route = selectedRoute;
      section = null;
      sections = [];
      sectionLoading = true;
    });
    try {
      sections = await OutletCreateService.instance.routeSections(selectedRoute.routeId);
    } catch (e) {
      if (mounted) _show('Section load failed: $e', error: true);
    } finally {
      if (mounted) setState(() => sectionLoading = false);
    }
  }

  String? _required(String? value, String label) {
    if ((value ?? '').trim().isEmpty) return '$label is required';
    return null;
  }

  Future<void> _searchLocation() async {
    final q = _location.text.trim();
    if (q.isEmpty) {
      _show('Please type outlet current location first.', error: true);
      return;
    }
    setState(() => searching = true);
    try {
      final results = await OutletCreateService.instance.searchLocation(q);
      if (!mounted) return;
      if (results.isEmpty) {
        _show('No valid Bangladesh location found. Please type a more specific location.', error: true);
        return;
      }
      await _showLocationPicker(results);
    } catch (e) {
      if (mounted) _show('$e', error: true);
    } finally {
      if (mounted) setState(() => searching = false);
    }
  }

  Future<void> _useCurrentGps() async {
    setState(() => searching = true);
    try {
      final result = await OutletCreateService.instance.currentGpsLocation();
      if (!mounted) return;
      if (result == null) {
        _show('Current GPS location not available. Please allow location permission and try again.', error: true);
        return;
      }
      setState(() {
        selectedLocation = result;
        _location.text = result.subtitle;
      });
    } catch (e) {
      if (mounted) _show('$e', error: true);
    } finally {
      if (mounted) setState(() => searching = false);
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(source: source, imageQuality: 72, maxWidth: 1400);
      if (picked == null) return;
      setState(() => shopImage = picked);
    } catch (e) {
      if (mounted) _show('Image select failed: $e', error: true);
    }
  }

  Future<void> _showImagePicker() async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        decoration: const BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 48, height: 5, decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(99))),
          const SizedBox(height: 16),
          const Text('Outlet Shop Image', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          ListTile(
            leading: const CircleAvatar(child: Icon(Icons.photo_camera_rounded)),
            title: const Text('Take Photo Now', style: TextStyle(fontWeight: FontWeight.w800)),
            onTap: () { Navigator.pop(ctx); _pickImage(ImageSource.camera); },
          ),
          ListTile(
            leading: const CircleAvatar(child: Icon(Icons.photo_library_rounded)),
            title: const Text('Select From Gallery', style: TextStyle(fontWeight: FontWeight.w800)),
            onTap: () { Navigator.pop(ctx); _pickImage(ImageSource.gallery); },
          ),
        ]),
      ),
    );
  }

  Future<void> _showLocationPicker(List<LocationSearchResult> results) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(ctx).size.height * .72,
        decoration: const BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
        child: Column(
          children: [
            Container(width: 48, height: 5, decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(99))),
            const SizedBox(height: 14),
            const Text('Select Outlet Location', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),
            Expanded(
              child: ListView.separated(
                itemCount: results.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final item = results[i];
                  return ListTile(
                    leading: CircleAvatar(backgroundColor: AppColors.danger.withOpacity(.12), child: const Icon(Icons.location_on_rounded, color: AppColors.danger)),
                    title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.w900)),
                    subtitle: Text(item.subtitle, maxLines: 3, overflow: TextOverflow.ellipsis),
                    onTap: () {
                      Navigator.pop(ctx);
                      setState(() {
                        selectedLocation = item;
                        _location.text = item.subtitle;
                      });
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    if (territory == null) {
      _show('Territory is required.', error: true);
      return;
    }
    if (route == null) {
      _show('Route is required.', error: true);
      return;
    }
    if (section == null) {
      _show('Section is required.', error: true);
      return;
    }
    if (selectedLocation == null) {
      _show('Outlet current map location is required. Please find location first.', error: true);
      return;
    }
    if (shopImage == null) {
      _show('Outlet shop image is required.', error: true);
      return;
    }
    setState(() => saving = true);
    try {
      await OutletCreateService.instance.createOutlet(
        territory: territory!,
        route: route!,
        section: section!,
        marketName: _market.text.trim(),
        outletName: _shop.text.trim(),
        ownerName: _owner.text.trim(),
        contactNumber: _mobile.text.trim(),
        shopAddress: _address.text.trim(),
        locationText: _location.text.trim(),
        latitude: selectedLocation!.latitude,
        longitude: selectedLocation!.longitude,
        locationSource: selectedLocation!.title == 'Current GPS Location' ? 'GPS' : 'Search',
        shopImagePath: shopImage!.path,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) _show('Outlet create failed: $e', error: true);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  void _show(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: error ? AppColors.danger : AppColors.success,
      duration: const Duration(seconds: 2),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Outlet')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  ProCard(
                    gradient: const LinearGradient(colors: [AppColors.primaryDark, AppColors.primary, AppColors.secondary]),
                    child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('New Outlet Setup', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                      SizedBox(height: 6),
                      Text('Create outlet with territory, route, section, owner details, image and verified map location.', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w700)),
                    ]),
                  ),
                  const SizedBox(height: 16),
                  ProCard(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const SectionTitle('Outlet Information'),
                      SearchableSelect<TerritoryModel>(
                        label: 'Territory *',
                        hint: 'Search and select territory',
                        value: territory,
                        items: territories,
                        icon: Icons.map_rounded,
                        titleBuilder: (t) => t.territoryName,
                        subtitleBuilder: (t) => 'Territory ID: ${t.id}',
                        onChanged: (t) => setState(() => territory = t),
                      ),
                      const SizedBox(height: 12),
                      SearchableSelect<OutletRouteModel>(
                        label: 'Route *',
                        hint: 'Search and select route',
                        value: route,
                        items: routes,
                        icon: Icons.alt_route_rounded,
                        titleBuilder: (r) => r.displayName,
                        subtitleBuilder: (r) => 'Route ID: ${r.routeId}',
                        onChanged: _loadSections,
                      ),
                      const SizedBox(height: 12),
                      if (sectionLoading) const Center(child: Padding(padding: EdgeInsets.all(10), child: CircularProgressIndicator()))
                      else SearchableSelect<RouteSectionModel>(
                        label: 'Section *',
                        hint: route == null ? 'Select route first' : 'Search and select section',
                        value: section,
                        items: sections,
                        icon: Icons.account_tree_rounded,
                        titleBuilder: (s) => s.sectionName,
                        subtitleBuilder: (s) => 'Section ID: ${s.sectionId}',
                        onChanged: (s) => setState(() => section = s),
                      ),
                      const SizedBox(height: 12),
                      _text(_market, 'Market Name *', Icons.store_mall_directory_rounded, validator: (v) => _required(v, 'Market Name')),
                      const SizedBox(height: 12),
                      _text(_shop, 'Shop Name *', Icons.storefront_rounded, validator: (v) => _required(v, 'Shop Name')),
                      const SizedBox(height: 12),
                      _text(_owner, 'Owner Name *', Icons.person_rounded, validator: (v) => _required(v, 'Owner Name')),
                      const SizedBox(height: 12),
                      _text(_mobile, 'Owner Mobile Number *', Icons.call_rounded, keyboardType: TextInputType.phone, validator: (v) => _required(v, 'Owner Mobile Number')),
                      const SizedBox(height: 12),
                      _text(_address, 'Shop Address', Icons.location_city_rounded, maxLines: 2),
                    ]),
                  ),
                  const SizedBox(height: 16),
                  ProCard(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const SectionTitle('Outlet Shop Image', subtitle: 'Take a photo immediately or select from gallery.'),
                      InkWell(
                        onTap: _showImagePicker,
                        borderRadius: BorderRadius.circular(18),
                        child: Container(
                          width: double.infinity,
                          height: 170,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(.06),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: AppColors.primary.withOpacity(.22)),
                          ),
                          child: shopImage == null
                              ? const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                                  Icon(Icons.add_a_photo_rounded, size: 42, color: AppColors.primary),
                                  SizedBox(height: 8),
                                  Text('Tap to add shop image', style: TextStyle(fontWeight: FontWeight.w900, color: AppColors.primary)),
                                ])
                              : ClipRRect(borderRadius: BorderRadius.circular(18), child: Image.file(File(shopImage!.path), fit: BoxFit.cover)),
                        ),
                      ),
                      if (shopImage != null) ...[
                        const SizedBox(height: 10),
                        OutlinedButton.icon(onPressed: _showImagePicker, icon: const Icon(Icons.edit_rounded), label: const Text('Change Image')),
                      ],
                    ]),
                  ),
                  const SizedBox(height: 16),
                  ProCard(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const SectionTitle('Outlet Current Map Location', subtitle: 'Type outlet location or use current GPS, then save latitude and longitude.'),
                      _text(_location, 'Outlet Current Location *', Icons.location_on_rounded, maxLines: 2, validator: (v) => _required(v, 'Outlet Current Location')),
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: searching ? null : _searchLocation,
                            icon: searching ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.search_rounded),
                            label: const Text('Find Location'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: searching ? null : _useCurrentGps,
                            icon: const Icon(Icons.my_location_rounded),
                            label: const Text('Use GPS'),
                          ),
                        ),
                      ]),
                      if (selectedLocation != null) ...[
                        const SizedBox(height: 14),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.success.withOpacity(.10),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: AppColors.success.withOpacity(.30)),
                          ),
                          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            const Icon(Icons.check_circle_rounded, color: AppColors.success),
                            const SizedBox(width: 10),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              const Text('Location Selected', style: TextStyle(fontWeight: FontWeight.w900, color: AppColors.success)),
                              const SizedBox(height: 4),
                              Text(selectedLocation!.subtitle, style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.w700)),
                              const SizedBox(height: 4),
                              Text('Lat: ${selectedLocation!.latitude.toStringAsFixed(6)} • Lng: ${selectedLocation!.longitude.toStringAsFixed(6)}', style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w700, fontSize: 12)),
                            ])),
                          ]),
                        ),
                      ],
                    ]),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: saving ? null : _save,
                    icon: saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.save_rounded),
                    label: Text(saving ? 'Saving Outlet...' : 'Save Outlet'),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  Widget _text(TextEditingController controller, String label, IconData icon, {TextInputType? keyboardType, int maxLines = 1, String? Function(String?)? validator}) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
    );
  }
}
