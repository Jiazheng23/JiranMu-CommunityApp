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

      // 一次性关联所有子表，确保 extractName 逻辑有数据可用
      var query = supabase.from('requests').select('''
        *, 
        admin_requests(*), 
        resident_requests(*), 
        visitor_requests(*), 
        facility_requests(*), 
        event_requests(*)
      ''');

      // 根据首页传过来的 type 进行分类过滤
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

      // 状态过滤
      if (statusFilter != "all") {
        query = query.eq('status', statusFilter);
      }

      final data = await query.order('created_at', ascending: false);

      // 本地搜索过滤 (基于提取出的全名)
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

  /// 辅助函数：安全提取子表数据
  Map? extractSubData(dynamic raw) {
    if (raw == null) return null;
    if (raw is List && raw.isNotEmpty) return raw[0];
    if (raw is Map) return raw;
    return null;
  }

  /// 核心逻辑：根据请求类型抓取展示名称
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

  /// ✅ 重点：按照你要求的照片风格实现的 Card 设计
  Widget buildRequestCard(Map data) {
    String status = (data['status'] ?? "pending").toString().toLowerCase();
    String displayName = extractNameForRequest(data);
    String subtitle = data['title'] ?? data['type'] ?? "";

    Color statusColor;
    if (status == 'approved') {
      statusColor = Colors.green;
    } else if (status == 'rejected') {
      statusColor = Colors.red;
    } else {
      statusColor = Colors.orange;
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 0, // 扁平化设计
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200), // 浅灰色微边框
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          // 点击整个卡片跳转
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => RequestDetailPage(data: data),
            ),
          ).then((_) => fetchRequests()); // 返回时刷新列表
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // 左侧内容部分
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Color(0xFF1D1D1D),
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
              // 右侧状态和指示箭头
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
                  const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 搜索栏设计
  Widget buildSearchBar() {
    return TextField(
      controller: searchController,
      decoration: InputDecoration(
        hintText: "Search requests...",
        prefixIcon: const Icon(Icons.search),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 0),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      onChanged: (value) {
        searchText = value;
        fetchRequests();
      },
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
                  color: isSelected ? Colors.blue : Colors.transparent,
                  width: 2,
                ),
              ),
            ),
            child: Text(
              status.toUpperCase(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Colors.blue : Colors.grey,
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
      backgroundColor: const Color(0xFFF5F6FA), // 背景淡灰色，突出白色卡片
      appBar: AppBar(
        title: Text("${widget.type} Requests", style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
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
                  ? const Center(child: Text("No requests found"))
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