import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../AdminVisitorPassScreen.dart'; // 确认你的路径是否正确

class RequestDetailPage extends StatefulWidget {
  final Map data;

  const RequestDetailPage({super.key, required this.data});

  @override
  State<RequestDetailPage> createState() => _RequestDetailPageState();
}

class _RequestDetailPageState extends State<RequestDetailPage> {
  final supabase = Supabase.instance.client;
  final TextEditingController reasonController = TextEditingController();

  // 🤎 统一定义棕色主题色
  static const Color _bg = Color(0xFFF5EBE6);
  static const Color _brown = Color(0xFF8B5E4A);
  static const Color _darkText = Color(0xFF2B2B2B);

  Future<String> _getAdminIdentifier() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return "Unknown Admin";
      final adminData = await supabase
          .from('admin_new')
          .select('full_name')
          .eq('email', user.email!)
          .maybeSingle();
      return adminData?['full_name'] ?? user.email ?? "Unknown Admin";
    } catch (e) {
      return supabase.auth.currentUser?.email ?? "Unknown Admin";
    }
  }

  Map? extractSubData(dynamic raw) {
    if (raw == null) return null;
    if (raw is List && raw.isNotEmpty) return raw[0];
    if (raw is Map) return raw;
    return null;
  }

  Future<void> approve() async {
    try {
      final String requestId = widget.data['request_id'].toString();
      final String userId = widget.data['user_id'];
      final String type = widget.data['type'];
      final String adminName = await _getAdminIdentifier();

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
      } else if (type == 'booking') {
        final subData = extractSubData(widget.data['event_requests']);
        if (subData != null) {
          await supabase.from('events').insert({
            'id': requestId,
            'title': subData['event_title'] ?? widget.data['title'] ?? "New Event",
            'description': subData['description'] ?? widget.data['description'] ?? "",
            'location': subData['location'] ?? "Community Hall",
            'event_date': subData['date'] ?? DateTime.now().toIso8601String(),
            'start_time': subData['start_time'],
            'end_time': subData['end_time'],
            'image_url': subData['image_url'],
            'user_id': userId,
            'created_by_name': subData['created_by_name'] ?? subData['full_name'] ?? "Resident",
            'is_private': subData['is_private'] ?? false,
            'created_at': DateTime.now().toIso8601String(),
            'max_capacity': subData['max_capacity'] ?? 20,
            'participants': 0,
          });
        }
      } else if (type == 'visitor') {
        final subData = extractSubData(widget.data['visitor_requests']);
        if (subData != null) {
          await supabase.from('visitor_passes').insert({
            'visitor_name': subData['visitor_name'],
            'visitor_ic':   subData['ic'],
            'valid_date':   subData['visit_date'],
            'status':       'approved',
          });
        }
      }

      await supabase.from('requests').update({
        'status': 'approved',
        'respond_time': DateTime.now().toIso8601String(),
        'processed_by': adminName,
      }).eq('request_id', requestId);

      if (mounted) {
        if (type == 'visitor') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => const AdminVisitorPassScreen(),
            ),
          );
        } else {
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Error approving: $e")));
      }
    }
  }

  Future<void> reject() async {
    try {
      final String adminName = await _getAdminIdentifier();
      await supabase.from('requests').update({
        'status': 'rejected',
        'reject_reason': reasonController.text,
        'respond_time': DateTime.now().toIso8601String(),
        'processed_by': adminName,
      }).eq('request_id', widget.data['request_id']);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Error rejecting: $e")));
      }
    }
  }

  Widget _buildDetailTile(String key, dynamic value, {String? endTime}) {
    String k = key.toLowerCase();
    String displayValue = value?.toString() ?? "-";

    if (k.contains('image_url') && displayValue.startsWith('http')) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLabel(Icons.image_outlined, "EVENT POSTER"),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              displayValue,
              height: 180,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                height: 100,
                color: Colors.brown.shade50,
                child: Icon(Icons.broken_image, color: Colors.brown.shade300),
              ),
            ),
          ),
        ],
      );
    }

    if (k.contains('start_time') && endTime != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLabel(Icons.access_time_rounded, "EVENT SCHEDULE"),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 24),
            child: Row(
              children: [
                Text(displayValue,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _darkText)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Icon(Icons.arrow_forward_rounded, size: 14, color: Colors.brown.shade300),
                ),
                Text(endTime,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _darkText)),
              ],
            ),
          ),
        ],
      );
    }

    if (k.contains('is_private')) {
      bool isPrivate = displayValue == 'true';
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLabel(Icons.visibility_off_outlined, "VISIBILITY"),
          const SizedBox(height: 6),
          Container(
            margin: const EdgeInsets.only(left: 24),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isPrivate ? Colors.red.shade50 : Colors.green.shade50,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(isPrivate ? Icons.lock : Icons.public,
                    size: 12, color: isPrivate ? Colors.red : Colors.green),
                const SizedBox(width: 4),
                Text(isPrivate ? "PRIVATE" : "PUBLIC",
                    style: TextStyle(
                        color: isPrivate ? Colors.red : Colors.green,
                        fontWeight: FontWeight.bold,
                        fontSize: 11)),
              ],
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(_getIconForKey(k), key.replaceAll('_', ' ').toUpperCase()),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.only(left: 24),
          child: Text(displayValue,
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: _darkText)),
        ),
      ],
    );
  }

  Widget _buildLabel(IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, size: 16, color: _brown),
        const SizedBox(width: 8),
        Text(label,
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: Colors.brown.shade400,
                letterSpacing: 0.8)),
      ],
    );
  }

  IconData _getIconForKey(String k) {
    if (k.contains('phone')) return Icons.phone_android_rounded;
    if (k.contains('email')) return Icons.mail_outline_rounded;
    if (k.contains('date')) return Icons.calendar_today_rounded;
    if (k.contains('location')) return Icons.place_outlined;
    if (k.contains('name')) return Icons.person_outline_rounded;
    if (k.contains('capacity')) return Icons.groups_rounded;
    return Icons.info_outline_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final type = data['type'];
    final status = data['status'] ?? 'pending';

    Map? details;
    if (type == 'admin')    details = extractSubData(data['admin_requests']);
    else if (type == 'resident') details = extractSubData(data['resident_requests']);
    else if (type == 'visitor')  details = extractSubData(data['visitor_requests']);
    else if (type == 'booking')  details = extractSubData(data['event_requests']);
    else if (type == 'facility') details = extractSubData(data['facility_requests']);

    return Scaffold(
      backgroundColor: _bg, // 🤎 背景改成棕色主题
      appBar: AppBar(
        title: Text("Review Request",
            style: TextStyle(fontWeight: FontWeight.bold, color: _darkText)),
        centerTitle: true,
        backgroundColor: _bg, // 🤎 AppBar 跟随背景色
        foregroundColor: _darkText,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildHeader(data, type),
            const SizedBox(height: 30),
            if (details != null) ...[
              const Row(children: [
                Icon(Icons.assignment_outlined, size: 18, color: _brown), // 🤎 图标变棕色
                SizedBox(width: 8),
                Text("SPECIFIC DETAILS",
                    style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                        color: _brown, // 🤎 标题变棕色
                        letterSpacing: 1.2)),
              ]),
              const Divider(height: 24),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.brown.shade100)), // 🤎 边框变浅棕色
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: details.entries
                      .where((e) =>
                  e.key != 'request_id' &&
                      e.key != 'id' &&
                      e.key != 'end_time')
                      .map((e) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: _buildDetailTile(
                        e.key,
                        e.value,
                        endTime: e.key == 'start_time'
                            ? details!['end_time']?.toString()
                            : null,
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
            const SizedBox(height: 30),
            _buildActionSection(status),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(Map data, String type) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.brown.shade50), // 🤎 加上极浅的棕色边框
          boxShadow: [
            BoxShadow(
                color: Colors.brown.withOpacity(0.05), blurRadius: 20) // 🤎 棕色微弱阴影
          ]),
      child: Column(children: [
        Chip(
          label: Text(type.toUpperCase(),
              style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.white)), // 🤎 标签文字变白
          backgroundColor: _brown, // 🤎 标签底色变主题棕
          side: BorderSide.none,
        ),
        const SizedBox(height: 12),
        Text(data['title'] ?? "No Title",
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: _darkText)),
        const SizedBox(height: 8),
        Text(data['description'] ?? "No description",
            style: TextStyle(color: Colors.brown.shade600, height: 1.4), // 🤎 描述文字变浅棕
            textAlign: TextAlign.center),
      ]),
    );
  }

  Widget _buildActionSection(String status) {
    if (status != 'pending') {
      return Container(
        padding: const EdgeInsets.all(20),
        width: double.infinity,
        decoration: BoxDecoration(
            color: status == 'approved' ? Colors.green.shade50 : Colors.red.shade50,
            borderRadius: BorderRadius.circular(16)),
        child: Column(children: [
          Icon(
              status == 'approved' ? Icons.check_circle : Icons.cancel,
              color: status == 'approved' ? Colors.green.shade600 : Colors.red.shade600,
              size: 30),
          const SizedBox(height: 8),
          Text("REQUEST ${status.toUpperCase()}",
              style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: status == 'approved' ? Colors.green.shade700 : Colors.red.shade700)),
          if (widget.data['processed_by'] != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text("By: ${widget.data['processed_by']}",
                  style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.grey.shade600)),
            ),
        ]),
      );
    }

    // 🤎 处于 pending 状态时，只显示两个按钮，不显示输入框了
    return Row(children: [
      Expanded(
        child: ElevatedButton(
          onPressed: approve,
          style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4CAF50), // 略微柔和的绿色
              padding: const EdgeInsets.all(16),
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12))),
          child: const Text("APPROVE",
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1)),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: ElevatedButton(
          onPressed: _showRejectDialog, // 🚨 这里改成了调用弹窗方法
          style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE53935), // 略微柔和的红色
              padding: const EdgeInsets.all(16),
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12))),
          child: const Text("REJECT",
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1)),
        ),
      ),
    ]);
  }

  // 🤎 拒绝时弹出的对话框
  void _showRejectDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text("Reject Request",
              style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2B2B2B))),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Please provide a reason for rejection.",
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
              const SizedBox(height: 16),
              TextField(
                controller: reasonController,
                maxLines: 3,
                cursorColor: const Color(0xFF8B5E4A),
                decoration: InputDecoration(
                  hintText: "Reason (optional)",
                  hintStyle: TextStyle(color: Colors.brown.shade300),
                  filled: true,
                  fillColor: const Color(0xFFF5EBE6), // 浅棕色背景
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none), // 去掉默认边框
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF8B5E4A), width: 1.5)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext), // 点击取消，关闭弹窗
              style: TextButton.styleFrom(foregroundColor: Colors.grey.shade500),
              child: const Text("CANCEL", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext); // 先关闭弹窗
                reject(); // 然后执行真正的拒绝并退出页面的操作
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE53935),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              child: const Text("CONFIRM",
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }
}