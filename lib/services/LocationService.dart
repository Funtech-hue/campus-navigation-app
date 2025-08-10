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

  // add location to firebase
  Future<void> addLocation(Location location) {
    return _locationsCollection.doc(location.id).set(location.toMap());
  }

  //update location
Future<void> updateLocation(Location location) async {
    try{
      await _locationsCollection.doc(location.id).update(location.toMap());
    }catch(e){
      print('Error updating location: $e');
    }
  }

  //delete location
  Future<void> deleteLocation(Location location) async {
    try{
      await _locationsCollection.doc(location.id).delete();
    }catch(e){
      print('Error deleting location: $e');
    }
}

}