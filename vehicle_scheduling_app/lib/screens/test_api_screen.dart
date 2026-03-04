import 'package:flutter/material.dart';
import 'package:vehicle_scheduling_app/services/vehicle_service.dart';
import 'package:vehicle_scheduling_app/models/vehicle.dart';

class TestApiScreen extends StatefulWidget {
  const TestApiScreen({super.key});

  @override
  State<TestApiScreen> createState() => _TestApiScreenState();
}

class _TestApiScreenState extends State<TestApiScreen> {
  final VehicleService _vehicleService = VehicleService();
  List<Vehicle> _vehicles = [];
  bool _loading = false;
  String _error = '';

  Future<void> _loadVehicles() async {
    setState(() {
      _loading = true;
      _error = '';
    });

    try {
      final vehicles = await _vehicleService.getAllVehicles();
      setState(() {
        _vehicles = vehicles;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('API Connection Test')),
      body: Center(
        child: _loading
            ? const CircularProgressIndicator()
            : _error.isNotEmpty
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, size: 60, color: Colors.red),
                  const SizedBox(height: 20),
                  const Text('Connection Failed'),
                  const SizedBox(height: 10),
                  Text(_error, textAlign: TextAlign.center),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _loadVehicles,
                    child: const Text('Retry'),
                  ),
                ],
              )
            : _vehicles.isEmpty
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('No data loaded'),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _loadVehicles,
                    child: const Text('Load Vehicles'),
                  ),
                ],
              )
            : ListView.builder(
                itemCount: _vehicles.length,
                itemBuilder: (context, index) {
                  final vehicle = _vehicles[index];
                  return ListTile(
                    leading: const Icon(Icons.local_shipping),
                    title: Text(vehicle.vehicleName),
                    subtitle: Text(vehicle.licensePlate),
                    trailing: Text(vehicle.statusText),
                  );
                },
              ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _loadVehicles,
        child: const Icon(Icons.refresh),
      ),
    );
  }
}
