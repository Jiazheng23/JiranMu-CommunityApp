import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<Position> getCurrentLocation() async {
  bool serviceEnabled;
  LocationPermission permission;

  // 🔥 1. check service
  serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) {
    throw Exception('Location service disabled');
  }

  // 🔥 2. check permission
  permission = await Geolocator.checkPermission();

  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }

  if (permission == LocationPermission.deniedForever) {
    throw Exception('Permission permanently denied');
  }

  // 🔥 3. get location
  return await Geolocator.getCurrentPosition();
}

Future<void> updateLocation(String table, String userId) async {
  final position = await getCurrentLocation();

  await Supabase.instance.client
      .from(table)
      .update({
    'latitude': position.latitude,
    'longitude': position.longitude,
  })
      .eq('id', userId);
}

Future<void> createEmergency(String id) async {
  final supabase = Supabase.instance.client;

  try {
    final position = await getCurrentLocation();

    await supabase.from('emergency').insert({
      'id': id,
      'type': 'Emergency',
      'status': 'active',

      'latitude': position.latitude,
      'longitude': position.longitude,

      'created_at': DateTime.now().toIso8601String(),
    });

    print("Emergency created");
  } catch (e) {
    print("Error: $e");
  }


}