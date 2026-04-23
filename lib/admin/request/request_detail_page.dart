import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../AdminVisitorPassScreen.dart';

class RequestDetailPage extends StatefulWidget {
  final Map data;

  const RequestDetailPage({super.key, required this.data});

  @override
  State<RequestDetailPage> createState() => _RequestDetailPageState();
}

class _RequestDetailPageState extends State<RequestDetailPage> {
  final supabase = Supabase.instance.client;
  final TextEditingController reasonController = TextEditingController();
  bool _isProcessing = false;

  // 🤎 统一定义棕色主题色
  static const Color _bg = Color(0xFFF5EBE6);
  static const Color _brown = Color(0xFF8B5E4A);
  static const Color _darkText = Color(0xFF2B2B2B);

  Future<String> _getAdminIdentifier() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return 'Unknown Admin';
      final adminData = await supabase
          .from('admin_new')
          .select('full_name')
          .eq('email', user.email!)
          .maybeSingle();
      return adminData?['full_name'] ?? user.email ?? 'Unknown Admin';
    } catch (e) {
      return supabase.auth.currentUser?.email ?? 'Unknown Admin';
    }
  }

  Map? extractSubData(dynamic raw) {
    if (raw == null) return null;
    if (raw is List && raw.isNotEmpty) return raw[0];
    if (raw is Map) return raw;
    return null;
  }

  // ── APPROVE ───────────────────────────────────────────────────────────────
  Future<void> approve() async {
    setState(() => _isProcessing = true);
    try {
      final String requestId = widget.data['request_id'].toString();
      final String userId    = widget.data['user_id'];
      final String type      = widget.data['type'];
      final String adminName = await _getAdminIdentifier();

      if (type == 'resident') {
        final subData = extractSubData(widget.data['resident_requests']);
        if (subData != null) {
          await supabase.from('resident').upsert({
            'id':            userId,
            'full_name':     subData['full_name'],
            'email':         subData['email'],
            'phone_number':  subData['phone_number'],
            'role':          subData['role'],
            'block':         subData['block'],
            'unit_number':   subData['unit_number'],
            'status':        'active',
            'resident_type': 'owner',
          });
        }
      } else if (type == 'booking') {
        final subData = extractSubData(widget.data['event_requests']);
        if (subData != null) {
          await supabase.from('events').insert({
            'id':              requestId,
            'title':           subData['event_title'] ?? widget.data['title'] ?? 'New Event',
            'description':     subData['description'] ?? widget.data['description'] ?? '',
            'location':        subData['location'] ?? 'Community Hall',
            'event_date':      subData['date'] ?? DateTime.now().toIso8601String(),
            'start_time':      subData['start_time'],
            'end_time':        subData['end_time'],
            'image_url':       subData['image_url'],
            'user_id':         userId,
            'created_by_name': subData['created_by_name'] ?? subData['full_name'] ?? 'Resident',
            'is_private':      subData['is_private'] ?? false,
            'created_at':      DateTime.now().toIso8601String(),
            'max_capacity':    subData['max_capacity'] ?? 20,
            'participants':    0,
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
        'status':       'approved',
        'respond_time': DateTime.now().toIso8601String(),
        'processed_by': adminName,
      }).eq('request_id', requestId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Request approved!'),
              backgroundColor: Colors.green),
        );
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
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  // ── REJECT ────────────────────────────────────────────────────────────────
  Future<void> reject() async {
    setState(() => _isProcessing = true);
    try {
      final String adminName = await _getAdminIdentifier();
      await supabase.from('requests').update({
        'status':        'rejected',
        'reject_reason': reasonController.text,
        'respond_time':  DateTime.now().toIso8601String(),
        'processed_by':  adminName,
      }).eq('request_id', widget.data['request_id']);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Request rejected.'),
              backgroundColor: Colors.orange),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  // ── Detail tile helpers ───────────────────────────────────────────────────
  Widget _buildDetailTile(String key, dynamic value, {String? endTime}) {
    final String k            = key.toLowerCase();
    final String displayValue = value?.toString() ?? '-';

    if (k.contains('image_url') && displayValue.startsWith('http')) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLabel(Icons.image_outlined, 'EVENT POSTER'),
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
                  color: Colors.grey[200],
                  child: const Icon(Icons.broken_image)),
            ),
          ),
        ],
      );
    }

    if (k.contains('start_time') && endTime != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLabel(Icons.access_time_rounded, 'EVENT SCHEDULE'),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 24),
            child: Row(
              children: [
                Flexible(
                  child: Text(displayValue,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: Icon(Icons.arrow_forward_rounded,
                      size: 14, color: Colors.grey),
                ),
                Flexible(
                  child: Text(endTime,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          ),
        ],
      );
    }

    if (k.contains('is_private')) {
      final bool isPrivate = displayValue == 'true';
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLabel(Icons.visibility_off_outlined, 'VISIBILITY'),
          const SizedBox(height: 6),
          Container(
            margin: const EdgeInsets.only(left: 24),
            padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isPrivate ? Colors.red.shade50 : Colors.green.shade50,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(isPrivate ? Icons.lock : Icons.public,
                    size: 12,
                    color: isPrivate ? Colors.red : Colors.green),
                const SizedBox(width: 4),
                Text(isPrivate ? 'PRIVATE' : 'PUBLIC',
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
        _buildLabel(
            _getIconForKey(k), key.replaceAll('_', ' ').toUpperCase()),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.only(left: 24),
          child: Text(displayValue,
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF263238))),
        ),
      ],
    );
  }

  Widget _buildLabel(IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFF6D4C41)),
        const SizedBox(width: 8),
        Text(label,
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: Colors.grey.shade500,
                letterSpacing: 0.8)),
      ],
    );
  }

  IconData _getIconForKey(String k) {
    if (k.contains('phone'))    return Icons.phone_android_rounded;
    if (k.contains('email'))    return Icons.mail_outline_rounded;
    if (k.contains('date'))     return Icons.calendar_today_rounded;
    if (k.contains('location')) return Icons.place_outlined;
    if (k.contains('name'))     return Icons.person_outline_rounded;
    if (k.contains('capacity')) return Icons.groups_rounded;
    return Icons.info_outline_rounded;
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final data   = widget.data;
    final type   = data['type'] ?? '';
    final status = data['status'] ?? 'pending';

    Map? details;
    if (type == 'admin')         details = extractSubData(data['admin_requests']);
    else if (type == 'resident') details = extractSubData(data['resident_requests']);
    else if (type == 'visitor')  details = extractSubData(data['visitor_requests']);
    else if (type == 'booking')  details = extractSubData(data['event_requests']);
    else if (type == 'facility') details = extractSubData(data['facility_requests']);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F9),
      appBar: AppBar(
        title: const Text('Review Request',
            style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
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
                Icon(Icons.assignment_outlined,
                    size: 18, color: Colors.blueGrey),
                SizedBox(width: 8),
                Text('SPECIFIC DETAILS',
                    style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                        color: Colors.blueGrey,
                        letterSpacing: 1.2)),
              ]),
              const Divider(height: 24),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200)),
                child: Wrap(
                  runSpacing: 25, // 只需要保留上下间距
                  children: details.entries
                      .where((e) =>
                  e.key != 'request_id' &&
                      e.key != 'id' &&
                      e.key != 'end_time')
                      .map((e) {
                    // 💡 重点：这里不再去判断全宽还是半宽，统统设为全宽 (double.infinity)！往下排！
                    return SizedBox(
                      width: double.infinity,
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
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.04), blurRadius: 20)
          ]),
      child: Column(children: [
        Chip(
          label: Text(type.toUpperCase(),
              style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF6D4C41))),
          backgroundColor: const Color(0xFF6D4C41).withOpacity(0.1),
        ),
        const SizedBox(height: 12),
        Text(data['title'] ?? 'No Title',
            style: const TextStyle(
                fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(data['description'] ?? 'No description',
            style: TextStyle(color: Colors.grey.shade600, height: 1.4),
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
            color: status == 'approved'
                ? Colors.green.shade50
                : Colors.red.shade50,
            borderRadius: BorderRadius.circular(16)),
        child: Column(children: [
          Icon(
              status == 'approved' ? Icons.check_circle : Icons.cancel,
              color: status == 'approved' ? Colors.green : Colors.red,
              size: 30),
          const SizedBox(height: 8),
          Text('REQUEST ${status.toUpperCase()}',
              style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color:
                  status == 'approved' ? Colors.green : Colors.red)),
          if (widget.data['processed_by'] != null)
            Text('By: ${widget.data['processed_by']}',
                style: const TextStyle(
                    fontSize: 12, fontStyle: FontStyle.italic)),
        ]),
      );
    }

    return Column(children: [
      TextField(
        controller: reasonController,
        maxLines: 2,
        decoration: InputDecoration(
          hintText: 'Reason for rejection (optional)',
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade200)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade200)),
        ),
      ),
      const SizedBox(height: 20),
      Row(children: [
        Expanded(
          child: ElevatedButton(
            onPressed: _isProcessing ? null : approve,
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: const EdgeInsets.all(16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12))),
            child: _isProcessing
                ? const SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2))
                : const Text('APPROVE',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ElevatedButton(
            onPressed: _isProcessing ? null : reject,
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                padding: const EdgeInsets.all(16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12))),
            child: _isProcessing
                ? const SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2))
                : const Text('REJECT',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold)),
          ),
        ),
      ]),
    ]);
  }
}