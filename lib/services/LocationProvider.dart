import 'package:flutter/material.dart';
import '../model/location.dart';
import 'LocationService.dart';

class LocationProvider with ChangeNotifier {
  final LocationService _locationService = LocationService();
  String _selectedCategory = 'All';

  String get selectedCategory => _selectedCategory;

  String _searchQuery = '';

  String get searchQuery => _searchQuery;

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  Stream<List<Location>> get locations {
    return _locationService.getLocations().map((locations) {
      List<Location> filteredLocations = locations;
      if (_selectedCategory != 'All') {
        filteredLocations = filteredLocations
            .where((location) => location.category == _selectedCategory)
            .toList();
      }
      if (_searchQuery.isNotEmpty) {
        final lowerQuery = _searchQuery.toLowerCase();
        filteredLocations = filteredLocations.where((location) {
          return location.locationName.toLowerCase().contains(lowerQuery) ||
              location.description.toLowerCase().contains(lowerQuery) ||
              location.category.toLowerCase().contains(lowerQuery);
        }).toList();
      }
      return filteredLocations;
    });
  }

  // add location provider
  Future<void> addLocation(Location location) async {
    await _locationService.addLocation(location);
    notifyListeners();
  }

  // set category provider
  void setCategory(String category) {
    _selectedCategory = category;
    notifyListeners();
  }

  //update location provider
  Future<void> updateLocation(Location location) async {
    await _locationService.updateLocation(location);
    notifyListeners();
  }

  //delete location provider
  Future<void> deleteLocation(Location location) async {
    await _locationService.deleteLocation(location);
    notifyListeners();
  }
}
