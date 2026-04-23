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

  @override
  void initState() {
    super.initState();
    fetchRequests();
  }

  String? get currentAdminEmail => supabase.auth.currentUser?.email;

  Future<void> fetchRequests() async {
    try {
      setState(() => isLoading = true);

      // 1. Get the current admin's full name for filtering
      String adminIdentifier = "";
      if (currentAdminEmail != null) {
        final adminData = await supabase
            .from('admin_new')
            .select('full_name')
            .eq('email', currentAdminEmail!)
            .maybeSingle();

        adminIdentifier = adminData?['full_name'] ?? currentAdminEmail!;
      }

      // 2. Build Query with all sub-tables
      var query = supabase.from('requests').select('''
        *, 
        admin_requests(*), 
        resident_requests(*), 
        visitor_requests(*),
        event_requests(*),
        facility_requests(*) 
      ''');

      // 3. Map UI Types to Database Types
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

  Widget buildRequestCard(Map data) {
    String status = (data['status'] ?? "pending").toString().toLowerCase();
    String displayName = extractNameForRequest(data);
    String type = data['type'] ?? '';

    // Label logic
    String displayLabel = type.toUpperCase();
    if (type == 'booking') displayLabel = "EVENT REQUEST";

    // Privacy Badge logic
    final eventData = extractSubData(data['event_requests']);
    bool isPrivate = eventData?['is_private'] ?? false;

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
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            decoration: BoxDecoration(
              border: Border(
                  bottom: BorderSide(
                      color: isSelected ? Colors.brown.shade700 : Colors.transparent, // 选中时底部边框变棕色
                      width: 2.5
                  )
              ),
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
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF8F5), // 统一的淡米棕色背景
      appBar: AppBar(
        title: Text("${widget.type} Requests", style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.brown.shade600, // 深棕色 AppBar
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            buildSearchBar(),
            const SizedBox(height: 12),
            buildStatusFilter(),
            const SizedBox(height: 12),
            Expanded(
              child: isLoading
                  ? Center(child: CircularProgressIndicator(color: Colors.brown.shade400)) // 棕色加载条
                  : requests.isEmpty
                  ? Center(
                  child: Text(
                      "No $statusFilter requests found",
                      style: TextStyle(color: Colors.brown.shade500, fontSize: 16)
                  )
              )
                  : ListView.builder(
                itemCount: requests.length,
                itemBuilder: (context, index) => buildRequestCard(requests[index]),
              ),
            )
          ],
        ),
      ),
    );
  }
}