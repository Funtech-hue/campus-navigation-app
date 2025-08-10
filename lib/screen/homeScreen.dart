import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart' as geocoding;
import '../model/location.dart';
import '../services/LocationProvider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _currentLocationText = 'Fetching location...';

  @override
  void initState() {
    super.initState();
    _getCurrentLocation(); // Fetch location only on first open
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _currentLocationText = 'Fetching location...';
    });

    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() {
        _currentLocationText = 'North Campus';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location services are disabled. Using default location.')),
      );
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() {
          _currentLocationText = 'North Campus';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permissions denied. Using default location.')),
        );
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      setState(() {
        _currentLocationText = 'North Campus';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location permissions permanently denied. Using default location.')),
      );
      return;
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.bestForNavigation, // High precision
        timeLimit: const Duration(seconds: 15), // Allow time for GPS fix
      );
      await _updateCurrentLocationName(position.latitude, position.longitude);
    } catch (e) {
      setState(() {
        _currentLocationText = 'North Campus';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching location: $e')),
      );
    }
  }

  Future<void> _updateCurrentLocationName(double latitude, double longitude) async {
    const double campusLat = 7.7115;
    const double campusLon = 4.5149;
    const double campusRadius = 500; // meters
    final double distanceToCampus = Geolocator.distanceBetween(latitude, longitude, campusLat, campusLon);

    if (distanceToCampus <= campusRadius) {
      try {
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
            locationName: 'North Campus',
            description: '',
            imageUrl: '',
            latitude: 0,
            longitude: 0,
            category: 'Other',
          ),
        );
        setState(() {
          _currentLocationText = nearbyLocation.locationName;
        });
      } catch (e) {
        setState(() {
          _currentLocationText = 'North Campus';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error accessing Firestore: $e')),
        );
      }
    } else {
      try {
        final placemarks = await geocoding.placemarkFromCoordinates(latitude, longitude);
        if (placemarks.isNotEmpty) {
          final placemark = placemarks.first;
          final locationName = [
            placemark.locality,
            placemark.administrativeArea,
            placemark.country,
          ].where((element) => element != null && element.isNotEmpty).join(', ');
          setState(() {
            _currentLocationText = locationName.isNotEmpty ? locationName : 'Unknown Location';
          });
        } else {
          setState(() {
            _currentLocationText = 'Unknown Location';
          });
        }
      } catch (e) {
        setState(() {
          _currentLocationText = 'Unknown Location';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error getting location name: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final locationProvider = Provider.of<LocationProvider>(context);
    final categories = ['All', 'Labs', 'Offices', 'Hostels', 'Lecture Halls', 'Other'];

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _getCurrentLocation, // Manual pull-to-refresh
          color: Colors.blue.shade700,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(), // Enable pull-to-refresh
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Welcome to\nFPE North Campus Map',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade800,
                          height: 1.4,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        Navigator.pushNamed(context, '/admin');
                      },
                      icon: const Icon(Icons.admin_panel_settings, size: 28, color: Colors.blue),
                      tooltip: 'Admin Panel',
                    ),
                    const SizedBox(width: 5),
                    IconButton(
                      onPressed: () {
                        Navigator.pushReplacementNamed(context, '/welcome');
                      },
                      icon: const Icon(Icons.logout, size: 28, color: Colors.blue),
                      tooltip: 'Logout',
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Location
                Text(
                  'Your current location',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.location_on, size: 18, color: Colors.blue),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _currentLocationText,
                        style: const TextStyle(fontSize: 15),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 30),
                // Search + Filter
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 10,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: TextField(
                          onSubmitted: (value) {
                            if (value.isNotEmpty) {
                              Navigator.pushNamed(
                                context,
                                '/location',
                                arguments: {'searchQuery': value},
                              );
                            }
                          },
                          decoration: const InputDecoration(
                            contentPadding: EdgeInsets.symmetric(vertical: 15),
                            border: InputBorder.none,
                            hintText: 'Search by name, type, or location',
                            prefixIcon: Icon(Icons.search, color: Colors.grey),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 6,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.filter_alt_rounded, color: Colors.white),
                    ),
                  ],
                ),
                const SizedBox(height: 30),
                // Category List
                SizedBox(
                  height: 40,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: categories.length,
                    itemBuilder: (context, index) {
                      final category = categories[index];
                      final isSelected = locationProvider.selectedCategory == category;
                      return GestureDetector(
                        onTap: () {
                          locationProvider.setCategory(category);
                        },
                        child: Container(
                          margin: const EdgeInsets.only(right: 10),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.blue.shade700 : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black12,
                                blurRadius: 4,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Text(
                            category,
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.black87,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 20),
                // Location Grid
                StreamBuilder<List<Location>>(
                  stream: locationProvider.locations,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return const Center(child: Text('Error loading locations'));
                    }
                    final locations = snapshot.data ?? [];
                    if (locations.isEmpty) {
                      return const Center(child: Text('No locations available'));
                    }
                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                      ),
                      itemCount: locations.length,
                      itemBuilder: (context, index) {
                        final location = locations[index];
                        return GestureDetector(
                          onTap: () {
                            Navigator.pushNamed(
                              context,
                              '/location',
                              arguments: {'destination': location},
                            );
                          },
                          child: Card(
                            color: Colors.white,
                            clipBehavior: Clip.antiAlias,
                            elevation: 4,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: Colors.grey.shade300,
                                width: 1,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ClipRRect(
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                                  child: Image.network(
                                    location.imageUrl,
                                    height: 120,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) => Container(
                                      height: 120,
                                      width: double.infinity,
                                      color: Colors.grey.shade200,
                                      child: const Icon(Icons.broken_image, size: 40, color: Colors.grey),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.fromLTRB(10, 10, 10, 5),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          location.locationName,
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black87,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          location.description,
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey.shade600,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}