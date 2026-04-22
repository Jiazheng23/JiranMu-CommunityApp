import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../AdminVisitorPassScreen.dart';
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

      if (statusFilter == "pending") {
        query = query.eq('status', 'pending');
      } else if (statusFilter == "approved" || statusFilter == "rejected") {
        query = query.eq('status', statusFilter).eq('processed_by', adminIdentifier);
      } else {
        query = query.or('status.eq.pending,and(status.in.(approved,rejected),processed_by.eq."$adminIdentifier")');
      }

      final data = await query.order('created_at', ascending: false);

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

  Widget buildRequestCard(Map data) {
    String status = (data['status'] ?? "pending").toString().toLowerCase();
    String displayName = extractNameForRequest(data);
    String type = data['type'] ?? '';

    String displayLabel = type.toUpperCase();
    if (type == 'booking') displayLabel = "EVENT REQUEST";

    final eventData = extractSubData(data['event_requests']);
    bool isPrivate = eventData?['is_private'] ?? false;

    Color statusColor = status == 'approved'
        ? Colors.green
        : (status == 'rejected' ? Colors.red : Colors.orange);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          // ── VISITOR: go to AdminVisitorPassScreen ──
          // ── ALL OTHERS: go to RequestDetailPage ──
          if (type == 'visitor') {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const AdminVisitorPassScreen(),
              ),
            ).then((_) => fetchRequests());
          } else {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => RequestDetailPage(data: data)),
            ).then((_) => fetchRequests());
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(displayName,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(displayLabel,
                            style: TextStyle(
                                color: Colors.blue.shade700,
                                fontSize: 11,
                                fontWeight: FontWeight.bold)),
                        if (isPrivate && type == 'booking') ...[
                          const SizedBox(width: 8),
                          const Icon(Icons.lock, size: 10, color: Colors.grey),
                          const Text(" PRIVATE",
                              style: TextStyle(
                                  fontSize: 9, color: Colors.grey)),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      data['processed_by'] != null
                          ? "Handled by: ${data['processed_by']}"
                          : data['created_at'].toString().substring(0, 10),
                      style: TextStyle(
                          color: Colors.grey.shade500, fontSize: 11),
                    ),
                  ],
                ),
              ),
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
                    child: Text(status.toUpperCase(),
                        style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 10)),
                  ),
                  const SizedBox(height: 12),
                  const Icon(Icons.chevron_right,
                      color: Colors.grey, size: 20),
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
      decoration: InputDecoration(
        hintText: "Search $statusFilter requests...",
        prefixIcon: const Icon(Icons.search),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none),
      ),
      onChanged: (value) {
        setState(() => searchText = value);
        fetchRequests();
      },
    );
  }

  Widget buildStatusFilter() {
    final statuses = ["all", "pending", "approved", "rejected"];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: statuses.map((status) {
        final isSelected = statusFilter == status;
        String label = status.toUpperCase();
        if (status == "approved") label = "MY APPROVED";
        if (status == "rejected") label = "MY REJECTED";

        return GestureDetector(
          onTap: () {
            setState(() => statusFilter = status);
            fetchRequests();
          },
          child: Container(
            padding:
            const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            decoration: BoxDecoration(
              border: Border(
                  bottom: BorderSide(
                      color: isSelected ? Colors.blue : Colors.transparent,
                      width: 2)),
            ),
            child: Text(label,
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                    color: isSelected ? Colors.blue : Colors.grey)),
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: Text("${widget.type} Requests",
            style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            buildSearchBar(),
            const SizedBox(height: 10),
            buildStatusFilter(),
            const SizedBox(height: 10),
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : requests.isEmpty
                  ? Center(
                  child:
                  Text("No $statusFilter requests found"))
                  : ListView.builder(
                itemCount: requests.length,
                itemBuilder: (context, index) =>
                    buildRequestCard(requests[index]),
              ),
            )
          ],
        ),
      ),
    );
  }
}