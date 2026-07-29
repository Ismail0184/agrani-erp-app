import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../core/app_theme.dart';
import '../models/outlet_master_model.dart';
import '../services/outlet_create_service.dart';
import '../widgets/pro_widgets.dart';

class ExistingOutletUpdatePage extends StatefulWidget {
  final OutletMasterModel outlet;
  const ExistingOutletUpdatePage({super.key, required this.outlet});

  @override
  State<ExistingOutletUpdatePage> createState() => _ExistingOutletUpdatePageState();
}

class _ExistingOutletUpdatePageState extends State<ExistingOutletUpdatePage> {
  final ImagePicker _picker = ImagePicker();
  LocationSearchResult? currentLocation;
  XFile? shopImage;
  bool locating = false;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _useCurrentGps());
  }

  Future<void> _useCurrentGps() async {
    if (locating) return;
    setState(() => locating = true);
    try {
      final result = await OutletCreateService.instance.currentGpsLocation();
      if (!mounted) return;
      if (result == null) {
        _show('Current GPS location not available. Please allow location permission and try again.', error: true);
        return;
      }
      setState(() => currentLocation = result);
    } catch (e) {
      if (mounted) _show('Current GPS location failed: $e', error: true);
    } finally {
      if (mounted) setState(() => locating = false);
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
            onTap: () {
              Navigator.pop(ctx);
              _pickImage(ImageSource.camera);
            },
          ),
          ListTile(
            leading: const CircleAvatar(child: Icon(Icons.photo_library_rounded)),
            title: const Text('Select From Gallery', style: TextStyle(fontWeight: FontWeight.w800)),
            onTap: () {
              Navigator.pop(ctx);
              _pickImage(ImageSource.gallery);
            },
          ),
        ]),
      ),
    );
  }

  Future<void> _save() async {
    if (currentLocation == null) {
      _show('Current GPS location is required.', error: true);
      return;
    }
    if (shopImage == null) {
      _show('Outlet shop image is required.', error: true);
      return;
    }

    setState(() => saving = true);
    try {
      await OutletCreateService.instance.updateExistingOutlet(
        outletId: widget.outlet.outletId,
        locationText: currentLocation!.subtitle,
        latitude: currentLocation!.latitude,
        longitude: currentLocation!.longitude,
        shopImagePath: shopImage!.path,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) _show('Outlet update failed: $e', error: true);
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
    final outlet = widget.outlet;
    return Scaffold(
      appBar: AppBar(title: const Text('Update Existing Outlet')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ProCard(
            gradient: const LinearGradient(colors: [AppColors.primaryDark, AppColors.primary, AppColors.secondary]),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(outlet.outletName.isEmpty ? 'Existing Outlet' : outlet.outletName, style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w900)),
              const SizedBox(height: 5),
              Text(outlet.outletCode.isEmpty ? 'Outlet ID: ${outlet.outletId}' : outlet.outletCode, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700)),
            ]),
          ),
          const SizedBox(height: 16),
          ProCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const SectionTitle('Outlet Information'),
              if (outlet.routeName.isNotEmpty) _line(Icons.alt_route_rounded, 'Route', outlet.routeName),
              if (outlet.marketName.isNotEmpty) _line(Icons.store_mall_directory_rounded, 'Market', outlet.marketName),
              if (outlet.ownerName.isNotEmpty) _line(Icons.person_rounded, 'Owner', outlet.ownerName),
              if (outlet.contactNumber.isNotEmpty) _line(Icons.call_rounded, 'Mobile', outlet.contactNumber),
              if (outlet.shopAddress.isNotEmpty) _line(Icons.location_city_rounded, 'Address', outlet.shopAddress),
            ]),
          ),
          const SizedBox(height: 16),
          ProCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const SectionTitle('Current GPS Location'),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: AppColors.primary.withOpacity(.07), borderRadius: BorderRadius.circular(16)),
                child: Row(children: [
                  const Icon(Icons.my_location_rounded, color: AppColors.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      currentLocation == null ? 'Current GPS location is not captured yet.' : currentLocation!.subtitle,
                      style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.text),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: locating ? null : _useCurrentGps,
                icon: locating ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.gps_fixed_rounded),
                label: Text(locating ? 'Getting Current Location...' : 'Get Current Location'),
              ),
            ]),
          ),
          const SizedBox(height: 16),
          ProCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const SectionTitle('Shop Image'),
              InkWell(
                onTap: _showImagePicker,
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  height: 210,
                  decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFE2E8F0))),
                  clipBehavior: Clip.antiAlias,
                  child: shopImage == null
                      ? const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Icon(Icons.add_a_photo_rounded, color: AppColors.primary, size: 44),
                          SizedBox(height: 10),
                          Text('Tap to capture shop image', style: TextStyle(fontWeight: FontWeight.w900)),
                        ])
                      : Image.file(File(shopImage!.path), fit: BoxFit.cover),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(onPressed: _showImagePicker, icon: const Icon(Icons.photo_camera_rounded), label: Text(shopImage == null ? 'Add Shop Image' : 'Change Shop Image')),
            ]),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: saving ? null : _save,
            icon: saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.save_rounded),
            label: Text(saving ? 'Updating...' : 'Update Outlet'),
          ),
          const SizedBox(height: 36),
        ],
      ),
    );
  }

  Widget _line(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 18, color: AppColors.muted),
        const SizedBox(width: 8),
        SizedBox(width: 72, child: Text(label, style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w800))),
        Expanded(child: Text(value, style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.w800))),
      ]),
    );
  }
}
