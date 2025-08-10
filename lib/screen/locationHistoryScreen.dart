import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../model/location.dart';
import '../services/LocationProvider.dart';

class LocationHistoryScreen extends StatelessWidget {
  const LocationHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('All Locations'),
        backgroundColor: Colors.blue.shade800,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<List<Location>>(
        stream: Provider.of<LocationProvider>(context).locations, //
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error loading locations: ${snapshot.error}',
                style: const TextStyle(color: Colors.red),
              ),
            );
          }
          final locations = snapshot.data ?? [];
          if (locations.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.location_off, size: 60, color: Colors.grey),
                  SizedBox(height: 12),
                  Text(
                    'No locations available',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                ],
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
            itemCount: locations.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final location = locations[index];
              return Card(
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () {
                    // TODO: Navigate to location details or map
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Tapped on "${location.locationName}"')),
                    );
                  },
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: location.imageUrl.isNotEmpty
                          ? FadeInImage.assetNetwork(
                        placeholder: 'assets/images/placeholder.png',
                        image: location.imageUrl,
                        width: 60,
                        height: 60,
                        fit: BoxFit.cover,
                        imageErrorBuilder: (context, error, stackTrace) =>
                        const Icon(Icons.broken_image, size: 40, color: Colors.grey),
                      )
                          : const Icon(Icons.location_city, size: 40, color: Colors.grey),
                    ),
                    title: Text(
                      location.locationName,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      location.description.isNotEmpty
                          ? location.description
                          : location.category,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
