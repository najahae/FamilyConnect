import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class FamilyMapPage extends StatefulWidget {
  final String familyID;

  FamilyMapPage({required this.familyID});

  @override
  _FamilyMapPageState createState() => _FamilyMapPageState();
}

class _FamilyMapPageState extends State<FamilyMapPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  late GoogleMapController _mapController;
  final Set<Marker> _markers = {};
  bool _isLoading = true;

  LatLng _initialPosition = LatLng(3.1390, 101.6869); // Malaysia Center

  @override
  void initState() {
    super.initState();
    _loadFamilyData();
  }

  Future<void> _loadFamilyData() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final familyMembers = await _firestore
          .collection('families')
          .doc(widget.familyID)
          .collection('family_members')
          .get();

      for (var doc in familyMembers.docs) {
        final data = doc.data();
        final fullName = data['fullName'] ?? '';

        final locationData = data['location'];
        if (locationData == null) {
          print('Skipped ${doc.id} - No location data.');
          continue;
        }

        final double? lat = locationData['latitude'];
        final double? lng = locationData['longitude'];

        if (lat == null || lng == null) {
          print('Skipped ${doc.id} - Invalid lat/lng.');
          continue;
        }

        final LatLng location = LatLng(lat, lng);
        _markers.add(
          Marker(
            markerId: MarkerId(doc.id),
            position: location,
            infoWindow: InfoWindow(title: fullName),
          ),
        );
      }
    } catch (e) {
      print('Error loading family members: $e');
    }

    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(60),
        child: ClipRRect(
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(25),
            bottomRight: Radius.circular(25),
          ),
          child: AppBar(
            backgroundColor: Colors.green[200],
            centerTitle: true,
            automaticallyImplyLeading: false,
            title: Text(
              "Map",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _markers.isNotEmpty
                  ? _markers.first.position
                  : _initialPosition,
              zoom: 8,
            ),
            onMapCreated: (controller) {
              _mapController = controller;
            },
            markers: _markers,
            myLocationButtonEnabled: true,
            zoomControlsEnabled: false,
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(25),
                ),
                boxShadow: [
                  BoxShadow(color: Colors.black26, blurRadius: 5)
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(height: 20),
                  Container(
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    "Family Members Location",
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 20),
                  // Future enhancement: list of names under the map
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
