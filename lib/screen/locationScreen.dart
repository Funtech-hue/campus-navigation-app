import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart' hide GeoPoint;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_osm_plugin/flutter_osm_plugin.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import '../model/location.dart';
import '../services/LocationProvider.dart';

class LocationScreen extends StatefulWidget {
  final String? searchQuery;
  final Location? destination;

  const LocationScreen({super.key, this.searchQuery, this.destination});

  @override
  _LocationScreenState createState() => _LocationScreenState();
}

class _LocationScreenState extends State<LocationScreen> {
  MapController? _mapController;
  GeoPoint? _currentPosition;
  GeoPoint? _currentMarkerPoint;
  Location? _destination;
  final TextEditingController _fromController = TextEditingController();
  final TextEditingController _toController = TextEditingController();
  RoadInfo? _routeInfo;
  final List<GeoPoint> _staticMarkerPoints = [];
  StreamSubscription<Position>? _positionStream;
  bool _isTracking = false;  // Start with false to avoid auto-follow

  static GeoPoint _campusCenter = GeoPoint(latitude: 7.7115, longitude: 4.5149);

  @override
  void initState() {
    super.initState();
    _initializeMap();
    _getCurrentLocation();
    _startLocationTracking();
    if (widget.searchQuery != null) {
      _toController.text = widget.searchQuery!;
      _searchDestination(widget.searchQuery!);
    } else if (widget.destination != null) {
      setState(() {
        _destination = widget.destination;
        _toController.text = widget.destination!.locationName;
      });
      _getRoute();
    }
  }

  Future<void> _initializeMap() async {
    _mapController = MapController.withPosition(
      initPosition: _campusCenter,
      areaLimit: BoundingBox(north: 7.7215, south: 7.7015, east: 4.5249, west: 4.5049),
    );
    // Do not enable tracking to avoid auto-follow
    setState(() {});
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location services are disabled. Please enable them.')),
      );
      _useFallbackLocation();
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permissions are denied.')),
        );
        _useFallbackLocation();
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location permissions are permanently denied.')),
      );
      _useFallbackLocation();
      return;
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
      _currentPosition = GeoPoint(latitude: position.latitude, longitude: position.longitude);
      await _updateCurrentLocationName(position.latitude, position.longitude);
      await _updateCurrentMarker();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error getting location: $e')),
      );
      _useFallbackLocation();
    }
  }

  Future<void> _useFallbackLocation() async {
    _currentPosition = _campusCenter;
    _fromController.text = 'Campus Center (7.7115, 4.5149)';
    await _updateCurrentMarker();
  }

  Future<void> _updateCurrentLocationName(double latitude, double longitude) async {
    final locations = await Provider.of<LocationProvider>(context, listen: false).locations.first;
    final nearbyLocation = locations.firstWhere(
          (location) =>
      Geolocator.distanceBetween(
        latitude,
        longitude,
        location.latitude,
        location.longitude,
      ) <
          20, // Within 20 meters
      orElse: () => Location(
        id: '',
        locationName: '',
        description: '',
        imageUrl: '',
        latitude: 0,
        longitude: 0,
        category: 'Other',
      ),
    );
    setState(() {
      _fromController.text = nearbyLocation.id.isNotEmpty
          ? nearbyLocation.locationName
          : 'Current Location ($latitude, $longitude)';
    });
  }

  Future<void> _updateCurrentMarker() async {
    if (_currentPosition == null) return;
    if (_currentMarkerPoint != null) {
      await _mapController?.removeMarker(_currentMarkerPoint!);
    }
    await _mapController?.addMarker(
      _currentPosition!,
      markerIcon: const MarkerIcon(
        icon: Icon(Icons.location_pin, color: Colors.red, size: 32),
      ),
    );
    _currentMarkerPoint = _currentPosition;
  }

  void _startLocationTracking() {
    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    ).listen((Position position) async {
      _currentPosition = GeoPoint(latitude: position.latitude, longitude: position.longitude);
      await _updateCurrentLocationName(position.latitude, position.longitude);
      await _updateCurrentMarker();
      if (_isTracking) {  // Only redraw route if tracking is on
        await _getRoute();
      }
      if (_destination != null) {
        final distance = await Geolocator.distanceBetween(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
          _destination!.latitude,
          _destination!.longitude,
        );
        if (distance < 10) {
          _positionStream?.cancel();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('You have reached your destination!')),
          );
        }
      }
    }, onError: (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Location tracking error: $e')),
      );
      _useFallbackLocation();
    });
  }

  Future<void> _addMarker(GeoPoint point, Location? location) async {
    Color iconColor = Colors.grey;
    if (location != null) {
      iconColor = location.category == 'Labs'
          ? Colors.red
          : location.category == 'Offices'
          ? Colors.green
          : location.category == 'Hostels'
          ? Colors.blue
          : location.category == 'Lecture Halls'
          ? Colors.purple
          : Colors.yellow;
    }
    await _mapController?.addMarker(
      point,
      markerIcon: MarkerIcon(
        iconWidget: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (location != null && location.imageUrl.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  location.imageUrl,
                  width: 40,
                  height: 40,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, size: 40),
                ),
              ),
            if (location != null)
              Text(
                location.locationName,
                style: const TextStyle(fontSize: 12, color: Colors.black, backgroundColor: Colors.white),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            Icon(Icons.location_pin, color: iconColor, size: 32),
          ],
        ),
      ),
    );
    _staticMarkerPoints.add(point);
  }

  Future<void> _clearStaticMarkers() async {
    if (_staticMarkerPoints.isNotEmpty) {
      await _mapController?.removeMarkers(_staticMarkerPoints);
      _staticMarkerPoints.clear();
    }
  }

  Future<void> _reloadFirestoreMarkers() async {
    final locations = await Provider.of<LocationProvider>(context, listen: false).locations.first;
    for (var location in locations) {
      _addMarker(
        GeoPoint(latitude: location.latitude, longitude: location.longitude),
        location,
      );
    }
  }

  Future<void> _searchDestination(String query) async {
    final locations = await Provider.of<LocationProvider>(context, listen: false).locations.first;
    final filtered = locations
        .where((location) => location.locationName.toLowerCase().contains(query.toLowerCase()))
        .toList();
    if (filtered.isNotEmpty) {
      final location = filtered.first;
      setState(() {
        _destination = location;
        _toController.text = location.locationName;
      });
      _getRoute();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No matching destination found.')),
      );
    }
  }

  Future<void> _setManualFromLocation(String input) async {
    if (input.contains(',')) {
      try {
        final coords = input.split(',').map((e) => double.parse(e.trim())).toList();
        if (coords.length == 2) {
          _currentPosition = GeoPoint(latitude: coords[0], longitude: coords[1]);
          await _updateCurrentLocationName(coords[0], coords[1]);
          await _updateCurrentMarker();
          _getRoute();
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid coordinates format. Use lat,lon')),
        );
      }
    } else {
      final locations = await Provider.of<LocationProvider>(context, listen: false).locations.first;
      final filtered = locations
          .where((location) => location.locationName.toLowerCase().contains(input.toLowerCase()))
          .toList();
      if (filtered.isNotEmpty) {
        final location = filtered.first;
        _currentPosition = GeoPoint(latitude: location.latitude, longitude: location.longitude);
        _fromController.text = location.locationName;
        await _updateCurrentMarker();
        _getRoute();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No matching location found.')),
        );
      }
    }
  }

  Future<void> _getRoute() async {
    if (_currentPosition == null || _destination == null) return;

    try {
      await _clearStaticMarkers();
      await _reloadFirestoreMarkers();
      _routeInfo = await _mapController?.drawRoad(
        _currentPosition!,
        GeoPoint(latitude: _destination!.latitude, longitude: _destination!.longitude),
        roadType: RoadType.foot,
        roadOption: const RoadOption(roadColor: Colors.green, roadWidth: 5),  // Changed to green
      );
      await _mapController?.zoomToBoundingBox(
        BoundingBox(
          north: _currentPosition!.latitude > _destination!.latitude
              ? _currentPosition!.latitude
              : _destination!.latitude,
          south: _currentPosition!.latitude < _destination!.latitude
              ? _currentPosition!.latitude
              : _destination!.latitude,
          east: _currentPosition!.longitude > _destination!.longitude
              ? _currentPosition!.longitude
              : _destination!.longitude,
          west: _currentPosition!.longitude < _destination!.longitude
              ? _currentPosition!.longitude
              : _destination!.longitude,
        ),
        paddinInPixel: 50,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching route: $e')),
      );
    }
  }

  void _setFromToCurrent() {
    if (_currentPosition != null) {
      _fromController.text = 'Current Location (${_currentPosition!.latitude.toStringAsFixed(4)}, ${_currentPosition!.longitude.toStringAsFixed(4)})';
      _mapController?.changeLocation(_currentPosition!);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Current location not available')));
    }
  }

  void _showLocationDetails(Location location) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (location.imageUrl.isNotEmpty)
              Image.network(location.imageUrl, height: 150, width: double.infinity, fit: BoxFit.cover),
            const SizedBox(height: 8),
            Text(location.locationName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(location.description),
            const SizedBox(height: 8),
            Text('Category: ${location.category}'),
            const SizedBox(height: 8),
            Text('Coordinates: ${location.latitude}, ${location.longitude}'),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Campus Navigation'),
        backgroundColor: Colors.blue.shade800,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(_isTracking ? Icons.gps_fixed : Icons.gps_off),
            onPressed: () {
              setState(() {
                _isTracking = !_isTracking;
                if (_isTracking && _currentPosition != null) {
                  _mapController?.changeLocation(_currentPosition!);
                }
              });
            },
            tooltip: _isTracking ? 'Stop Tracking' : 'Start Tracking',
          ),
        ],
      ),
      body: _mapController == null
          ? const Center(child: CircularProgressIndicator())
          : Stack(
        children: [
          OSMFlutter(
            controller: _mapController!,
            osmOption: OSMOption(
              userLocationMarker: UserLocationMaker(
                personMarker: const MarkerIcon(
                  icon: Icon(Icons.location_pin, color: Colors.red, size: 32),  // Changed current marker to red
                ),
                directionArrowMarker: const MarkerIcon(
                  icon: Icon(Icons.arrow_forward, color: Colors.purple, size: 32),  // Changed direction arrow to purple
                ),
              ),
              zoomOption: const ZoomOption(
                initZoom: 15,
                minZoomLevel: 10,
                maxZoomLevel: 19,
              ),
              roadConfiguration: const RoadOption(roadColor: Colors.green),  // Changed route color to green
              showContributorBadgeForOSM: true,
              isPicker: false,
              enableRotationByGesture: true,
              showDefaultInfoWindow: true,
            ),
            onMapIsReady: (isReady) async {
              if (isReady) {
                await _reloadFirestoreMarkers();
                Provider.of<LocationProvider>(context, listen: false)
                    .locations
                    .listen((locations) async {
                  await _clearStaticMarkers();
                  await _reloadFirestoreMarkers();
                });
              }
            },
            onGeoPointClicked: (GeoPoint point) async {
              final locations = await Provider.of<LocationProvider>(context, listen: false).locations.first;
              final selectedLocation = locations.firstWhere(
                    (location) =>
                (location.latitude - point.latitude).abs() < 0.0001 &&
                    (location.longitude - point.longitude).abs() < 0.0001,
                orElse: () => Location(
                  id: '',
                  locationName: '',
                  description: '',
                  imageUrl: '',
                  latitude: 0,
                  longitude: 0,
                  category: 'Other',
                ),
              );
              if (selectedLocation.id.isNotEmpty) {
                _showLocationDetails(selectedLocation);
              }
            },
          ),
          Positioned(
            top: 10,
            left: 10,
            right: 10,
            child: Column(
              children: [
                TypeAheadField<Location>(
                  builder: (context, controller, focusNode) {
                    return TextField(
                      controller: _fromController,
                      focusNode: focusNode,
                      decoration: InputDecoration(
                        labelText: 'FROM',
                        prefixIcon: const Icon(Icons.my_location),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                      ),
                      onSubmitted: (value) {
                        if (value.isNotEmpty) _setManualFromLocation(value);
                      },
                    );
                  },
                  suggestionsCallback: (pattern) async {
                    final locations = await Provider.of<LocationProvider>(context, listen: false).locations.first;
                    return locations.where((loc) => loc.locationName.toLowerCase().contains(pattern.toLowerCase())).toList();
                  },
                  itemBuilder: (context, location) {
                    return ListTile(title: Text(location.locationName));
                  },
                  onSelected: (location) {
                    _fromController.text = location.locationName;
                    _currentPosition = GeoPoint(latitude: location.latitude, longitude: location.longitude);
                    _updateCurrentMarker();
                    _getRoute();
                  },
                ),
                const SizedBox(height: 10),
                TypeAheadField<Location>(
                  builder: (context, controller, focusNode) {
                    return TextField(
                      controller: _toController,
                      focusNode: focusNode,
                      decoration: InputDecoration(
                        labelText: 'TO',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                      ),
                      onSubmitted: (value) {
                        if (value.isNotEmpty) _searchDestination(value);
                      },
                    );
                  },
                  suggestionsCallback: (pattern) async {
                    final locations = await Provider.of<LocationProvider>(context, listen: false).locations.first;
                    return locations.where((loc) => loc.locationName.toLowerCase().contains(pattern.toLowerCase())).toList();
                  },
                  itemBuilder: (context, location) {
                    return ListTile(title: Text(location.locationName));
                  },
                  onSelected: (location) {
                    _toController.text = location.locationName;
                    _destination = location;
                    _getRoute();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: 'zoom_in',
            onPressed: () => _mapController?.zoomIn(),
            child: const Icon(Icons.zoom_in),
            tooltip: 'Zoom In',
          ),
          const SizedBox(height: 8),
          FloatingActionButton(
            heroTag: 'zoom_out',
            onPressed: () => _mapController?.zoomOut(),
            child: const Icon(Icons.zoom_out),
            tooltip: 'Zoom Out',
          ),
          const SizedBox(height: 16),
          FloatingActionButton(
            heroTag: 'current',
            onPressed: () {
              _setFromToCurrent();
              if (_currentPosition != null) {
                _mapController?.changeLocation(_currentPosition!);
              }
            },
            child: const Icon(Icons.my_location),
            tooltip: 'Go to Current Location',
          ),
          const SizedBox(height: 16),
          FloatingActionButton(
            heroTag: 'search',
            onPressed: () {
              _searchDestination(_toController.text);
            },
            child: const Icon(Icons.search),
            tooltip: 'Search Destination',
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _mapController?.dispose();
    _fromController.dispose();
    _toController.dispose();
    super.dispose();
  }
}