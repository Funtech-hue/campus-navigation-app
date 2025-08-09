import 'package:flutter/material.dart';
import '../model/location.dart';
import 'LocationService.dart';

class LocationProvider with ChangeNotifier {
  final LocationService _locationService = LocationService();
  String _selectedCategory = 'All';

  String get selectedCategory => _selectedCategory;

  Stream<List<Location>> get locations {
    return _locationService.getLocations().map((locations) {
      if (_selectedCategory == 'All') return locations;
      return locations
          .where((location) => location.category == _selectedCategory)
          .toList();
    });
  }

  Future<void> addLocation(Location location) async {
    await _locationService.addLocation(location);
    notifyListeners();
  }

  void setCategory(String category) {
    _selectedCategory = category;
    notifyListeners();
  }
}