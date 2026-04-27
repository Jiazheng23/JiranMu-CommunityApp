import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:assignment/chat/user_session.dart';

import '../../resident/ResidentInvitationsWidget.dart';
import '../CommunityChatScreen.dart';
import '../chat_shared_widget.dart';
import '../in_app_notification_service.dart';

final supabase = Supabase.instance.client;

class ResidentChatsListScreen extends StatefulWidget {
  const ResidentChatsListScreen({Key? key}) : super(key: key);

  @override
  State<ResidentChatsListScreen> createState() =>
      _ResidentChatsListScreenState();
}

class _ResidentChatsListScreenState extends State<ResidentChatsListScreen> {
  static const Color _bg       = Color(0xFFF5F1ED);
  static const Color _primary  = Color(0xFF9A4B3C);
  static const Color _accent   = Color(0xFFF26A3D);
  static const Color _textDark = Color(0xFF2B2B2B);

  bool    _loading          = true;
  String? _errorMessage;
  String  _currentUserId    = '';
  String  _currentUserEmail = '';
  String  _currentUserName  = '';
  String  _currentUserBlock = '';
  String  _searchQuery      = '';
  String  _filter           = 'all';
  bool    _isSearchActive   = false;

  final List<String>          _recentSearches   = [];
  final TextEditingController _searchController = TextEditingController();

  List<ResidentProfile>    _blockNeighbours    = [];
  List<ConversationPreview> _conversations     = [];
  List<GroupChatPreview>   _residentGroupChats = [];
  RealtimeChannel?         _realtimeChannel;

  // ── Lifecycle ─────────────────────────────────────────────────────────────

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

  // ── Init & load ───────────────────────────────────────────────────────────

  Future<void> _initAndLoad() async {
    setState(() {
      _loading      = true;
      _errorMessage = null;
    });
    try {
      await UserSession.init();
      _currentUserId    = UserSession.uid   ?? '';
      _currentUserEmail = UserSession.email ?? '';
      await _loadResidentData();
    } catch (e) {
      setState(() {
        _loading      = false;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _loadResidentData() async {
    try {
      final myProfile = await supabase
          .from('resident')
          .select('full_name, email, block')
          .eq('id', _currentUserId)
          .maybeSingle();

      if (myProfile == null) {
        setState(() => _loading = false);
        return;
      }

      final myBlock = myProfile['block'] as String? ?? '';
      if (myBlock.isEmpty) {
        setState(() => _loading = false);
        return;
      }

      _currentUserName  = myProfile['full_name']?.toString() ?? '';
      _currentUserBlock = myBlock;

      // ── Neighbours ──────────────────────────────────────────────────────
      final neighboursData = await supabase
          .from('resident')
          .select('id, full_name, email, block')
          .eq('block', myBlock)
          .neq('id', _currentUserId);

      final neighbours = (neighboursData as List<dynamic>)
          .map((e) => ResidentProfile.fromMap(e as Map<String, dynamic>))
          .toList();

      // ── Chat rooms — fetch both orderings, then deduplicate ─────────────
      final roomsAsUser1 = await supabase
          .from('chat_rooms')
          .select('room_id, user1_id, user2_id')
          .eq('user1_id', _currentUserId);

      final roomsAsUser2 = await supabase
          .from('chat_rooms')
          .select('room_id, user1_id, user2_id')
          .eq('user2_id', _currentUserId);

      final allRooms = [
        ...(roomsAsUser1 as List<dynamic>),
        ...(roomsAsUser2 as List<dynamic>),
      ];

      // FIX: only keep the FIRST (oldest) room per user pair to avoid
      // duplicate-room issues that cause 406 errors downstream.
      final Map<String, String> userRoomMap = {};
      for (final row in allRooms) {
        final roomId  = row['room_id']  as String;
        final u1      = row['user1_id'] as String;
        final u2      = row['user2_id'] as String;
        final otherId = (u1 == _currentUserId) ? u2 : u1;
        if (!userRoomMap.containsKey(otherId)) {
          userRoomMap[otherId] = roomId;
        }
      }

      // ── DM conversation previews ─────────────────────────────────────────
      final convos = <ConversationPreview>[];
      for (final neighbour in neighbours) {
        final roomId = userRoomMap[neighbour.id];
        if (roomId == null) continue;

        final msgs = await supabase
            .from('messages')
            .select('content, created_at, sender')
            .eq('room_id', roomId)
            .order('created_at', ascending: false)
            .limit(1);

        final msgList = msgs as List<dynamic>;
        final lastMsg = msgList.isNotEmpty
            ? friendlyPreview(msgList[0]['content'] as String)
            : 'Tap to start chatting';
        final lastTime = msgList.isNotEmpty
            ? DateTime.parse(msgList[0]['created_at'] as String)
            : DateTime.now();

        final unreadMsgsRes = await supabase
            .from('messages')
            .select('id')
            .eq('room_id', roomId)
            .neq('sender', _currentUserEmail)
            .eq('is_read', false);
        final int unreadCount = (unreadMsgsRes as List<dynamic>).length;

        convos.add(ConversationPreview(
          resident:    neighbour,
          lastMessage: lastMsg,
          lastTime:    lastTime,
          roomId:      roomId,
          unreadCount: unreadCount,
        ));
      }
      convos.sort((a, b) => b.lastTime.compareTo(a.lastTime));

      // ── Group chat previews ──────────────────────────────────────────────
      final invitations = await supabase
          .from('group_chat_invitations')
          .select('group_chat_id, status')
          .eq('invited_user_id', _currentUserId)
          .eq('status', 'accepted');

      final groupChats = <GroupChatPreview>[];
      for (final inv in (invitations as List<dynamic>)) {
        final groupChatId = inv['group_chat_id'] as String;
        final groupData   = await supabase
            .from('group_chats')
            .select('id, room_id, block, name')
            .eq('id', groupChatId)
            .maybeSingle();

        if (groupData == null) continue;

        final roomId  = groupData['room_id'] as String;
        final msgs    = await supabase
            .from('messages')
            .select('content, created_at')
            .eq('room_id', roomId)
            .order('created_at', ascending: false)
            .limit(1);

        final msgList = msgs as List<dynamic>;
        final lastMsg  = msgList.isNotEmpty
            ? msgList[0]['content'] as String
            : 'No messages yet';
        final lastTime = msgList.isNotEmpty
            ? DateTime.parse(msgList[0]['created_at'] as String)
            : DateTime.now();

        final unreadGroupRes = await supabase
            .from('messages')
            .select('id')
            .eq('room_id', roomId)
            .neq('sender', _currentUserEmail)
            .eq('is_read', false);
        final int unreadCount = (unreadGroupRes as List<dynamic>).length;

        groupChats.add(GroupChatPreview(
          groupId:     groupData['id']   as String,
          roomId:      roomId,
          name:        groupData['name'] as String? ??
              'Block ${groupData['block']}',
          block:       groupData['block']?.toString() ?? '',
          lastMessage: lastMsg,
          lastTime:    lastTime,
          unreadCount: unreadCount,
        ));
      }
      groupChats.sort((a, b) => b.lastTime.compareTo(a.lastTime));

      setState(() {
        _blockNeighbours    = neighbours;
        _conversations      = convos;
        _residentGroupChats = groupChats;
        _loading            = false;
      });

      _setupRealtimeListener();
    } catch (e, stack) {
      debugPrint('❌ Resident load error: $e\n$stack');
      setState(() {
        _loading      = false;
        _errorMessage = e.toString();
      });
    }
  }

  // ── Realtime ──────────────────────────────────────────────────────────────

  void _setupRealtimeListener() {
    _realtimeChannel?.unsubscribe();

    final groupRoomIds = _residentGroupChats.map((g) => g.roomId).toSet();
    final dmRoomIds    = _conversations.map((c) => c.roomId).toSet();
    final allRoomIds   = {...groupRoomIds, ...dmRoomIds};
    if (allRoomIds.isEmpty) return;

    _realtimeChannel =
    supabase.channel('resident_chat_list_$_currentUserId')
      ..onPostgresChanges(
        event:    PostgresChangeEvent.insert,
        schema:   'public',
        table:    'messages',
        callback: (payload) {
          final row     = payload.newRecord;
          final roomId  = row['room_id'] as String? ?? '';
          final sender  = row['sender']  as String? ?? '';
          final content = row['content'] as String? ?? '';

          if (!allRoomIds.contains(roomId)) return;
          if (sender == _currentUserEmail) return;

          String        notifTitle = 'New Message';
          VoidCallback? onTap;

          if (groupRoomIds.contains(roomId)) {
            final group = _residentGroupChats.firstWhere(
                  (g) => g.roomId == roomId,
              orElse: () => GroupChatPreview(
                groupId:     '',
                roomId:      roomId,
                name:        'Group Chat',
                block:       '',
                lastMessage: '',
                lastTime:    DateTime.now(),
              ),
            );
            notifTitle = group.name;
            onTap      = () => _openResidentGroupChat(group);
          } else if (dmRoomIds.contains(roomId)) {
            final convo = _conversations.firstWhere(
                  (c) => c.roomId == roomId,
              orElse: () => _conversations.first,
            );
            notifTitle = convo.resident.name;
            onTap      = () => _openOrCreateResidentDM(convo.resident);
          }

          InAppNotificationService.instance.show(InAppNotification(
            title:  notifTitle,
            body:   friendlyPreview(content),
            roomId: roomId,
            onTap:  onTap,
          ));

          _loadResidentData();
        },
      )
      ..subscribe();
  }

  // ── Room ID generator ─────────────────────────────────────────────────────

  Future<String> _generateRoomId() async {
    final existing = await supabase.from('chat_rooms').select('room_id');
    final ids = (existing as List<dynamic>)
        .map((e) => e['room_id']?.toString() ?? '')
        .where((id) => id.startsWith('ROOM_'))
        .map((id) => int.tryParse(id.replaceFirst('ROOM_', '')) ?? 0)
        .toList();
    final nextNum =
    ids.isEmpty ? 1 : (ids.reduce((a, b) => a > b ? a : b) + 1);
    return 'ROOM_${nextNum.toString().padLeft(2, '0')}';
  }

  // ── Open / create DM ──────────────────────────────────────────────────────

  Future<void> _openOrCreateResidentDM(ResidentProfile resident) async {
    try {
      String? roomId;

      // FIX: use .limit(1) instead of .maybeSingle() so that duplicate rows
      // in the DB never cause a 406 "multiple rows returned" crash.
      final asUser1 = await supabase
          .from('chat_rooms')
          .select('room_id')
          .eq('user1_id', _currentUserId)
          .eq('user2_id', resident.id)
          .order('created_at', ascending: true)
          .limit(1);

      if ((asUser1 as List).isNotEmpty) {
        roomId = asUser1.first['room_id'] as String;
      } else {
        final asUser2 = await supabase
            .from('chat_rooms')
            .select('room_id')
            .eq('user1_id', resident.id)
            .eq('user2_id', _currentUserId)
            .order('created_at', ascending: true)
            .limit(1);

        if ((asUser2 as List).isNotEmpty) {
          roomId = asUser2.first['room_id'] as String;
        }
      }

      // No room exists yet — create one
      if (roomId == null) {
        roomId = await _generateRoomId();
        await supabase.from('chat_rooms').insert({
          'room_id':  roomId,
          'user1_id': _currentUserId,
          'user2_id': resident.id,
        });
      }

      if (!mounted) return;
      InAppNotificationService.activeRoomId = roomId;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CommunityChatScreen(
            roomId:        roomId!,
            communityName: resident.name,
            currentUserId: _currentUserId,
            currentUser:   _currentUserEmail,
            isAdmin:       false,
          ),
        ),
      );
      InAppNotificationService.activeRoomId = null;
      _loadResidentData();
    } catch (e, stack) {
      debugPrint('❌ Error opening DM: $e\n$stack');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not open chat: $e')));
      }
    }
  }

  // ── Open group chat ───────────────────────────────────────────────────────

  void _openResidentGroupChat(GroupChatPreview group) async {
    InAppNotificationService.activeRoomId = group.roomId;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CommunityChatScreen(
          roomId:        group.roomId,
          communityName: group.name,
          currentUserId: _currentUserId,
          currentUser:   _currentUserEmail,
          isAdmin:       false,
        ),
      ),
    );
    InAppNotificationService.activeRoomId = null;
    _loadResidentData();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _formatTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1)  return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min';
    if (diff.inHours   < 24) return '${diff.inHours} hr';
    if (diff.inDays    == 1) return '1 day';
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
    if (parts.isEmpty)    return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  Color _nameToColor(String name) {
    final hue =
    (name.codeUnits.fold(0, (a, b) => a + b) % 360).toDouble();
    return HSLColor.fromAHSL(1, hue, 0.55, 0.55).toColor();
  }

  // ── UI helpers ────────────────────────────────────────────────────────────

  Widget _buildProfileHeader({
    required String name,
    required String subtitle,
  }) {
    final displayName = name.isNotEmpty ? name : 'Hello';
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
      child: Row(children: [
        Container(
          width:  42,
          height: 42,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                _nameToColor(displayName),
                _nameToColor(displayName).withOpacity(0.7),
              ],
              begin: Alignment.topLeft,
              end:   Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Center(
            child: Text(
              _getInitials(displayName),
              style: const TextStyle(
                  color:      Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize:   15),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(displayName,
                  style: const TextStyle(
                      fontSize:   17,
                      fontWeight: FontWeight.w800,
                      color:      _textDark)),
              Text(subtitle,
                  style: const TextStyle(
                      fontSize:   12,
                      color:      Colors.black45,
                      fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _buildDivider() => Container(
    height: 1,
    margin: const EdgeInsets.symmetric(horizontal: 22),
    color:  Colors.black.withOpacity(0.07),
  );

  Widget _buildFilterChip(String label, String value,
      {int totalUnread = 0}) {
    final isSelected = _filter == value;
    return GestureDetector(
      onTap: () => setState(() => _filter = value),
      child: Container(
        margin:  const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color:        isSelected ? _primary : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color:      isSelected ? Colors.white : Colors.black54,
            fontWeight: FontWeight.w600,
            fontSize:   13,
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar({required String hint}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 4, 22, 4),
      child: Container(
        height: 53,
        decoration: BoxDecoration(
          color:        Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _isSearchActive
                ? _primary.withOpacity(0.5)
                : Colors.transparent,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
                color:      Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset:     const Offset(0, 3)),
          ],
        ),
        child: TextField(
          controller: _searchController,
          onTap:      () => setState(() => _isSearchActive = true),
          onChanged:  (v) => setState(() => _searchQuery = v.toLowerCase()),
          onSubmitted: (v) {
            _addRecentSearch(v.trim());
            setState(() => _isSearchActive = false);
          },
          style: const TextStyle(fontSize: 16, color: _textDark),
          decoration: InputDecoration(
            hintText:   hint,
            hintStyle:  const TextStyle(color: Colors.black38, fontSize: 14),
            prefixIcon: const Icon(Icons.search_rounded,
                color: Colors.black38, size: 20),
            suffixIcon: _searchQuery.isNotEmpty
                ? GestureDetector(
              onTap: () {
                _searchController.clear();
                setState(() {
                  _searchQuery    = '';
                  _isSearchActive = false;
                });
              },
              child: const Icon(Icons.close_rounded,
                  color: Colors.black38, size: 18),
            )
                : null,
            border:         InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 10),
          ),
        ),
      ),
    );
  }

  Widget _buildRecentSearches() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 4, 22, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('RECENT',
              style: TextStyle(
                  fontSize:      10,
                  fontWeight:    FontWeight.w800,
                  color:         Colors.black38,
                  letterSpacing: 1.1)),
          const SizedBox(height: 8),
          Wrap(
            spacing:    8,
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
                    color:        Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(20)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.history_rounded,
                        size: 13, color: Colors.black45),
                    const SizedBox(width: 5),
                    Text(s,
                        style: const TextStyle(
                            fontSize:   12,
                            color:      Colors.black54,
                            fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline,
                size: 56, color: Colors.redAccent),
            const SizedBox(height: 16),
            const Text('Something went wrong',
                style: TextStyle(
                    fontSize:   18,
                    fontWeight: FontWeight.w700,
                    color:      Color(0xFF2B2B2B))),
            const SizedBox(height: 8),
            Text(_errorMessage ?? '',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 12, color: Colors.black45)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _initAndLoad,
              icon:      const Icon(Icons.refresh),
              label:     const Text('Retry'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12))),
            ),
          ],
        ),
      ),
    );
  }

  // ── Body ──────────────────────────────────────────────────────────────────

  Widget _buildBody() {
    final filteredConvos = _searchQuery.isEmpty
        ? _conversations
        : _conversations
        .where((c) => c.resident.name
        .toLowerCase()
        .contains(_searchQuery))
        .toList();

    final filteredGroupChats = _searchQuery.isEmpty
        ? _residentGroupChats
        : _residentGroupChats
        .where((g) =>
    g.name.toLowerCase().contains(_searchQuery) ||
        g.block.toLowerCase().contains(_searchQuery))
        .toList();

    final List<Map<String, dynamic>> combinedList = [];
    if (_filter == 'all' || _filter == 'group') {
      combinedList.addAll(
          filteredGroupChats.map((g) => {'type': 'group', 'data': g}));
    }
    if (_filter == 'all' || _filter == 'dm') {
      combinedList.addAll(
          filteredConvos.map((c) => {'type': 'dm', 'data': c}));
    }
    combinedList.sort((a, b) {
      final aTime = a['type'] == 'group'
          ? (a['data'] as GroupChatPreview).lastTime
          : (a['data'] as ConversationPreview).lastTime;
      final bTime = b['type'] == 'group'
          ? (b['data'] as GroupChatPreview).lastTime
          : (b['data'] as ConversationPreview).lastTime;
      return bTime.compareTo(aTime);
    });

    final totalUnread = combinedList.fold<int>(
      0,
          (sum, item) => item['type'] == 'group'
          ? sum + (item['data'] as GroupChatPreview).unreadCount
          : sum + (item['data'] as ConversationPreview).unreadCount,
    );

    return RefreshIndicator(
      color:     _primary,
      onRefresh: _loadResidentData,
      child: CustomScrollView(slivers: [
        SliverToBoxAdapter(
            child: _buildProfileHeader(
                name:     _currentUserName,
                subtitle: 'Block $_currentUserBlock')),
        SliverToBoxAdapter(
            child: _buildSearchBar(hint: 'Search neighbours, groups…')),
        if (_isSearchActive &&
            _searchQuery.isEmpty &&
            _recentSearches.isNotEmpty)
          SliverToBoxAdapter(child: _buildRecentSearches()),
        if (_searchQuery.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 8, 22, 0),
              child: Text(
                '${combinedList.length} result${combinedList.length == 1 ? '' : 's'} for "$_searchQuery"',
                style: const TextStyle(fontSize: 12, color: Colors.black45),
              ),
            ),
          ),
        if (_searchQuery.isEmpty) ...[
          SliverToBoxAdapter(child: _buildNeighboursStrip()),
          SliverToBoxAdapter(child: _buildDivider()),
          const SliverToBoxAdapter(child: SizedBox(height: 6)),
        ],
        if (_searchQuery.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 6, 22, 8),
              child: Row(children: [
                _buildFilterChip('All',    'all',   totalUnread: totalUnread),
                _buildFilterChip('Direct', 'dm'),
                _buildFilterChip('Groups', 'group'),
              ]),
            ),
          ),
        SliverToBoxAdapter(
            child: ResidentInvitationsWidget(
              currentUserId: _currentUserId,
              currentUser:   _currentUserEmail,
            )),
        if (combinedList.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.chat_bubble_outline_rounded,
                      size: 48, color: Colors.black26),
                  SizedBox(height: 12),
                  Text(
                    'No conversations yet.\nStart chatting now!',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.black45, height: 1.6),
                  ),
                ],
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(22, 4, 22, 100),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                    (context, i) {
                  final item = combinedList[i];
                  if (item['type'] == 'group') {
                    final group = item['data'] as GroupChatPreview;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: GroupChatTile(
                        group:        group,
                        primaryColor: _primary,
                        formatTime:   _formatTime,
                        isAdmin:      false,
                        searchQuery:  _searchQuery,
                        onTap: () => _openResidentGroupChat(group),
                      ),
                    );
                  } else {
                    final convo = item['data'] as ConversationPreview;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: ConversationTile(
                        preview:      convo,
                        primaryColor: _primary,
                        accentColor:  _accent,
                        formatTime:   _formatTime,
                        searchQuery:  _searchQuery,
                        onTap: () =>
                            _openOrCreateResidentDM(convo.resident),
                      ),
                    );
                  }
                },
                childCount: combinedList.length,
              ),
            ),
          ),
      ]),
    );
  }

  Widget _buildNeighboursStrip() {
    if (_blockNeighbours.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(22, 16, 22, 8),
        child: Text('No neighbours found in your block.',
            style: TextStyle(color: Colors.black45, fontSize: 13)),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 14, 22, 10),
          child: Row(children: [
            Text('IN YOUR BLOCK',
                style: TextStyle(
                    fontSize:      11,
                    fontWeight:    FontWeight.w800,
                    color:         _primary,
                    letterSpacing: 1.2)),
            const SizedBox(width: 8),
            CountBadge(count: _blockNeighbours.length, color: _primary),
            const SizedBox(width: 8),
            Text('· tap to chat',
                style: TextStyle(
                    fontSize:   11,
                    color:      Colors.black38,
                    fontStyle:  FontStyle.italic)),
          ]),
        ),
        SizedBox(
          height: 104,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding:         const EdgeInsets.symmetric(horizontal: 22),
            itemCount:       _blockNeighbours.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, i) => NeighbourCard(
              profile:      _blockNeighbours[i],
              primaryColor: _primary,
              isOnline:     i % 3 == 0,
              onTap: () => _openOrCreateResidentDM(_blockNeighbours[i]),
            ),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: _loading
            ? const Center(
            child: CircularProgressIndicator(
                color: Color(0xFF9A4B3C)))
            : _errorMessage != null
            ? _buildErrorState()
            : _buildBody(),
      ),
    );
  }
}