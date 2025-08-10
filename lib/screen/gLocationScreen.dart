import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../model/location.dart';

class GoogleLocationScreen extends StatefulWidget {
  const GoogleLocationScreen({super.key});

  @override
  State<GoogleLocationScreen> createState() => _GoogleLocationScreenState();
}

class _GoogleLocationScreenState extends State<GoogleLocationScreen> {
  GoogleMapController? _mapController;
  Location? _destination;
  String? _searchQuery;
  final LatLng _defaultCenter = const LatLng(7.7115, 4.5149); // Your campus center

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Get arguments from navigation
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (args != null) {
      _destination = args['destination'] as Location?;
      _searchQuery = args['searchQuery'] as String?;
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    // Center on destination if provided
    if (_destination != null) {
      _mapController?.animateCamera(
        CameraUpdate.newLatLng(LatLng(_destination!.latitude, _destination!.longitude)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_searchQuery ?? _destination?.locationName ?? 'Location Map'),
        backgroundColor: Colors.blue.shade800,
        foregroundColor: Colors.white,
      ),
      body: GoogleMap(
        onMapCreated: _onMapCreated,
        initialCameraPosition: CameraPosition(
          target: _destination != null
              ? LatLng(_destination!.latitude, _destination!.longitude)
              : _defaultCenter,
          zoom: 15.0, // Adjust zoom level as needed
        ),
        markers: _buildMarkers(),
      ),
    );
  }

  Set<Marker> _buildMarkers() {
    final markers = <Marker>{};
    if (_destination != null) {
      markers.add(
        Marker(
          markerId: MarkerId(_destination!.id),
          position: LatLng(_destination!.latitude, _destination!.longitude),
          infoWindow: InfoWindow(
            title: _destination!.locationName,
            snippet: _destination!.description,
          ),
        ),
      );
    }
    // TODO: Add more markers for search results in Step 6
    return markers;
  }
}