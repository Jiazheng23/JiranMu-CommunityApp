import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:assignment/chat/user_session.dart';
import 'package:assignment/chat/CommunityChatScreen.dart';
import 'package:assignment/chat/in_app_notification_service.dart';
import 'package:assignment/admin/emergency/emergency_list_page.dart';
import 'package:assignment/admin/request/request_list_page.dart';

final _supabase = Supabase.instance.client;

// ── Notification kind enum ────────────────────────────────────────────────────
enum _NotifKind { emergency, request, groupChat, directMessage }

// ── Typed notification model ──────────────────────────────────────────────────
class _NotifItem {
  final _NotifKind kind;
  final String id;
  final String title;
  final String body;
  final DateTime time;
  final bool isRead;
  final int unreadCount;
  final Map<String, dynamic> raw;

  const _NotifItem({
    required this.kind,
    required this.id,
    required this.title,
    required this.body,
    required this.time,
    this.isRead = false,
    this.unreadCount = 0,
    required this.raw,
  });
}

// ─────────────────────────────────────────────────────────────────────────────

class AdminNotificationsPage extends StatefulWidget {
  const AdminNotificationsPage({super.key});

  @override
  State<AdminNotificationsPage> createState() => _AdminNotificationsPageState();
}

class _AdminNotificationsPageState extends State<AdminNotificationsPage> {
  static const Color _primary = Color(0xFF9A4B3C);

  bool _loading = true;
  String _currentUserId = '';
  String _currentUserEmail = '';

  // Track rooms cleared by a tap this session so the badge disappears instantly
  final Set<String> _clearedRooms = {};

  String _filter = 'all'; // 'all' | 'messages' | 'requests' | 'emergency'
  List<_NotifItem> _items = [];

  // ── Init ────────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await UserSession.init();
    _currentUserId = UserSession.uid ?? '';
    _currentUserEmail = UserSession.email ?? '';
    await _fetch();
  }

  // ── Fetch all notification sources in parallel ───────────────────────────

  Future<void> _fetch() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _fetchRequests(),
        _fetchEmergencies(),
        _fetchGroupChatMessages(),
        _fetchDirectMessages(),
      ]);

      final combined = results.expand((l) => l).toList()
        ..sort((a, b) => b.time.compareTo(a.time));

      setState(() {
        _items = combined;
        _loading = false;
      });
    } catch (e) {
      debugPrint('❌ Notifications fetch error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Data fetching ────────────────────────────────────────────────────────

  Future<List<_NotifItem>> _fetchRequests() async {
    final rows = await _supabase
        .from('requests')
        .select('*')
        .eq('status', 'pending')
        .order('created_at', ascending: false)
        .limit(20);

    return (rows as List<dynamic>).map((r) => _NotifItem(
      kind: _NotifKind.request,
      id: r['id']?.toString() ?? '',
      title: r['title'] ?? 'New Request',
      body: r['description'] ?? '',
      time: _parseDate(r['created_at']),
      raw: Map<String, dynamic>.from(r),
    )).toList();
  }

  Future<List<_NotifItem>> _fetchEmergencies() async {
    final rows = await _supabase
        .from('emergency')
        .select('*')
        .eq('status', 'active')
        .order('created_at', ascending: false)
        .limit(20);

    return (rows as List<dynamic>).map((r) => _NotifItem(
      kind: _NotifKind.emergency,
      id: r['id']?.toString() ?? r['emergency_id']?.toString() ?? '',
      title: 'Emergency SOS',
      body: r['description'] ?? r['reason'] ?? 'Immediate attention required.',
      time: _parseDate(r['created_at']),
      raw: Map<String, dynamic>.from(r),
    )).toList();
  }

  Future<List<_NotifItem>> _fetchGroupChatMessages() async {
    if (_currentUserId.isEmpty) return [];

    final groups = await _supabase
        .from('group_chats')
        .select('id, room_id, name, block')
        .eq('created_by', _currentUserId);

    final items = <_NotifItem>[];
    for (final g in (groups as List<dynamic>)) {
      final roomId = g['room_id'] as String;

      // Skip rooms already cleared by a tap this session
      if (_clearedRooms.contains(roomId)) continue;

      final unreadRes = await _supabase
          .from('messages')
          .select('id, content, created_at, sender')
          .eq('room_id', roomId)
          .neq('sender', _currentUserEmail)
          .eq('is_read', false)
          .order('created_at', ascending: false)
          .limit(1);

      final unreadList = unreadRes as List<dynamic>;
      if (unreadList.isEmpty) continue;

      final lastMsg = unreadList.first;
      final unreadCountRes = await _supabase
          .from('messages')
          .select('id')
          .eq('room_id', roomId)
          .neq('sender', _currentUserEmail)
          .eq('is_read', false);

      items.add(_NotifItem(
        kind: _NotifKind.groupChat,
        id: roomId,
        title: g['name'] as String? ?? 'Block ${g['block']}',
        body: lastMsg['content'] as String? ?? '',
        time: _parseDate(lastMsg['created_at']),
        unreadCount: (unreadCountRes as List).length,
        raw: {
          'room_id': roomId,
          'group_id': g['id'],
          'name': g['name'],
        },
      ));
    }
    return items;
  }

  Future<List<_NotifItem>> _fetchDirectMessages() async {
    if (_currentUserId.isEmpty) return [];

    final roomsU1 = await _supabase
        .from('chat_rooms')
        .select('room_id, user1_id, user2_id')
        .eq('user1_id', _currentUserId);
    final roomsU2 = await _supabase
        .from('chat_rooms')
        .select('room_id, user1_id, user2_id')
        .eq('user2_id', _currentUserId);

    final allRooms = [
      ...(roomsU1 as List<dynamic>),
      ...(roomsU2 as List<dynamic>),
    ];

    final items = <_NotifItem>[];
    for (final room in allRooms) {
      final roomId = room['room_id'] as String;

      // Skip rooms already cleared by a tap this session
      if (_clearedRooms.contains(roomId)) continue;

      final otherId = (room['user1_id'] == _currentUserId)
          ? room['user2_id'] as String
          : room['user1_id'] as String;

      final unreadRes = await _supabase
          .from('messages')
          .select('id, content, created_at, sender')
          .eq('room_id', roomId)
          .neq('sender', _currentUserEmail)
          .eq('is_read', false)
          .order('created_at', ascending: false)
          .limit(1);

      final unreadList = unreadRes as List<dynamic>;
      if (unreadList.isEmpty) continue;

      String otherName = 'Resident';
      final profile = await _supabase
          .from('resident')
          .select('full_name')
          .eq('id', otherId)
          .maybeSingle();
      if (profile != null) {
        otherName = profile['full_name']?.toString() ?? otherName;
      }

      final unreadCountRes = await _supabase
          .from('messages')
          .select('id')
          .eq('room_id', roomId)
          .neq('sender', _currentUserEmail)
          .eq('is_read', false);

      items.add(_NotifItem(
        kind: _NotifKind.directMessage,
        id: roomId,
        title: otherName,
        body: unreadList.first['content'] as String? ?? '',
        time: _parseDate(unreadList.first['created_at']),
        unreadCount: (unreadCountRes as List).length,
        raw: {
          'room_id': roomId,
          'other_name': otherName,
        },
      ));
    }
    return items;
  }

  // ── Navigation ───────────────────────────────────────────────────────────

  void _onTap(_NotifItem item) {
    switch (item.kind) {
      case _NotifKind.emergency:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const EmergencyListPage()),
        ).then((_) => _fetch());

      case _NotifKind.request:
        final type = item.raw['type'] as String? ?? '';
        String? targetPageType;
        switch (type.toLowerCase()) {
          case 'resident':
          case 'user':
            targetPageType = 'Users';
          case 'event':
          case 'booking':
            targetPageType = 'Event';
          case 'facility':
            targetPageType = 'Facilities';
          case 'visitor':
            targetPageType = 'Visitor';
          default:
            targetPageType = type.isNotEmpty ? type : null;
        }
        if (targetPageType != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => RequestListPage(type: targetPageType!)),
          ).then((_) => _fetch());
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Unknown request type.')),
          );
        }

      case _NotifKind.groupChat:
      case _NotifKind.directMessage:
        final roomId = item.raw['room_id'] as String;
        // Optimistically clear the badge for this room
        setState(() => _clearedRooms.add(roomId));

        InAppNotificationService.activeRoomId = roomId;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CommunityChatScreen(
              roomId: roomId,
              communityName: item.title,
              currentUserId: _currentUserId,
              currentUser: _currentUserEmail,
              isAdmin: true,
            ),
          ),
        ).then((_) {
          InAppNotificationService.activeRoomId = null;
          // Full refresh when returning so counts reflect actual DB state
          _fetch();
        });
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  DateTime _parseDate(dynamic v) {
    if (v == null) return DateTime.now();
    try {
      return DateTime.parse(v.toString());
    } catch (_) {
      return DateTime.now();
    }
  }

  Color _nameToColor(String name) {
    final hue =
    (name.codeUnits.fold(0, (a, b) => a + b) % 360).toDouble();
    return HSLColor.fromAHSL(1, hue, 0.55, 0.55).toColor();
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final filtered = _items.where((item) {
      switch (_filter) {
        case 'messages':
          return item.kind == _NotifKind.groupChat ||
              item.kind == _NotifKind.directMessage;
        case 'requests':
          return item.kind == _NotifKind.request;
        case 'emergency':
          return item.kind == _NotifKind.emergency;
        default:
          return true;
      }
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F1ED),
      appBar: AppBar(
        title: const Text(
          'Notifications',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w700),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetch,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilterBar(),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                ? _buildEmpty()
                : RefreshIndicator(
              color: _primary,
              onRefresh: _fetch,
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                itemCount: filtered.length,
                separatorBuilder: (_, __) =>
                const SizedBox(height: 8),
                itemBuilder: (_, i) => _buildTile(filtered[i]),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Filter bar ───────────────────────────────────────────────────────────

  Widget _buildFilterBar() {
    const filters = [
      ('all', 'All'),
      ('messages', 'Messages'),
      ('requests', 'Requests'),
      ('emergency', 'Emergency'),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Row(
        children: filters.map((f) {
          final isSelected = _filter == f.$1;

          // Count per filter — only shown when NOT selected
          int count = 0;
          switch (f.$1) {
            case 'messages':
              count = _items
                  .where((i) =>
              i.kind == _NotifKind.groupChat ||
                  i.kind == _NotifKind.directMessage)
                  .fold(0, (s, i) => s + i.unreadCount);
            case 'emergency':
              count = _items
                  .where((i) => i.kind == _NotifKind.emergency)
                  .length;
            case 'requests':
              count = _items
                  .where((i) => i.kind == _NotifKind.request)
                  .length;
            case 'all':
              final msgUnread = _items
                  .where((i) =>
              i.kind == _NotifKind.groupChat ||
                  i.kind == _NotifKind.directMessage)
                  .fold(0, (s, i) => s + i.unreadCount);
              count = _items
                  .where((i) => i.kind == _NotifKind.emergency)
                  .length +
                  _items
                      .where((i) => i.kind == _NotifKind.request)
                      .length +
                  msgUnread;
          }

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => setState(() => _filter = f.$1),
              child: Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: isSelected ? _primary : Colors.grey.shade200,
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
                        color: isSelected ? Colors.white : Colors.black54,
                      ),
                    ),
                    // Show count badge only when chip is NOT selected
                    if (count > 0 && !isSelected) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: _primary,
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

  // ── Tile ─────────────────────────────────────────────────────────────────

  Widget _buildTile(_NotifItem item) {
    final isEmergency = item.kind == _NotifKind.emergency;
    final isMessage = item.kind == _NotifKind.groupChat ||
        item.kind == _NotifKind.directMessage;

    // ── Avatar
    Widget avatar;
    if (item.kind == _NotifKind.emergency) {
      avatar = _iconAvatar(Icons.emergency, Colors.red);
    } else if (item.kind == _NotifKind.request) {
      avatar = _iconAvatar(_requestIcon(item.raw['type'] ?? ''), Colors.blue);
    } else {
      avatar = Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: _nameToColor(item.title).withOpacity(0.2),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Icon(
            item.kind == _NotifKind.groupChat
                ? Icons.groups_rounded
                : Icons.person_rounded,
            color: _nameToColor(item.title),
            size: 20,
          ),
        ),
      );
    }

    // ── Trailing badge
    Widget? trailing;
    final roomId = item.raw['room_id'] as String?;
    final isCleared = roomId != null && _clearedRooms.contains(roomId);

    if (isMessage && item.unreadCount > 0 && !isCleared) {
      trailing = Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: _primary,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          item.unreadCount > 99 ? '99+' : '${item.unreadCount}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
      );
    } else if (!item.isRead && !isCleared) {
      trailing = Container(
        width: 9,
        height: 9,
        decoration: const BoxDecoration(
          color: Colors.redAccent,
          shape: BoxShape.circle,
        ),
      );
    }

    return GestureDetector(
      onTap: () => _onTap(item),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: isEmergency
              ? Border.all(color: Colors.red.shade200, width: 1.5)
              : Border.all(color: Colors.black.withOpacity(0.06)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ListTile(
          contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          leading: avatar,
          title: Text(
            item.title,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color:
              isEmergency ? Colors.red.shade800 : Colors.black87,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 3),
              Text(
                item.body,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style:
                const TextStyle(fontSize: 13, color: Colors.black54),
              ),
              const SizedBox(height: 5),
              Text(
                timeago.format(item.time),
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          trailing: trailing,
        ),
      ),
    );
  }

  // ── Small helpers ────────────────────────────────────────────────────────

  Widget _iconAvatar(IconData icon, Color color) => Container(
    width: 42,
    height: 42,
    decoration: BoxDecoration(
      color: color.withOpacity(0.12),
      shape: BoxShape.circle,
    ),
    child: Icon(icon, color: color, size: 20),
  );

  IconData _requestIcon(String type) {
    switch (type.toLowerCase()) {
      case 'visitor':
        return Icons.directions_walk;
      case 'facility':
      case 'booking':
        return Icons.event_available;
      case 'complaint':
        return Icons.report_problem_outlined;
      case 'resident':
        return Icons.person_add_alt_1;
      default:
        return Icons.notifications_active;
    }
  }

  Widget _buildEmpty() => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.notifications_off_outlined,
            size: 72, color: Colors.grey.shade300),
        const SizedBox(height: 16),
        const Text(
          'All caught up!',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: Colors.black54,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'No new notifications',
          style: TextStyle(color: Colors.grey),
        ),
      ],
    ),
  );
}