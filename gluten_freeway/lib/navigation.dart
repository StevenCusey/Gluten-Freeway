import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:mongo_dart/mongo_dart.dart' as mongo;
import 'mongo_db_connection.dart';

class NavigationPage extends StatefulWidget {
  @override
  _NavigationPageState createState() => _NavigationPageState();
}

class _NavigationPageState extends State<NavigationPage> {
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  LatLng? _currentLocation;
  LatLng? _selectedDestination;
  bool _isLoading = true;
  final PolylinePoints polylinePoints = PolylinePoints();
  String googleApiKey = "AIzaSyDljvZ4gPqszp3lWvZ0im0c8qJMhKRqdL4"; 

  @override
  void initState() {
    super.initState();
    _getUserLocation();
  }

  /// Get the user's current location
  Future<void> _getUserLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) return;

    Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    setState(() {
      _currentLocation = LatLng(position.latitude, position.longitude);
    });

    _fetchRestaurantLocations();
  }

  /// Fetch restaurant locations and reviews from MongoDB
  Future<void> _fetchRestaurantLocations() async {
    try {
      var db = await mongo.Db.create(mongoDbConnectionString);
      await db.open();
      var restaurantCollection = db.collection("restaurants");
      var reviewCollection = db.collection("reviews");

      var restaurants = await restaurantCollection.find().toList();
      Set<Marker> markers = {};

      for (var restaurant in restaurants) {
        if (restaurant.containsKey("latitude") && restaurant.containsKey("longitude")) {
          double latitude = double.tryParse(restaurant["latitude"].toString()) ?? 0.0;
          double longitude = double.tryParse(restaurant["longitude"].toString()) ?? 0.0;
          String name = restaurant["restaurantname"];
          String restaurantId = restaurant["_id"].toHexString();

          // Fetch and calculate average rating
          var reviews = await reviewCollection.find({"restaurantId": restaurantId}).toList();
          double avgRating = reviews.isNotEmpty
              ? reviews.map((r) => r["reviewStars"] as num).reduce((a, b) => a + b) / reviews.length
              : 0.0;
          String ratingText = avgRating > 0 ? "⭐ ${avgRating.toStringAsFixed(1)}" : "No Rating";

          markers.add(
            Marker(
              markerId: MarkerId(name),
              position: LatLng(latitude, longitude),
              infoWindow: InfoWindow(
                title: "$name - $ratingText",
                snippet: "",
              ),
              onTap: () {
                _showGoHereButton(name, ratingText, LatLng(latitude, longitude));
              },
            ),
          );
        }
      }

      await db.close();
      setState(() {
        _markers = markers;
        _isLoading = false;
      });
    } catch (e) {
      print("Error fetching restaurant locations: $e");
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Displays the "Go Here" button overlay on the map
  void _showGoHereButton(String restaurantName, String ratingText, LatLng destination) {
    setState(() {
      _selectedDestination = destination;
    });

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Container(
            padding: EdgeInsets.all(16),
            height: 140,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "$restaurantName - $ratingText",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 10),
                OutlinedButton(
                  onPressed: () {
                    _startNavigation(destination);
                    Navigator.pop(context);
                  },
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 16, horizontal: 32),
                    side: BorderSide(color: Colors.green, width: 2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                    backgroundColor: Colors.white,
                  ),
                  child: Text(
                    "Go Here",
                    style: TextStyle(color: Colors.green, fontSize: 18),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Start navigation and draw route
  void _startNavigation(LatLng destination) async {
    if (_currentLocation == null) {
      print("Current location not available.");
      return;
    }

    _selectedDestination = destination;

    List<LatLng> routeCoords = await _getRouteCoordinates(_currentLocation!, destination);

    setState(() {
      _polylines.clear();
      _polylines.add(
        Polyline(
          polylineId: PolylineId("route"),
          color: Colors.blue,
          width: 5,
          points: routeCoords,
        ),
      );
    });

    _mapController?.animateCamera(CameraUpdate.newLatLngZoom(destination, 14));
  }

  /// Fetch route from Google Directions API
  Future<List<LatLng>> _getRouteCoordinates(LatLng start, LatLng end) async {
    List<LatLng> routeCoords = [];

    PolylineResult result = await polylinePoints.getRouteBetweenCoordinates(
      googleApiKey,
      PointLatLng(start.latitude, start.longitude),
      PointLatLng(end.latitude, end.longitude),
      travelMode: TravelMode.driving,
    );

    if (result.points.isNotEmpty) {
      for (var point in result.points) {
        routeCoords.add(LatLng(point.latitude, point.longitude));
      }
    } else {
      print("Error fetching route: ${result.errorMessage}");
    }

    return routeCoords;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.green,
        title: Text("Restaurant Navigation"),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : GoogleMap(
              initialCameraPosition: _currentLocation != null
                  ? CameraPosition(target: _currentLocation!, zoom: 12)
                  : CameraPosition(target: LatLng(46.8083, -100.7837), zoom: 12),
              markers: _markers,
              polylines: _polylines,
              myLocationEnabled: true,
              onMapCreated: (GoogleMapController controller) {
                _mapController = controller;
              },
            ),
    );
  }
}
