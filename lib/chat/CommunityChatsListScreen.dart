import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:assignment/chat/user_session.dart';
import '../resident/ResidentInvitationsWidget.dart';
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
    this.unreadCount = 0,
  });
}

class GroupChatPreview {
  final String groupId;
  final String roomId;
  final String name;
  final String block;
  final String lastMessage;
  final DateTime lastTime;

  GroupChatPreview({
    required this.groupId,
    required this.roomId,
    required this.name,
    required this.block,
    required this.lastMessage,
    required this.lastTime,
  });
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
  late final String _currentUserId;
  late final String _currentUserEmail;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _filter = 'all';

  // ── Resident state ──────────────────────────
  List<ResidentProfile> _blockNeighbours = [];
  List<ConversationPreview> _conversations = [];
  List<GroupChatPreview> _residentGroupChats = [];

  // ── Admin state ─────────────────────────────
  List<String> _adminBlocks = [];
  String? _selectedAdminBlock;
  List<GroupChatPreview> _adminGroupChats = [];

  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _currentUserId = supabase.auth.currentUser?.id ?? '';
    _currentUserEmail = supabase.auth.currentUser?.email ?? '';
    if (_isAdmin) {
      _loadAdminData();
    } else if (_isResident) {
      _loadResidentData();
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
    setState(() => _loading = true);
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

      // Neighbours in same block
      final neighboursData = await supabase
          .from('resident')
          .select('id, full_name, email, block')
          .eq('block', myBlock)
          .neq('id', _currentUserId);

      final neighbours = (neighboursData as List<dynamic>)
          .map((e) => ResidentProfile.fromMap(e as Map<String, dynamic>))
          .toList();

      // ── FIX: fetch all rooms for current user using two separate queries
      // then merge, instead of using .or() with compound filters which
      // can be rejected by some Supabase/PostgREST configurations.
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
            .select('content, created_at')
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

        convos.add(ConversationPreview(
          resident: neighbour,
          lastMessage: lastMsg,
          lastTime: lastTime,
          roomId: roomId,
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

        groupChats.add(GroupChatPreview(
          groupId: groupData['id'] as String,
          roomId: roomId,
          name: groupData['name'] as String? ?? 'Block ${groupData['block']}',
          block: groupData['block']?.toString() ?? '',
          lastMessage: lastMsg,
          lastTime: lastTime,
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
      debugPrint('Resident load error: $e\n$stack');
      setState(() => _loading = false);
    }
  }

  Future<String> _generateRoomId() async {
    final existing = await supabase.from('chat_rooms').select('room_id');
    final ids = (existing as List<dynamic>)
        .map((e) => e['room_id']?.toString() ?? '')
        .where((id) => id.startsWith('ROOM_'))
        .map((id) => int.tryParse(id.replaceFirst('ROOM_', '')) ?? 0)
        .toList();
    final nextNum = ids.isEmpty ? 1 : (ids.reduce((a, b) => a > b ? a : b) + 1);
    return 'ROOM_${nextNum.toString().padLeft(2, '0')}';
  }

  Future<void> _openOrCreateResidentDM(ResidentProfile resident) async {
    try {
      // ── FIX: use two separate queries instead of compound .or() filter
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

      // No existing room — create one
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
      debugPrint('Error opening DM: $e\n$stack');
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
    setState(() => _loading = true);
    try {
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

        groups.add(GroupChatPreview(
          groupId: g['id'] as String,
          roomId: roomId,
          name: g['name'] as String? ?? 'Block ${g['block']}',
          block: g['block']?.toString() ?? '',
          lastMessage: lastMsg,
          lastTime: lastTime,
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
      setState(() => _loading = false);
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
            : _isAdmin
            ? _buildAdminLayout()
            : _isResident
            ? _buildResidentLayout()
            : const Center(child: Text('Unknown role')),
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
        .where((c) =>
        c.resident.name.toLowerCase().contains(_searchQuery))
        .toList();

    final List<Map<String, dynamic>> combinedList = [];

    if (_filter == 'all' || _filter == 'group') {
      combinedList.addAll(_residentGroupChats.map((g) => {
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

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _buildHeader(title: 'Messages')),

        SliverToBoxAdapter(child: _buildNeighboursStrip()),

        SliverToBoxAdapter(child: _buildDivider()),

        SliverToBoxAdapter(
          child: _buildSearchBar(hint: 'Search neighbours…'),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 8)),

        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 8, 22, 8),
            child: Row(
              children: [
                _buildFilterChip('All', 'all'),
                _buildFilterChip('Direct', 'dm'),
                _buildFilterChip('Groups', 'group'),
              ],
            ),
          ),
        ),

        SliverToBoxAdapter(
          child: ResidentInvitationsWidget(
            currentUserId: _currentUserId,
            currentUser: _currentUserEmail,
          ),
        ),

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
            padding: const EdgeInsets.fromLTRB(22, 8, 22, 100),
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
          height: 100,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 22),
            itemCount: _blockNeighbours.length,
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            // ── FIX: pass neighbour directly so tapping always works,
            // even if no prior conversation exists in _conversations.
            itemBuilder: (context, i) => _NeighbourCard(
              profile: _blockNeighbours[i],
              primaryColor: _primary,
              onTap: () => _openOrCreateResidentDM(_blockNeighbours[i]),
            ),
          ),
        ),
        const SizedBox(height: 6),
      ],
    );
  }

  // ══════════════════════════════════════════════
  // ADMIN layout
  // ══════════════════════════════════════════════

  Widget _buildAdminLayout() {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
            child: _buildHeader(title: 'Community Chats', isAdmin: true)),
        SliverToBoxAdapter(child: _buildDivider()),
        SliverToBoxAdapter(
            child: _buildSearchBar(hint: 'Search group chats…')),
        const SliverToBoxAdapter(child: SizedBox(height: 10)),
        if (_adminGroupChats.isNotEmpty)
          SliverToBoxAdapter(
            child: _buildSectionLabel('GROUP CHATS',
                count: _adminGroupChats.length),
          ),
        _buildAdminGroupSliver(),
        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }

  Widget _buildAdminGroupSliver() {
    final filtered = _searchQuery.isEmpty
        ? _adminGroupChats
        : _adminGroupChats
        .where((g) =>
    g.name.toLowerCase().contains(_searchQuery) ||
        g.block.toLowerCase().contains(_searchQuery))
        .toList();

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
                'No group chats yet.\nUse + to invite residents to a block chat.',
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

  Widget _buildHeader({required String title, bool isAdmin = false}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 4),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: _textDark,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
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

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _filter == value;

    return GestureDetector(
      onTap: () => setState(() => _filter = value),
      child: Container(
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? _primary : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black54,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar({required String hint}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 14, 22, 0),
      child: Container(
        height: 60,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
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
          onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
          style: const TextStyle(fontSize: 14, color: _textDark),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle:
            const TextStyle(color: Colors.black38, fontSize: 14),
            prefixIcon: const Icon(Icons.search_rounded,
                color: Colors.black38, size: 20),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Sub-widgets
// ─────────────────────────────────────────────

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

class _GroupChatChip extends StatelessWidget {
  final GroupChatPreview group;
  final Color primaryColor;
  final String Function(DateTime) formatTime;
  final VoidCallback onTap;

  const _GroupChatChip({
    required this.group,
    required this.primaryColor,
    required this.formatTime,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 160,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [primaryColor, primaryColor.withOpacity(0.7)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      group.block,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  formatTime(group.lastTime),
                  style:
                  const TextStyle(fontSize: 10, color: Colors.black38),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              group.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF2B2B2B),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              group.lastMessage,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, color: Colors.black45),
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupChatTile extends StatelessWidget {
  final GroupChatPreview group;
  final Color primaryColor;
  final String Function(DateTime) formatTime;
  final bool isAdmin;
  final VoidCallback onTap;

  const _GroupChatTile({
    required this.group,
    required this.primaryColor,
    required this.formatTime,
    required this.isAdmin,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
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
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          group.name,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF2B2B2B),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    group.lastMessage,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13, color: Colors.black45),
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
                  style: const TextStyle(
                      fontSize: 12, color: Colors.black38),
                )
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _NeighbourCard extends StatelessWidget {
  final ResidentProfile profile;
  final Color primaryColor;
  final VoidCallback onTap;

  const _NeighbourCard({
    required this.profile,
    required this.primaryColor,
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
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    profile.avatarColor,
                    profile.avatarColor.withOpacity(0.7),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: profile.avatarColor.withOpacity(0.4),
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
                    fontSize: 20,
                  ),
                ),
              ),
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

class _ConversationTile extends StatelessWidget {
  final ConversationPreview preview;
  final Color primaryColor;
  final Color accentColor;
  final String Function(DateTime) formatTime;
  final VoidCallback onTap;

  const _ConversationTile({
    required this.preview,
    required this.primaryColor,
    required this.accentColor,
    required this.formatTime,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final resident = preview.resident;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
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
                  Text(
                    resident.name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF2B2B2B),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    preview.lastMessage,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      color: preview.unreadCount > 0
                          ? const Color(0xFF2B2B2B)
                          : Colors.black45,
                      fontWeight: preview.unreadCount > 0
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
                    color: preview.unreadCount > 0
                        ? primaryColor
                        : Colors.black38,
                    fontWeight: preview.unreadCount > 0
                        ? FontWeight.w600
                        : FontWeight.w400,
                  ),
                ),
                if (preview.unreadCount > 0) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: primaryColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${preview.unreadCount}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
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