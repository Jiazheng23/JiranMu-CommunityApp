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

  Widget _buildImagePreview(String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty) {
      return Container(
        height: 180,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.image_not_supported_outlined, color: Colors.grey, size: 40),
            SizedBox(height: 8),
            Text("No Image Provided", style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.network(
        imageUrl,
        height: 200,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          height: 180,
          color: Colors.grey.shade200,
          child: const Center(child: Text("Error loading image")),
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value, {Color? iconColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (iconColor ?? Colors.blue).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 20, color: iconColor ?? Colors.blue.shade700),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 12, fontWeight: FontWeight.w500)),
                Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> approve() async {
    try {
      final String requestId = widget.data['request_id'];
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
      } else if (type == 'booking') {
        final subData = extractSubData(widget.data['event_requests']);
        if (subData != null) {
          await supabase.from('events').insert({
            'id': requestId,
            'title': subData['event_title'] ?? widget.data['title'] ?? "New Event",
            'description': subData['description'] ?? widget.data['description'] ?? "",
            'location': subData['location'] ?? "Community Hall",
            'event_date': subData['event_date'] ?? subData['date'] ?? DateTime.now().toIso8601String(),
            'start_time': subData['start_time'],
            'end_time': subData['end_time'],
            'image_url': subData['image_url'],
            'user_id': userId,
            'created_by_name': subData['full_name'] ?? "Resident",
            'is_private': subData['is_private'] ?? false,
            'max_capacity': subData['max_capacity'] ?? 0,
            'participants': 0,
            'processed_by': adminName,
            'created_at': DateTime.now().toIso8601String(),
          });
        }
      }

      await supabase.from('requests').update({
        'status': 'approved',
        'respond_time': DateTime.now().toIso8601String(),
        'processed_by': adminName,
      }).eq('request_id', requestId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Request Successfully Approved")));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  Future<void> reject() async {
    final String reason = reasonController.text.trim();
    if (reason.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please enter a rejection reason"), backgroundColor: Colors.red));
      return;
    }

    try {
      final String adminName = await _getAdminIdentifier();
      await supabase.from('requests').update({
        'status': 'rejected',
        'reject_reason': reason,
        'respond_time': DateTime.now().toIso8601String(),
        'processed_by': adminName,
      }).eq('request_id', widget.data['request_id']);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Request Rejected")));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final type = data['type'];
    final status = data['status'] ?? 'pending';

    Map? details;
    if (type == 'admin') details = extractSubData(data['admin_requests']);
    if (type == 'resident') details = extractSubData(data['resident_requests']);
    if (type == 'visitor') details = extractSubData(data['visitor_requests']);
    if (type == 'facility') details = extractSubData(data['facility_requests']);
    if (type == 'booking') details = extractSubData(data['event_requests']);

    // --- LOGIC TO CHECK SHAREABILITY AND PRIVACY ---
    final bool isShareable = type == 'booking' || type == 'facility';
    final bool isPrivate = details?['is_private'] == true;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text("Request Review", style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        centerTitle: true,
        actions: [
          // --- SHARE ICON HIDDEN IF PRIVATE ---
          if (status == 'approved' && isShareable && !isPrivate)
            IconButton(
              icon: const Icon(Icons.share_outlined, color: Colors.blue),
              tooltip: "Share Event",
              onPressed: () {
                // TODO: Implement share_plus logic later
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Preparing to share public event...")),
                );
              },
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(20)),
                    child: Text(type.toString().toUpperCase(), style: TextStyle(color: Colors.blue.shade800, fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                  const SizedBox(height: 12),
                  Text(data['title'] ?? "No Title Provided", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  Text(data['description'] ?? "No additional description", style: TextStyle(color: Colors.grey.shade600, fontSize: 14), textAlign: TextAlign.center),
                ],
              ),
            ),

            const SizedBox(height: 25),
            const Text("SUBMISSION DETAILS", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.blueGrey, letterSpacing: 1.1)),
            const SizedBox(height: 10),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
              child: details == null
                  ? const Text("No specific details available.")
                  : Column(
                children: [
                  if (type == 'booking') ...[
                    _buildImagePreview(details['image_url']),
                    const SizedBox(height: 15),

                    // --- ADDED PRIVACY STATUS ROW ---
                    _detailRow(
                      isPrivate ? Icons.lock : Icons.public,
                      "Visibility",
                      isPrivate ? "Private Event" : "Public Event",
                      iconColor: isPrivate ? Colors.redAccent : Colors.green,
                    ),

                    _detailRow(Icons.title, "Event Name", details['event_title'] ?? "-"),
                    _detailRow(Icons.location_on, "Location", details['location'] ?? "-"),
                    _detailRow(Icons.calendar_month, "Date", details['event_date'] ?? details['date'] ?? "-"),
                    _detailRow(Icons.access_time, "Duration", "${details['start_time']} - ${details['end_time']}"),
                    _detailRow(Icons.people, "Capacity", "${details['max_capacity']} Pax"),
                  ] else if (type == 'resident' || type == 'admin') ...[
                    _detailRow(Icons.person, "Full Name", details['full_name'] ?? "-"),
                    _detailRow(Icons.email, "Email Address", details['email'] ?? "-"),
                    _detailRow(Icons.phone, "Phone Number", details['phone_number'] ?? "-"),
                    if (type == 'resident') _detailRow(Icons.home, "Address", "Block ${details['block']}, Unit ${details['unit_number']}"),
                  ] else ...[
                    ...details.entries.where((e) => e.key != 'request_id').map((e) =>
                        _detailRow(Icons.info_outline, e.key.toString().replaceAll('_', ' ').toUpperCase(), e.value.toString())
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 25),

            if (status == 'pending') ...[
              const Text("ADMIN ACTION", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.blueGrey, letterSpacing: 1.1)),
              const SizedBox(height: 12),
              TextField(
                controller: reasonController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: "Enter rejection reason (only required for rejection)",
                  fillColor: Colors.white,
                  filled: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: approve,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text("APPROVE", style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: reject,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade50,
                        foregroundColor: Colors.red,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.red.shade100)),
                      ),
                      child: const Text("REJECT", style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ] else ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: status == 'approved' ? Colors.green.shade50 : Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: status == 'approved' ? Colors.green.shade100 : Colors.red.shade100),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(status == 'approved' ? Icons.check_circle : Icons.cancel, color: status == 'approved' ? Colors.green : Colors.red),
                        const SizedBox(width: 8),
                        Text("This request was ${status.toUpperCase()}", style: TextStyle(fontWeight: FontWeight.bold, color: status == 'approved' ? Colors.green.shade900 : Colors.red.shade900)),
                      ],
                    ),
                    if (status == 'rejected') ...[
                      const SizedBox(height: 10),
                      Text("Reason: ${data['reject_reason'] ?? 'No reason provided'}", style: const TextStyle(fontSize: 14)),
                    ],
                    const Divider(),
                    Text("Handled by: ${data['processed_by'] ?? 'Unknown Admin'}", style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}