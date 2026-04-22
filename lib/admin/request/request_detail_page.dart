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

  // ── Design Tokens ──
  static const Color bgColor = Color(0xFFF5F1ED);
  static const Color primaryColor = Color(0xFF9A4B3C);
  static const Color textDark = Color(0xFF2B2B2B);

  bool _isProcessing = false; // 防连点/加载状态

  // 辅助函数
  Map? extractSubData(dynamic raw) {
    if (raw == null) return null;
    if (raw is List && raw.isNotEmpty) return raw[0];
    if (raw is Map) return raw;
    return null;
  }

  // 格式化 Key (例如: "unit_number" -> "Unit Number")
  String _formatKey(String key) {
    return key.split('_').map((word) {
      if (word.isEmpty) return '';
      return word[0].toUpperCase() + word.substring(1);
    }).join(' ');
  }

  // 获取状态对应的颜色
  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return const Color(0xFF6B8E6B);
      case 'rejected':
        return const Color(0xFFE57373);
      case 'pending':
        return const Color(0xFFE6A822); // 暖黄色
      default:
        return Colors.grey;
    }
  }

  Future<void> approve() async {
    setState(() => _isProcessing = true);
    try {
      final String requestId = widget.data['request_id'];
      final String userId = widget.data['user_id'];
      final String type = widget.data['type'];

      // 1. 处理居民 (Resident)
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
        await supabase.from('requests').update({
          'status': 'approved',
          'respond_time': DateTime.now().toIso8601String(),
          'reject_reason': null,
        }).eq('request_id', requestId);
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
            'status': 'active',
          });
        }
        await supabase.from('requests').update({
          'status': 'approved',
          'respond_time': DateTime.now().toIso8601String(),
          'reject_reason': null,
        }).eq('request_id', requestId);
      }

      // 3. Facility approval
      else if (type == 'facility') {
        final subData = extractSubData(widget.data['facility_requests']);
        if (subData == null) {
          throw Exception('Facility request detail not found.');
        }

        final facilityId = subData['facility_id'];
        final bookingDate = subData['booking_date'];
        final startTime = subData['start_time'];
        final endTime = subData['end_time'];
        final slotLabel = subData['slot_label'];
        final participants = subData['participants'] ?? 1;
        final purpose = subData['purpose'];

        // overlap check
        final existingBookings = await supabase
            .from('facility_bookings')
            .select('id, start_time, end_time')
            .eq('facility_id', facilityId)
            .eq('booking_date', bookingDate)
            .eq('status', 'approved');

        bool hasOverlap = false;
        for (final row in existingBookings) {
          final existingStart = row['start_time']?.toString();
          final existingEnd = row['end_time']?.toString();
          if (existingStart == null || existingEnd == null) continue;

          final overlap = !(endTime.compareTo(existingStart) <= 0 || startTime.compareTo(existingEnd) >= 0);
          if (overlap) {
            hasOverlap = true;
            break;
          }
        }

        if (hasOverlap) {
          throw Exception('This facility time range is already booked.');
        }

        String? bookingId;
        try {
          final bookingResponse = await supabase.from('facility_bookings').insert({
            'request_id': requestId,
            'facility_id': facilityId,
            'resident_id': userId,
            'booking_date': bookingDate,
            'start_time': startTime,
            'end_time': endTime,
            'slot_label': slotLabel,
            'participants': participants,
            'purpose': purpose,
            'status': 'approved',
          }).select('id').single();

          bookingId = bookingResponse['id'] as String;

          await supabase.from('requests').update({
            'status': 'approved',
            'respond_time': DateTime.now().toIso8601String(),
            'reject_reason': null,
          }).eq('request_id', requestId);
        } catch (e) {
          if (bookingId != null) {
            await supabase.from('facility_bookings').delete().eq('id', bookingId);
          }
          rethrow;
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Approved and data migrated!"), backgroundColor: Color(0xFF6B8E6B)),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Approve Error: $e"), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  // ── 弹出拒绝理由对话框 ──
  Future<void> _showRejectDialog() async {
    reasonController.clear(); // 每次打开清空输入框

    await showDialog(
      context: context,
      barrierDismissible: false, // 点击外部不关闭，强制用户点击按钮
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text(
            "Reject Request",
            style: TextStyle(fontWeight: FontWeight.bold, color: textDark, fontSize: 18),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Please provide a reason for rejecting this request. This is required.",
                style: TextStyle(fontSize: 14, color: Colors.black54, height: 1.4),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: reasonController,
                maxLines: 3,
                autofocus: true, // 自动弹出键盘
                style: const TextStyle(fontSize: 14, color: textDark),
                decoration: InputDecoration(
                  hintText: "Enter reject reason...",
                  hintStyle: const TextStyle(color: Colors.black38, fontSize: 14),
                  filled: true,
                  fillColor: bgColor, // 使用页面的背景色，显得更有层次
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.all(16),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text("Cancel", style: TextStyle(color: Colors.black54, fontWeight: FontWeight.bold)),
            ),
            ElevatedButton(
              onPressed: () {
                final reason = reasonController.text.trim();
                if (reason.isEmpty) {
                  // 必填校验
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Reject reason is required!"), backgroundColor: Colors.redAccent),
                  );
                  return;
                }
                // 校验通过，关闭弹窗并执行拒绝操作
                Navigator.pop(dialogContext);
                _executeReject(reason);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE57373),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ),
              child: const Text("Confirm", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  // ── 实际执行拒绝数据库操作 ──
  Future<void> _executeReject(String reason) async {
    setState(() => _isProcessing = true);
    try {
      await supabase.from('requests').update({
        'status': 'rejected',
        'reject_reason': reason, // 直接存入刚才填写的理由
        'respond_time': DateTime.now().toIso8601String(),
      }).eq('request_id', widget.data['request_id']);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Request rejected successfully."), backgroundColor: Color(0xFFE57373)),
        );
        Navigator.pop(context); // 返回上一页
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Reject Error: $e"), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  // ── UI Components ──

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              _formatKey(label),
              style: const TextStyle(color: Colors.black54, fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value.isEmpty ? "-" : value,
              style: const TextStyle(color: textDark, fontWeight: FontWeight.w600, fontSize: 14, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final type = data['type'];
    final status = data['status'] ?? 'pending';

    // 提取子表数据供展示
    Map? details;
    if (type == 'admin') details = extractSubData(data['admin_requests']);
    if (type == 'resident') details = extractSubData(data['resident_requests']);
    if (type == 'visitor') details = extractSubData(data['visitor_requests']);
    if (type == 'facility' || type == 'booking') details = extractSubData(data['facility_requests']);
    if (type == 'complaint') details = extractSubData(data['event_requests']);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: textDark),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Request Detail",
          style: TextStyle(color: textDark, fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Section 1: Overview ──
              const Text("Overview", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textDark)),
              const SizedBox(height: 12),
              _buildCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            type?.toString().toUpperCase() ?? "UNKNOWN",
                            style: const TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 11),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: _getStatusColor(status).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            status.toString().toUpperCase(),
                            style: TextStyle(color: _getStatusColor(status), fontWeight: FontWeight.bold, fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      data['title'] ?? "No Title",
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textDark),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      data['description'] ?? "No description provided.",
                      style: const TextStyle(fontSize: 14, color: Colors.black54, height: 1.4),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // ── Section 2: Details ──
              if (details != null && details.isNotEmpty) ...[
                const Text("Submission Details", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textDark)),
                const SizedBox(height: 12),
                _buildCard(
                  child: Column(
                    children: details.entries
                        .where((e) => e.key != 'request_id' && e.key != 'id' && e.value != null) // 隐藏系统ID和空值
                        .map((e) => _buildInfoRow(e.key.toString(), e.value.toString()))
                        .toList(),
                  ),
                ),
                const SizedBox(height: 28),
              ],

              // ── Section 3: Action / Status ──
              if (status == 'pending') ...[
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isProcessing ? null : _showRejectDialog, // 点击打开弹窗
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: const BorderSide(color: Color(0xFFE57373), width: 1.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: _isProcessing
                            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFE57373)))
                            : const Text("Reject", style: TextStyle(color: Color(0xFFE57373), fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isProcessing ? null : approve,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6B8E6B), // 绿色
                          disabledBackgroundColor: const Color(0xFF6B8E6B).withOpacity(0.5),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 4,
                          shadowColor: const Color(0xFF6B8E6B).withOpacity(0.4),
                        ),
                        child: _isProcessing
                            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text("Approve", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 40),
              ] else if (status == 'rejected') ...[
                const Text("Rejection Info", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textDark)),
                const SizedBox(height: 12),
                _buildCard(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline_rounded, color: Color(0xFFE57373), size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Reason", style: TextStyle(color: Colors.black54, fontSize: 12, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 4),
                            Text(
                              data['reject_reason'] ?? "No specific reason provided.",
                              style: const TextStyle(color: textDark, fontSize: 14, height: 1.4),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
              ]
            ],
          ),
        ),
      ),
    );
  }
}