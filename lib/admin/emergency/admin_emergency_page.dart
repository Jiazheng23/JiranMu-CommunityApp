import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
// 🔥 确保路径正确（已修正为单斜杠）
import '../emergency/location.dart';

class AdminEmergencyPage extends StatefulWidget {
  final Map<String, dynamic> emergency;

  const AdminEmergencyPage({super.key, required this.emergency});

  @override
  State<AdminEmergencyPage> createState() => _AdminEmergencyPageState();
}

class _AdminEmergencyPageState extends State<AdminEmergencyPage> {
  final supabase = Supabase.instance.client;

  double targetLat = 0.0;
  double targetLng = 0.0;
  String currentStatus = 'active'; // 用于追踪当前状态

  Position? adminPosition;
  GoogleMapController? mapController;

  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};

  File? _evidencePhoto;

  @override
  void initState() {
    super.initState();

    targetLat = double.tryParse(widget.emergency['latitude']?.toString() ?? '0') ?? 0.0;
    targetLng = double.tryParse(widget.emergency['longitude']?.toString() ?? '0') ?? 0.0;
    currentStatus = widget.emergency['status'] ?? 'active';

    _markers.add(
      Marker(
        markerId: const MarkerId("emergency_location"),
        position: LatLng(targetLat, targetLng),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      ),
    );

    // 如果还没结案，才需要订阅实时位置并画路线
    if (currentStatus != 'solved') {
      subscribeRealtime();
      _loadAdminLocationAndDrawRoute();
    } else {
      // 已经结案的话，只要把镜头对准事发地就行
      Future.delayed(const Duration(milliseconds: 500), () {
        mapController?.animateCamera(CameraUpdate.newLatLngZoom(LatLng(targetLat, targetLng), 16));
      });
    }
  }

  // ==========================================
  // 📸 调用相机拍照
  // ==========================================
  Future<void> _takePhoto() async {
    final ImagePicker picker = ImagePicker();

    try {
      final XFile? image = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
      );

      if (image == null) return;

      setState(() {
        _evidencePhoto = File(image.path);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Photo captured as evidence!"), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      print("Error taking photo: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to take photo: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ==========================================
  // 🗺️ 获取管理员位置并绘制路线
  // ==========================================
  Future<void> _loadAdminLocationAndDrawRoute() async {
    try {
      final pos = await getCurrentLocation();
      if (!mounted) return;

      setState(() {
        adminPosition = pos;
        _markers.add(
          Marker(
            markerId: const MarkerId("admin_location"),
            position: LatLng(pos.latitude, pos.longitude),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
            infoWindow: const InfoWindow(title: "You are here"),
          ),
        );
      });

      final routePoints = await getRouteCoordinates(pos.latitude, pos.longitude, targetLat, targetLng);
      if (routePoints.isNotEmpty && mounted) {
        setState(() {
          _polylines.removeWhere((p) => p.polylineId.value == 'route_line');
          _polylines.add(Polyline(polylineId: const PolylineId("route_line"), points: routePoints, color: Colors.blueAccent, width: 5));
        });
      }

      if (mapController != null) {
        LatLngBounds bounds = _boundsFromLatLngList([LatLng(pos.latitude, pos.longitude), LatLng(targetLat, targetLng)]);
        mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 80));
      }
    } catch (e) {
      print("Failed to load admin location or route: $e");
    }
  }

  LatLngBounds _boundsFromLatLngList(List<LatLng> list) {
    if (list.isEmpty) return LatLngBounds(northeast: const LatLng(0, 0), southwest: const LatLng(0, 0));
    double? x0, x1, y0, y1;
    for (LatLng latLng in list) {
      if (x0 == null) {
        x0 = x1 = latLng.latitude;
        y0 = y1 = latLng.longitude;
      } else {
        if (latLng.latitude > x1!) x1 = latLng.latitude;
        if (latLng.latitude < x0) x0 = latLng.latitude;
        if (latLng.longitude > y1!) y1 = latLng.longitude;
        if (latLng.longitude < y0!) y0 = latLng.longitude;
      }
    }
    return LatLngBounds(northeast: LatLng(x1!, y1!), southwest: LatLng(x0!, y0!));
  }

  void subscribeRealtime() {
    supabase.channel('emergency-updates-${widget.emergency['emergency_id']}').onPostgresChanges(
        event: PostgresChangeEvent.update,
        schema: 'public',
        table: 'emergency',
        filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'emergency_id', value: widget.emergency['emergency_id'].toString()),
        callback: (payload) {
          final newData = payload.newRecord;
          if (!mounted) return;
          setState(() {
            targetLat = double.tryParse(newData['latitude']?.toString() ?? '0') ?? targetLat;
            targetLng = double.tryParse(newData['longitude']?.toString() ?? '0') ?? targetLng;
            currentStatus = newData['status'] ?? currentStatus;

            _markers.removeWhere((m) => m.markerId.value == 'emergency_location');
            _markers.add(Marker(markerId: const MarkerId("emergency_location"), position: LatLng(targetLat, targetLng), icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed)));
          });

          if (currentStatus != 'solved') {
            _loadAdminLocationAndDrawRoute();
          }
        }).subscribe();
  }

  @override
  void dispose() {
    supabase.removeAllChannels();
    super.dispose();
  }

  Future<void> _makePhoneCall(String? phoneNumber) async {
    if (phoneNumber == null || phoneNumber.isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No phone number available.")));
      return;
    }
    final Uri url = Uri.parse("tel:$phoneNumber");
    if (await canLaunchUrl(url)) { await launchUrl(url); }
  }

  Future<void> _launchNavigation() async {
    final Uri googleMapsUrl = Uri.parse("https://www.google.com/maps/dir/?api=1&destination=$targetLat,$targetLng");
    if (await canLaunchUrl(googleMapsUrl)) {
      await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Could not open maps app.")));
    }
  }

  // ==========================================
  // ✅ 提交结案报告
  // ==========================================
  Future<void> markSolved() async {
    if (_evidencePhoto == null) return;

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final String emergencyId = widget.emergency['emergency_id'].toString();
      final String fileName = 'evidence_$emergencyId\_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final String filePath = 'records/$fileName';

      // 获取当前管理员邮箱作为记录人，如果没有就写 Admin
      final String adminName = supabase.auth.currentUser?.email ?? 'Admin';

      // 1. 上传图片
      await supabase.storage.from('emergency_evidence').upload(
        filePath,
        _evidencePhoto!,
        fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
      );

      // 2. 获取图片公开链接
      final String publicUrl = supabase.storage.from('emergency_evidence').getPublicUrl(filePath);

      // 3. 更新数据库：包含所有必须字段
      await supabase.from('emergency').update({
        'status': 'solved',
        'evidence_url': publicUrl,
        'solved_at': DateTime.now().toIso8601String(),
        'solved_by': adminName,
      }).eq('emergency_id', emergencyId);

      if (mounted) {
        setState(() {
          currentStatus = 'solved';
        });
        Navigator.pop(context); // 关掉加载圈

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Case successfully solved!"), backgroundColor: Colors.green),
        );

        // 退出到上一页，并返回 true，通知列表页刷新数据
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) Navigator.pop(context); // 关掉加载圈
      print("Upload/Update Error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.emergency['user_data'] ?? {};
    final name = user['full_name'] ?? user['username'] ?? 'Unknown';
    final age = user['Age'] ?? user['age'];
    final block = user['block'] ?? '-';
    final unit = user['unit_number'] ?? 'Admin';
    final phone = user['phone_number'] ?? user['phone'];
    final blood = user['Blood'] ?? user['blood'] ?? 'N/A';
    final weight = user['Weight'] ?? user['weight'] ?? '-';
    final height = user['Height'] ?? user['height'] ?? '-';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Emergency Response", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: currentStatus == 'solved' ? Colors.green[700] : Colors.red[700],
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          // 如果未结案，显示导航按钮
          if (currentStatus != 'solved')
            IconButton(icon: const Icon(Icons.directions), tooltip: "Open Maps", onPressed: _launchNavigation)
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
              child: GoogleMap(
                  initialCameraPosition: CameraPosition(target: LatLng(targetLat, targetLng), zoom: 16),
                  onMapCreated: (controller) { mapController = controller; },
                  markers: _markers,
                  polylines: _polylines,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false
              )
          ),
          DraggableScrollableSheet(
            initialChildSize: 0.6, minChildSize: 0.15, maxChildSize: 0.85,
            builder: (context, scrollController) {
              return Container(
                decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(30)), boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10, spreadRadius: 2)]),
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                  children: [
                    Center(child: Container(width: 50, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(20)))),
                    const SizedBox(height: 20),
                    const Text("User Information", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 20),

                    Container(padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(15)), child: ListTile(contentPadding: EdgeInsets.zero, leading: CircleAvatar(radius: 30, backgroundColor: Colors.red[100], child: const Icon(Icons.person, size: 35, color: Colors.red)), title: Text(age != null ? "$name ($age)" : name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)), subtitle: Text("Location: $block - $unit"), trailing: IconButton.filled(onPressed: () => _makePhoneCall(phone?.toString()), icon: const Icon(Icons.phone), style: IconButton.styleFrom(backgroundColor: Colors.green)))),
                    const SizedBox(height: 20),

                    GridView.count(crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisSpacing: 15, mainAxisSpacing: 15, childAspectRatio: 1.5, children: [
                      _infoTile("Blood Type", blood.toString(), Icons.bloodtype, Colors.red),
                      _infoTile("Weight", weight == '-' ? "-" : "$weight kg", Icons.monitor_weight, Colors.blue),
                      _infoTile("Height", height == '-' ? "-" : "$height cm", Icons.height, Colors.purple),
                      _infoTile("Type", "${widget.emergency['type'] ?? 'Emergency'}", Icons.warning, Colors.orange),
                    ]),

                    const SizedBox(height: 30),

                    // ==========================================
                    // 🔍 UI 分支：结案报告 VS 处理面板
                    // ==========================================
                    if (currentStatus == 'solved')
                    // 👉 【模式一】如果已结案：显示结案报告
                      Container(
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(color: Colors.green[200]!),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.check_circle, color: Colors.green, size: 28),
                                SizedBox(width: 10),
                                Text("Solved Case Report", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.green)),
                              ],
                            ),
                            const Divider(height: 30),
                            Text("Solved By: ${widget.emergency['solved_by'] ?? 'System Admin'}", style: const TextStyle(fontSize: 16)),
                            const SizedBox(height: 8),
                            Text("Solved Time: ${widget.emergency['solved_at']?.toString().substring(0, 16).replaceFirst('T', ' ') ?? 'N/A'}", style: const TextStyle(fontSize: 16)),
                            const SizedBox(height: 20),
                            const Text("Evidence Photo:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            const SizedBox(height: 10),
                            // 显示数据库中的照片
                            if (widget.emergency['evidence_url'] != null)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.network(
                                  widget.emergency['evidence_url'],
                                  width: double.infinity,
                                  height: 250,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => Container(
                                    height: 200, color: Colors.grey[300], child: const Center(child: Text("Failed to load photo")),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      )
                    else
                    // 👉 【模式二】如果未结案：显示操作按钮与相片预览
                      Column(
                        children: [
                          if (_evidencePhoto != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 20.0),
                              child: Container(
                                height: 200, width: double.infinity,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.grey[300]!),
                                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, spreadRadius: 1)],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(15),
                                  child: Stack(
                                    children: [
                                      Image.file(_evidencePhoto!, width: double.infinity, height: double.infinity, fit: BoxFit.cover),
                                      Positioned(
                                        top: 5, right: 5,
                                        child: CircleAvatar(
                                          backgroundColor: Colors.black.withOpacity(0.5),
                                          child: IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () { setState(() { _evidencePhoto = null; }); }),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _evidencePhoto != null ? null : _takePhoto,
                                  icon: const Icon(Icons.camera_alt),
                                  label: Text(_evidencePhoto != null ? "Photo Taken" : "Take Photo"),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 15),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    foregroundColor: _evidencePhoto != null ? Colors.grey : const Color(0xFF673AB7),
                                    side: BorderSide(color: _evidencePhoto != null ? Colors.grey[300]! : const Color(0xFF673AB7)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 15),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _evidencePhoto == null ? () { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please take a photo first!"), backgroundColor: Colors.orange)); } : markSolved,
                                  icon: const Icon(Icons.check),
                                  label: const Text("Mark Solved"),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _evidencePhoto != null ? Colors.green : Colors.grey[400],
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 15),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                    const SizedBox(height: 20),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _infoTile(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white, border: Border.all(color: Colors.grey[200]!), borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.05), blurRadius: 5, spreadRadius: 1)],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24), const SizedBox(height: 8),
          Text(title, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}