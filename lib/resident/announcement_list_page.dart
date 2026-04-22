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
    return Scaffold(
      backgroundColor: const Color(0xFFF5F1ED),
      appBar: AppBar(
        title: const Text("All Announcements", style: TextStyle(color: Colors.black87, fontSize: 18)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF9A4B3C)))
          : announcements.isEmpty
          ? const Center(child: Text("No announcements found."))
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
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AnnouncementDetailPage(announcement: announcement),
                  ),
                );
              },
              leading: CircleAvatar(
                radius: 20,
                backgroundColor: isUrgent ? Colors.red.shade50 : const Color(0xFFEADFD6),
                child: Icon(
                  isUrgent ? Icons.warning_amber_rounded : Icons.campaign_rounded,
                  size: 20,
                  color: isUrgent ? Colors.redAccent : const Color(0xFF9A4B3C),
                ),
              ),
              title: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  children: [
                    Text(
                      category.toUpperCase(),
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.black54),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      dateStr,
                      style: const TextStyle(fontSize: 11, color: Color(0xFF9A4B3C)),
                    ),
                  ],
                ),
              ),
              trailing: const Icon(Icons.chevron_right, color: Colors.black26),
            ),
          );
        },
      ),
    );
  }
}