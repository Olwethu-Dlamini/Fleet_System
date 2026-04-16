import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';

class LocationPickerResult {
  final LatLng position;
  final String address;

  LocationPickerResult({required this.position, required this.address});
}

class LocationPickerPopup extends StatefulWidget {
  final LatLng? initialPosition;
  final String? initialAddress;

  const LocationPickerPopup({
    super.key,
    this.initialPosition,
    this.initialAddress,
  });

  @override
  State<LocationPickerPopup> createState() => _LocationPickerPopupState();
}

class _LocationPickerPopupState extends State<LocationPickerPopup> {
  final Completer<GoogleMapController> _controller = Completer();
  LatLng? _selectedPosition;
  bool _loading = true;
  String _statusMessage = 'Initializing map...';

  static const CameraPosition _defaultKrugersdorp = CameraPosition(
    target: LatLng(-26.1000, 27.7700),
    zoom: 14.4746,
  );

  @override
  void initState() {
    super.initState();
    _selectedPosition = widget.initialPosition;
    _determinePosition();
  }

  Future<void> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    setState(() {
      _loading = true;
      _statusMessage = 'Checking permissions...';
    });

    // Test if location services are enabled.
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() {
        _loading = false;
        _statusMessage = 'Location services are disabled.';
      });
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() {
          _loading = false;
          _statusMessage = 'Location permissions are denied';
        });
        return;
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      setState(() {
        _loading = false;
        _statusMessage = 'Location permissions are permanently denied, we cannot request permissions.';
      });
      return;
    } 

    if (widget.initialPosition == null) {
      setState(() {
        _statusMessage = 'Getting current location...';
      });
      try {
        Position position = await Geolocator.getCurrentPosition();
        setState(() {
          _selectedPosition = LatLng(position.latitude, position.longitude);
          _loading = false;
        });
        
        final GoogleMapController controller = await _controller.future;
        controller.animateCamera(CameraUpdate.newLatLng(_selectedPosition!));
      } catch (e) {
        setState(() {
          _loading = false;
          _statusMessage = 'Could not get current location. Tap on map to select.';
        });
      }
    } else {
      setState(() {
        _loading = false;
      });
    }
  }

  void _onMapTapped(LatLng position) {
    setState(() {
      _selectedPosition = position;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Location'),
        actions: [
          if (_selectedPosition != null)
            IconButton(
              icon: const Icon(Icons.check),
              onPressed: () {
                final String coordStr = '${_selectedPosition!.latitude.toStringAsFixed(7)}, ${_selectedPosition!.longitude.toStringAsFixed(7)}';
                Navigator.pop(
                  context,
                  LocationPickerResult(
                    position: _selectedPosition!,
                    address: coordStr,
                  ),
                );
              },
            ),
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            mapType: MapType.normal,
            initialCameraPosition: widget.initialPosition != null 
                ? CameraPosition(target: widget.initialPosition!, zoom: 15)
                : _defaultKrugersdorp,
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            onMapCreated: (GoogleMapController controller) {
              _controller.complete(controller);
            },
            onTap: _onMapTapped,
            markers: _selectedPosition != null
                ? {
                    Marker(
                      markerId: const MarkerId('selected_location'),
                      position: _selectedPosition!,
                    ),
                  }
                : {},
          ),
          if (_loading)
            Container(
              color: Colors.black54,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: Colors.white),
                    const SizedBox(height: 16),
                    Text(
                      _statusMessage,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          if (!_loading && _selectedPosition == null)
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(_statusMessage),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
