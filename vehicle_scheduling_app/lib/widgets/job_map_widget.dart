// ============================================
// FILE: lib/widgets/job_map_widget.dart
// PURPOSE: Embedded Google Map with route polyline, ETA, and distance on job detail
// Requirements: GPS-01
// ============================================

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:vehicle_scheduling_app/services/gps_service.dart';

class JobMapWidget extends StatefulWidget {
  final int jobId;
  final double? destinationLat;
  final double? destinationLng;

  const JobMapWidget({
    super.key,
    required this.jobId,
    this.destinationLat,
    this.destinationLng,
  });

  @override
  State<JobMapWidget> createState() => _JobMapWidgetState();
}

class _JobMapWidgetState extends State<JobMapWidget> {
  // ── State ──────────────────────────────────────────────────────────────
  bool _loading = true;
  bool _error = false;

  Set<Polyline> _polylines = {};
  Set<Marker> _markers = {};

  String? _durationText;
  String? _distanceText;

  final Completer<GoogleMapController> _mapController = Completer();

  // ── Lifecycle ───────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    if (widget.destinationLat != null && widget.destinationLng != null) {
      _loadDirections();
    } else {
      setState(() => _loading = false);
    }
  }

  // ── Data loading ────────────────────────────────────────────────────────
  Future<void> _loadDirections() async {
    setState(() {
      _loading = true;
      _error = false;
    });

    try {
      // Try to get current device position for route origin
      Position? position;
      try {
        var permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        if (permission == LocationPermission.whileInUse ||
            permission == LocationPermission.always) {
          position = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.medium,
              timeLimit: Duration(seconds: 8),
            ),
          );
        }
      } catch (_) {
        // GPS unavailable — directions will be destination-only
      }

      if (!mounted) return;

      final directions = await GpsService.getDirections(
        widget.jobId,
        originLat: position?.latitude,
        originLng: position?.longitude,
      );

      if (!mounted) return;

      if (directions == null) {
        setState(() {
          _loading = false;
          _error = true;
        });
        return;
      }

      final destLat = widget.destinationLat!;
      final destLng = widget.destinationLng!;
      final destLatLng = LatLng(destLat, destLng);

      // Destination marker (red)
      final destinationMarker = Marker(
        markerId: const MarkerId('destination'),
        position: destLatLng,
        infoWindow: const InfoWindow(title: 'Destination'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      );

      Set<Marker> markers = {destinationMarker};
      Set<Polyline> polylines = {};
      String? durationText = directions['duration_text'] as String?;
      String? distanceText = directions['distance_text'] as String?;

      // Origin marker + polyline (only if we have origin and an encoded polyline)
      if (position != null) {
        final originLatLng = LatLng(position.latitude, position.longitude);

        markers.add(
          Marker(
            markerId: const MarkerId('origin'),
            position: originLatLng,
            infoWindow: const InfoWindow(title: 'You are here'),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          ),
        );

        final encodedPolyline = directions['encoded_polyline'] as String?;
        if (encodedPolyline != null && encodedPolyline.isNotEmpty) {
          final points = PolylinePoints.decodePolyline(encodedPolyline);
          if (points.isNotEmpty) {
            polylines.add(
              Polyline(
                polylineId: const PolylineId('route'),
                points: points
                    .map((p) => LatLng(p.latitude, p.longitude))
                    .toList(),
                color: Colors.blue,
                width: 4,
              ),
            );
          }
        }
      }

      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = false;
        _markers = markers;
        _polylines = polylines;
        _durationText = durationText;
        _distanceText = distanceText;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = true;
      });
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    // No destination coords — render nothing
    if (widget.destinationLat == null || widget.destinationLng == null) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 250,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.grey.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: _buildMapContent(),
          ),
        ),
        if (!_loading && !_error && (_durationText != null || _distanceText != null))
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                if (_durationText != null)
                  _InfoChip(
                    icon: Icons.access_time_outlined,
                    label: _durationText!,
                  ),
                if (_distanceText != null)
                  _InfoChip(
                    icon: Icons.straighten_outlined,
                    label: _distanceText!,
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildMapContent() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error) {
      return Container(
        color: Colors.grey[100],
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.map_outlined, size: 32, color: Colors.grey),
              SizedBox(height: 8),
              Text(
                'Directions unavailable',
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    final destLat = widget.destinationLat!;
    final destLng = widget.destinationLng!;

    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: LatLng(destLat, destLng),
        zoom: 13,
      ),
      markers: _markers,
      polylines: _polylines,
      mapType: MapType.normal,
      myLocationEnabled: false,
      zoomControlsEnabled: true,
      onMapCreated: (controller) {
        if (!_mapController.isCompleted) {
          _mapController.complete(controller);
        }
      },
    );
  }
}

// ── Small chip for ETA / distance display ──────────────────────────────────
class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.blue.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.blue[700]),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.blue[800],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
