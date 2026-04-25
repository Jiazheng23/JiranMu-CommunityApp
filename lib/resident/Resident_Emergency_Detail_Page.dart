import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class ResidentEmergencyDetailPage extends StatefulWidget {
  final Map<String, dynamic> emergency;

  const ResidentEmergencyDetailPage({super.key, required this.emergency});

  @override
  State<ResidentEmergencyDetailPage> createState() => _ResidentEmergencyDetailPageState();
}

class _ResidentEmergencyDetailPageState extends State<ResidentEmergencyDetailPage> {
  // 同样设定公寓固定坐标 (请确保替换为你的实际坐标)
  static const double CONDO_LAT = 3.1578;
  static const double CONDO_LNG = 101.7118;

  late double targetLat;
  late double targetLng;

  @override
  void initState() {
    super.initState();

    // 解析是家地址还是 GPS 地址，并设定目标坐标
    bool isHomeAddress = widget.emergency['is_home_address'] == true;

    if (isHomeAddress) {
      targetLat = CONDO_LAT;
      targetLng = CONDO_LNG;
    } else {
      targetLat = double.tryParse(widget.emergency['latitude']?.toString() ?? '$CONDO_LAT') ?? CONDO_LAT;
      targetLng = double.tryParse(widget.emergency['longitude']?.toString() ?? '$CONDO_LNG') ?? CONDO_LNG;
    }
  }

  // 格式化时间的辅助方法
  String _formatDate(String? isoString) {
    if (isoString == null || isoString.isEmpty) return 'N/A';
    try {
      final date = DateTime.parse(isoString).toLocal();
      // 输出格式类似: 2024-05-12 14:30
      return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";
    } catch (e) {
      return isoString.substring(0, 16).replaceFirst('T', ' ');
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.emergency['status'] ?? 'active';
    final isSolved = status == 'solved';
    final isHomeAddress = widget.emergency['is_home_address'] == true;

    final reportedAt = _formatDate(widget.emergency['created_at']);
    final solvedAt = _formatDate(widget.emergency['solved_at']);
    final solvedBy = widget.emergency['solved_by'] ?? 'Security Officer';
    final description = widget.emergency['description']?.toString() ?? "No additional details provided.";

    return Scaffold(
      backgroundColor: Colors.grey[50], // 给背景一点很浅的灰色，让卡片凸显出来
      appBar: AppBar(
        title: const Text("Report Details", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: isSolved ? Colors.green[600] : const Color(0xFFFF5A5A),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // ── 1. 顶部地图区域 ──
            SizedBox(
              height: 250,
              child: GoogleMap(
                initialCameraPosition: CameraPosition(target: LatLng(targetLat, targetLng), zoom: 16),
                markers: {
                  Marker(
                    markerId: const MarkerId("my_emergency"),
                    position: LatLng(targetLat, targetLng),
                    infoWindow: InfoWindow(title: isHomeAddress ? "Home Unit Alert" : "GPS Alert"),
                  )
                },
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
              ),
            ),

            // ── 2. 详情内容区 (往上偏移一点制造层次感) ──
            Transform.translate(
              offset: const Offset(0, -20),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [

                    // 👉 卡片 1：案件基本信息
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                  "Type: ${widget.emergency['type'] ?? 'Emergency'}",
                                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: isSolved ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                    isSolved ? 'SOLVED' : 'PROCESSING',
                                    style: TextStyle(color: isSolved ? Colors.green : Colors.orange, fontWeight: FontWeight.bold, fontSize: 12)
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 30),

                          _buildInfoRow(Icons.access_time_rounded, "Reported At", reportedAt),
                          const SizedBox(height: 12),
                          _buildInfoRow(Icons.location_on_rounded, "Location Mode", isHomeAddress ? "My Home Address" : "GPS Location"),
                          const SizedBox(height: 12),
                          _buildInfoRow(Icons.notes_rounded, "Description", description),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 👉 卡片 2：居民自己上传的证据照片
                    if (widget.emergency['report_evidence_url'] != null) ...[
                      const Padding(
                        padding: EdgeInsets.only(left: 8, bottom: 10),
                        child: Text("My Evidence Photo", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black54)),
                      ),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.network(
                          widget.emergency['report_evidence_url'],
                          height: 300, // 🔥 照片调大
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            height: 200, color: Colors.grey[200], child: const Center(child: Text("Image failed to load")),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],

                    // 👉 卡片 3：处理结果 (如果已解决)
                    if (isSolved && widget.emergency['admin_resolution_url'] != null) ...[
                      const Padding(
                        padding: EdgeInsets.only(left: 8, bottom: 10),
                        child: Text("Resolution Report", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green)),
                      ),
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.green[50], // 浅绿色背景强调已解决
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.green[200]!),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildInfoRow(Icons.verified_user_rounded, "Solved By", solvedBy, iconColor: Colors.green),
                            const SizedBox(height: 12),
                            _buildInfoRow(Icons.check_circle_outline_rounded, "Solved At", solvedAt, iconColor: Colors.green),
                            const SizedBox(height: 20),

                            // 保安上传的处理照片
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                widget.emergency['admin_resolution_url'],
                                height: 300, // 🔥 照片调大
                                width: double.infinity,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => Container(
                                  height: 200, color: Colors.white, child: const Center(child: Text("Image failed to load")),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 40), // 底部留白
                    ],
                  ],
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  // 提取一个生成信息行的小组件，让代码更干净
  Widget _buildInfoRow(IconData icon, String title, String value, {Color iconColor = Colors.black45}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: iconColor),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 12, color: Colors.black54)),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(fontSize: 15, color: Colors.black87, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ],
    );
  }
}