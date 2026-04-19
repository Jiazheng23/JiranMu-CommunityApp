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

  // 辅助函数 (放到上面方便其他方法调用)
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

      print("--- 开始审批流程 ---");
      print("Request ID: $requestId, User ID: $userId, Type: $type");

      // 1. 处理居民 (Resident)
      if (type == 'resident') {
        final subData = extractSubData(widget.data['resident_requests']);
        print("抓取到的居民子表数据: $subData");

        if (subData != null) {
          await supabase.from('resident').upsert({
            'id': userId,
            'full_name': subData['full_name'],
            'email': subData['email'],
            'phone_number': subData['phone_number'],
            'role': subData['role'],
            'block': subData['block'],
            'unit_number': subData['unit_number'],
            // 注意：你的 resident 表我们之前建议加了 status 和 resident_type，
            // 如果你的 resident 表里没有这两个字段，请把下面两行删掉，否则也会报错！
            'status': 'active',
            'resident_type': 'owner',
          });
          print("✅ 数据已成功搬运到 resident 表");
        } else {
          print("❌ 错误：未找到 resident_requests 子表数据");
        }
      }

      // 2. 处理管理员 (Admin)
      else if (type == 'admin') {
        final subData = extractSubData(widget.data['admin_requests']);

        if (subData != null) {
          await supabase.from('admin_new').upsert({
            'id': userId,
            'full_name': subData['full_name'],
            'email': subData['email'],
            'role': 'admin',
            'status': 'active', // 👈 既然数据库有了这个字段，这里就可以加上了
          });
        }
      }

      // 3. 最后更新主申请表状态
      await supabase.from('requests').update({
        'status': 'approved',
        'respond_time': DateTime.now().toIso8601String(),
      }).eq('request_id', requestId);

      print("✅ 主申请表状态已更新为 approved");

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Approved and data migrated!")),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      print("‼️ 审批发生崩溃: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Approve Error: $e")),
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

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Reject Error: $e")),
        );
      }
    }
  }

  Widget buildInfo(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("$label: ", style: const TextStyle(fontWeight: FontWeight.bold)),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final type = data['type'];

    // 提取子表数据供展示
    Map? details;
    if (type == 'admin') details = extractSubData(data['admin_requests']);
    if (type == 'resident') details = extractSubData(data['resident_requests']);
    if (type == 'visitor') details = extractSubData(data['visitor_requests']);
    if (type == 'booking') details = extractSubData(data['facility_requests']);
    if (type == 'complaint') details = extractSubData(data['event_requests']);

    return Scaffold(
      appBar: AppBar(title: const Text("Request Detail")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            buildInfo("Request Type", type?.toString().toUpperCase() ?? "-"),
            buildInfo("Title", data['title'] ?? "-"),
            buildInfo("Description", data['description'] ?? "-"),
            buildInfo("Status", data['status'] ?? "-"),

            const Divider(height: 30, thickness: 1),
            const Text("Details:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 10),

            // 动态显示详情内容
            if (details != null)
              ...details.entries
                  .where((e) => e.key != 'request_id') // 隐藏数据库ID
                  .map((e) => buildInfo(e.key.toString(), e.value?.toString() ?? "-")),

            const SizedBox(height: 20),

            if (data['status'] == 'pending') ...[
              TextField(
                controller: reasonController,
                decoration: const InputDecoration(
                  labelText: "Reject Reason (if any)",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: approve,
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                      child: const Text("Approve"),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: reject,
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                      child: const Text("Reject"),
                    ),
                  ),
                ],
              )
            ] else if (data['status'] == 'rejected') ...[
              buildInfo("Reject Reason", data['reject_reason'] ?? "No reason provided"),
            ]
          ],
        ),
      ),
    );
  }
}