import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'announcement_detail_page.dart';

class AnnouncementListPage extends StatefulWidget {
  const AnnouncementListPage({super.key});

  @override
  State<AnnouncementListPage> createState() => _AnnouncementListPageState();
}

class _AnnouncementListPageState extends State<AnnouncementListPage> {
  List<Map<String, dynamic>> announcements = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchAllAnnouncements();
  }

  // 获取所有公告
  Future<void> _fetchAllAnnouncements() async {
    try {
      final response = await Supabase.instance.client
          .from('announcements')
          .select()
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          announcements = List<Map<String, dynamic>>.from(response);
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching all announcements: $e');
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final DateTime date = DateTime.parse(dateStr).toLocal();
      final List<String> months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      return '${date.day} ${months[date.month - 1]}, ${date.year}';
    } catch (e) {
      return dateStr.substring(0, 10);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 🎨 你的核心主题色
    final Color primaryColor = const Color(0xFF9A4B3C);
    final Color bgColor = const Color(0xFFF5F1ED);

    return Scaffold(
      backgroundColor: bgColor,
      // 🔥 统一替换为棕色 AppBar
      appBar: AppBar(
        title: const Text(
            "All Announcements",
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18)
        ),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white, // 返回键和文字变白
        elevation: 0,
        centerTitle: true,
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator(color: primaryColor))
          : announcements.isEmpty
          ? const Center(child: Text("No announcements found.", style: TextStyle(color: Colors.black54)))
          : ListView.separated(
        padding: const EdgeInsets.all(20),
        itemCount: announcements.length,
        separatorBuilder: (context, index) => const SizedBox(height: 16),
        itemBuilder: (context, index) {
          final announcement = announcements[index];
          final title = announcement['title'] ?? 'Notice';
          final category = announcement['category'] ?? 'General';
          final isUrgent = announcement['is_urgent'] ?? false;
          final dateStr = _formatDate(announcement['created_at']);

          return Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            // 🔥 使用 Material 包裹，让点击出现水波纹动画
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AnnouncementDetailPage(announcement: announcement),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: isUrgent ? Colors.red.shade50 : const Color(0xFFEADFD6),
                        child: Icon(
                          isUrgent ? Icons.warning_amber_rounded : Icons.campaign_rounded,
                          size: 22,
                          color: isUrgent ? Colors.redAccent : primaryColor,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF2B2B2B)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEADFD6).withOpacity(0.5),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    category.toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: primaryColor,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  dateStr,
                                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded, color: Colors.black26),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}