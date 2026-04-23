import 'dart:async'; // 🔥 新增 Timer 需要的包
import 'package:assignment/chat/CommunityChatsListScreen.dart';
import 'package:assignment/facility/facility_booking_page.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../event/screen/event_calendar_screen.dart';
import '../event/model/event_model.dart';       // ← adjust path if needed
import '../event/service/event_service.dart';   // ← adjust path if needed
import '../resident/emergency_form.dart';
import '../admin/emergency/location.dart';
import 'VisitorPassListScreen.dart';
import 'announcement_detail_page.dart';
import 'announcement_list_page.dart';
import 'resident_booking_history_page.dart';
import 'package:assignment/resident/resident_login_page.dart';
import 'package:assignment/resident/resident_personal_information_page.dart';

class ResidentHomePage extends StatefulWidget {
  const ResidentHomePage({super.key});

  @override
  State<ResidentHomePage> createState() => _ResidentHomePageState();
}

class _ResidentHomePageState extends State<ResidentHomePage> {
  int currentIndex = 0;

  // 🔥 紧急按钮状态变量
  bool isWaiting = false;
  bool isEmergency = false;
  Timer? _timer;
  int countdown = 10;

  // 🔥 公告状态变量 (使用 List 存放多条用于滑动的公告)
  List<Map<String, dynamic>> latestAnnouncements = [];
  bool isLoadingAnnouncement = true;

  final Color bgColor = const Color(0xFFF5F1ED);
  final Color primaryColor = const Color(0xFF9A4B3C);
  final Color accentColor = const Color(0xFFFC9D7E);
  final Color softYellow = const Color(0xFFF0E6B8);
  final Color textDark = const Color(0xFF2B2B2B);

  final EventService _eventService = EventService();

  // ── Upcoming events state ─────────────────────
  List<CommunityEvent> _upcomingEvents = [];
  bool _eventsLoading = true;

  // ── Resident account summary state ─────────────
  bool _accountLoading = true;
  String? _accountError;
  Map<String, dynamic>? _residentSummary;

  @override
  void initState() {
    super.initState();
    _fetchLatestAnnouncements(); // 页面初始化时获取最新的公告
    _loadUpcomingEvents();
    _loadResidentSummary();
  }

  void dispose() {
    _timer?.cancel(); // 页面销毁时清理定时器
    super.dispose();
  }

  Future<void> _loadUpcomingEvents() async {
    try {
      final all = await _eventService.fetchAllEvents();
      final now = DateTime.now();

      // Keep only approved, public events whose date is today or in the future
      final upcoming = all
          .where((e) =>
      e.status == 'approved' &&
          !e.isPrivate &&
          !e.eventDate.isBefore(DateTime(now.year, now.month, now.day)))
          .toList()
        ..sort((a, b) => a.eventDate.compareTo(b.eventDate));

      if (mounted) {
        setState(() {
          _upcomingEvents = upcoming;
          _eventsLoading  = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading upcoming events: $e');
      if (mounted) setState(() => _eventsLoading = false);
    }
  }

  // ── Auth ──────────────────────────────────────

  // 🔥 从 Supabase 获取最新 5 条公告
  Future<void> _fetchLatestAnnouncements() async {
    try {
      final response = await Supabase.instance.client
          .from('announcements') // 对应你的数据库表名
          .select()
          .order('created_at', ascending: false)
          .limit(5); // 拿最新 5 条

      if (mounted) {
        setState(() {
          latestAnnouncements = List<Map<String, dynamic>>.from(response);
          isLoadingAnnouncement = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching announcements: $e');
      if (mounted) {
        setState(() {
          isLoadingAnnouncement = false;
        });
      }
    }
  }

  // 辅助函数：格式化日期为 "5 Jan, 2026"
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

  Future<void> logout() async {
    await Supabase.instance.client.auth.signOut();

    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const ResidentLoginPage()),
          (route) => false,
    );
  }

  Future<void> _loadResidentSummary() async {
    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) {
        throw Exception('No active user session found.');
      }

      if (mounted) {
        setState(() {
          _accountLoading = true;
          _accountError = null;
        });
      }

      final resident = await Supabase.instance.client
          .from('resident')
          .select()
          .eq('id', currentUser.id)
          .maybeSingle();

      if (!mounted) return;

      setState(() {
        _residentSummary = resident == null
            ? {
          'full_name': currentUser.email?.split('@').first ?? 'Resident',
          'email': currentUser.email,
          'status': 'active',
          'resident_type': 'resident',
        }
            : {
          ...resident,
          'email': resident['email'] ?? currentUser.email,
        };
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _accountError = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() => _accountLoading = false);
      }
    }
  }

  String _accountDisplayValue(dynamic value, {String fallback = '-'}) {
    if (value == null) return fallback;
    final text = value.toString().trim();
    return text.isEmpty ? fallback : text;
  }

  String _accountInitials(String? fullName) {
    if (fullName == null || fullName.trim().isEmpty) return 'R';

    final parts = fullName
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();

    if (parts.isEmpty) return 'R';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();

    return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'.toUpperCase();
  }

  Color _accountStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return const Color(0xFF6B8E6B);
      case 'inactive':
        return const Color(0xFFD49A6A);
      case 'moved_out':
        return const Color(0xFFC67B75);
      default:
        return Colors.grey;
    }
  }

  Widget _buildAccountSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 6, bottom: 10),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: textDark,
        ),
      ),
    );
  }

  Widget _buildAccountCard({required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildAccountListTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color iconColor,
    required VoidCallback onTap,
    bool showDivider = true,
  }) {
    return Column(
      children: [
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: iconColor),
          ),
          title: Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: textDark,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              subtitle,
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ),
          trailing: Icon(Icons.arrow_forward_ios_rounded, size: 16, color: primaryColor),
          onTap: onTap,
        ),
        if (showDivider)
          const Divider(height: 1, indent: 72, endIndent: 16),
      ],
    );
  }

  Widget _buildAccountInfoPill({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.78),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.8)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _softInfoFill(label),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 18, color: primaryColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 11, color: Colors.black54),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: textDark,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _softInfoFill(String label) {
    switch (label.toLowerCase()) {
      case 'block':
        return softYellow.withOpacity(0.45);
      case 'unit':
        return accentColor.withOpacity(0.14);
      default:
        return const Color(0xFFF4E8E2);
    }
  }

  Widget _buildAccountErrorCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4F0),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF3C7BA)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, color: Color(0xFFC67B75)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _accountError ?? 'Unable to load resident profile.',
              style: const TextStyle(fontSize: 13),
            ),
          ),
          TextButton(
            onPressed: _loadResidentSummary,
            child: Text(
              'Retry',
              style: TextStyle(color: primaryColor),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openPersonalDetails() async {
    final currentUser = Supabase.instance.client.auth.currentUser;

    final userData = {
      ...?_residentSummary,
      'id': _residentSummary?['id'] ?? currentUser?.id,
      'email': _residentSummary?['email'] ?? currentUser?.email,
    };

    if (userData['id'] == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open personal details.')),
      );
      return;
    }

    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ResidentPersonalInformationPage(user: userData),
      ),
    );

    if (updated == true) {
      await _loadResidentSummary();
    }
  }

  // 重置紧急状态
  void resetState() {
    _timer?.cancel();
    setState(() {
      isWaiting = false;
      isEmergency = false;
      countdown = 10;
    });
  }

  // 带倒计时的紧急求救
  void handleEmergency() {
    if (isEmergency) {
      resetState();
      return;
    }

    if (!isWaiting) {
      setState(() {
        isWaiting = true;
        countdown = 10;
      });
      StateSetter? dialogSetState;

      _timer = Timer.periodic(const Duration(seconds: 1), (t) async {
        if (countdown > 1) {
          if (mounted) {
            setState(() {
              countdown--;
            });
          }
          if (dialogSetState != null) {
            dialogSetState!(() {});
          }
        } else {
          t.cancel();

          setState(() {
            isWaiting = false;
            isEmergency = true;
          });

          if (mounted) {
            Navigator.of(context, rootNavigator: true).pop();
          }

          // ── Shared widgets ────────────────────────────
          final userId = Supabase.instance.client.auth.currentUser?.id;

          if (userId != null) {
            try {
              final position = await getCurrentLocation();
              await createEmergency(userId.toString(), 'SOS', position);

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Emergency SOS Sent with Location!"),
                    backgroundColor: Color(0xFF6B8E6B),
                  ),
                );
              }
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text("Failed to send SOS: $e"),
                    backgroundColor: const Color(0xFFC67B75),
                  ),
                );
              }
              resetState();
            }
          }
        }
      });

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            content: StatefulBuilder(
              builder: (context, setStepState) {
                dialogSetState = setStepState;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Color(0xFFD49A6A), size: 70),
                    const SizedBox(height: 20),
                    const Text(
                      "Confirm sending emergency notification?",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF2B2B2B)),
                    ),
                    const SizedBox(height: 25),
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 80, height: 80,
                          child: CircularProgressIndicator(
                            value: countdown / 10,
                            strokeWidth: 6,
                            backgroundColor: Colors.grey.shade200,
                            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFD49A6A)),
                          ),
                        ),
                        Text(
                          "$countdown",
                          style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF2B2B2B)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 30),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF8B5E4A),
                          side: const BorderSide(color: Color(0xFF8B5E4A)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () {
                          resetState();
                          Navigator.pop(context);
                        },
                        child: const Text("Cancel Emergency"),
                      ),
                    ),
                  ],
                );
              },
            ),
          );
        },
      );
    }
  }

  Widget buildServiceItem({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Column(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: color.withOpacity(0.18),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: textDark,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildSectionTitle(String title, {VoidCallback? onSeeAll}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: textDark,
            ),
          ),

          if (onSeeAll != null)
            GestureDetector(
              onTap: onSeeAll,
              child: Text(
                "View All",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: primaryColor,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // 🔥 动态横向滑动公告卡片 (支持点击查看详情)
  Widget buildAnnouncementSlider() {
    if (isLoadingAnnouncement) {
      return Container(
        width: double.infinity,
        height: 140, // 固定高度防止页面跳动
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
        ),
        child: const Center(child: CircularProgressIndicator(color: Color(0xFF9A4B3C))),
      );
    }

    if (latestAnnouncements.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
        ),
        child: const Center(
          child: Text(
            "No announcements at the moment.",
            style: TextStyle(color: Colors.black54),
          ),
        ),
      );
    }

    return SizedBox(
      height: 145,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: latestAnnouncements.length,
        separatorBuilder: (context, index) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          final announcement = latestAnnouncements[index];
          final title = announcement['title'] ?? 'Notice';
          final content = announcement['content'] ?? '';
          final category = announcement['category'] ?? 'General';
          final isUrgent = announcement['is_urgent'] ?? false;
          final dateStr = _formatDate(announcement['created_at']);

          return Container(
            width: MediaQuery.of(context).size.width * 0.75, // 显示75%的宽度，让右侧露出下一张
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(22),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AnnouncementDetailPage(announcement: announcement),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (isUrgent) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.red.shade200),
                              ),
                              child: const Text(
                                "URGENT",
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.redAccent,
                                ),
                              ),
                            ),
                          ],
                          Expanded(
                            child: Text(
                              title,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: textDark,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: Text(
                          content,
                          style: const TextStyle(fontSize: 13, color: Colors.black54, height: 1.4),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 12,
                            backgroundColor: isUrgent ? Colors.red.shade50 : const Color(0xFFEADFD6),
                            child: Icon(
                                isUrgent ? Icons.warning_amber_rounded : Icons.campaign_rounded,
                                size: 12,
                                color: isUrgent ? Colors.redAccent : const Color(0xFF9A4B3C)
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              category.toUpperCase(),
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.black54,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            dateStr,
                            style: TextStyle(
                              fontSize: 11,
                              color: primaryColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
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

  // ── Upcoming events section ───────────────────

  Widget buildUpcomingEventsSection() {
    if (_eventsLoading) {
      return SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator(color: primaryColor)),
      );
    }

    if (_upcomingEvents.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 12,
                offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          children: [
            Icon(Icons.event_busy_rounded,
                size: 44, color: primaryColor.withOpacity(0.3)),
            const SizedBox(height: 10),
            Text("No upcoming events",
                style: TextStyle(color: primaryColor.withOpacity(0.5))),
          ],
        ),
      );
    }

    return SizedBox(
      height: 260,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(right: 4),
        itemCount: _upcomingEvents.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (context, index) =>
            _buildEventCard(_upcomingEvents[index]),
      ),
    );
  }

  Widget _buildEventCard(CommunityEvent event) {
    // Format date as "Mon, 22 Apr"
    const months = [
      'Jan','Feb','Mar','Apr','May','Jun',
      'Jul','Aug','Sep','Oct','Nov','Dec'
    ];
    const days = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
    final d = event.eventDate;
    final dateLabel =
        '${days[d.weekday - 1]}, ${d.day} ${months[d.month - 1]}';

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => EventCalendarScreen(highlightEventId: event.id),
        ),
      ).then((_) => _loadUpcomingEvents()),
      child: Container(
        width: 200,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 12,
                offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image / gradient banner
            ClipRRect(
              borderRadius:
              const BorderRadius.vertical(top: Radius.circular(22)),
              child: event.imageUrl != null && event.imageUrl!.isNotEmpty
                  ? Image.network(event.imageUrl!,
                  height: 120, width: double.infinity, fit: BoxFit.cover)
                  : Container(
                height: 120,
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      accentColor.withOpacity(0.6),
                      primaryColor.withOpacity(0.8)
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Icon(Icons.event_rounded,
                    color: Colors.white, size: 40),
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Date pill
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.calendar_today_rounded,
                            size: 11, color: primaryColor),
                        const SizedBox(width: 4),
                        Text(dateLabel,
                            style: TextStyle(
                                fontSize: 11,
                                color: primaryColor,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  // Title
                  Text(
                    event.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: textDark,
                        height: 1.3),
                  ),
                  const SizedBox(height: 4),
                  // Time
                  Row(
                    children: [
                      Icon(Icons.access_time_rounded,
                          size: 11, color: Colors.black38),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          "${event.startTime} – ${event.endTime}",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 11, color: Colors.black45),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Tabs ──────────────────────────────────────

  Widget buildHomeTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Location chip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4)),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.location_on_outlined, color: primaryColor, size: 18),
                const SizedBox(width: 6),
                Text("BLOCK A",
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: primaryColor,
                        letterSpacing: 0.5)),
                const SizedBox(width: 4),
                const Icon(Icons.keyboard_arrow_down_rounded),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text("Welcome back",
              style: TextStyle(
                  fontSize: 28, fontWeight: FontWeight.bold, color: textDark)),
          const SizedBox(height: 6),
          const Text(
            "Manage your community services and stay informed.",
            style: TextStyle(fontSize: 14, color: Colors.black54, height: 1.5),
          ),
          const SizedBox(height: 22),

          // Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: softYellow,
              borderRadius: BorderRadius.circular(26),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    "JiranMu keeps your community connected, safe and informed.",
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: primaryColor,
                        height: 1.5),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 54, height: 54,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.85),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(Icons.groups_rounded, color: primaryColor, size: 28),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
          buildSectionTitle("Services"),
          Row(
            children: [
              buildServiceItem(
                icon: Icons.badge_outlined,
                color: const Color(0xFFE96B9E),
                label: "Visitors",
                onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Visitors clicked"))),
              ),
              const SizedBox(width: 10),
              buildServiceItem(
                icon: Icons.fitness_center,
                color: const Color(0xFF4BC0B8),
                label: "Facility",
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => FacilityBookingPage())),
              ),
              const SizedBox(width: 10),
              buildServiceItem(
                icon: Icons.event_note_outlined,
                color: const Color(0xFF758BFD),
                label: "Events",
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => EventCalendarScreen())),
              ),
              const SizedBox(width: 10),
              buildServiceItem(
                icon: Icons.sos_outlined,
                color: const Color(0xFFFF5A5A),
                label: "SOS",
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => EmergencyForm(),
                    ),
                  );
                },
              ),
            ],
          ),

          const SizedBox(height: 28),
          buildSectionTitle(
            "Announcement",
            onSeeAll: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AnnouncementListPage(),
                ),
              );
            },
          ),
          buildAnnouncementSlider(), // 🔥 替换为滑动组件

          const SizedBox(height: 28),
          // "See all" navigates to the full calendar
          buildSectionTitle(
            "Upcoming Events",
            onSeeAll: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => EventCalendarScreen()),
            ).then((_) => _loadUpcomingEvents()),
          ),
          buildUpcomingEventsSection(),
        ],
      ),
    );
  }

  Widget buildMyFacilityTab() {
    return const FacilityBookingPage(showBackButton: false);
  }

  Widget buildChatsTab() => CommunityChatsListScreen();

  Widget buildAccountTab() {
    final resident = _residentSummary;
    final currentUser = Supabase.instance.client.auth.currentUser;

    final name = _accountDisplayValue(
      resident?['full_name'],
      fallback: 'Resident Account',
    );
    final email = _accountDisplayValue(
      resident?['email'] ?? currentUser?.email,
      fallback: 'No email address',
    );
    final residentType = _accountDisplayValue(
      resident?['resident_type'],
      fallback: 'resident',
    ).toUpperCase();
    final status = _accountDisplayValue(
      resident?['status'],
      fallback: 'active',
    ).toUpperCase();
    final statusColor = _accountStatusColor(status);

    if (_accountLoading && resident == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      color: primaryColor,
      onRefresh: _loadResidentSummary,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
        children: [
          if (_accountError != null && resident == null) _buildAccountErrorCard(),
          Container(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: const LinearGradient(
                colors: [Color(0xFFFFFFFF), Color(0xFFFFF7F1)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 4),
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withOpacity(0.12),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    radius: 44,
                    backgroundColor: const Color(0xFFEADFD6),
                    child: Text(
                      _accountInitials(resident?['full_name']?.toString()),
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  name,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: textDark,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  email,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        residentType,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: primaryColor,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        status,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: statusColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: _buildAccountInfoPill(
                        icon: Icons.apartment_rounded,
                        label: 'Block',
                        value: _accountDisplayValue(resident?['block']),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildAccountInfoPill(
                        icon: Icons.home_rounded,
                        label: 'Unit',
                        value: _accountDisplayValue(resident?['unit_number']),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 26),
          _buildAccountSectionTitle('Account Settings'),
          _buildAccountCard(
            children: [
              _buildAccountListTile(
                icon: Icons.badge_outlined,
                title: 'Personal Details',
                subtitle: 'Manage your personal details and password',
                iconColor: primaryColor,
                onTap: _openPersonalDetails,
                showDivider: false,
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildAccountSectionTitle('Activity'),
          _buildAccountCard(
            children: [
              _buildAccountListTile(
                icon: Icons.history_rounded,
                title: 'Booking History',
                subtitle: 'View pending, approved, and past facility bookings',
                iconColor: const Color(0xFFD49A6A),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ResidentBookingHistoryPage(),
                  ),
                ),
                showDivider: false,
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildAccountSectionTitle('Services'),
          _buildAccountCard(
            children: [
              _buildAccountListTile(
                icon: Icons.badge_outlined,
                title: 'Visitor Pass',
                subtitle: 'Create and manage visitor QR passes for your guests',
                iconColor: const Color(0xFF6B8E6B),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const VisitorPassListScreen()),
                ),
                showDivider: false,
              ),
            ],
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: logout,
              icon: const Icon(Icons.logout_rounded, color: Color(0xFFC67B75)),
              label: const Text(
                'Log Out',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFC67B75),
                ),
              ),
              style: ElevatedButton.styleFrom(
                elevation: 0,
                backgroundColor: const Color(0xFFFFF1EE),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget getCurrentPage() {
    switch (currentIndex) {
      case 0:return buildHomeTab();
      case 1:return buildMyFacilityTab();
      case 2:return buildChatsTab();
      case 3:return buildAccountTab();
      default:return buildHomeTab();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(child: getCurrentPage()),

      floatingActionButton: SizedBox(
        width: 65,
        height: 65,
        child: FloatingActionButton(
          onPressed: handleEmergency,
          backgroundColor: isEmergency ? Colors.red : (isWaiting ? Colors.orange : Colors.red),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(60)),
          elevation: 6,
          child: Icon(
            isEmergency ? Icons.warning : (isWaiting ? Icons.access_time : Icons.sos_rounded),
            size: 32, color: Colors.white,
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,

      bottomNavigationBar: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 18,
                offset: const Offset(0, 6)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BottomNavigationBar(
            currentIndex: currentIndex,
            onTap: (index) => setState(() => currentIndex = index),
            type: BottomNavigationBarType.fixed,
            backgroundColor: Colors.white,
            selectedItemColor: primaryColor,
            unselectedItemColor: Colors.black38,
            selectedFontSize: 12,
            unselectedFontSize: 12,
            elevation: 0,
            items: const [
              BottomNavigationBarItem(
                  icon: Icon(Icons.home_rounded), label: "Home"),
              BottomNavigationBarItem(
                icon: Icon(Icons.fitness_center_rounded),label: "Facility",),
              BottomNavigationBarItem(
                  icon: Icon(Icons.chat_bubble_outline_rounded), label: "Chats"),
              BottomNavigationBarItem(
                  icon: Icon(Icons.person_outline_rounded), label: "Account"),
            ],
          ),
        ),
      ),
    );
  }
}