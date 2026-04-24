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
    _fetchAnnouncementsAndEvents();
  }

  // Fetch both announcements and user's joined events
  Future<void> _fetchAnnouncementsAndEvents() async {
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;

      List<Map<String, dynamic>> combinedList = [];

      // 1. Fetch Official Announcements (General notices for everyone)
      final announcementsResponse = await supabase.from('announcements').select();
      combinedList.addAll(List<Map<String, dynamic>>.from(announcementsResponse));

      if (user != null) {
        // 2. Fetch JOINED events from 'event_participants'
        final joinedResponse = await supabase
            .from('event_participants')
            .select('joined_at, events(*)')
            .eq('user_id', user.id);

        for (var row in joinedResponse) {
          final dynamic eventData = row['events'];
          final Map<String, dynamic>? event = eventData is List
              ? (eventData.isNotEmpty ? eventData[0] : null)
              : eventData;

          if (event != null) {
            combinedList.add({
              'id': event['id'],
              'title': 'Joined: ${event['title']}',
              'category': 'Joined',
              'created_at': row['joined_at'],
              'is_event': true,
              'content': 'You are registered for this event. See you at ${event['location']}!',
            });
          }
        }

        // 3. Fetch APPROVED & REJECTED status from 'requests'
        final requestsResponse = await supabase
            .from('requests')
            .select()
            .eq('user_id', user.id)
            .eq('type', 'booking')
            .inFilter('status', ['approved', 'rejected']); // Only Approved or Rejected

        for (var req in requestsResponse) {
          bool isApproved = req['status'] == 'approved';

          combinedList.add({
            'id': req['request_id'],
            'title': isApproved
                ? 'Proposal Approved: ${req['title']}'
                : 'Proposal Rejected: ${req['title']}',
            'category': isApproved ? 'Approved' : 'Rejected',
            'is_urgent': !isApproved,
            'created_at': req['respond_time'] ?? req['created_at'],
            'is_status_update': true,
            'content': isApproved
                ? 'Your booking for "${req['title']}" was approved and added to the community calendar.'
                : 'Your booking for "${req['title']}" was rejected.\nReason: ${req['reject_reason'] ?? "No reason provided."}',
          });
        }
      }

      // 4. Sort by newest (based on respond_time or created_at)
      combinedList.sort((a, b) {
        final dateA = DateTime.tryParse(a['created_at']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
        final dateB = DateTime.tryParse(b['created_at']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
        return dateB.compareTo(dateA);
      });

      if (mounted) {
        setState(() {
          announcements = combinedList;
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Notice Board Error: $e');
      if (mounted) setState(() => isLoading = false);
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
      return dateStr.length >= 10 ? dateStr.substring(0, 10) : dateStr;
    }
  }

  @override
  @override
  Widget build(BuildContext context) {
    // 🤎 Core Theme Colors
    const Color primaryColor = Color(0xFF9A4B3C);
    const Color bgColor = Color(0xFFF5F1ED);
    const Color eventAccentColor = Color(0xFF4BC0B8); // Accent color for events

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text(
            "Notice Board",
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18)
        ),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: primaryColor))
          : announcements.isEmpty
          ? const Center(child: Text("No updates found.", style: TextStyle(color: Colors.black54)))
          : ListView.separated(
        padding: const EdgeInsets.all(20),
        itemCount: announcements.length,
        separatorBuilder: (context, index) => const SizedBox(height: 16),
        itemBuilder: (context, index) {
          final item = announcements[index];
          final title = item['title'] ?? 'Notice';
          final category = item['category'] ?? 'General';
          final isUrgent = item['is_urgent'] ?? false;
          final isEvent = item['is_event'] ?? false;
          final dateStr = _formatDate(item['created_at']);

          // ──────────────────────────────────────────────────────────
          // 1. DYNAMIC STYLING LOGIC (CHANGE THIS PART)
          // ──────────────────────────────────────────────────────────
          Color iconColor = primaryColor;
          IconData iconData = Icons.campaign_rounded;
          Color avatarBg = const Color(0xFFEADFD6);

          if (category == 'Approved') {
            iconColor = Colors.green;
            iconData = Icons.check_circle_rounded;
            avatarBg = Colors.green.shade50;
          } else if (category == 'Rejected' || isUrgent) {
            iconColor = Colors.redAccent;
            iconData = isUrgent ? Icons.warning_amber_rounded : Icons.cancel_rounded;
            avatarBg = Colors.red.shade50;
          } else if (isEvent || category == 'Joined') {
            iconColor = eventAccentColor;
            iconData = Icons.event_available_rounded;
            avatarBg = eventAccentColor.withOpacity(0.1);
          }
          // ──────────────────────────────────────────────────────────

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
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AnnouncementDetailPage(announcement: item),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: avatarBg,
                        child: Icon(iconData, size: 22, color: iconColor),
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
                                    color: iconColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    category.toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: iconColor,
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