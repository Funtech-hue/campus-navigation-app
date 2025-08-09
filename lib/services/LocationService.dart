import 'package:cloud_firestore/cloud_firestore.dart';
import '../model/location.dart';

class LocationService {
  final CollectionReference _locationsCollection =
  FirebaseFirestore.instance.collection('locations');

  Stream<List<Location>> getLocations() {
    return _locationsCollection.snapshots().map((snapshot) => snapshot.docs
        .map((doc) => Location.fromMap(doc.data() as Map<String, dynamic>, doc.id))
        .toList());
  }

  Future<void> addLocation(Location location) {
    return _locationsCollection.doc(location.id).set(location.toMap());
  }
}