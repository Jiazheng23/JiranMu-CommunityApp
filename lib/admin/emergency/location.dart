import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ==========================================
// 1. 获取设备当前的 GPS 位置
// ==========================================
Future<Position> getCurrentLocation() async {
  bool serviceEnabled;
  LocationPermission permission;

  // 检查定位服务是否开启
  serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) {
    return Future.error('Location services are disabled.');
  }

  // 检查并请求权限
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

  // 获取高精度的当前位置
  return await Geolocator.getCurrentPosition(
    desiredAccuracy: LocationAccuracy.high,
  );
}

// ==========================================
// 2. 住户端使用：创建求救记录 (createEmergency)
// ==========================================
// 接收三个参数：用户ID, 求救类型, 当前坐标
Future<void> createEmergency(String userId, String type, Position position) async {
  final supabase = Supabase.instance.client;

  // 插入数据到 emergency 表
  await supabase.from('emergency').insert({
    'user_id': userId, // 🔥 最关键的一步：告诉数据库是谁发出的求救！
    'type': type,
    'latitude': position.latitude,
    'longitude': position.longitude,
    'status': 'active', // 默认状态是 active
    // 如果你有 created_at 字段并且数据库没有设置默认值，也可以加上：
    // 'created_at': DateTime.now().toIso8601String(),
  });
}

// 3. 管理员端使用：获取真实的马路路线
Future<List<LatLng>> getRouteCoordinates(
    double startLat, double startLng, double endLat, double endLng) async {

  // 🔥 重点：必须用 https，否则 Android 会拦截请求
  final url = 'https://router.project-osrm.org/route/v1/driving/$startLng,$startLat;$endLng,$endLat?geometries=geojson';

  List<LatLng> routePoints = [];
  try {
    print("正在请求路线数据..."); // 调试用的 print
    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final routes = data['routes'];

      if (routes != null && routes.isNotEmpty) {
        final coordinates = routes[0]['geometry']['coordinates'];
        for (var coord in coordinates) {
          routePoints.add(LatLng(coord[1], coord[0]));
        }
        print("成功获取到路线点：${routePoints.length} 个");
      }
    } else {
      print("OSRM 服务器报错: ${response.statusCode}");
    }
  } catch (e) {
    print("路线网络请求异常: $e");
  }
  return routePoints;
}