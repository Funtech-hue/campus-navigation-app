import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_osm_plugin/flutter_osm_plugin.dart';
import 'package:geolocator/geolocator.dart';
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
  Location? _destination;
  final TextEditingController _currentLocationController = TextEditingController();
  final TextEditingController _destinationController = TextEditingController();
  RoadInfo? _routeInfo;
  final List<GeoPoint> _markerPoints = [];
  StreamSubscription<Position>? _positionStream;
  bool _isTracking = true;

  static  GeoPoint _campusCenter = GeoPoint(latitude: 7.7115, longitude: 4.5149);

  @override
  void initState() {
    super.initState();
    _initializeMap();
    _getCurrentLocation();
    _startLocationTracking();
    if (widget.searchQuery != null) {
      _searchDestination(widget.searchQuery!);
    } else if (widget.destination != null) {
      setState(() {
        _destination = widget.destination;
        _destinationController.text = widget.destination!.locationName;
        _addMarker(
          GeoPoint(latitude: widget.destination!.latitude, longitude: widget.destination!.longitude),
          Colors.red,
        );
      });
      _getRoute();
    }
  }

  Future<void> _initializeMap() async {
    _mapController = MapController.withPosition(
      initPosition: _campusCenter,
      areaLimit: BoundingBox(north: 7.7215, south: 7.7015, east: 4.5249, west: 4.5049),
    );
    await _mapController?.enableTracking();
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
      setState(() {
        _addMarker(_currentPosition!, Colors.blue);
      });
      if (_isTracking) {
        await _mapController?.changeLocation(_currentPosition!);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error getting location: $e')),
      );
      _useFallbackLocation();
    }
  }

  Future<void> _useFallbackLocation() async {
    _currentPosition = _campusCenter;
    _currentLocationController.text = 'Campus Center (7.7115, 4.5149)';
    setState(() {
      _addMarker(_currentPosition!, Colors.blue);
    });
    if (_isTracking) {
      await _mapController?.changeLocation(_currentPosition!);
    }
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
      _currentLocationController.text = nearbyLocation.id.isNotEmpty
          ? nearbyLocation.locationName
          : 'Current Location ($latitude, $longitude)';
    });
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
      setState(() {
        _clearMarkers();
        _addMarker(_currentPosition!, Colors.blue);
        _reloadFirestoreMarkers();
      });
      if (_isTracking) {
        await _mapController?.changeLocation(_currentPosition!);
      }
      if (_destination != null) {
        final distance = await Geolocator.distanceBetween(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
          _destination!.latitude,
          _destination!.longitude,
        );
        if (distance < 10) {
          setState(() => _isTracking = false);
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

  void _addMarker(GeoPoint point, Color color) {
    _mapController?.addMarker(
      point,
      markerIcon: MarkerIcon(
        icon: Icon(Icons.location_pin, color: color, size: 32),
      ),
    );
    _markerPoints.add(point);
  }

  Future<void> _clearMarkers() async {
    if (_markerPoints.isNotEmpty) {
      await _mapController?.removeMarkers(_markerPoints);
      _markerPoints.clear();
    }
  }

  Future<void> _reloadFirestoreMarkers() async {
    final locations = await Provider.of<LocationProvider>(context, listen: false).locations.first;
    for (var location in locations) {
      final iconColor = location.category == 'Labs'
          ? Colors.red
          : location.category == 'Offices'
          ? Colors.green
          : location.category == 'Hostels'
          ? Colors.blue
          : location.category == 'Lecture Halls'
          ? Colors.purple
          : Colors.yellow;
      _addMarker(
        GeoPoint(latitude: location.latitude, longitude: location.longitude),
        iconColor,
      );
    }
  }

  Future<void> _searchDestination(String query) async {
    final locations = Provider.of<LocationProvider>(context, listen: false).locations;
    final snapshot = await locations.first;
    final filtered = snapshot
        .where((location) => location.locationName.toLowerCase().contains(query.toLowerCase()))
        .toList();
    if (filtered.isNotEmpty) {
      final location = filtered.first;
      setState(() {
        _destination = location;
        _destinationController.text = location.locationName;
        _addMarker(
          GeoPoint(latitude: location.latitude, longitude: location.longitude),
          Colors.red,
        );
      });
      _getRoute();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No matching destination found.')),
      );
    }
  }

  Future<void> _setManualCurrentLocation(String input) async {
    if (input.contains(',')) {
      try {
        final coords = input.split(',').map((e) => double.parse(e.trim())).toList();
        if (coords.length == 2) {
          _currentPosition = GeoPoint(latitude: coords[0], longitude: coords[1]);
          await _updateCurrentLocationName(coords[0], coords[1]);
          setState(() {
            _clearMarkers();
            _addMarker(_currentPosition!, Colors.blue);
            _reloadFirestoreMarkers();
          });
          if (_isTracking) {
            await _mapController?.changeLocation(_currentPosition!);
          }
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
        _currentLocationController.text = location.locationName;
        setState(() {
          _clearMarkers();
          _addMarker(_currentPosition!, Colors.blue);
          _reloadFirestoreMarkers();
        });
        if (_isTracking) {
          await _mapController?.changeLocation(_currentPosition!);
        }
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
      await _clearMarkers();
      _addMarker(_currentPosition!, Colors.blue);
      _reloadFirestoreMarkers();
      _routeInfo = await _mapController?.drawRoad(
        _currentPosition!,
        GeoPoint(latitude: _destination!.latitude, longitude: _destination!.longitude),
        roadType: RoadType.foot,
        roadOption: const RoadOption(roadColor: Colors.blue, roadWidth: 5),
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
            osmOption:  OSMOption(
              userLocationMarker: UserLocationMaker(
                personMarker: MarkerIcon(
                    icon: Icon(Icons.my_location, color: Colors.blue, size: 32)),
                directionArrowMarker: MarkerIcon(
                    icon: Icon(Icons.navigation, color: Colors.blue, size: 32)),
              ),
              zoomOption: ZoomOption(
                  initZoom: 15, minZoomLevel: 10, maxZoomLevel: 19),
              roadConfiguration: RoadOption(roadColor: Colors.blue),
              showContributorBadgeForOSM: true,
              isPicker: false,
              enableRotationByGesture: true,
              showDefaultInfoWindow: true,
            ),
            onMapIsReady: (isReady) async {
              if (isReady) {
                await _reloadFirestoreMarkers();
                if (_currentPosition != null) {
                  _addMarker(_currentPosition!, Colors.blue);
                }
                Provider.of<LocationProvider>(context, listen: false)
                    .locations
                    .listen((locations) async {
                  await _clearMarkers();
                  await _reloadFirestoreMarkers();
                  if (_currentPosition != null) {
                    _addMarker(_currentPosition!, Colors.blue);
                  }
                });
              }
            },
            onGeoPointClicked: (GeoPoint point) async {
              final locations = await Provider.of<LocationProvider>(context, listen: false)
                  .locations
                  .first;
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
                    category: 'Other'),
              );
              if (selectedLocation.id.isNotEmpty) {
                setState(() {
                  _destination = selectedLocation;
                  _destinationController.text = selectedLocation.locationName;
                });
                _getRoute();
              }
            },
          ),
          Positioned(
            top: 10,
            left: 10,
            right: 10,
            child: Column(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: const [
                      BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 3)),
                    ],
                  ),
                  child: TextField(
                    controller: _currentLocationController,
                    decoration: InputDecoration(
                      hintText: 'Current Location or lat,lon',
                      prefixIcon: const Icon(Icons.my_location),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                    ),
                    onSubmitted: (value) {
                      if (value.isNotEmpty) _setManualCurrentLocation(value);
                    },
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: const [
                      BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 3)),
                    ],
                  ),
                  child: TextField(
                    controller: _destinationController,
                    decoration: InputDecoration(
                      hintText: 'Select Destination',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                    ),
                    onSubmitted: (value) {
                      if (value.isNotEmpty) _searchDestination(value);
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed:
        _currentPosition != null ? () => _mapController?.changeLocation(_currentPosition!) : null,
        child: const Icon(Icons.my_location),
      ),
    );
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _mapController?.disabledTracking();
    _mapController?.dispose();
    _currentLocationController.dispose();
    _destinationController.dispose();
    super.dispose();
  }
}