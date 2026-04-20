import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RequestDetailPage extends StatefulWidget {
  final Map data;

  const RequestDetailPage({super.key, required this.data});

  @override
  State<RequestDetailPage> createState() => _RequestDetailPageState();
}

class _RequestDetailPageState extends State<RequestDetailPage> {
  final supabase = Supabase.instance.client;
  final TextEditingController reasonController = TextEditingController();

  Map? extractSubData(dynamic raw) {
    if (raw == null) return null;
    if (raw is List && raw.isNotEmpty) return raw[0];
    if (raw is Map) return raw;
    return null;
  }

  Future<void> approve() async {
    try {
      final String requestId = widget.data['request_id'];
      final String userId = widget.data['user_id'];
      final String type = widget.data['type'];

      if (type == 'resident') {
        final subData = extractSubData(widget.data['resident_requests']);
        if (subData != null) {
          await supabase.from('resident').upsert({
            'id': userId,
            'full_name': subData['full_name'],
            'email': subData['email'],
            'phone_number': subData['phone_number'],
            'role': subData['role'],
            'block': subData['block'],
            'unit_number': subData['unit_number'],
            'status': 'active',
            'resident_type': 'owner',
          });
        }
      } else if (type == 'admin') {
        final subData = extractSubData(widget.data['admin_requests']);
        if (subData != null) {
          await supabase.from('admin_new').upsert({
            'id': userId,
            'full_name': subData['full_name'],
            'email': subData['email'],
            'role': 'admin',
            'status': 'active',
          });
        }
      }

      await supabase.from('requests').update({
        'status': 'approved',
        'respond_time': DateTime.now().toIso8601String(),
      }).eq('request_id', requestId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Approved and data migrated!"), backgroundColor: Color(0xFF6B8E6B)),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Approve Error: $e"), backgroundColor: const Color(0xFFC67B75)),
        );
      }
    }
  }

  Future<void> reject() async {
    try {
      await supabase.from('requests').update({
        'status': 'rejected',
        'reject_reason': reasonController.text,
        'respond_time': DateTime.now().toIso8601String(),
      }).eq('request_id', widget.data['request_id']);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Request Rejected"), backgroundColor: Color(0xFFC67B75)),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Reject Error: $e"), backgroundColor: const Color(0xFFC67B75)),
        );
      }
    }
  }

  /// 每一条信息的 UI 优化
  Widget buildInfo(String label, String value, {bool isStatus = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)
            ),
          ),
          Expanded(
            flex: 3,
            child: isStatus
                ? _buildStatusBadge(value)
                : Text(
                value,
                style: const TextStyle(fontWeight: FontWeight.w500, color: Color(0xFF2B2B2B), fontSize: 15)
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    status = status.toLowerCase();
    Color statusColor;
    if (status == 'approved') {
      statusColor = const Color(0xFF6B8E6B);
    } else if (status == 'rejected') {
      statusColor = const Color(0xFFC67B75);
    } else {
      statusColor = const Color(0xFFD49A6A);
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: statusColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          status.toUpperCase(),
          style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final type = data['type'];

    Map? details;
    if (type == 'admin') details = extractSubData(data['admin_requests']);
    if (type == 'resident') details = extractSubData(data['resident_requests']);
    if (type == 'visitor') details = extractSubData(data['visitor_requests']);
    if (type == 'booking') details = extractSubData(data['facility_requests']);
    if (type == 'complaint') details = extractSubData(data['event_requests']);

    return Scaffold(
      backgroundColor: const Color(0xFFF5EBE6), // 统一米棕色背景
      appBar: AppBar(
        title: const Text("Request Detail", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFFF5EBE6),
        foregroundColor: const Color(0xFF2B2B2B),
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🔥 将信息包裹在一个精致的白色卡片中
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF8B5E4A).withOpacity(0.08),
                    blurRadius: 15,
                    spreadRadius: 0,
                    offset: const Offset(0, 8),
                  )
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  buildInfo("Request Type", type?.toString().toUpperCase() ?? "-"),
                  buildInfo("Title", data['title'] ?? "-"),
                  buildInfo("Description", data['description'] ?? "-"),
                  buildInfo("Status", data['status'] ?? "-", isStatus: true),

                  if (details != null) ...[
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 10),
                      child: Divider(thickness: 1, color: Color(0xFFF5EBE6)),
                    ),
                    const Text(
                        "Details Information",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF8B5E4A))
                    ),
                    const SizedBox(height: 15),
                    ...details.entries
                        .where((e) => e.key != 'request_id')
                        .map((e) => buildInfo(
                        e.key.toString().replaceAll('_', ' ').toUpperCase(),
                        e.value?.toString() ?? "-"
                    )),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 30),

            if (data['status'] == 'pending') ...[
              TextField(
                controller: reasonController,
                decoration: InputDecoration(
                  labelText: "Reject Reason (Optional)",
                  labelStyle: const TextStyle(color: Colors.grey),
                  filled: true,
                  fillColor: Colors.white,
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF8B5E4A), width: 2),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: ElevatedButton(
                        onPressed: approve,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6B8E6B), // 莫兰迪绿
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text("Approve", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: ElevatedButton(
                        onPressed: reject,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFC67B75), // 砖红色
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text("Reject", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
                ],
              )
            ] else if (data['status'] == 'rejected') ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFC67B75).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFC67B75).withOpacity(0.5)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Color(0xFFC67B75)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "Reject Reason: ${data['reject_reason'] ?? 'No reason provided'}",
                        style: const TextStyle(color: Color(0xFFC67B75), fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }
}