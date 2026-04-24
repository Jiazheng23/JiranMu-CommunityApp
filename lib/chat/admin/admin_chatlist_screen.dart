import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:assignment/chat/user_session.dart';

import '../CommunityChatScreen.dart';
import '../CommunityChatsListScreen.dart';
import '../chat_shared_widget.dart';
import '../in_app_notification_service.dart';

final supabase = Supabase.instance.client;

class AdminChatsListScreen extends StatefulWidget {
  const AdminChatsListScreen({Key? key}) : super(key: key);

  @override
  State<AdminChatsListScreen> createState() => _AdminChatsListScreenState();
}

class _AdminChatsListScreenState extends State<AdminChatsListScreen> {
  static const Color _bg = Color(0xFFF5F1ED);
  static const Color _primary = Color(0xFF9A4B3C);
  static const Color _textDark = Color(0xFF2B2B2B);

  bool _loading = true;
  String? _errorMessage;
  String _currentUserId = '';
  String _currentUserEmail = '';
  String _currentUserName = '';
  String _searchQuery = '';
  bool _isSearchActive = false;
  final List<String> _recentSearches = [];
  final TextEditingController _searchController = TextEditingController();
  List<String> _adminBlocks = [];
  List<GroupChatPreview> _adminGroupChats = [];
  bool _fabExpanded = false;
  RealtimeChannel? _realtimeChannel;

  @override
  void initState() {
    super.initState();
    _initAndLoad();
  }

  @override
  void dispose() {
    _realtimeChannel?.unsubscribe();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _initAndLoad() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      await UserSession.init();
      _currentUserId = UserSession.uid ?? '';
      _currentUserEmail = UserSession.email ?? '';
      await _loadAdminData();
    } catch (e) {
      setState(() {
        _loading = false;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _loadAdminData() async {
    try {
      final adminProfile = await supabase
          .from('admin_new')
          .select('full_name, email')
          .eq('id', _currentUserId)
          .maybeSingle();
      if (adminProfile != null) {
        _currentUserName = adminProfile['full_name']?.toString() ?? '';
      }

      final blocksData = await supabase
          .from('resident')
          .select('block')
          .neq('block', '');
      final blocks = (blocksData as List)
          .map((e) => e['block']?.toString() ?? '')
          .where((s) => s.isNotEmpty)
          .toSet()
          .toList()
        ..sort();

      final groupsData = await supabase
          .from('group_chats')
          .select('id, room_id, block, name')
          .eq('created_by', _currentUserId);

      final groups = <GroupChatPreview>[];
      for (final g in (groupsData as List<dynamic>)) {
        final roomId = g['room_id'] as String;
        final msgs = await supabase
            .from('messages')
            .select('content, created_at')
            .eq('room_id', roomId)
            .order('created_at', ascending: false)
            .limit(1);

        final msgList = msgs as List<dynamic>;
        final lastMsg = msgList.isNotEmpty
            ? msgList[0]['content'] as String
            : 'No messages yet';
        final lastTime = msgList.isNotEmpty
            ? DateTime.parse(msgList[0]['created_at'] as String)
            : DateTime.now();

        final unreadAdminRes = await supabase
            .from('messages')
            .select('id')
            .eq('room_id', roomId)
            .neq('sender', _currentUserId)
            .eq('is_read', false);
        final int unreadCount = (unreadAdminRes as List<dynamic>).length;

        groups.add(GroupChatPreview(
          groupId: g['id'] as String,
          roomId: roomId,
          name: g['name'] as String? ?? 'Block ${g['block']}',
          block: g['block']?.toString() ?? '',
          lastMessage: lastMsg,
          lastTime: lastTime,
          unreadCount: unreadCount,
        ));
      }
      groups.sort((a, b) => b.lastTime.compareTo(a.lastTime));

      setState(() {
        _adminBlocks = blocks;
        _adminGroupChats = groups;
        _loading = false;
      });

      _setupRealtimeListener();
    } catch (e, stack) {
      debugPrint('❌ Admin load error: $e\n$stack');
      setState(() {
        _loading = false;
        _errorMessage = e.toString();
      });
    }
  }

  void _setupRealtimeListener() {
    _realtimeChannel?.unsubscribe();
    final watchedRoomIds = _adminGroupChats.map((g) => g.roomId).toSet();
    if (watchedRoomIds.isEmpty) return;

    _realtimeChannel =
    supabase.channel('admin_chat_list_${_currentUserId}')
      ..onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'messages',
        callback: (payload) {
          final row = payload.newRecord;
          final roomId = row['room_id'] as String? ?? '';
          final sender = row['sender'] as String? ?? '';
          final content = row['content'] as String? ?? '';

          if (!watchedRoomIds.contains(roomId)) return;
          if (sender == _currentUserEmail) return;

          final group = _adminGroupChats.firstWhere(
                (g) => g.roomId == roomId,
            orElse: () => GroupChatPreview(
              groupId: '',
              roomId: roomId,
              name: 'Group Chat',
              block: '',
              lastMessage: '',
              lastTime: DateTime.now(),
            ),
          );

          InAppNotificationService.instance.show(InAppNotification(
            title: group.name,
            body: content,
            roomId: roomId,
            onTap: () => _openAdminGroupChat(group),
          ));

          _loadAdminData();
        },
      )
      ..subscribe();
  }

  void _openAdminGroupChat(GroupChatPreview group) async {
    InAppNotificationService.activeRoomId = group.roomId;
    await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CommunityChatScreen(
            roomId: group.roomId,
            communityName: group.name,
            currentUserId: _currentUserId,
            currentUser: _currentUserEmail,
            isAdmin: true,
          ),
        ));
    InAppNotificationService.activeRoomId = null;
    _loadAdminData();
  }

  // ── Helpers ──────────────────────────────────

  String _formatTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min';
    if (diff.inHours < 24) return '${diff.inHours} hr';
    if (diff.inDays == 1) return '1 day';
    return '${diff.inDays} days';
  }

  void _addRecentSearch(String query) {
    if (query.trim().isEmpty) return;
    setState(() {
      _recentSearches.remove(query);
      _recentSearches.insert(0, query);
      if (_recentSearches.length > 5) _recentSearches.removeLast();
    });
  }

  String _getInitials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  Color _nameToColor(String name) {
    final hue =
    (name.codeUnits.fold(0, (a, b) => a + b) % 360).toDouble();
    return HSLColor.fromAHSL(1, hue, 0.55, 0.55).toColor();
  }

  // ── UI Helpers ────────────────────────────────

  Widget _buildProfileHeader(
      {required String name, required String subtitle}) {
    final displayName = name.isNotEmpty ? name : 'Hello';
    final totalUnread =
    _adminGroupChats.fold<int>(0, (sum, g) => sum + g.unreadCount);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
      child: Row(children: [
        // Avatar
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                _nameToColor(displayName),
                _nameToColor(displayName).withOpacity(0.7)
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Center(
              child: Text(_getInitials(displayName),
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 15))),
        ),
        const SizedBox(width: 12),
        // Name & subtitle
        Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(displayName,
                      style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: _textDark)),
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black45,
                          fontWeight: FontWeight.w500)),
                ])),
      ]),
    );
  }

  Widget _buildDivider() => Container(
    height: 1,
    margin: const EdgeInsets.symmetric(horizontal: 22),
    color: Colors.black.withOpacity(0.07),
  );

  Widget _buildSectionLabel(String label, {int? count}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 12, 22, 8),
      child: Row(children: [
        Text(label,
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: _primary,
                letterSpacing: 1.2)),
        if (count != null) ...[
          const SizedBox(width: 8),
          CountBadge(count: count, color: _primary),
        ],
      ]),
    );
  }

  Widget _buildSearchBar({required String hint}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 4, 22, 4),
      child: Container(
        height: 53,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _isSearchActive
                ? _primary.withOpacity(0.5)
                : Colors.transparent,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 3))
          ],
        ),
        child: TextField(
          controller: _searchController,
          onTap: () => setState(() => _isSearchActive = true),
          onChanged: (v) =>
              setState(() => _searchQuery = v.toLowerCase()),
          onSubmitted: (v) {
            _addRecentSearch(v.trim());
            setState(() => _isSearchActive = false);
          },
          style: const TextStyle(fontSize: 14, color: _textDark),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle:
            const TextStyle(color: Colors.black38, fontSize: 14),
            prefixIcon: const Icon(Icons.search_rounded,
                color: Colors.black38, size: 20),
            suffixIcon: _searchQuery.isNotEmpty
                ? GestureDetector(
              onTap: () {
                _searchController.clear();
                setState(() {
                  _searchQuery = '';
                  _isSearchActive = false;
                });
              },
              child: const Icon(Icons.close_rounded,
                  color: Colors.black38, size: 18),
            )
                : null,
            border: InputBorder.none,
            contentPadding:
            const EdgeInsets.symmetric(vertical: 10),
          ),
        ),
      ),
    );
  }

  Widget _buildRecentSearches() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 4, 22, 4),
      child:
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('RECENT',
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: Colors.black38,
                letterSpacing: 1.1)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: _recentSearches
              .map((s) => GestureDetector(
            onTap: () {
              _searchController.text = s;
              setState(() => _searchQuery = s.toLowerCase());
            },
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(20)),
              child:
              Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.history_rounded,
                    size: 13, color: Colors.black45),
                const SizedBox(width: 5),
                Text(s,
                    style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                        fontWeight: FontWeight.w500)),
              ]),
            ),
          ))
              .toList(),
        ),
      ]),
    );
  }

  Widget _buildErrorState() {
    return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.error_outline, size: 56, color: Colors.redAccent),
            const SizedBox(height: 16),
            const Text('Something went wrong',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2B2B2B))),
            const SizedBox(height: 8),
            Text(_errorMessage ?? '',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: Colors.black45)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _initAndLoad,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12))),
            ),
          ]),
        ));
  }

  // ── Body ──────────────────────────────────────

  Widget _buildBody() {
    final filtered = _searchQuery.isEmpty
        ? _adminGroupChats
        : _adminGroupChats
        .where((g) =>
    g.name.toLowerCase().contains(_searchQuery) ||
        g.block.toLowerCase().contains(_searchQuery))
        .toList();

    return Stack(children: [
      // ── Wrap CustomScrollView with RefreshIndicator ──
      RefreshIndicator(
        color: _primary,
        onRefresh: _loadAdminData, // reuses existing load method
        child: CustomScrollView(slivers: [
          SliverToBoxAdapter(
              child: _buildProfileHeader(
                  name: _currentUserName, subtitle: 'Administrator')),
          SliverToBoxAdapter(child: _buildDivider()),
          SliverToBoxAdapter(
              child: _buildSearchBar(hint: 'Search group chats…')),
          if (_isSearchActive &&
              _searchQuery.isEmpty &&
              _recentSearches.isNotEmpty)
            SliverToBoxAdapter(child: _buildRecentSearches()),
          if (_searchQuery.isNotEmpty)
            SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(22, 8, 22, 0),
                  child: Text(
                      '${filtered.length} result${filtered.length == 1 ? '' : 's'} for "$_searchQuery"',
                      style: const TextStyle(fontSize: 12, color: Colors.black45)),
                )),
          if (_adminGroupChats.isNotEmpty)
            SliverToBoxAdapter(
                child: _buildSectionLabel('GROUP CHATS',
                    count: _adminGroupChats.length)),
          _buildAdminGroupSliver(filtered),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ]),
      ),
      Positioned(right: 18, bottom: 18, child: _buildAdminFab()),
    ]);
  }

  Widget _buildAdminGroupSliver(List<GroupChatPreview> filtered) {
    if (filtered.isEmpty) {
      return SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: 40),
            child:
            Column(mainAxisSize: MainAxisSize.min, children: const [
              Icon(Icons.groups_outlined, size: 56, color: Colors.black26),
              SizedBox(height: 12),
              Text(
                  'No group chats yet.\nUse + to create a block group chat.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.black45, height: 1.6)),
            ]),
          ));
    }
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
                (context, i) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: GroupChatTile(
                    group: filtered[i],
                    primaryColor: _primary,
                    formatTime: _formatTime,
                    isAdmin: true,
                    searchQuery: _searchQuery,
                    onTap: () => _openAdminGroupChat(filtered[i]))),
            childCount: filtered.length,
          )),
    );
  }

  Widget _buildAdminFab() {
    return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (_fabExpanded) ...[
            FabOption(
              label: 'New Group',
              icon: Icons.group_add_rounded,
              color: _primary,
              onTap: () {
                setState(() => _fabExpanded = false);
              },
            ),
            const SizedBox(height: 12),
          ],
          GestureDetector(
            onTap: () =>
                setState(() => _fabExpanded = !_fabExpanded),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: _fabExpanded ? Colors.black87 : _primary,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: (_fabExpanded ? Colors.black : _primary)
                        .withOpacity(0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  )
                ],
              ),
              child: AnimatedRotation(
                turns: _fabExpanded ? 0.125 : 0,
                duration: const Duration(milliseconds: 200),
                child: const Icon(Icons.add_rounded,
                    color: Colors.white, size: 28),
              ),
            ),
          ),
        ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _errorMessage != null
              ? _buildErrorState()
              : _buildBody()),
    );
  }
}