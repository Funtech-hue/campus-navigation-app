import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../model/location.dart';
import '../services/LocationProvider.dart';
import 'AdminPanelScreen.dart';
import 'locationScreen.dart';

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
        stream: Provider.of<LocationProvider>(context).locations,
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
              return Dismissible(
                key: Key(location.id.toString()),
                // Assuming Location has a unique 'id' field (e.g., String or int). Adjust if your model uses a different unique identifier.
                direction: DismissDirection.endToStart,
                // Swipe from right to left to delete
                onDismissed: (direction) async {
                  // Store a copy for potential undo
                  final deletedLocation = location;

                  // Call the delete method from the provider
                  await Provider.of<LocationProvider>(
                    context,
                    listen: false,
                  ).deleteLocation(location);

                  // Show a snackbar with optional undo action
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Deleted "${deletedLocation.locationName}"',
                      ),
                      action: SnackBarAction(
                        label: 'Undo',
                        onPressed: () async {
                          // Implement undo logic: re-add the location via provider
                          await Provider.of<LocationProvider>(
                            context,
                            listen: false,
                          ).addLocation(deletedLocation);
                        },
                      ),
                    ),
                  );
                },
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  color: Colors.red,
                  child: const Icon(
                    Icons.delete,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
                child: Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () {
                      // Navigate to location details screen
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => LocationScreen(destination: location),
                        ),
                      );
                    },
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child:
                            location.imageUrl.isNotEmpty
                                ? FadeInImage.assetNetwork(
                                  placeholder: 'assets/images/placeholder.jpg',
                                  image: location.imageUrl,
                                  width: 60,
                                  height: 60,
                                  fit: BoxFit.cover,
                                  imageErrorBuilder:
                                      (context, error, stackTrace) =>
                                          const Icon(
                                            Icons.broken_image,
                                            size: 40,
                                            color: Colors.grey,
                                          ),
                                )
                                : const Icon(
                                  Icons.location_city,
                                  size: 40,
                                  color: Colors.grey,
                                ),
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
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.edit,
                              size: 20,
                              color: Colors.blue,
                            ),
                            onPressed: () {
                              // Navigate to edit screen
                                 Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => AdminPanelScreen(location: location),
                                ),
                              );
                            },
                          ),
                          const Icon(
                            Icons.arrow_forward_ios,
                            size: 16,
                            color: Colors.grey,
                          ),
                        ],
                      ),
                    ),
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
