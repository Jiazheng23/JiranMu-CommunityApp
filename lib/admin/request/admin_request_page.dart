import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'request_detail_page.dart';
import 'request_list_page.dart';

class AdminRequestsPage extends StatefulWidget {
  const AdminRequestsPage({super.key});

  @override
  State<AdminRequestsPage> createState() => _AdminRequestsPageState();
}

class _AdminRequestsPageState extends State<AdminRequestsPage> {
  final supabase = Supabase.instance.client;

  Map<String, List> grouped = {
    'user': [],
    'event': [],
    'facility': [],
    'visitor': [],
  };

  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchRequests();
  }

  /// 获取请求数据
  Future<void> fetchRequests() async {
    try {
      setState(() => isLoading = true);

      // 这里建议增加 .select('*, resident_requests(*), admin_requests(*), visitor_requests(*), facility_requests(*), event_requests(*)')
      // 否则详情页可能拿不到子表数据
      final data = await supabase
          .from('requests')
          .select('''
            *,
            resident_requests(*),
            admin_requests(*),
            visitor_requests(*),
            facility_requests(*),
            event_requests(*)
          ''')
          .order('created_at', ascending: false)
          .limit(20);

      Map<String, List> temp = {
        'user': [],
        'event': [],
        'facility': [],
        'visitor': [],
      };

      for (var r in data) {
        final type = r['type'];
        if (type == 'visitor') {
          temp['visitor']!.add(r);
        } else if (type == 'booking') {
          temp['facility']!.add(r);
        } else if (type == 'complaint') {
          temp['event']!.add(r);
        } else if (type == 'admin' || type == 'resident') {
          temp['user']!.add(r);
        }
      }

      setState(() {
        grouped = temp;
        isLoading = false;
      });
    } catch (e) {
      debugPrint("Fetch error: $e");
      setState(() => isLoading = false);
    }
  }

  void navigateTo(String type) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => RequestListPage(type: type)),
    );
  }

  /// 修改后的 Request Card：点击整个 Box 触发跳转
  Widget buildRequestCard(Map data) {
    String status = (data['status'] ?? "pending").toString().toLowerCase();

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
        side: BorderSide(color: Colors.grey.shade200), // 微边框
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
          ).then((_) => fetchRequests()); // 返回时刷新
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // 左侧内容
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data['title'] ?? "No Title",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      data['description'] ?? "",
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
              // 右侧状态
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
                  const SizedBox(height: 10),
                  const Icon(Icons.chevron_right, color: Colors.grey),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- 其余 UI 组件保持逻辑一致 ---

  Widget buildTopButton(String title, IconData icon, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          margin: const EdgeInsets.symmetric(horizontal: 5),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
          ),
          child: Column(
            children: [
              Icon(icon, size: 28, color: Colors.blue),
              const SizedBox(height: 6),
              FittedBox(child: Text(title, style: const TextStyle(fontSize: 12))),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildSection(String title, String key) {
    final list = grouped[key]!;
    if (list.isEmpty) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 15),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("$title Requests", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            TextButton(onPressed: () => navigateTo(title), child: const Text("View All")),
          ],
        ),
        ...list.take(2).map((r) => buildRequestCard(r)).toList(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: const Text("Admin Dashboard"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: fetchRequests,
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                buildTopButton("Users", Icons.person, () => navigateTo("Users")),
                buildTopButton("Event", Icons.event, () => navigateTo("Event")),
                buildTopButton("Facilities", Icons.home, () => navigateTo("Facilities")),
                buildTopButton("Visitor", Icons.badge, () => navigateTo("Visitor")),
              ],
            ),
            const SizedBox(height: 20),
            const Text("Recent Requests", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            buildSection("Users", "user"),
            buildSection("Event", "event"),
            buildSection("Facilities", "facility"),
            buildSection("Visitor", "visitor"),
          ],
        ),
      ),
    );
  }
}