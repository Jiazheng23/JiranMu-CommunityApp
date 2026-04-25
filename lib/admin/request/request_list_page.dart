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

  static const Color _bg       = Color(0xFFF5EBE6);
  static const Color _brown    = Color(0xFF8B5E4A);
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

      final String uiType = widget.type.toLowerCase().trim();

      // ── Build query — only join the sub-table relevant to this page ──────
      dynamic query;

      if (uiType == 'users' || uiType == 'user') {
        query = supabase
            .from('requests')
            .select('*, admin_requests(*), resident_requests(*)')
            .inFilter('type', ['admin', 'resident']);
      } else if (uiType == 'event' || uiType == 'events' || uiType == 'booking') {
        query = supabase
            .from('requests')
            .select('*, event_requests(*)')
            .eq('type', 'booking');
      } else if (uiType == 'facilities' || uiType == 'facility') {
        query = supabase
            .from('requests')
            .select('*, facility_bookings(*)')
            .eq('type', 'facility');
      } else if (uiType == 'visitor' || uiType == 'visitors') {
        query = supabase
            .from('requests')
            .select('*, visitor_requests(*)')
            .eq('type', 'visitor');
      } else {
        query = supabase
            .from('requests')
            .select('*')
            .eq('type', uiType);
      }

      // ── Status filter ─────────────────────────────────────────────────────
      if (statusFilter == 'pending') {
        query = query.eq('status', 'pending');
      } else if (statusFilter == 'approved') {
        query = query.eq('status', 'approved');
      } else if (statusFilter == 'rejected') {
        query = query.eq('status', 'rejected');
      }

      final data = await query.order('created_at', ascending: false);

      // ── Local search filter ───────────────────────────────────────────────
      List filteredData = data;
      if (searchText.isNotEmpty) {
        filteredData = (data as List).where((r) {
          final String name = extractNameForRequest(r).toLowerCase();
          return name.contains(searchText.toLowerCase());
        }).toList();
      }

      if (mounted) {
        setState(() {
          requests  = filteredData;
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('fetchRequests ERROR: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load requests: $e'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => isLoading = false);
      }
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  Map? extractSubData(dynamic raw) {
    if (raw == null) return null;
    if (raw is List && raw.isNotEmpty) return raw[0];
    if (raw is Map) return raw;
    return null;
  }

  String extractNameForRequest(Map data) {
    final String type = data['type'] ?? '';
    switch (type) {
      case 'admin':
        return extractSubData(data['admin_requests'])?['full_name'] ?? 'Admin Request';
      case 'resident':
        return extractSubData(data['resident_requests'])?['full_name'] ?? 'Resident Request';
      case 'visitor':
        return extractSubData(data['visitor_requests'])?['visitor_name'] ?? 'Visitor Request';
      case 'booking':
        final eventData = extractSubData(data['event_requests']);
        return eventData?['event_title'] ?? "Event: ${data['title'] ?? 'Untitled'}";
      case 'facility':
        final facilityData = extractSubData(data['facility_bookings']);
        return facilityData?['facility_name'] ?? 'Facility Booking';
      default:
        return data['title'] ?? 'Request Detail';
    }
  }

  String extractSubtitleForRequest(Map data) {
    final String type = data['type'] ?? '';
    switch (type) {
      case 'admin':
        return extractSubData(data['admin_requests'])?['email'] ?? 'Admin';
      case 'resident':
        final sub   = extractSubData(data['resident_requests']);
        final block = sub?['block'] ?? '-';
        final unit  = sub?['unit_number'] ?? '-';
        return 'Block $block - $unit';
      case 'visitor':
        return extractSubData(data['visitor_requests'])?['purpose'] ?? 'Visitor';
      case 'booking':
        return extractSubData(data['event_requests'])?['location'] ?? 'Event';
      case 'facility':
        return extractSubData(data['facility_bookings'])?['booking_date'] ?? 'Facility';
      default:
        return '';
    }
  }

  // ── Per-type accent colours ───────────────────────────────────────────────
  Color _typeColor(String type) {
    switch (type) {
      case 'admin':
      case 'resident':  return const Color(0xFF758BFD);
      case 'booking':   return const Color(0xFF4BC0B8);
      case 'facility':  return const Color(0xFF9A4B3C);
      case 'visitor':   return const Color(0xFFE96B9E);
      default:          return _brown;
    }
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'admin':    return Icons.admin_panel_settings_outlined;
      case 'resident': return Icons.person_outline;
      case 'booking':  return Icons.event_note_outlined;
      case 'facility': return Icons.home_work_outlined;
      case 'visitor':  return Icons.badge_outlined;
      default:         return Icons.info_outline;
    }
  }

  String _typeLabel(String type) {
    if (type == 'booking') return 'EVENT';
    return type.toUpperCase();
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'approved': return const Color(0xFF6B8E6B);
      case 'rejected': return const Color(0xFFC67B75);
      default:         return const Color(0xFFD4A847);
    }
  }

  // ── Request card ──────────────────────────────────────────────────────────
  Widget buildRequestCard(Map data) {
    final String status      = (data['status'] ?? 'pending').toString().toLowerCase();
    final String displayName = extractNameForRequest(data);
    final String subtitle    = extractSubtitleForRequest(data);
    final String type        = data['type'] ?? '';
    final Color  typeColor   = _typeColor(type);
    final Color  statusColor = _statusColor(status);

    // Image from sub-request (events only)
    final sub      = extractSubData(data['${type == 'booking' ? 'event' : type}_requests']);
    final imageUrl = sub?['image_url'] as String?;

    // Privacy badge — events only
    final eventData = extractSubData(data['event_requests']);
    final bool isPrivate =
        (eventData?['is_private'] ?? false) == true && type == 'booking';

    // Footer text
    final String footerText = data['processed_by'] != null
        ? 'Handled by: ${data['processed_by']}'
        : (data['created_at']?.toString().length ?? 0) >= 10
        ? data['created_at'].toString().substring(0, 10)
        : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _brown.withOpacity(0.06),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => RequestDetailPage(data: data)),
            ).then((_) => fetchRequests());
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Avatar
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: typeColor.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: CircleAvatar(
                    radius: 24,
                    backgroundColor: const Color(0xFFF0F0F5),
                    backgroundImage: (imageUrl != null && imageUrl.isNotEmpty)
                        ? NetworkImage(imageUrl)
                        : null,
                    child: (imageUrl == null || imageUrl.isEmpty)
                        ? Icon(_typeIcon(type), color: typeColor, size: 24)
                        : null,
                  ),
                ),
                const SizedBox(width: 16),

                // Text column
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: _darkText),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: TextStyle(
                            color: Colors.grey.shade600, fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            _typeLabel(type),
                            style: TextStyle(
                                color: typeColor,
                                fontSize: 11,
                                fontWeight: FontWeight.bold),
                          ),
                          if (isPrivate) ...[
                            const SizedBox(width: 6),
                            Icon(Icons.lock,
                                size: 10, color: Colors.grey.shade400),
                            Text(' PRIVATE',
                                style: TextStyle(
                                    fontSize: 9,
                                    color: Colors.grey.shade400)),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        footerText,
                        style: TextStyle(
                            color: Colors.grey.shade400, fontSize: 11),
                      ),
                    ],
                  ),
                ),

                // Status badge
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        status.toUpperCase(),
                        style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 10),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _typeLabel(type),
                      style: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 11,
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Search bar ────────────────────────────────────────────────────────────
  Widget buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: _brown.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, 3)),
        ],
      ),
      child: TextField(
        controller: searchController,
        decoration: InputDecoration(
          hintText: 'Search requests...',
          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
          prefixIcon: Icon(Icons.search, color: Colors.grey.shade400),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none),
          filled: true,
          fillColor: Colors.transparent,
          contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        onChanged: (value) {
          setState(() => searchText = value);
          fetchRequests();
        },
      ),
    );
  }

  // ── Filter pills ──────────────────────────────────────────────────────────
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
          ),
        ),
      ),
    );
  }

  // ── Scaffold ──────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: Text(
          '${widget.type} Requests',
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
                _filterPill('all', 'All'),
                const SizedBox(width: 10),
                _filterPill('pending', 'Pending'),
                const SizedBox(width: 10),
                _filterPill('approved', 'Approved'),
                const SizedBox(width: 10),
                _filterPill('rejected', 'Rejected'),
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
                valueColor: AlwaysStoppedAnimation<Color>(_brown),
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
                    'No $statusFilter requests found',
                    style: TextStyle(
                        color: Colors.grey.shade500, fontSize: 16),
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