import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:assignment/chat/CommunityChatsListScreen.dart';
import 'package:assignment/chat/CommunityChatScreen.dart';
import 'package:assignment/chat/in_app_notification_service.dart';
import 'package:assignment/chat/user_session.dart';
import 'package:assignment/facility/facility_booking_page.dart';
import 'package:assignment/event/screen/event_calendar_screen.dart';
import 'package:assignment/event/model/event_model.dart';
import 'package:assignment/event/service/event_service.dart';
import 'package:assignment/resident/emergency_form.dart';
import 'package:assignment/admin/emergency/location.dart';
import 'package:assignment/resident/VisitorPassListScreen.dart';
import 'package:assignment/resident/announcement_detail_page.dart';
import 'package:assignment/resident/announcement_list_page.dart';
import 'package:assignment/resident/resident_booking_history_page.dart';
import 'package:assignment/resident/resident_login_page.dart';
import 'package:assignment/resident/resident_personal_information_page.dart';

// ── Unified notification item model ──────────────────────────────────────────

enum _NotifType { announcement, message }

class _NotifItem {
  final _NotifType type;

  // Announcement fields
  final Map<String, dynamic>? announcement;

  // Message fields
  final String? roomId;
  final String? chatName;
  final String? lastMessage;
  final String? senderName;
  final int unreadCount;
  final DateTime? lastTime;
  final bool isGroup;

  const _NotifItem.announcement(this.announcement)
      : type = _NotifType.announcement,
        roomId = null,
        chatName = null,
        lastMessage = null,
        senderName = null,
        unreadCount = 0,
        lastTime = null,
        isGroup = false;

  const _NotifItem.message({
    required this.roomId,
    required this.chatName,
    required this.lastMessage,
    required this.senderName,
    required this.unreadCount,
    required this.lastTime,
    required this.isGroup,
  })  : type = _NotifType.message,
        announcement = null;
}

// ─────────────────────────────────────────────────────────────────────────────

class ResidentHomePage extends StatefulWidget {
  const ResidentHomePage({super.key});

  @override
  State<ResidentHomePage> createState() => _ResidentHomePageState();
}

class _ResidentHomePageState extends State<ResidentHomePage> {
  int currentIndex = 0;
  bool _sessionReady = false;

  // ── Emergency button state ────────────────────
  bool isWaiting = false;
  bool isEmergency = false;
  Timer? _timer;
  int countdown = 10;

  // ── Announcement state ────────────────────────
  List<Map<String, dynamic>> latestAnnouncements = [];
  bool isLoadingAnnouncement = true;
  bool _hasUnreadAnnouncements = false;

  // ── Message notification state ────────────────
  int _unreadMessageCount = 0;

  // ── Theme colors ──────────────────────────────
  final Color bgColor = const Color(0xFFF5F1ED);
  final Color primaryColor = const Color(0xFF9A4B3C);
  final Color accentColor = const Color(0xFFFC9D7E);
  final Color softYellow = const Color(0xFFF0E6B8);
  final Color textDark = const Color(0xFF2B2B2B);

  // ── Events state ──────────────────────────────
  final EventService _eventService = EventService();
  List<CommunityEvent> _upcomingEvents = [];
  bool _eventsLoading = true;

  // ── Resident account summary state ────────────
  bool _accountLoading = true;
  String? _accountError;
  Map<String, dynamic>? _residentSummary;

  // ─────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _ensureSession();
    _checkUnreadAnnouncements();
    _fetchLatestAnnouncements();
    _loadUpcomingEvents();
    _loadResidentSummary();
    _loadUnreadMessageCount();
    InAppNotificationService.instance.addListener(_onNewMessage);
  }

  @override
  void dispose() {
    _timer?.cancel();
    InAppNotificationService.instance.removeListener(_onNewMessage);
    super.dispose();
  }

  void _onNewMessage() {
    if (InAppNotificationService.instance.current != null) {
      _loadUnreadMessageCount();
    }
  }

  Future<void> _ensureSession() async {
    await UserSession.init();
    if (mounted) setState(() => _sessionReady = true);
  }

  // ── Unread message count ──────────────────────────────────────────────────
  // Only counts messages where sender != current user email so self-sent
  // messages never inflate the badge.

  Future<void> _loadUnreadMessageCount() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      final email = Supabase.instance.client.auth.currentUser?.email;
      if (userId == null || email == null) return;

      // DM rooms
      final roomsU1 = await Supabase.instance.client
          .from('chat_rooms')
          .select('room_id')
          .eq('user1_id', userId);
      final roomsU2 = await Supabase.instance.client
          .from('chat_rooms')
          .select('room_id')
          .eq('user2_id', userId);

      final dmRoomIds = [
        ...(roomsU1 as List).map((r) => r['room_id'] as String),
        ...(roomsU2 as List).map((r) => r['room_id'] as String),
      ];

      // Group rooms this user has accepted
      final invitations = await Supabase.instance.client
          .from('group_chat_invitations')
          .select('group_chat_id')
          .eq('invited_user_id', userId)
          .eq('status', 'accepted');

      final groupRoomIds = <String>[];
      for (final inv in (invitations as List)) {
        final group = await Supabase.instance.client
            .from('group_chats')
            .select('room_id')
            .eq('id', inv['group_chat_id'] as String)
            .maybeSingle();
        if (group != null) groupRoomIds.add(group['room_id'] as String);
      }

      final allRoomIds = [...dmRoomIds, ...groupRoomIds];
      if (allRoomIds.isEmpty) {
        if (mounted) setState(() => _unreadMessageCount = 0);
        return;
      }

      int total = 0;
      for (final roomId in allRoomIds) {
        final res = await Supabase.instance.client
            .from('messages')
            .select('id')
            .eq('room_id', roomId)
            .neq('sender', email) // exclude messages I sent
            .eq('is_read', false);
        total += (res as List).length;
      }

      if (mounted) setState(() => _unreadMessageCount = total);
    } catch (e) {
      debugPrint('Error loading unread message count: $e');
    }
  }

  // ── Unified notification items ────────────────────────────────────────────
  // Message items are only added when unreadCount > 0 from OTHER people.

  Future<List<_NotifItem>> _loadNotifItems() async {
    final items = <_NotifItem>[];
    final userId = Supabase.instance.client.auth.currentUser?.id;
    final email = Supabase.instance.client.auth.currentUser?.email;

    // ── Announcements ────────────────────────────────────────────────────
    try {
      final anns = await Supabase.instance.client
          .from('announcements')
          .select()
          .order('created_at', ascending: false)
          .limit(5);
      for (final a in (anns as List)) {
        items.add(_NotifItem.announcement(Map<String, dynamic>.from(a)));
      }
    } catch (e) {
      debugPrint('Error loading announcements for notif sheet: $e');
    }

    if (userId == null || email == null) return items;

    // ── Messages ─────────────────────────────────────────────────────────
    try {
      // DM rooms
      final roomsU1 = await Supabase.instance.client
          .from('chat_rooms')
          .select('room_id, user1_id, user2_id')
          .eq('user1_id', userId);
      final roomsU2 = await Supabase.instance.client
          .from('chat_rooms')
          .select('room_id, user1_id, user2_id')
          .eq('user2_id', userId);

      final allDmRooms = [
        ...(roomsU1 as List),
        ...(roomsU2 as List),
      ];

      for (final room in allDmRooms) {
        final roomId = room['room_id'] as String;
        final otherId = (room['user1_id'] as String) == userId
            ? room['user2_id'] as String
            : room['user1_id'] as String;

        final unreadRes = await Supabase.instance.client
            .from('messages')
            .select('id')
            .eq('room_id', roomId)
            .neq('sender', email) // exclude my own
            .eq('is_read', false);
        final unreadCount = (unreadRes as List).length;
        if (unreadCount == 0) continue; // nothing to show

        String neighbourName = 'Neighbour';
        try {
          final profile = await Supabase.instance.client
              .from('resident')
              .select('full_name')
              .eq('id', otherId)
              .maybeSingle();
          if (profile != null) {
            neighbourName =
                profile['full_name']?.toString() ?? neighbourName;
          }
        } catch (_) {}

        final msgs = await Supabase.instance.client
            .from('messages')
            .select('content, created_at, sender')
            .eq('room_id', roomId)
            .neq('sender', email)
            .eq('is_read', false)
            .order('created_at', ascending: false)
            .limit(1);

        final msgList = msgs as List;
        if (msgList.isEmpty) continue;

        items.add(_NotifItem.message(
          roomId: roomId,
          chatName: neighbourName,
          lastMessage: msgList[0]['content'] as String? ?? '',
          senderName: neighbourName,
          unreadCount: unreadCount,
          lastTime:
          DateTime.parse(msgList[0]['created_at'] as String),
          isGroup: false,
        ));
      }

      // Group rooms
      final invitations = await Supabase.instance.client
          .from('group_chat_invitations')
          .select('group_chat_id')
          .eq('invited_user_id', userId)
          .eq('status', 'accepted');

      for (final inv in (invitations as List)) {
        final groupData = await Supabase.instance.client
            .from('group_chats')
            .select('room_id, name, block')
            .eq('id', inv['group_chat_id'] as String)
            .maybeSingle();
        if (groupData == null) continue;

        final roomId = groupData['room_id'] as String;
        final groupName =
            groupData['name'] as String? ?? 'Block ${groupData['block']}';

        final unreadRes = await Supabase.instance.client
            .from('messages')
            .select('id')
            .eq('room_id', roomId)
            .neq('sender', email)
            .eq('is_read', false);
        final unreadCount = (unreadRes as List).length;
        if (unreadCount == 0) continue;

        final msgs = await Supabase.instance.client
            .from('messages')
            .select('content, created_at, sender')
            .eq('room_id', roomId)
            .neq('sender', email)
            .eq('is_read', false)
            .order('created_at', ascending: false)
            .limit(1);

        final msgList = msgs as List;
        if (msgList.isEmpty) continue;

        final senderEmail = msgList[0]['sender'] as String? ?? '';
        String senderName = senderEmail;
        try {
          final profile = await Supabase.instance.client
              .from('resident')
              .select('full_name')
              .eq('email', senderEmail)
              .maybeSingle();
          if (profile != null) {
            senderName =
                profile['full_name']?.toString() ?? senderEmail;
          }
        } catch (_) {}

        items.add(_NotifItem.message(
          roomId: roomId,
          chatName: groupName,
          lastMessage: msgList[0]['content'] as String? ?? '',
          senderName: senderName,
          unreadCount: unreadCount,
          lastTime:
          DateTime.parse(msgList[0]['created_at'] as String),
          isGroup: true,
        ));
      }
    } catch (e) {
      debugPrint('Error loading message notif items: $e');
    }

    // Announcements first, then messages sorted by time desc
    final annItems =
    items.where((i) => i.type == _NotifType.announcement).toList();
    final msgItems = items
        .where((i) => i.type == _NotifType.message)
        .toList()
      ..sort((a, b) => (b.lastTime ?? DateTime(0))
          .compareTo(a.lastTime ?? DateTime(0)));

    return [...annItems, ...msgItems];
  }

  // ── Events ────────────────────────────────────────────────────────────────

  Future<void> _loadUpcomingEvents() async {
    try {
      final all = await _eventService.fetchAllEvents();
      final now = DateTime.now();
      final upcoming = all
          .where((e) =>
      e.status == 'approved' &&
          !e.isPrivate &&
          !e.eventDate.isBefore(
              DateTime(now.year, now.month, now.day)))
          .toList()
        ..sort((a, b) => a.eventDate.compareTo(b.eventDate));

      if (mounted) {
        setState(() {
          _upcomingEvents = upcoming;
          _eventsLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading upcoming events: $e');
      if (mounted) setState(() => _eventsLoading = false);
    }
  }

  // ── Announcements ─────────────────────────────────────────────────────────

  Future<void> _fetchLatestAnnouncements() async {
    try {
      final response = await Supabase.instance.client
          .from('announcements')
          .select()
          .order('created_at', ascending: false)
          .limit(5);

      if (mounted) {
        setState(() {
          latestAnnouncements =
          List<Map<String, dynamic>>.from(response);
          isLoadingAnnouncement = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching announcements: $e');
      if (mounted) setState(() => isLoadingAnnouncement = false);
    }
  }

  Future<void> _checkUnreadAnnouncements() async {
    try {
      final response = await Supabase.instance.client
          .from('announcements')
          .select('created_at')
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response != null && response['created_at'] != null) {
        final DateTime latestDbDate =
        DateTime.parse(response['created_at']);
        final prefs = await SharedPreferences.getInstance();
        final String? lastReadStr =
        prefs.getString('last_read_announcements');

        if (mounted) {
          setState(() {
            _hasUnreadAnnouncements = lastReadStr == null
                ? true
                : latestDbDate
                .isAfter(DateTime.parse(lastReadStr));
          });
        }
      }
    } catch (e) {
      debugPrint('Error checking unread announcements: $e');
    }
  }

  // ── Resident summary ──────────────────────────────────────────────────────

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
          'full_name':
          currentUser.email?.split('@').first ?? 'Resident',
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
      setState(() =>
      _accountError = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _accountLoading = false);
    }
  }

  // ── Auth ──────────────────────────────────────────────────────────────────

  Future<void> logout() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      await Supabase.instance.client.auth.signOut();

      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const ResidentLoginPage()),
              (route) => false,
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Logout failed: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  // ── Emergency ─────────────────────────────────────────────────────────────

  void resetState() {
    _timer?.cancel();
    setState(() {
      isWaiting = false;
      isEmergency = false;
      countdown = 10;
    });
  }

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
          if (mounted) setState(() => countdown--);
          dialogSetState?.call(() {});
        } else {
          t.cancel();
          setState(() {
            isWaiting = false;
            isEmergency = true;
          });
          if (mounted) Navigator.of(context, rootNavigator: true).pop();

          final userId =
              Supabase.instance.client.auth.currentUser?.id;
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
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text("Failed to send SOS: $e"),
                  backgroundColor: const Color(0xFFC67B75),
                ));
              }
              resetState();
            }
          }
        }
      });

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)),
          content: StatefulBuilder(
            builder: (context, setStepState) {
              dialogSetState = setStepState;
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      color: Colors.red, size: 70),
                  const SizedBox(height: 20),
                  const Text(
                    "Confirm sending emergency notification?",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Color(0xFF2B2B2B)),
                  ),
                  const SizedBox(height: 25),
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 80,
                        height: 80,
                        child: CircularProgressIndicator(
                          value: countdown / 10,
                          strokeWidth: 6,
                          backgroundColor: Colors.grey.shade200,
                          valueColor:
                          const AlwaysStoppedAnimation<Color>(
                              Colors.red),
                        ),
                      ),
                      Text("$countdown",
                          style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2B2B2B))),
                    ],
                  ),
                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.black,
                        side: const BorderSide(color: Colors.black),
                        shape: RoundedRectangleBorder(
                            borderRadius:
                            BorderRadius.circular(12)),
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
        ),
      );
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final DateTime date = DateTime.parse(dateStr).toLocal();
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      return '${date.day} ${months[date.month - 1]}, ${date.year}';
    } catch (_) {
      return dateStr.substring(0, 10);
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
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'R';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
        .toUpperCase();
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

  Future<void> _openPersonalDetails() async {
    final currentUser = Supabase.instance.client.auth.currentUser;
    final userData = {
      ...?_residentSummary,
      'id': _residentSummary?['id'] ?? currentUser?.id,
      'email': _residentSummary?['email'] ?? currentUser?.email,
    };

    if (userData['id'] == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Unable to open personal details.')),
      );
      return;
    }

    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
          builder: (_) =>
              ResidentPersonalInformationPage(user: userData)),
    );

    if (updated == true) await _loadResidentSummary();
  }

  // ── Unified notification bottom sheet ─────────────────────────────────────

  void _showNotificationSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _NotificationSheet(
        primaryColor: primaryColor,
        textDark: textDark,
        hasUnreadAnnouncements: _hasUnreadAnnouncements,
        loadItems: _loadNotifItems,
        onAnnouncementTap: (announcement) async {
          setState(() => _hasUnreadAnnouncements = false);
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(
              'last_read_announcements',
              DateTime.now().toIso8601String());
          if (mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    AnnouncementDetailPage(announcement: announcement),
              ),
            ).then((_) => _checkUnreadAnnouncements());
          }
        },
        onMessageTap: (item) {
          final userId =
              Supabase.instance.client.auth.currentUser?.id ?? '';
          final email =
              Supabase.instance.client.auth.currentUser?.email ?? '';
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CommunityChatScreen(
                roomId: item.roomId!,
                communityName: item.chatName!,
                currentUserId: userId,
                currentUser: email,
                isAdmin: false,
              ),
            ),
          ).then((_) {
            _loadUnreadMessageCount();
            _checkUnreadAnnouncements();
          });
        },
      ),
    ).then((_) {
      _checkUnreadAnnouncements();
      _loadUnreadMessageCount();
    });
  }

  // ── Shared widgets ────────────────────────────────────────────────────────

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
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: textDark)),
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
          Text(title,
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textDark)),
          if (onSeeAll != null)
            GestureDetector(
              onTap: onSeeAll,
              child: Text("View All",
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: primaryColor)),
            ),
        ],
      ),
    );
  }

  // ── Announcement slider ───────────────────────────────────────────────────

  Widget buildAnnouncementSlider() {
    if (isLoadingAnnouncement) {
      return Container(
        width: double.infinity,
        height: 140,
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22)),
        child: Center(
            child:
            CircularProgressIndicator(color: Colors.brown.shade400)),
      );
    }

    if (latestAnnouncements.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22)),
        child: Center(
          child: Text("No announcements at the moment.",
              style: TextStyle(color: Colors.brown.shade400)),
        ),
      );
    }

    return SizedBox(
      height: 220,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: latestAnnouncements.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          final announcement = latestAnnouncements[index];
          final title = announcement['title'] ?? 'Notice';
          final content = announcement['content'] ?? '';
          final isUrgent = announcement['is_urgent'] ?? false;
          final imageUrl =
              announcement['image_url']?.toString() ?? '';
          final hasImage =
              imageUrl.isNotEmpty && imageUrl.startsWith('http');

          return Container(
            width: MediaQuery.of(context).size.width * 0.75,
            margin: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4)),
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
                      builder: (_) => AnnouncementDetailPage(
                          announcement: announcement),
                    ),
                  ).then((_) => _checkUnreadAnnouncements());
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    hasImage
                        ? SizedBox(
                      height: 100,
                      child: ClipRRect(
                        borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(22),
                            topRight: Radius.circular(22)),
                        child: Image.network(imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                _buildColorBlockFallback(
                                    isUrgent)),
                      ),
                    )
                        : _buildColorBlockFallback(isUrgent),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                if (isUrgent) ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    margin: const EdgeInsets.only(
                                        right: 8),
                                    decoration: BoxDecoration(
                                      color: Colors.red.shade50,
                                      borderRadius:
                                      BorderRadius.circular(6),
                                      border: Border.all(
                                          color: Colors.red.shade200),
                                    ),
                                    child: const Text("URGENT",
                                        style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.redAccent)),
                                  ),
                                ],
                                Expanded(
                                  child: Text(title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color:
                                          Colors.brown.shade900)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Expanded(
                              child: Text(content,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.brown.shade800,
                                      height: 1.4)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildColorBlockFallback(bool isUrgent) {
    return Container(
      height: 100,
      decoration: BoxDecoration(
        color: isUrgent
            ? const Color(0xFFFFC1AC)
            : Colors.amber.shade400,
        borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(22),
            topRight: Radius.circular(22)),
      ),
      child: Center(
        child: Icon(
          isUrgent
              ? Icons.warning_amber_rounded
              : Icons.campaign_rounded,
          size: 50,
          color: Colors.white.withOpacity(0.6),
        ),
      ),
    );
  }

  // ── Upcoming events ───────────────────────────────────────────────────────

  Widget buildUpcomingEventsSection() {
    if (_eventsLoading) {
      return SizedBox(
        height: 200,
        child: Center(
            child: CircularProgressIndicator(color: primaryColor)),
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
                offset: const Offset(0, 4))
          ],
        ),
        child: Column(
          children: [
            Icon(Icons.event_busy_rounded,
                size: 44, color: primaryColor.withOpacity(0.3)),
            const SizedBox(height: 10),
            Text("No upcoming events",
                style: TextStyle(
                    color: primaryColor.withOpacity(0.5))),
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
        itemBuilder: (_, index) =>
            _buildEventCard(_upcomingEvents[index]),
      ),
    );
  }

  Widget _buildEventCard(CommunityEvent event) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final d = event.eventDate;
    final dateLabel =
        '${days[d.weekday - 1]}, ${d.day} ${months[d.month - 1]}';

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) =>
                EventCalendarScreen(highlightEventId: event.id)),
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
                offset: const Offset(0, 4))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius:
              const BorderRadius.vertical(top: Radius.circular(22)),
              child: event.imageUrl != null &&
                  event.imageUrl!.isNotEmpty
                  ? Image.network(event.imageUrl!,
                  height: 120,
                  width: double.infinity,
                  fit: BoxFit.cover)
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
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                        color: primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8)),
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
                  Text(event.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: textDark,
                          height: 1.3)),
                  const SizedBox(height: 4),
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
                                fontSize: 11,
                                color: Colors.black45)),
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

  // ── Account tab widgets ───────────────────────────────────────────────────

  Widget _buildAccountSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 6, bottom: 10),
      child: Text(title,
          style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: textDark)),
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
              offset: const Offset(0, 6))
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
          contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: iconColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14)),
            child: Icon(icon, color: iconColor),
          ),
          title: Text(title,
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: textDark)),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(subtitle,
                style: const TextStyle(
                    fontSize: 12, color: Colors.black54)),
          ),
          trailing: Icon(Icons.arrow_forward_ios_rounded,
              size: 16, color: primaryColor),
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
      padding:
      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, size: 18, color: primaryColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 11, color: Colors.black54)),
                const SizedBox(height: 2),
                Text(value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: textDark)),
              ],
            ),
          ),
        ],
      ),
    );
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
          const Icon(Icons.info_outline_rounded,
              color: Color(0xFFC67B75)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
                _accountError ??
                    'Unable to load resident profile.',
                style: const TextStyle(fontSize: 13)),
          ),
          TextButton(
            onPressed: _loadResidentSummary,
            child:
            Text('Retry', style: TextStyle(color: primaryColor)),
          ),
        ],
      ),
    );
  }

  // ── Tabs ──────────────────────────────────────────────────────────────────

  Widget buildHomeTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top bar: block chip + notification bell
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 4))
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.location_on_outlined,
                        color: primaryColor, size: 18),
                    const SizedBox(width: 6),
                    // Block from DB (current version improvement)
                    Text(
                      _residentSummary?['block'] != null &&
                          _residentSummary!['block']
                              .toString()
                              .trim()
                              .isNotEmpty
                          ? 'BLOCK ${_residentSummary!['block'].toString().trim().toUpperCase()}'
                          : 'MY BLOCK',
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: primaryColor,
                          letterSpacing: 0.5),
                    ),
                    const SizedBox(width: 4),
                  ],
                ),
              ),

              // ── Unified notification bell ──────────────────────────────
              GestureDetector(
                onTap: _showNotificationSheet,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 4))
                    ],
                  ),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Icon(Icons.notifications_none_rounded,
                          color: primaryColor, size: 24),
                      if (_hasUnreadAnnouncements ||
                          _unreadMessageCount > 0)
                        Positioned(
                          top: -3,
                          right: -3,
                          child: Container(
                            padding: _unreadMessageCount > 0
                                ? const EdgeInsets.symmetric(
                                horizontal: 4, vertical: 1)
                                : EdgeInsets.zero,
                            constraints: BoxConstraints(
                              minWidth:
                              _unreadMessageCount > 0 ? 16 : 8,
                              minHeight:
                              _unreadMessageCount > 0 ? 16 : 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red.shade500,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: Colors.white, width: 1.5),
                            ),
                            child: _unreadMessageCount > 0
                                ? Text(
                              _unreadMessageCount > 99
                                  ? '99+'
                                  : '$_unreadMessageCount',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800),
                              textAlign: TextAlign.center,
                            )
                                : const SizedBox.shrink(),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),
          Text("Welcome back",
              style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: textDark)),
          const SizedBox(height: 6),
          const Text(
            "Manage your community services and stay informed.",
            style: TextStyle(
                fontSize: 14, color: Colors.black54, height: 1.5),
          ),
          const SizedBox(height: 22),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
                color: softYellow,
                borderRadius: BorderRadius.circular(26)),
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
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.85),
                      borderRadius: BorderRadius.circular(18)),
                  child: Icon(Icons.groups_rounded,
                      color: primaryColor, size: 28),
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
                onTap: () => ScaffoldMessenger.of(context)
                    .showSnackBar(const SnackBar(
                    content: Text("Visitors clicked"))),
              ),
              const SizedBox(width: 10),
              buildServiceItem(
                icon: Icons.fitness_center,
                color: const Color(0xFF4BC0B8),
                label: "Facility",
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => FacilityBookingPage())),
              ),
              const SizedBox(width: 10),
              buildServiceItem(
                icon: Icons.event_note_outlined,
                color: const Color(0xFF758BFD),
                label: "Events",
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => EventCalendarScreen())),
              ),
              const SizedBox(width: 10),
              buildServiceItem(
                icon: Icons.sos_outlined,
                color: const Color(0xFFFF5A5A),
                label: "SOS",
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => EmergencyForm())),
              ),
            ],
          ),

          const SizedBox(height: 28),
          buildSectionTitle("Announcement",
              onSeeAll: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                      const AnnouncementListPage()))),
          buildAnnouncementSlider(),

          const SizedBox(height: 28),
          buildSectionTitle("Upcoming Events",
              onSeeAll: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => EventCalendarScreen()))
                  .then((_) => _loadUpcomingEvents())),
          buildUpcomingEventsSection(),
        ],
      ),
    );
  }

  Widget buildMyFacilityTab() =>
      const FacilityBookingPage(showBackButton: false);

  Widget buildAccountTab() {
    final resident = _residentSummary;
    final currentUser = Supabase.instance.client.auth.currentUser;

    final name = _accountDisplayValue(resident?['full_name'],
        fallback: 'Resident Account');
    final email = _accountDisplayValue(
        resident?['email'] ?? currentUser?.email,
        fallback: 'No email address');
    final residentType =
    _accountDisplayValue(resident?['resident_type'],
        fallback: 'resident')
        .toUpperCase();
    final status =
    _accountDisplayValue(resident?['status'], fallback: 'active')
        .toUpperCase();
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
          if (_accountError != null && resident == null)
            _buildAccountErrorCard(),

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
                    offset: const Offset(0, 8))
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
                          offset: const Offset(0, 4))
                    ],
                  ),
                  child: CircleAvatar(
                    radius: 44,
                    backgroundColor: const Color(0xFFEADFD6),
                    child: Text(
                      _accountInitials(
                          resident?['full_name']?.toString()),
                      style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: primaryColor),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(name,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: textDark)),
                const SizedBox(height: 6),
                Text(email,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 13, color: Colors.black54)),
                const SizedBox(height: 14),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                          color: primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20)),
                      child: Text(residentType,
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: primaryColor)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20)),
                      child: Text(status,
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: statusColor)),
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
                          value: _accountDisplayValue(
                              resident?['block'])),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildAccountInfoPill(
                          icon: Icons.home_rounded,
                          label: 'Unit',
                          value: _accountDisplayValue(
                              resident?['unit_number'])),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 26),
          _buildAccountSectionTitle('Account Settings'),
          _buildAccountCard(children: [
            _buildAccountListTile(
              icon: Icons.badge_outlined,
              title: 'Personal Details',
              subtitle: 'Manage your personal details and password',
              iconColor: primaryColor,
              onTap: _openPersonalDetails,
              showDivider: false,
            ),
          ]),

          const SizedBox(height: 20),
          _buildAccountSectionTitle('Activity'),
          _buildAccountCard(children: [
            _buildAccountListTile(
              icon: Icons.history_rounded,
              title: 'Booking History',
              subtitle:
              'View pending, approved, and past facility bookings',
              iconColor: const Color(0xFFD49A6A),
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                      const ResidentBookingHistoryPage())),
              showDivider: false,
            ),
          ]),

          const SizedBox(height: 20),
          _buildAccountSectionTitle('Services'),
          _buildAccountCard(children: [
            _buildAccountListTile(
              icon: Icons.badge_outlined,
              title: 'Visitor Pass',
              subtitle:
              'Create and manage visitor QR passes for your guests',
              iconColor: const Color(0xFF6B8E6B),
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                      const VisitorPassListScreen())),
              showDivider: false,
            ),
          ]),

          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: logout,
              icon: const Icon(Icons.logout_rounded,
                  color: Color(0xFFC67B75)),
              label: const Text('Log Out',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFC67B75))),
              style: ElevatedButton.styleFrom(
                elevation: 0,
                backgroundColor: const Color(0xFFFFF1EE),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: !_sessionReady
            ? Center(
            child: CircularProgressIndicator(color: primaryColor))
            : IndexedStack(
          index: currentIndex,
          children: [
            buildHomeTab(),
            buildMyFacilityTab(),
            CommunityChatsListScreen(
                key: ValueKey('chat_${UserSession.uid}')),
            buildAccountTab(),
          ],
        ),
      ),
      floatingActionButton: SizedBox(
        width: 65,
        height: 65,
        child: FloatingActionButton(
          onPressed: handleEmergency,
          backgroundColor: isEmergency
              ? Colors.red
              : (isWaiting ? Colors.orange : Colors.red),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(60)),
          elevation: 6,
          child: Icon(
            isEmergency
                ? Icons.warning
                : (isWaiting ? Icons.access_time : Icons.sos_rounded),
            size: 32,
            color: Colors.white,
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
                offset: const Offset(0, 6))
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
                  icon: Icon(Icons.fitness_center_rounded),
                  label: "Facility"),
              BottomNavigationBarItem(
                  icon: Icon(Icons.chat_bubble_outline_rounded),
                  label: "Chats"),
              BottomNavigationBarItem(
                  icon: Icon(Icons.person_outline_rounded),
                  label: "Account"),
            ],
          ),
        ),
      ),
    );
  }
}


// ─────────────────────────────────────────────────────────────────────────────
// _NotificationSheet  — with All / Announcements / Messages filter tabs
// ─────────────────────────────────────────────────────────────────────────────

class _NotificationSheet extends StatefulWidget {
  final Color primaryColor;
  final Color textDark;
  final bool hasUnreadAnnouncements;
  final Future<List<_NotifItem>> Function() loadItems;
  final void Function(Map<String, dynamic> announcement) onAnnouncementTap;
  final void Function(_NotifItem item) onMessageTap;

  const _NotificationSheet({
    required this.primaryColor,
    required this.textDark,
    required this.hasUnreadAnnouncements,
    required this.loadItems,
    required this.onAnnouncementTap,
    required this.onMessageTap,
  });

  @override
  State<_NotificationSheet> createState() => _NotificationSheetState();
}

class _NotificationSheetState extends State<_NotificationSheet> {
  List<_NotifItem>? _items;
  bool _loading = true;
  String _filter = 'all'; // 'all' | 'announcements' | 'messages'

  @override
  void initState() {
    super.initState();
    widget.loadItems().then((items) {
      if (mounted) setState(() { _items = items; _loading = false; });
    });
  }

  String _formatTimeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'yesterday';
    return '${diff.inDays}d ago';
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final DateTime date = DateTime.parse(dateStr).toLocal();
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      return '${date.day} ${months[date.month - 1]}, ${date.year}';
    } catch (_) {
      return dateStr.substring(0, 10);
    }
  }

  List<_NotifItem> get _filteredItems {
    if (_items == null) return [];
    switch (_filter) {
      case 'announcements':
        return _items!
            .where((i) => i.type == _NotifType.announcement)
            .toList();
      case 'messages':
        return _items!
            .where((i) => i.type == _NotifType.message)
            .toList();
      default:
        return _items!;
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = _items?.length ?? 0;

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (_, scrollController) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFFF5F1ED),
          borderRadius:
          BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            // ── Handle + title ──────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: Column(
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                          color: Colors.black12,
                          borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Text('Notifications',
                          style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: widget.textDark)),
                      const SizedBox(width: 10),
                      if (!_loading && total > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                              color: widget.primaryColor,
                              borderRadius:
                              BorderRadius.circular(10)),
                          child: Text('$total',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // ── Filter chips ──────────────────────────────────
                  if (!_loading && _items != null)
                    _buildFilterBar(),

                  const SizedBox(height: 2),
                ],
              ),
            ),

            // ── Content ─────────────────────────────────────────────
            Expanded(
              child: _loading
                  ? Center(
                  child: CircularProgressIndicator(
                      color: widget.primaryColor))
                  : _filteredItems.isEmpty
                  ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                        Icons.notifications_none_rounded,
                        size: 48,
                        color: widget.primaryColor
                            .withOpacity(0.3)),
                    const SizedBox(height: 12),
                    const Text('No notifications',
                        style: TextStyle(
                            color: Colors.black45)),
                  ],
                ),
              )
                  : ListView.separated(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(
                    20, 8, 20, 32),
                itemCount: _filteredItems.length,
                separatorBuilder: (_, __) =>
                const SizedBox(height: 10),
                itemBuilder: (_, i) {
                  final item = _filteredItems[i];
                  return item.type ==
                      _NotifType.announcement
                      ? _buildAnnouncementTile(
                      item.announcement!)
                      : _buildMessageTile(item);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Filter bar ────────────────────────────────────────────────────────────

  Widget _buildFilterBar() {
    final items = _items!;
    final annCount =
        items.where((i) => i.type == _NotifType.announcement).length;
    final msgCount =
        items.where((i) => i.type == _NotifType.message).length;
    final totalCount = items.length;

    const filters = [
      ('all', 'All'),
      ('announcements', 'Announcements'),
      ('messages', 'Messages'),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((f) {
          final isSelected = _filter == f.$1;
          int count = 0;
          switch (f.$1) {
            case 'all':
              count = totalCount;
            case 'announcements':
              count = annCount;
            case 'messages':
              count = msgCount;
          }

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => setState(() => _filter = f.$1),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: isSelected
                      ? widget.primaryColor
                      : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      f.$2,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isSelected
                            ? Colors.white
                            : Colors.black54,
                      ),
                    ),
                    // Count badge hidden when chip is selected
                    if (count > 0 && !isSelected) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: widget.primaryColor,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$count',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Tiles ─────────────────────────────────────────────────────────────────

  Widget _buildAnnouncementTile(Map<String, dynamic> ann) {
    final title = ann['title']?.toString() ?? 'Notice';
    final content = ann['content']?.toString() ?? '';
    final isUrgent = ann['is_urgent'] ?? false;
    final dateStr = _formatDate(ann['created_at']?.toString());

    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        widget.onAnnouncementTap(ann);
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 3))
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isUrgent
                    ? Colors.red.shade50
                    : widget.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                isUrgent
                    ? Icons.warning_amber_rounded
                    : Icons.campaign_rounded,
                color: isUrgent
                    ? Colors.redAccent
                    : widget.primaryColor,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (isUrgent)
                        Container(
                          margin: const EdgeInsets.only(right: 6),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                                color: Colors.red.shade200),
                          ),
                          child: const Text('URGENT',
                              style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.redAccent)),
                        ),
                      Expanded(
                        child: Text(title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: widget.textDark)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(content,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                          height: 1.4)),
                  const SizedBox(height: 6),
                  Text(dateStr,
                      style: const TextStyle(
                          fontSize: 11, color: Colors.black38)),
                ],
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.arrow_forward_ios_rounded,
                size: 13, color: Colors.black26),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageTile(_NotifItem item) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        widget.onMessageTap(item);
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 3))
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color:
                const Color(0xFF4BC0B8).withOpacity(0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                item.isGroup
                    ? Icons.groups_rounded
                    : Icons.person_rounded,
                color: const Color(0xFF4BC0B8),
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.chatName ?? '',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: widget.textDark)),
                  const SizedBox(height: 3),
                  RichText(
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    text: TextSpan(
                      style: const TextStyle(fontSize: 12),
                      children: [
                        TextSpan(
                          text: '${item.senderName}: ',
                          style: TextStyle(
                              color: widget.primaryColor
                                  .withOpacity(0.8),
                              fontWeight: FontWeight.w600),
                        ),
                        TextSpan(
                          text: item.lastMessage ?? '',
                          style: const TextStyle(
                              color: Colors.black87),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  item.lastTime != null
                      ? _formatTimeAgo(item.lastTime!)
                      : '',
                  style: const TextStyle(
                      fontSize: 10, color: Colors.black38),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                      color: widget.primaryColor,
                      borderRadius: BorderRadius.circular(10)),
                  child: Text(
                    item.unreadCount > 99
                        ? '99+'
                        : '${item.unreadCount}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}