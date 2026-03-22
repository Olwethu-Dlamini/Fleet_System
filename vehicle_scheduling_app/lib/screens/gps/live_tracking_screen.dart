// ============================================
// FILE: lib/screens/gps/live_tracking_screen.dart
// PURPOSE: Admin/scheduler map view showing live driver positions
// Requirements: GPS-02, GPS-03
// ============================================

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:vehicle_scheduling_app/config/theme.dart';
import 'package:vehicle_scheduling_app/services/gps_service.dart';

class LiveTrackingScreen extends StatefulWidget {
  const LiveTrackingScreen({super.key});

  @override
  State<LiveTrackingScreen> createState() => _LiveTrackingScreenState();
}

class _LiveTrackingScreenState extends State<LiveTrackingScreen> {
  // ── State ──────────────────────────────────────────────────────────────────
  GoogleMapController? _mapController;
  final Map<MarkerId, Marker> _driverMarkers = {};
  Timer? _pollTimer;
  bool _loading = true;
  String? _error;
  int _driverCount = 0;
  DateTime? _lastUpdated;
  bool _cameraBoundsFitted = false;

  // ── Default camera position: Cape Town, South Africa ──────────────────────
  static const CameraPosition _initialPosition = CameraPosition(
    target: LatLng(-33.9249, 18.4241),
    zoom: 10,
  );

  // ── Lifecycle ──────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _fetchDriverLocations();
    _pollTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _fetchDriverLocations(),
    );
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  // ── Data fetching ──────────────────────────────────────────────────────────
  Future<void> _fetchDriverLocations() async {
    try {
      final drivers = await GpsService.getDriverLocations();

      if (!mounted) return;

      final Map<MarkerId, Marker> newMarkers = {};
      final now = DateTime.now();

      for (final driver in drivers) {
        final driverId = driver['driver_id'];
        final lat = (driver['lat'] as num?)?.toDouble();
        final lng = (driver['lng'] as num?)?.toDouble();

        if (driverId == null || lat == null || lng == null) continue;

        // Parse updated_at (milliseconds since epoch)
        final updatedAtMs = driver['updated_at'];
        if (updatedAtMs == null) continue;

        final updatedAt = DateTime.fromMillisecondsSinceEpoch(
          (updatedAtMs as num).toInt(),
        );
        final minutesAgo = now.difference(updatedAt).inMinutes;

        // Skip stale markers (older than 5 minutes)
        if (minutesAgo > 5) continue;

        final markerId = MarkerId('driver_$driverId');
        final driverName =
            driver['driver_name'] as String? ?? 'Driver $driverId';

        // Green for recent (<= 2 min), orange for getting stale (3–5 min)
        final markerHue = minutesAgo > 2
            ? BitmapDescriptor.hueOrange
            : BitmapDescriptor.hueGreen;

        newMarkers[markerId] = Marker(
          markerId: markerId,
          position: LatLng(lat, lng),
          infoWindow: InfoWindow(
            title: driverName,
            snippet: minutesAgo == 0 ? 'Just now' : '$minutesAgo min ago',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(markerHue),
        );
      }

      // On first successful load with drivers, fit the camera to show all markers
      final isFirstLoad = _loading;
      final hasMarkers = newMarkers.isNotEmpty;

      setState(() {
        _driverMarkers
          ..clear()
          ..addAll(newMarkers);
        _driverCount = newMarkers.length;
        _loading = false;
        _error = null;
        _lastUpdated = now;
      });

      if (isFirstLoad && hasMarkers && !_cameraBoundsFitted) {
        _fitCameraToMarkers(newMarkers.values.toList());
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Failed to load driver locations. Tap retry to try again.';
      });
    }
  }

  /// Animate camera to show all driver markers with padding.
  void _fitCameraToMarkers(List<Marker> markers) {
    if (markers.isEmpty || _mapController == null) return;

    _cameraBoundsFitted = true;

    double minLat = markers.first.position.latitude;
    double maxLat = markers.first.position.latitude;
    double minLng = markers.first.position.longitude;
    double maxLng = markers.first.position.longitude;

    for (final marker in markers) {
      if (marker.position.latitude < minLat) minLat = marker.position.latitude;
      if (marker.position.latitude > maxLat) maxLat = marker.position.latitude;
      if (marker.position.longitude < minLng) {
        minLng = marker.position.longitude;
      }
      if (marker.position.longitude > maxLng) {
        maxLng = marker.position.longitude;
      }
    }

    final bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );

    _mapController?.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 80),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Tracking'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(24),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              _loading
                  ? 'Loading drivers…'
                  : '$_driverCount active driver${_driverCount == 1 ? '' : 's'}',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
              ),
            ),
          ),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                size: 48,
                color: Colors.red,
              ),
              const SizedBox(height: 12),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _loading = true;
                    _error = null;
                  });
                  _fetchDriverLocations();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_driverMarkers.isEmpty) {
      return Stack(
        children: [
          // Show the map even when empty so the user can see the region
          GoogleMap(
            initialCameraPosition: _initialPosition,
            markers: const {},
            mapType: MapType.normal,
            myLocationEnabled: false,
            zoomControlsEnabled: true,
            onMapCreated: (controller) => _mapController = controller,
          ),
          // Overlay "no drivers" indicator
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 32),
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 16,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.location_off, size: 40, color: Colors.grey),
                  SizedBox(height: 8),
                  Text(
                    'No active drivers',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Driver locations appear here when\nGPS is active and recent.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ],
              ),
            ),
          ),
          // Last-updated chip at bottom
          _buildLastUpdatedOverlay(),
        ],
      );
    }

    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition: _initialPosition,
          markers: Set<Marker>.from(_driverMarkers.values),
          mapType: MapType.normal,
          myLocationEnabled: false,
          zoomControlsEnabled: true,
          onMapCreated: (controller) {
            _mapController = controller;
            // Fit bounds after the map is ready (first-load scenario when
            // markers were already populated before the controller existed)
            if (_driverMarkers.isNotEmpty && !_cameraBoundsFitted) {
              Future.delayed(const Duration(milliseconds: 300), () {
                _fitCameraToMarkers(_driverMarkers.values.toList());
              });
            }
          },
        ),
        _buildLastUpdatedOverlay(),
      ],
    );
  }

  /// Bottom overlay showing last update time and a manual refresh button.
  Widget _buildLastUpdatedOverlay() {
    final label = _lastUpdated == null
        ? 'Not yet updated'
        : 'Last updated: ${_formatRelativeTime(_lastUpdated!)}';

    return Positioned(
      left: 12,
      right: 12,
      bottom: 16,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ),
            InkWell(
              onTap: () {
                setState(() => _loading = false);
                _fetchDriverLocations();
              },
              borderRadius: BorderRadius.circular(20),
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(
                  Icons.refresh,
                  size: 20,
                  color: AppTheme.primaryColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatRelativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 10) return 'just now';
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ago';
  }
}
