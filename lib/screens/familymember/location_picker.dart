import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_google_places_hoc081098/flutter_google_places_hoc081098.dart';
import 'package:flutter_google_places_hoc081098/google_maps_webservice_places.dart';


const kGoogleApiKey = "AIzaSyAZiWGZq-pvvLccrN22xLYH_kP0OZQGrrA"; // Replace with your real key

class LocationPicker extends StatefulWidget {
  @override
  _LocationPickerState createState() => _LocationPickerState();
}

class _LocationPickerState extends State<LocationPicker> {
  late GoogleMapController mapController;
  LatLng? _pickedLocation;
  LatLng? _currentLocation;
  Marker? _marker;
  final GoogleMapsPlaces places = GoogleMapsPlaces(apiKey: kGoogleApiKey);


  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      permission = await Geolocator.requestPermission();
    }

    Position position = await Geolocator.getCurrentPosition();
    setState(() {
      _currentLocation = LatLng(position.latitude, position.longitude);
      _pickedLocation = _currentLocation;
      _marker = Marker(markerId: MarkerId("current"), position: _currentLocation!);
    });
  }

  Future<void> _handleSearch() async {
    Prediction? prediction = await PlacesAutocomplete.show(
      context: context,
      apiKey: kGoogleApiKey,
      mode: Mode.overlay,
      language: "en",
      components: [Component(Component.country, "my")],
    );

    if (prediction != null && prediction.placeId != null) {
      PlacesDetailsResponse detail = await places.getDetailsByPlaceId(prediction.placeId!);

      final lat = detail.result.geometry?.location.lat;
      final lng = detail.result.geometry?.location.lng;

      if (lat != null && lng != null) {
        final searchedLatLng = LatLng(lat, lng);

        setState(() {
          _pickedLocation = searchedLatLng;
          _marker = Marker(markerId: MarkerId("picked"), position: searchedLatLng);
        });

        mapController.animateCamera(CameraUpdate.newLatLngZoom(searchedLatLng, 15));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Pick a Location")),
      body: _currentLocation == null
          ? const Center(child: CircularProgressIndicator())
          : Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(target: _currentLocation!, zoom: 15),
            onMapCreated: (controller) => mapController = controller,
            markers: _marker != null ? {_marker!} : {},
            onTap: (position) {
              setState(() {
                _pickedLocation = position;
                _marker = Marker(markerId: MarkerId("manual"), position: position);
              });
            },
          ),
          Positioned(
            top: 10,
            left: 10,
            right: 10,
            child: GestureDetector(
              onTap: _handleSearch,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                margin: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
                ),
                child: Row(
                  children: const [
                    Icon(Icons.search, color: Colors.grey),
                    SizedBox(width: 10),
                    Text("Search location...", style: TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.check),
        onPressed: () {
          if (_pickedLocation != null) {
            Navigator.pop(context, _pickedLocation);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Please select a location")),
            );
          }
        },
      ),
    );
  }
}
