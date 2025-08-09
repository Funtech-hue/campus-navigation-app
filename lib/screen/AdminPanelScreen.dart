import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:geolocator/geolocator.dart';
import 'package:campus_map/screen/locationHistoryScreen.dart';
import '../services/LocationProvider.dart';
import '../model/location.dart';

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  final _formKey = GlobalKey<FormState>();
  final _locationController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _imageController = TextEditingController();
  final _latitudeController = TextEditingController();
  final _longitudeController = TextEditingController();
  bool isLoading = false;
  String _currentLocationText = 'Fetching location...';
  StreamSubscription<Position>? _positionStream;

  final List<String> _categories = [
    'Labs',
    'Offices',
    'Hostels',
    'Buildings',
    'Sport',
    'Halls',
    'Lecture Halls',
    'Other',
  ];

  String? _selectedCategory;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _startLocationUpdates();
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _currentLocationText = 'Fetching location...';
    });

    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() {
        _currentLocationText = 'Location services disabled';
        _latitudeController.text = '7.7115';
        _longitudeController.text = '4.5149';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Location services are disabled. Using campus center.'),
        ),
      );
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() {
          _currentLocationText = 'Location permissions denied';
          _latitudeController.text = '7.7115';
          _longitudeController.text = '4.5149';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location permissions denied. Using campus center.'),
          ),
        );
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      setState(() {
        _currentLocationText = 'Location permissions permanently denied';
        _latitudeController.text = '7.7115';
        _longitudeController.text = '4.5149';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Location permissions permanently denied. Using campus center.',
          ),
        ),
      );
      return;
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.bestForNavigation,
        // Improved accuracy
        timeLimit: const Duration(seconds: 15), // Increased timeout
      );
      setState(() {
        _currentLocationText =
            'Current Location: ${position.latitude}, ${position.longitude}';
        _latitudeController.text = position.latitude.toStringAsFixed(6);
        _longitudeController.text = position.longitude.toStringAsFixed(6);
      });
    } catch (e) {
      setState(() {
        _currentLocationText = 'Error fetching location';
        _latitudeController.text = '7.7115';
        _longitudeController.text = '4.5149';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error fetching location: $e. Using campus center.'),
        ),
      );
    }
  }

  void _startLocationUpdates() {
    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation, // Improved accuracy
        distanceFilter: 5, // Update every 5 meters
      ),
    ).listen(
      (Position position) {
        setState(() {
          _currentLocationText =
              'Current Location: ${position.latitude}, ${position.longitude}';
          _latitudeController.text = position.latitude.toStringAsFixed(6);
          _longitudeController.text = position.longitude.toStringAsFixed(6);
        });
      },
      onError: (e) {
        setState(() {
          _currentLocationText = 'Error fetching location';
          _latitudeController.text = '7.7115';
          _longitudeController.text = '4.5149';
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Location update error: $e')));
      },
    );
  }

  Future<void> _addLocation() async {
    if (_formKey.currentState!.validate()) {
      setState(() => isLoading = true);
      final location = Location(
        id: const Uuid().v4(),
        locationName: _locationController.text,
        description: _descriptionController.text,
        imageUrl: _imageController.text,
        latitude: double.parse(_latitudeController.text),
        longitude: double.parse(_longitudeController.text),
        category: _selectedCategory ?? 'Other',
      );
      try {
        await Provider.of<LocationProvider>(
          context,
          listen: false,
        ).addLocation(location);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location uploaded successfully'),
            backgroundColor: Colors.green,
          ),
        );
        _formKey.currentState!.reset();
        _locationController.clear();
        _descriptionController.clear();
        _imageController.clear();
        setState(() {
          _selectedCategory = null;
          isLoading = false;
        });
        await _getCurrentLocation(); // Refresh location after submission
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error uploading location: $e'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _locationController.dispose();
    _descriptionController.dispose();
    _imageController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        leading: IconButton(
          onPressed: () {
            Navigator.pushReplacementNamed(context, '/welcome');
          },
          icon: const Icon(Icons.logout_sharp, size: 28, color: Colors.white),
          tooltip: 'Logout',
        ),
        title: const Text(
          'Admin Panel',
          style: TextStyle(color: Colors.white, fontSize: 24),
        ),
        centerTitle: true,
        backgroundColor: Colors.blue.shade800,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => LocationHistoryScreen()),
              );
            },
            icon: const Icon(Icons.history_edu, size: 28, color: Colors.white),
            tooltip: 'Location History',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _getCurrentLocation, // Pull-to-refresh
        color: Colors.blue.shade700,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          // Enable scrolling for pull-to-refresh
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Upload New Location',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade900,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.location_on, size: 18, color: Colors.blue),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _currentLocationText,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade700,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      DropdownButtonFormField<String>(
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.category),
                          labelText: 'Category',
                          hintText: 'Select a category',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                        ),
                        value: _selectedCategory,
                        items:
                            _categories.map((category) {
                              return DropdownMenuItem<String>(
                                value: category,
                                child: Text(category),
                              );
                            }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedCategory = value;
                          });
                        },
                        validator:
                            (value) =>
                                value == null
                                    ? 'Please select a category'
                                    : null,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _locationController,
                        label: 'Location Name',
                        hint: 'e.g., Chemistry Lab',
                        icon: Icons.location_on,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _descriptionController,
                        label: 'Description',
                        hint: 'Brief about this location',
                        icon: Icons.description,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _imageController,
                        label: 'Image URL (optional for future AR)',
                        hint: 'https://example.com/image.jpg',
                        icon: Icons.image,
                        required: false,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _latitudeController,
                        label: 'Latitude',
                        hint: 'e.g., 7.7116',
                        icon: Icons.map,
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _longitudeController,
                        label: 'Longitude',
                        hint: 'e.g., 4.5150',
                        icon: Icons.map_outlined,
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          icon:
                              isLoading
                                  ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                  : const Icon(Icons.upload_rounded),
                          label: Text(
                            isLoading ? 'Submitting...' : 'Submit',
                            style: const TextStyle(fontSize: 16),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade700,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 4,
                          ),
                          onPressed: isLoading ? null : _addLocation,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool required = true,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        prefixIcon: Icon(icon),
        labelText: label,
        hintText: hint,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.grey.shade50,
      ),
      validator: (value) {
        if (required && (value == null || value.isEmpty)) {
          return 'Please enter $label';
        }
        if (label == 'Latitude' || label == 'Longitude') {
          if (value != null &&
              value.isNotEmpty &&
              double.tryParse(value) == null) {
            return 'Please enter a valid number';
          }
        }
        return null;
      },
    );
  }
}
