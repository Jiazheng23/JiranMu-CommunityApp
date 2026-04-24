import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:assignment/chat/user_session.dart';
import 'package:assignment/resident/ResidentInvitationsWidget.dart';
import 'CommunityChatScreen.dart';

final supabase = Supabase.instance.client;

// ─────────────────────────────────────────────
// Models
// ─────────────────────────────────────────────

class ResidentProfile {
  final String id;
  final String name;
  final String block;
  final String email;

  ResidentProfile({
    required this.id,
    required this.name,
    required this.block,
    required this.email,
  });

  factory ResidentProfile.fromMap(Map<String, dynamic> map) => ResidentProfile(
    id: map['id']?.toString() ?? '',
    name: map['full_name']?.toString() ?? 'Unknown',
    block: map['block']?.toString() ?? '',
    email: map['email']?.toString() ?? '',
  );

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  String get firstName => name.trim().split(RegExp(r'\s+')).first;

  Color get avatarColor {
    final hue = (name.codeUnits.fold(0, (a, b) => a + b) % 360).toDouble();
    return HSLColor.fromAHSL(1, hue, 0.55, 0.55).toColor();
  }
}

class ConversationPreview {
  final ResidentProfile resident;
  final String lastMessage;
  final DateTime lastTime;
  final int unreadCount;
  final String roomId;

  ConversationPreview({
    required this.resident,
    required this.lastMessage,
    required this.lastTime,
    required this.roomId,
    int? unreadCount,
  }) : unreadCount = unreadCount ?? 0;
}

class GroupChatPreview {
  final String groupId;
  final String roomId;
  final String name;
  final String block;
  final String lastMessage;
  final DateTime lastTime;
  final int unreadCount;

  GroupChatPreview({
    required this.groupId,
    required this.roomId,
    required this.name,
    required this.block,
    required this.lastMessage,
    required this.lastTime,
    int? unreadCount,
  }) : unreadCount = unreadCount ?? 0;
}

// ─────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────

class CommunityChatsListScreen extends StatefulWidget {
  const CommunityChatsListScreen({Key? key}) : super(key: key);

  @override
  State<CommunityChatsListScreen> createState() =>
      _CommunityChatsListScreenState();
}

class _CommunityChatsListScreenState extends State<CommunityChatsListScreen>
    with SingleTickerProviderStateMixin {
  static const Color _bg = Color(0xFFF5F1ED);
  static const Color _primary = Color(0xFF9A4B3C);
  static const Color _accent = Color(0xFFF26A3D);
  static const Color _textDark = Color(0xFF2B2B2B);

  bool get _isAdmin => UserSession.isAdmin;
  bool get _isResident => UserSession.isResident;

  bool _loading = true;
  String? _errorMessage;

  String _currentUserId = '';
  String _currentUserEmail = '';

  // Logged-in user profile (for header)
  String _currentUserName = '';
  String _currentUserBlock = '';

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _filter = 'all';

  // Search state
  bool _isSearchActive = false;
  final List<String> _recentSearches = [];

  // ── Resident state ──────────────────────────
  List<ResidentProfile> _blockNeighbours = [];
  List<ConversationPreview> _conversations = [];
  List<GroupChatPreview> _residentGroupChats = [];

  // ── Admin state ─────────────────────────────
  List<String> _adminBlocks = [];
  String? _selectedAdminBlock;
  List<GroupChatPreview> _adminGroupChats = [];

  late final TabController _tabController;

  // ── FAB state ────────────────────────────────
  bool _fabExpanded = false;

  // ══════════════════════════════════════════════
  // INIT
  // ══════════════════════════════════════════════

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initAndLoad();
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

      debugPrint(
          '✅ UserSession ready — role: ${UserSession.role}, uid: $_currentUserId');

      if (_currentUserId.isEmpty) {
        debugPrint('❌ No authenticated user found');
        setState(() => _loading = false);
        return;
      }

      if (UserSession.isAdmin) {
        await _loadAdminData();
      } else if (UserSession.isResident) {
        await _loadResidentData();
      } else {
        debugPrint('❌ Unknown role — not found in admin_new or resident');
        setState(() => _loading = false);
      }
    } catch (e, stack) {
      debugPrint('❌ _initAndLoad error: $e\n$stack');
      setState(() {
        _loading = false;
        _errorMessage = e.toString();
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  // ══════════════════════════════════════════════
  // RESIDENT – data loading
  // ══════════════════════════════════════════════

  Future<void> _loadResidentData() async {
    try {
      final myProfile = await supabase
          .from('resident')
          .select('full_name, email, block')
          .eq('id', _currentUserId)
          .maybeSingle();

      if (myProfile == null) {
        debugPrint('❌ Resident profile not found for uid: $_currentUserId');
        setState(() => _loading = false);
        return;
      }

      final myBlock = myProfile['block'] as String? ?? '';
      if (myBlock.isEmpty) {
        debugPrint('❌ Resident has no block assigned');
        setState(() => _loading = false);
        return;
      }

      // Store current user info for header
      _currentUserName = myProfile['full_name']?.toString() ?? '';
      _currentUserBlock = myBlock;

      // Neighbours in same block
      final neighboursData = await supabase
          .from('resident')
          .select('id, full_name, email, block')
          .eq('block', myBlock)
          .neq('id', _currentUserId);

      final neighbours = (neighboursData as List<dynamic>)
          .map((e) => ResidentProfile.fromMap(e as Map<String, dynamic>))
          .toList();

      // Fetch all rooms for current user
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

      final Map<String, String> userRoomMap = {};
      for (final row in allRooms) {
        final roomId = row['room_id'] as String;
        final u1 = row['user1_id'] as String;
        final u2 = row['user2_id'] as String;
        final otherId = (u1 == _currentUserId) ? u2 : u1;
        userRoomMap[otherId] = roomId;
      }

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
            ? msgList[0]['content'] as String
            : 'Tap to start chatting';
        final lastTime = msgList.isNotEmpty
            ? DateTime.parse(msgList[0]['created_at'] as String)
            : DateTime.now();

        // Count unread messages not sent by current user
        final unreadMsgsRes = await supabase
            .from('messages')
            .select('id')
            .eq('room_id', roomId)
            .neq('sender', _currentUserId)
            .eq('is_read', false);
        final int unreadCount = (unreadMsgsRes as List<dynamic>).length;

        convos.add(ConversationPreview(
          resident: neighbour,
          lastMessage: lastMsg,
          lastTime: lastTime,
          roomId: roomId,
          unreadCount: unreadCount,
        ));
      }
      convos.sort((a, b) => b.lastTime.compareTo(a.lastTime));

      // Accepted group chats
      final invitations = await supabase
          .from('group_chat_invitations')
          .select('group_chat_id, status')
          .eq('invited_user_id', _currentUserId)
          .eq('status', 'accepted');

      final groupChats = <GroupChatPreview>[];
      for (final inv in (invitations as List<dynamic>)) {
        final groupChatId = inv['group_chat_id'] as String;

        final groupData = await supabase
            .from('group_chats')
            .select('id, room_id, block, name')
            .eq('id', groupChatId)
            .maybeSingle();

        if (groupData == null) continue;

        final roomId = groupData['room_id'] as String;
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

        final unreadGroupRes = await supabase
            .from('messages')
            .select('id')
            .eq('room_id', roomId)
            .neq('sender', _currentUserId)
            .eq('is_read', false);
        final int unreadCount = (unreadGroupRes as List<dynamic>).length;

        groupChats.add(GroupChatPreview(
          groupId: groupData['id'] as String,
          roomId: roomId,
          name: groupData['name'] as String? ?? 'Block ${groupData['block']}',
          block: groupData['block']?.toString() ?? '',
          lastMessage: lastMsg,
          lastTime: lastTime,
          unreadCount: unreadCount,
        ));
      }
      groupChats.sort((a, b) => b.lastTime.compareTo(a.lastTime));

      setState(() {
        _blockNeighbours = neighbours;
        _conversations = convos;
        _residentGroupChats = groupChats;
        _loading = false;
      });
    } catch (e, stack) {
      debugPrint('❌ Resident load error: $e\n$stack');
      setState(() {
        _loading = false;
        _errorMessage = e.toString();
      });
    }
  }

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

  Future<void> _openOrCreateResidentDM(ResidentProfile resident) async {
    try {
      String? roomId;

      final asUser1 = await supabase
          .from('chat_rooms')
          .select('room_id')
          .eq('user1_id', _currentUserId)
          .eq('user2_id', resident.id)
          .maybeSingle();

      if (asUser1 != null) {
        roomId = asUser1['room_id'] as String;
      } else {
        final asUser2 = await supabase
            .from('chat_rooms')
            .select('room_id')
            .eq('user1_id', resident.id)
            .eq('user2_id', _currentUserId)
            .maybeSingle();

        if (asUser2 != null) {
          roomId = asUser2['room_id'] as String;
        }
      }

      if (roomId == null) {
        roomId = await _generateRoomId();
        await supabase.from('chat_rooms').insert({
          'room_id': roomId,
          'user1_id': _currentUserId,
          'user2_id': resident.id,
        });
      }

      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CommunityChatScreen(
            roomId: roomId!,
            communityName: resident.name,
            currentUserId: _currentUserId,
            currentUser: _currentUserEmail,
            isAdmin: false,
          ),
        ),
      );
      _loadResidentData();
    } catch (e, stack) {
      debugPrint('❌ Error opening DM: $e\n$stack');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open chat: $e')),
        );
      }
    }
  }

  void _openResidentGroupChat(GroupChatPreview group) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CommunityChatScreen(
          roomId: group.roomId,
          communityName: group.name,
          currentUserId: _currentUserId,
          currentUser: _currentUserEmail,
          isAdmin: false,
        ),
      ),
    );
    _loadResidentData();
  }

  // ══════════════════════════════════════════════
  // ADMIN – data loading
  // ══════════════════════════════════════════════

  Future<void> _loadAdminData() async {
    try {
      // Load admin profile for header
      final adminProfile = await supabase
          .from('admin_new')
          .select('full_name, email')
          .eq('id', _currentUserId)
          .maybeSingle();

      if (adminProfile != null) {
        _currentUserName = adminProfile['full_name']?.toString() ?? '';
      }

      final blocksData =
      await supabase.from('resident').select('block').neq('block', '');
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
    } catch (e, stack) {
      debugPrint('❌ Admin load error: $e\n$stack');
      setState(() {
        _loading = false;
        _errorMessage = e.toString();
      });
    }
  }

  void _openAdminGroupChat(GroupChatPreview group) async {
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
      ),
    );
    _loadAdminData();
  }

  // ══════════════════════════════════════════════
  // Helpers
  // ══════════════════════════════════════════════

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
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

  // ══════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null
            ? _buildErrorState()
            : _isAdmin
            ? _buildAdminLayout()
            : _isResident
            ? _buildResidentLayout()
            : _buildUnknownRoleState(),
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
            const Icon(Icons.error_outline, size: 56, color: Colors.redAccent),
            const SizedBox(height: 16),
            const Text(
              'Something went wrong',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF2B2B2B)),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? '',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Colors.black45),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _initAndLoad,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnknownRoleState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.person_off_outlined,
                size: 56, color: Colors.black38),
            const SizedBox(height: 16),
            const Text(
              'Account not recognised',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF2B2B2B)),
            ),
            const SizedBox(height: 8),
            Text(
              'UID: $_currentUserId\nRole: ${UserSession.role}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Colors.black45),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _initAndLoad,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════
  // RESIDENT layout
  // ══════════════════════════════════════════════

  Widget _buildResidentLayout() {
    final filteredConvos = _searchQuery.isEmpty
        ? _conversations
        : _conversations
        .where(
            (c) => c.resident.name.toLowerCase().contains(_searchQuery))
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
      combinedList.addAll(filteredGroupChats.map((g) => {
        'type': 'group',
        'data': g,
      }));
    }

    if (_filter == 'all' || _filter == 'dm') {
      combinedList.addAll(filteredConvos.map((c) => {
        'type': 'dm',
        'data': c,
      }));
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

    final totalUnread = combinedList.fold<int>(0, (int sum, item) {
      if (item['type'] == 'group') {
        return sum + ((item['data'] as GroupChatPreview).unreadCount);
      } else {
        return sum + ((item['data'] as ConversationPreview).unreadCount);
      }
    });

    return CustomScrollView(
      slivers: [
        // ── Header with resident profile ──
        SliverToBoxAdapter(
          child: _buildProfileHeader(
            name: _currentUserName,
            subtitle: 'Block $_currentUserBlock',
          ),
        ),

        // ── Search bar ──
        SliverToBoxAdapter(
          child: _buildSearchBar(hint: 'Search neighbours, groups…'),
        ),

        // ── Recent searches (shown when search is active but empty) ──
        if (_isSearchActive && _searchQuery.isEmpty && _recentSearches.isNotEmpty)
          SliverToBoxAdapter(child: _buildRecentSearches()),

        // ── Search result count ──
        if (_searchQuery.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 8, 22, 0),
              child: Text(
                '${combinedList.length} result${combinedList.length == 1 ? '' : 's'} for "$_searchQuery"',
                style:
                const TextStyle(fontSize: 12, color: Colors.black45),
              ),
            ),
          ),

        // ── Neighbours strip (hidden when searching) ──
        if (_searchQuery.isEmpty) ...[
          SliverToBoxAdapter(child: _buildNeighboursStrip()),
          SliverToBoxAdapter(child: _buildDivider()),
          const SliverToBoxAdapter(child: SizedBox(height: 6)),
        ],

        // ── Filter chips ──
        if (_searchQuery.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 6, 22, 8),
              child: Row(
                children: [
                  _buildFilterChip('All', 'all', totalUnread: totalUnread),
                  _buildFilterChip('Direct', 'dm'),
                  _buildFilterChip('Groups', 'group'),
                ],
              ),
            ),
          ),

        // ── Invitations widget ──
        SliverToBoxAdapter(
          child: ResidentInvitationsWidget(
            currentUserId: _currentUserId,
            currentUser: _currentUserEmail,
          ),
        ),

        // ── Chat list ──
        if (combinedList.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: const [
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
                      child: _GroupChatTile(
                        group: group,
                        primaryColor: _primary,
                        formatTime: _formatTime,
                        isAdmin: false,
                        searchQuery: _searchQuery,
                        onTap: () => _openResidentGroupChat(group),
                      ),
                    );
                  } else {
                    final convo = item['data'] as ConversationPreview;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _ConversationTile(
                        preview: convo,
                        primaryColor: _primary,
                        accentColor: _accent,
                        formatTime: _formatTime,
                        searchQuery: _searchQuery,
                        onTap: () => _openOrCreateResidentDM(convo.resident),
                      ),
                    );
                  }
                },
                childCount: combinedList.length,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildNeighboursStrip() {
    if (_blockNeighbours.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(22, 16, 22, 8),
        child: Text(
          'No neighbours found in your block.',
          style: TextStyle(color: Colors.black45, fontSize: 13),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 14, 22, 10),
          child: Row(
            children: [
              Text(
                'IN YOUR BLOCK',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: _primary,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(width: 8),
              _CountBadge(count: _blockNeighbours.length, color: _primary),
              const SizedBox(width: 8),
              Text(
                '· tap to chat',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.black38,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 104,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 22),
            itemCount: _blockNeighbours.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, i) => _NeighbourCard(
              profile: _blockNeighbours[i],
              primaryColor: _primary,
              // Simulated online status — replace with real presence if available
              isOnline: i % 3 == 0,
              onTap: () => _openOrCreateResidentDM(_blockNeighbours[i]),
            ),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  // ══════════════════════════════════════════════
  // ADMIN layout
  // ══════════════════════════════════════════════

  Widget _buildAdminLayout() {
    final filtered = _searchQuery.isEmpty
        ? _adminGroupChats
        : _adminGroupChats
        .where((g) =>
    g.name.toLowerCase().contains(_searchQuery) ||
        g.block.toLowerCase().contains(_searchQuery))
        .toList();

    return Stack(
      children: [
        CustomScrollView(
          slivers: [
            // ── Header with admin profile ──
            SliverToBoxAdapter(
              child: _buildProfileHeader(
                name: _currentUserName,
                subtitle: 'Administrator',
              ),
            ),
            SliverToBoxAdapter(child: _buildDivider()),

            // ── Search bar ──
            SliverToBoxAdapter(
              child: _buildSearchBar(hint: 'Search group chats…'),
            ),

            // ── Recent searches ──
            if (_isSearchActive && _searchQuery.isEmpty && _recentSearches.isNotEmpty)
              SliverToBoxAdapter(child: _buildRecentSearches()),

            // ── Result count ──
            if (_searchQuery.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(22, 8, 22, 0),
                  child: Text(
                    '${filtered.length} result${filtered.length == 1 ? '' : 's'} for "$_searchQuery"',
                    style:
                    const TextStyle(fontSize: 12, color: Colors.black45),
                  ),
                ),
              ),

            if (_adminGroupChats.isNotEmpty)
              SliverToBoxAdapter(
                child: _buildSectionLabel('GROUP CHATS',
                    count: _adminGroupChats.length),
              ),

            _buildAdminGroupSliver(filtered),

            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),

        // ── FAB (admin only: New Group) ──
        Positioned(
          right: 18,
          bottom: 18,
          child: _buildAdminFab(),
        ),
      ],
    );
  }

  Widget _buildAdminGroupSliver(List<GroupChatPreview> filtered) {
    if (filtered.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.only(top: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.groups_outlined, size: 56, color: Colors.black26),
              SizedBox(height: 12),
              Text(
                'No group chats yet.\nUse + to create a block group chat.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black45, height: 1.6),
              ),
            ],
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
              (context, i) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _GroupChatTile(
              group: filtered[i],
              primaryColor: _primary,
              formatTime: _formatTime,
              isAdmin: true,
              searchQuery: _searchQuery,
              onTap: () => _openAdminGroupChat(filtered[i]),
            ),
          ),
          childCount: filtered.length,
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════
  // SHARED UI helpers
  // ══════════════════════════════════════════════

  /// Profile header: avatar + name + subtitle + optional search icon
  Widget _buildProfileHeader({
    required String name,
    required String subtitle,
  }) {
    final displayName = name.isNotEmpty ? name : 'Hello';
    final initials = _getInitials(displayName);
    final avatarColor = _nameToColor(displayName);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [avatarColor, avatarColor.withOpacity(0.7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Center(
              child: Text(
                initials,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Name + subtitle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: _textDark,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.black45,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getInitials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  Color _nameToColor(String name) {
    final hue = (name.codeUnits.fold(0, (a, b) => a + b) % 360).toDouble();
    return HSLColor.fromAHSL(1, hue, 0.55, 0.55).toColor();
  }

  Widget _buildSectionLabel(String label, {int? count}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 12, 22, 8),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: _primary,
              letterSpacing: 1.2,
            ),
          ),
          if (count != null) ...[
            const SizedBox(width: 8),
            _CountBadge(count: count, color: _primary),
          ],
        ],
      ),
    );
  }

  Widget _buildDivider() => Container(
    height: 1,
    margin: const EdgeInsets.symmetric(horizontal: 22),
    color: Colors.black.withOpacity(0.07),
  );

  Widget _buildFilterChip(String label, String value, {int totalUnread = 0}) {
    final isSelected = _filter == value;
    final showBadge = value == 'all' && totalUnread > 0 && !isSelected;

    return GestureDetector(
      onTap: () => setState(() => _filter = value),
      child: Container(
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? _primary : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.black54,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            if (showBadge) ...[
              const SizedBox(width: 5),
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: _primary,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
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
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: TextField(
          controller: _searchController,
          onTap: () => setState(() => _isSearchActive = true),
          onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
          onSubmitted: (v) {
            _addRecentSearch(v.trim());
            setState(() => _isSearchActive = false);
          },
          style: const TextStyle(fontSize: 14, color: _textDark),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.black38, fontSize: 14),
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
            contentPadding: const EdgeInsets.symmetric(vertical: 10),
          ),
        ),
      ),
    );
  }

  Widget _buildRecentSearches() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 8, 22, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'RECENT',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: Colors.black38,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: _recentSearches
                .map(
                  (s) => GestureDetector(
                onTap: () {
                  _searchController.text = s;
                  setState(() => _searchQuery = s.toLowerCase());
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.history_rounded,
                          size: 13, color: Colors.black45),
                      const SizedBox(width: 5),
                      Text(
                        s,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
                .toList(),
          ),
        ],
      ),
    );
  }

  // ── Admin FAB: only "New Group" ──────────────
  Widget _buildAdminFab() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Expanded option
        if (_fabExpanded) ...[
          _FabOption(
            label: 'New Group',
            icon: Icons.group_add_rounded,
            color: _primary,
            onTap: () {
              setState(() => _fabExpanded = false);
              // TODO: navigate to create group screen
            },
          ),
          const SizedBox(height: 12),
        ],
        // Main FAB
        GestureDetector(
          onTap: () => setState(() => _fabExpanded = !_fabExpanded),
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
                ),
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
      ],
    );
  }
}

// ─────────────────────────────────────────────
// Sub-widgets
// ─────────────────────────────────────────────

class _FabOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _FabOption({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withOpacity(0.85),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
        ],
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  final int count;
  final Color color;
  const _CountBadge({required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$count',
        style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}

// ── Neighbour card with online dot ──────────────
class _NeighbourCard extends StatelessWidget {
  final ResidentProfile profile;
  final Color primaryColor;
  final bool isOnline;
  final VoidCallback onTap;

  const _NeighbourCard({
    required this.profile,
    required this.primaryColor,
    required this.isOnline,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 64,
        child: Column(
          children: [
            Stack(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        profile.avatarColor,
                        profile.avatarColor.withOpacity(0.7),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(17),
                    boxShadow: [
                      BoxShadow(
                        color: profile.avatarColor.withOpacity(0.35),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      profile.initials,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ),
                // Online dot
                if (isOnline)
                  Positioned(
                    bottom: 1,
                    right: 1,
                    child: Container(
                      width: 13,
                      height: 13,
                      decoration: BoxDecoration(
                        color: const Color(0xFF22C55E),
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: const Color(0xFFF5F1ED), width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              profile.firstName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2B2B2B),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Group chat tile with unread indicator ────────
class _GroupChatTile extends StatelessWidget {
  final GroupChatPreview group;
  final Color primaryColor;
  final String Function(DateTime) formatTime;
  final bool isAdmin;
  final String searchQuery;
  final VoidCallback onTap;

  const _GroupChatTile({
    required this.group,
    required this.primaryColor,
    required this.formatTime,
    required this.isAdmin,
    required this.searchQuery,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasUnread = group.unreadCount > 0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: hasUnread
              ? Border(
            left: BorderSide(color: primaryColor, width: 4),
          )
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [primaryColor, primaryColor.withOpacity(0.7)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: Text(
                  group.block,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _HighlightText(
                    text: group.name,
                    query: searchQuery,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight:
                      hasUnread ? FontWeight.w800 : FontWeight.w700,
                      color: const Color(0xFF2B2B2B),
                    ),
                    highlightColor: primaryColor,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    group.lastMessage,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      color: hasUnread
                          ? const Color(0xFF2B2B2B)
                          : Colors.black45,
                      fontWeight: hasUnread
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  formatTime(group.lastTime),
                  style: TextStyle(
                    fontSize: 12,
                    color: hasUnread ? primaryColor : Colors.black38,
                    fontWeight: hasUnread
                        ? FontWeight.w600
                        : FontWeight.w400,
                  ),
                ),
                if (hasUnread) ...[
                  const SizedBox(height: 5),
                  Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: primaryColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Conversation tile with unread indicator ──────
class _ConversationTile extends StatelessWidget {
  final ConversationPreview preview;
  final Color primaryColor;
  final Color accentColor;
  final String Function(DateTime) formatTime;
  final String searchQuery;
  final VoidCallback onTap;

  const _ConversationTile({
    required this.preview,
    required this.primaryColor,
    required this.accentColor,
    required this.formatTime,
    required this.searchQuery,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final resident = preview.resident;
    final hasUnread = preview.unreadCount > 0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: hasUnread
              ? Border(
            left: BorderSide(color: primaryColor, width: 4),
          )
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    resident.avatarColor,
                    resident.avatarColor.withOpacity(0.7),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: Text(
                  resident.initials,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _HighlightText(
                    text: resident.name,
                    query: searchQuery,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight:
                      hasUnread ? FontWeight.w800 : FontWeight.w700,
                      color: const Color(0xFF2B2B2B),
                    ),
                    highlightColor: primaryColor,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    preview.lastMessage,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      color: hasUnread
                          ? const Color(0xFF2B2B2B)
                          : Colors.black45,
                      fontWeight: hasUnread
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  formatTime(preview.lastTime),
                  style: TextStyle(
                    fontSize: 12,
                    color: hasUnread ? primaryColor : Colors.black38,
                    fontWeight: hasUnread
                        ? FontWeight.w600
                        : FontWeight.w400,
                  ),
                ),
                if (hasUnread) ...[
                  const SizedBox(height: 5),
                  Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: primaryColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Text with search highlight ────────────────────
class _HighlightText extends StatelessWidget {
  final String text;
  final String query;
  final TextStyle style;
  final Color highlightColor;

  const _HighlightText({
    required this.text,
    required this.query,
    required this.style,
    required this.highlightColor,
  });

  @override
  Widget build(BuildContext context) {
    if (query.isEmpty) {
      return Text(text, style: style, maxLines: 1, overflow: TextOverflow.ellipsis);
    }

    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();
    final matchIndex = lowerText.indexOf(lowerQuery);

    if (matchIndex == -1) {
      return Text(text, style: style, maxLines: 1, overflow: TextOverflow.ellipsis);
    }

    return RichText(
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        style: style,
        children: [
          if (matchIndex > 0)
            TextSpan(text: text.substring(0, matchIndex)),
          TextSpan(
            text: text.substring(matchIndex, matchIndex + query.length),
            style: style.copyWith(
              color: highlightColor,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (matchIndex + query.length < text.length)
            TextSpan(text: text.substring(matchIndex + query.length)),
        ],
      ),
    );
  }
}