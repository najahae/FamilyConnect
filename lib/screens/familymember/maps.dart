import 'package:familytree/screens/familymember/heatmap_webview.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';

class FamilyMapPage extends StatefulWidget {
  final String familyID;

  const FamilyMapPage({required this.familyID, Key? key}) : super(key: key);

  @override
  _FamilyMapPageState createState() => _FamilyMapPageState();
}

class _FamilyMapPageState extends State<FamilyMapPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  late GoogleMapController _mapController;
  final Set<Marker> _markers = {};
  final List<FamilyMemberLocation> _allMembers = [];

  final Map<String, List<FamilyMemberLocation>> _bubbleGroups = {};
  final LatLng _initialPosition = LatLng(3.1390, 101.6869); // KL center

  bool _isLoading = true;
  bool _bubbleView = true;

  @override
  void initState() {
    super.initState();
    _loadFamilyData();
  }

  Future<void> _loadFamilyData() async {
    final snapshot = await _firestore
        .collection('families')
        .doc(widget.familyID)
        .collection('family_members')
        .get();

    for (var doc in snapshot.docs) {
      final data = doc.data();
      final locationData = data['location'];
      if (locationData == null || locationData['latitude'] == null || locationData['longitude'] == null) {
        continue;
      }

      final member = FamilyMemberLocation(
        id: doc.id,
        fullName: data['fullName'] ?? '',
        gender: data['gender'] ?? 'unknown',
        address: data['address'] ?? '',
        lat: locationData['latitude'],
        lng: locationData['longitude'],
      );

      _allMembers.add(member);

      final key = '${member.lat.toStringAsFixed(2)},${member.lng.toStringAsFixed(2)}';
      _bubbleGroups.putIfAbsent(key, () => []).add(member);

      _markers.add(Marker(
        markerId: MarkerId(member.id),
        position: LatLng(member.lat, member.lng),
        infoWindow: InfoWindow(title: member.fullName),
      ));
    }

    setState(() => _isLoading = false);
  }

  void _toggleView() {
    setState(() {
      _bubbleView = !_bubbleView;
    });
  }

  void _zoomIn() {
    _mapController.animateCamera(CameraUpdate.zoomIn());
  }

  void _zoomOut() {
    _mapController.animateCamera(CameraUpdate.zoomOut());
  }


  void _showMemberList(List<FamilyMemberLocation> members) async {
    if (members.isEmpty) return;

    final member = members[0];
    String address = "Loading address...";

    try {
      final placemarks = await placemarkFromCoordinates(member.lat, member.lng);
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        address = [
          if (place.street != null) place.street,
          if (place.locality != null) place.locality,
          if (place.postalCode != null) place.postalCode,
          if (place.country != null) place.country,
        ].where((part) => part != null).join(', ');
      }
    } catch (e) {
      address = "Location: ${member.lat.toStringAsFixed(4)}, ${member.lng.toStringAsFixed(4)}";
      debugPrint("Geocoding failed: $e");
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 50,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Location section
            Text(
              address,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),

            // Members list
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.6,
              ),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: members.length,
                itemBuilder: (context, index) {
                  final member = members[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: _getGenderColor(member.gender),
                      child: Text(
                        member.initials,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    title: Text(member.fullName),
                    subtitle: Text(_formatGender(member.gender)),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

// Helper methods
  Color _getGenderColor(String gender) {
    switch (gender.toLowerCase()) {
      case 'male': return Colors.blue;
      case 'female': return Colors.pink;
      default: return Colors.grey;
    }
  }

  String _formatGender(String gender) {
    if (gender.isEmpty) return 'Unknown';
    return '${gender[0].toUpperCase()}${gender.substring(1).toLowerCase()}';
  }

  double _calculateBubbleRadius(int count) {
    const double baseRadius = 5000.0; // Minimum bubble size
    const double scaleFactor = 1500.0; // Increase size per person
    return baseRadius + (count * scaleFactor);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: ClipRRect(
          borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(25), bottomRight: Radius.circular(25)),
          child: AppBar(
            backgroundColor: Colors.green[200],
            centerTitle: true,
            automaticallyImplyLeading: false,
            title: const Text("Map", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : GoogleMap(
        initialCameraPosition: CameraPosition(
          target: _allMembers.isNotEmpty
              ? LatLng(_allMembers.first.lat, _allMembers.first.lng)
              : _initialPosition,
          zoom: 7,
        ),
        onMapCreated: (controller) => _mapController = controller,
        markers: _bubbleView ? {} : _markers,
        circles: _bubbleView
            ? _bubbleGroups.entries.map((entry) {
          final members = entry.value;
          final first = members.first;
          final count = members.length;

          return Circle(
            circleId: CircleId(entry.key),
            center: LatLng(first.lat, first.lng),
            radius: _calculateBubbleRadius(count), // Bigger bubble = more people
            fillColor: Colors.pink.withOpacity(0.4),
            strokeColor: Colors.transparent,
            consumeTapEvents: true,
            onTap: () => _showMemberList(members),
          );
        }).toSet()
            : {},
        myLocationButtonEnabled: true,
        zoomControlsEnabled: false,
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: 'toHeatmap',
            backgroundColor: Colors.redAccent,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => HeatMapWebView(familyID: widget.familyID),
                ),
              );
            },
            child: const Icon(Icons.thermostat, color: Colors.white),
            tooltip: 'Open Heatmap',
          ),
          const SizedBox(height: 10),
          FloatingActionButton(
            heroTag: 'toggleView',
            backgroundColor: Colors.white,
            onPressed: _toggleView,
            child: Icon(_bubbleView ? Icons.place : Icons.bubble_chart, color: Colors.black),
          ),
          const SizedBox(height: 10),
          FloatingActionButton(
            heroTag: 'zoomIn',
            mini: true,
            onPressed: _zoomIn,
            child: const Icon(Icons.zoom_in),
          ),
          const SizedBox(height: 10),
          FloatingActionButton(
            heroTag: 'zoomOut',
            mini: true,
            onPressed: _zoomOut,
            child: const Icon(Icons.zoom_out),
          ),
        ],
      ),
    );
  }
}

class FamilyMemberLocation {
  final String id;
  final String fullName;
  final String gender;
  final String address;
  final double lat;
  final double lng;

  FamilyMemberLocation({
    required this.id,
    required this.fullName,
    required this.gender,
    required this.address,
    required this.lat,
    required this.lng,
  });

  String get initials {
    final parts = fullName.trim().split(" ");
    if (parts.length == 1) return parts[0][0];
    return parts[0][0] + parts.last[0];
  }
}

extension StringExtensions on String {
  String capitalize() {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1).toLowerCase()}';
  }
}
