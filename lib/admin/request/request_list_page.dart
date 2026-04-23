import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'request_detail_page.dart';

class RequestListPage extends StatefulWidget {
  final String type;

  const RequestListPage({super.key, required this.type});

  @override
  State<RequestListPage> createState() => _RequestListPageState();
}

class _RequestListPageState extends State<RequestListPage> {
  final supabase = Supabase.instance.client;

  List requests = [];
  bool isLoading = true;
  String statusFilter = "all";
  String searchText = "";
  final TextEditingController searchController = TextEditingController();

  // ── colours matching EmergencyListPage ──
  static const Color _bg = Color(0xFFF5EBE6);
  static const Color _brown = Color(0xFF8B5E4A);
  static const Color _darkText = Color(0xFF2B2B2B);

  @override
  void initState() {
    super.initState();
    fetchRequests();
  }

  String? get currentAdminEmail => supabase.auth.currentUser?.email;

  Future<void> fetchRequests() async {
    try {
      setState(() => isLoading = true);

      String adminIdentifier = "";
      if (currentAdminEmail != null) {
        final adminData = await supabase
            .from('admin_new')
            .select('full_name')
            .eq('email', currentAdminEmail!)
            .maybeSingle();
        adminIdentifier = adminData?['full_name'] ?? currentAdminEmail!;
      }

      var query = supabase.from('requests').select('''
        *, 
        admin_requests(*), 
        resident_requests(*), 
        visitor_requests(*),
        event_requests(*),
        facility_requests(*) 
      ''');

      String uiType = widget.type.toLowerCase().trim();
      if (uiType == 'users' || uiType == 'user') {
        query = query.inFilter('type', ['admin', 'resident']);
      } else if (uiType == 'event' || uiType == 'events' || uiType == 'booking') {
        query = query.eq('type', 'booking');
      } else if (uiType == 'facilities' || uiType == 'facility') {
        query = query.eq('type', 'facility');
      } else if (uiType == 'visitor' || uiType == 'visitors') {
        query = query.eq('type', 'visitor');
      } else {
        query = query.eq('type', uiType);
      }

      // 4. Status and Admin Filtering Logic
      if (statusFilter == "pending") {
        query = query.eq('status', 'pending');
      } else if (statusFilter == "approved") {
        query = query.eq('status', 'approved');
      } else if (statusFilter == "rejected") {
        query = query.eq('status', 'rejected');
      }

      final data = await query.order('created_at', ascending: false);

      // 5. Local Search Filtering
      List filteredData = data;
      if (searchText.isNotEmpty) {
        filteredData = data.where((r) {
          String name = extractNameForRequest(r).toLowerCase();
          return name.contains(searchText.toLowerCase());
        }).toList();
      }

      setState(() {
        requests = filteredData;
        isLoading = false;
      });
    } catch (e) {
      debugPrint("ERROR: $e");
      setState(() => isLoading = false);
    }
  }

  Map? extractSubData(dynamic raw) {
    if (raw == null) return null;
    if (raw is List && raw.isNotEmpty) return raw[0];
    if (raw is Map) return raw;
    return null;
  }

  String extractNameForRequest(Map data) {
    String type = data['type'] ?? '';
    if (type == 'admin') {
      return extractSubData(data['admin_requests'])?['full_name'] ?? "Admin Request";
    } else if (type == 'resident') {
      return extractSubData(data['resident_requests'])?['full_name'] ?? "Resident Request";
    } else if (type == 'visitor') {
      return extractSubData(data['visitor_requests'])?['visitor_name'] ?? "Visitor Request";
    } else if (type == 'booking') {
      final eventData = extractSubData(data['event_requests']);
      return eventData?['event_title'] ?? "Event: ${data['title'] ?? 'Untitled'}";
    } else if (type == 'facility') {
      final facilityData = extractSubData(data['facility_requests']);
      return facilityData?['facility_name'] ?? "Facility Booking";
    }
    return data['title'] ?? "Request Detail";
  }

  String extractSubtitleForRequest(Map data) {
    String type = data['type'] ?? '';
    if (type == 'admin') {
      return extractSubData(data['admin_requests'])?['email'] ?? "Admin";
    } else if (type == 'resident') {
      final sub = extractSubData(data['resident_requests']);
      final block = sub?['block'] ?? '-';
      final unit = sub?['unit_number'] ?? '-';
      return "Block $block - $unit";
    } else if (type == 'visitor') {
      final sub = extractSubData(data['visitor_requests']);
      return sub?['purpose'] ?? "Visitor";
    } else if (type == 'booking') {
      final sub = extractSubData(data['event_requests']);
      return sub?['location'] ?? "Event";
    } else if (type == 'facility') {
      final sub = extractSubData(data['facility_requests']);
      return sub?['booking_date'] ?? "Facility";
    }
    return "";
  }

  // Per-type colour accent — matches dashboard icon colours
  Color _typeColor(String type) {
    switch (type) {
      case 'admin':
      case 'resident':
        return const Color(0xFF758BFD);
      case 'booking':
        return const Color(0xFF4BC0B8);
      case 'facility':
        return const Color(0xFF9A4B3C);
      case 'visitor':
        return const Color(0xFFE96B9E);
      default:
        return _brown;
    }
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'admin':
        return Icons.admin_panel_settings_outlined;
      case 'resident':
        return Icons.person_outline;
      case 'booking':
        return Icons.event_note_outlined;
      case 'facility':
        return Icons.home_work_outlined;
      case 'visitor':
        return Icons.badge_outlined;
      default:
        return Icons.info_outline;
    }
  }

  String _typeLabel(String type) {
    if (type == 'booking') return 'EVENT';
    return type.toUpperCase();
  }

  // ── Status colour (mirrors emergency card logic) ──
  Color _statusColor(String status) {
    switch (status) {
      case 'approved':
        return const Color(0xFF6B8E6B);
      case 'rejected':
        return const Color(0xFFC67B75);
      default:
        return const Color(0xFFD4A847);
    }
  }

  // ── CARD (matches _buildEmergencyCard exactly) ──
  Widget buildRequestCard(Map data) {
    final String status = (data['status'] ?? "pending").toString().toLowerCase();
    final String displayName = extractNameForRequest(data);
    final String subtitle = extractSubtitleForRequest(data);
    final String type = data['type'] ?? '';
    final Color typeColor = _typeColor(type);
    final Color statusColor = _statusColor(status);

    // Try to get an image from the sub-request
    String? imageUrl;
    final sub = extractSubData(data['${type == 'booking' ? 'event' : type}_requests']);
    imageUrl = sub?['image_url'];

    // 状态颜色保留语义色，但稍微调柔和一点点
    Color statusColor = status == 'approved'
        ? Colors.green.shade600
        : (status == 'rejected' ? Colors.red.shade600 : Colors.orange.shade600);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.brown.shade100, width: 1), // 极浅的棕色边框
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => RequestDetailPage(data: data)),
          ).then((_) => fetchRequests());
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        displayName,
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.brown.shade900)
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                            displayLabel,
                            style: TextStyle(color: Colors.brown.shade600, fontSize: 11, fontWeight: FontWeight.bold) // 类型标签改为主题棕色
                        ),
                        if (isPrivate && type == 'booking') ...[
                          const SizedBox(width: 8),
                          Icon(Icons.lock, size: 10, color: Colors.brown.shade400),
                          Text(" PRIVATE", style: TextStyle(fontSize: 9, color: Colors.brown.shade400)),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      data['processed_by'] != null
                          ? "Handled by: ${data['processed_by']}"
                          : data['created_at'].toString().substring(0, 10),
                      style: TextStyle(color: Colors.brown.shade400, fontSize: 11),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(status.toUpperCase(),
                        style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 10)),
                  ),
                  const SizedBox(height: 12),
                  Icon(Icons.chevron_right, color: Colors.brown.shade300, size: 20), // 箭头变为浅棕色
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildSearchBar() {
    return TextField(
      controller: searchController,
      cursorColor: Colors.brown.shade600,
      style: TextStyle(color: Colors.brown.shade900),
      decoration: InputDecoration(
        hintText: "Search $statusFilter requests...",
        hintStyle: TextStyle(color: Colors.brown.shade300),
        prefixIcon: Icon(Icons.search, color: Colors.brown.shade400),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.brown.shade100, width: 1)
        ),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.brown.shade100, width: 1)
        ),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.brown.shade400, width: 1.5)
        ),
      ),
      onChanged: (value) {
        setState(() => searchText = value);
        fetchRequests(); // Re-fetch to apply search
      },
    );
  }

  // ── FILTER PILLS (matches filterButton in EmergencyListPage exactly) ──
  Widget _filterPill(String value, String label) {
    final isSelected = statusFilter == value;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() => statusFilter = value);
          fetchRequests();
        },
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? _brown : Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: isSelected
                ? [
              BoxShadow(
                  color: _brown.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 3))
            ]
                : [
              BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2))
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : _brown,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
            child: Text(
                label,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                    color: isSelected ? Colors.brown.shade800 : Colors.brown.shade300 // 颜色过渡
                )
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: Text(
          "${widget.type} Requests",
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: _bg,
        foregroundColor: _darkText,
        elevation: 0,
        centerTitle: true,
      ),
      body: Column(
        children: [
          const SizedBox(height: 10),

          // Filter pills
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _filterPill("all", "All"),
                const SizedBox(width: 10),
                _filterPill("pending", "Pending"),
                const SizedBox(width: 10),
                _filterPill("approved", "My Approved"),
                const SizedBox(width: 10),
                _filterPill("rejected", "My Rejected"),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Search bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: buildSearchBar(),
          ),

          const SizedBox(height: 14),

          // List
          Expanded(
            child: isLoading
                ? Center(
              child: CircularProgressIndicator(
                valueColor:
                const AlwaysStoppedAnimation<Color>(_brown),
              ),
            )
                : requests.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inbox_outlined,
                      size: 60, color: Colors.grey.shade400),
                  const SizedBox(height: 10),
                  Text(
                    "No $statusFilter requests found",
                    style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 16),
                  ),
                ],
              ),
            )
                : ListView.builder(
              padding: const EdgeInsets.only(
                  left: 16, right: 16, bottom: 40),
              itemCount: requests.length,
              itemBuilder: (context, index) =>
                  buildRequestCard(requests[index]),
            ),
          ),
        ],
      ),
    );
  }
}