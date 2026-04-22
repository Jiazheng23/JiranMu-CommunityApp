import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeago/timeago.dart' as timeago; // 建议在 pubspec.yaml 加上 timeago 包，用于显示 "2 hours ago"

class AdminNotificationsPage extends StatefulWidget {
  const AdminNotificationsPage({super.key});

  @override
  State<AdminNotificationsPage> createState() => _AdminNotificationsPageState();
}

class _AdminNotificationsPageState extends State<AdminNotificationsPage> {
  final supabase = Supabase.instance.client;
  List<dynamic> notifications = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  // 从 requests 表抓取最新的 pending 状态数据作为通知
  Future<void> _fetchNotifications() async {
    setState(() => isLoading = true);
    try {
      final response = await supabase
          .from('requests')
          .select('*')
          .eq('status', 'pending') // 主要拉取未处理的请求
          .order('created_at', ascending: false)
          .limit(20); // 只看最近20条

      setState(() {
        notifications = response;
      });
    } catch (e) {
      debugPrint("Error fetching notifications: $e");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // 根据类型获取图标
  IconData _getIconForType(String type) {
    switch (type.toLowerCase()) {
      case 'resident':
        return Icons.person_add_alt_1;
      case 'visitor':
        return Icons.directions_walk;
      case 'facility':
      case 'booking':
        return Icons.event_available;
      case 'complaint':
        return Icons.report_problem_outlined;
      default:
        return Icons.notifications_active;
    }
  }

  // 根据类型获取图标颜色
  Color _getColorForType(String type) {
    switch (type.toLowerCase()) {
      case 'resident':
        return Colors.blue;
      case 'visitor':
        return Colors.orange;
      case 'facility':
      case 'booking':
        return Colors.green;
      case 'complaint':
        return Colors.redAccent;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F1ED),
      appBar: AppBar(
        title: const Text("Notifications", style: TextStyle(color: Colors.black87)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchNotifications,
          )
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : notifications.isEmpty
          ? _buildEmptyState()
          : RefreshIndicator(
        onRefresh: _fetchNotifications,
        child: ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: notifications.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final item = notifications[index];
            final type = item['type'] ?? 'system';
            final title = item['title'] ?? 'New Request';
            final desc = item['description'] ?? '';
            final rawDate = item['created_at'];

            // 格式化时间 (例如: "2 hours ago")
            String timeText = '';
            if (rawDate != null) {
              try {
                final date = DateTime.parse(rawDate);
                timeText = timeago.format(date);
              } catch (e) {
                timeText = rawDate.toString().substring(0, 10);
              }
            }

            return Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _getColorForType(type).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _getIconForType(type),
                    color: _getColorForType(type),
                  ),
                ),
                title: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text(
                      desc,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.black54, fontSize: 13),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      timeText,
                      style: const TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                trailing: Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: Colors.redAccent, // 红点提示未读/待处理
                    shape: BoxShape.circle,
                  ),
                ),
                onTap: () {
                  // TODO: 可以在这里添加导航到详情页的逻辑
                  // Navigator.push(context, MaterialPageRoute(builder: (_) => RequestDetailPage(data: item)));
                },
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_off_outlined, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text(
            "No new notifications",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black54),
          ),
          const SizedBox(height: 8),
          const Text(
            "You're all caught up!",
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}