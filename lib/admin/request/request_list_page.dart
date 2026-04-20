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

  /// 获取请求列表并关联所有可能的子表
  Future<void> fetchRequests() async {
    try {
      setState(() => isLoading = true);

      var query = supabase.from('requests').select('''
        *, 
        admin_requests(*), 
        resident_requests(*), 
        visitor_requests(*), 
        facility_requests(*), 
        event_requests(*)
      ''');

      String uiType = widget.type.toLowerCase();
      if (uiType == 'users') {
        query = query.inFilter('type', ['admin', 'resident']);
      } else if (uiType == 'event') {
        query = query.eq('type', 'complaint');
      } else if (uiType == 'facilities') {
        query = query.eq('type', 'booking');
      } else {
        query = query.eq('type', uiType);
      }

      if (statusFilter != "all") {
        query = query.eq('status', statusFilter);
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
      return extractSubData(data['facility_requests'])?['facility_name'] ?? "Facility Booking";
    } else if (type == 'complaint') {
      return extractSubData(data['event_requests'])?['event_title'] ?? "Event/Complaint";
    }
    return "No Name";
  }

  /// ✅ 统一风格：带有浅棕色阴影的悬浮卡片
  Widget buildRequestCard(Map data) {
    String status = (data['status'] ?? "pending").toString().toLowerCase();
    String displayName = extractNameForRequest(data);
    String subtitle = data['title'] ?? data['type'] ?? "";

    // 🔥 调整状态颜色，让它们搭配棕色背景更好看
    Color statusColor;
    if (status == 'approved') {
      statusColor = const Color(0xFF6B8E6B); // 柔和的莫兰迪绿
    } else if (status == 'rejected') {
      statusColor = const Color(0xFFC67B75); // 之前退出的砖红色
    } else {
      statusColor = const Color(0xFFD49A6A); // 焦糖橙色
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        // 🔥 添加和 Profile 页面一样的浅棕色悬浮阴影
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8B5E4A).withOpacity(0.1),
            blurRadius: 15,
            spreadRadius: 0,
            offset: const Offset(0, 8),
          )
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
                builder: (_) => RequestDetailPage(data: data),
              ),
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
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Color(0xFF2B2B2B), // 🔥 统一深灰色字体
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        data['created_at'].toString().substring(0, 16).replaceAll('T', ' '),
                        style: TextStyle(color: Colors.grey.shade400, fontSize: 11),
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
                      child: Text(
                        status.toUpperCase(),
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // 🔥 右侧箭头换成主打深棕色
                    const Icon(Icons.chevron_right, color: Color(0xFF8B5E4A), size: 20),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 搜索栏设计
  Widget buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        // 🔥 搜索栏也加上淡淡的棕色阴影
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8B5E4A).withOpacity(0.05),
            blurRadius: 10,
            spreadRadius: 0,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: TextField(
        controller: searchController,
        decoration: InputDecoration(
          hintText: "Search requests...",
          hintStyle: TextStyle(color: Colors.grey.shade400),
          // 🔥 搜索图标换成深棕色
          prefixIcon: const Icon(Icons.search, color: Color(0xFF8B5E4A)),
          filled: true,
          fillColor: Colors.transparent,
          contentPadding: const EdgeInsets.symmetric(vertical: 15),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
        onChanged: (value) {
          searchText = value;
          fetchRequests();
        },
      ),
    );
  }

  /// 状态过滤器设计
  Widget buildStatusFilter() {
    final statuses = ["all", "pending", "approved", "rejected"];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: statuses.map((status) {
        final isSelected = statusFilter == status;
        return GestureDetector(
          onTap: () {
            setState(() => statusFilter = status);
            fetchRequests();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  // 🔥 选中时的下划线换成深棕色
                  color: isSelected ? const Color(0xFF8B5E4A) : Colors.transparent,
                  width: 2,
                ),
              ),
            ),
            child: Text(
              status.toUpperCase(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                // 🔥 选中时的文字换成深棕色
                color: isSelected ? const Color(0xFF8B5E4A) : Colors.grey.shade500,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 🔥 整页背景换成浅米棕色
      backgroundColor: const Color(0xFFF5EBE6),
      appBar: AppBar(
        title: Text(
            "${widget.type} Requests",
            style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2B2B2B))
        ),
        // 🔥 AppBar 背景也使用浅米棕色，融为一体
        backgroundColor: const Color(0xFFF5EBE6),
        foregroundColor: const Color(0xFF2B2B2B), // 返回键等图标颜色
        elevation: 0,
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            buildSearchBar(),
            const SizedBox(height: 15),
            buildStatusFilter(),
            const SizedBox(height: 15),
            Expanded(
              child: isLoading
              // 🔥 加载圈换成深棕色
                  ? const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8B5E4A))))
                  : requests.isEmpty
                  ? const Center(child: Text("No requests found", style: TextStyle(color: Colors.grey)))
                  : ListView.builder(
                itemCount: requests.length,
                itemBuilder: (context, index) {
                  return buildRequestCard(requests[index]);
                },
              ),
            )
          ],
        ),
      ),
    );
  }
}