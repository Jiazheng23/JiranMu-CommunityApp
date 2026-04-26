import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';


Future<Position> getCurrentLocation() async {
  bool serviceEnabled;
  LocationPermission permission;

  serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) {
    return Future.error('Location services are disabled.');
  }

  permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) {
      return Future.error('Location permissions are denied');
    }
  }

  if (permission == LocationPermission.deniedForever) {
    return Future.error('Location permissions are permanently denied.');
  }

  return await Geolocator.getCurrentPosition(
    desiredAccuracy: LocationAccuracy.high,
  );
}

Future<void> createEmergency(String userId, String type, Position position) async {
  final supabase = Supabase.instance.client;


  await supabase.from('emergency').insert({
    'user_id': userId,
    'type': type,
    'latitude': position.latitude,
    'longitude': position.longitude,
    'status': 'active',
  });
}

Future<List<LatLng>> getRouteCoordinates(
    double startLat, double startLng, double endLat, double endLng) async {

  final url = 'https://router.project-osrm.org/route/v1/driving/$startLng,$startLat;$endLng,$endLat?geometries=geojson';

  List<LatLng> routePoints = [];
  try {
    print("Requesting route data...");
    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final routes = data['routes'];

      if (routes != null && routes.isNotEmpty) {
        final coordinates = routes[0]['geometry']['coordinates'];
        for (var coord in coordinates) {
          routePoints.add(LatLng(coord[1], coord[0]));
        }
        print("Successfully obtained route points：${routePoints.length} 个");
      }
    } else {
      print("OSRM Server error: ${response.statusCode}");
    }
  } catch (e) {
    print("Route network request exception: $e");
  }
  return routePoints;
}