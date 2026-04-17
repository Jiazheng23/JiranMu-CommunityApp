import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
    name: map['full_name']?.toString() ?? 'Unknown', // ✅ correct column
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

// ─────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────

class CommunityChatsListScreen extends StatefulWidget {
  const CommunityChatsListScreen({Key? key}) : super(key: key);

  @override
  State<CommunityChatsListScreen> createState() =>
      _CommunityChatsListScreenState();
}

class _CommunityChatsListScreenState extends State<CommunityChatsListScreen> {
  static const Color _bg = Color(0xFFF5F1ED);
  static const Color _primary = Color(0xFF9A4B3C);
  static const Color _accent = Color(0xFFF26A3D);
  static const Color _textDark = Color(0xFF2B2B2B);

  List<ResidentProfile> _blockNeighbours = [];
  List<ConversationPreview> _conversations = [];
  bool _loading = true;

  late final String _currentUserId;
  late final String _currentUserEmail;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _currentUserId = supabase.auth.currentUser?.id ?? '';
    _currentUserEmail = supabase.auth.currentUser?.email ?? '';
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ── Data loading ──────────────────────────────

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      // 1. Get current user's block — select full_name, email, block
      final myProfile = await supabase
          .from('profiles')
          .select('full_name, email, block') // ✅ full_name not name
          .eq('id', _currentUserId)
          .maybeSingle();

      if (myProfile == null) {
        debugPrint('⚠️ No profile found for user $_currentUserId');
        setState(() => _loading = false);
        return;
      }

      final myBlock = myProfile['block'] as String? ?? '';
      debugPrint('✅ My block: $myBlock');

      if (myBlock.isEmpty) {
        debugPrint('⚠️ Block is empty — check profiles table has block set');
        setState(() => _loading = false);
        return;
      }

      // 2. ALL neighbours in same block
      final neighboursData = await supabase
          .from('profiles')
          .select('id, full_name, email, block') // ✅ full_name not name
          .eq('block', myBlock)
          .neq('id', _currentUserId);

      debugPrint('✅ Neighbours found: ${(neighboursData as List).length}');

      final neighbours = (neighboursData as List<dynamic>)
          .map((e) => ResidentProfile.fromMap(e as Map<String, dynamic>))
          .toList();

      // 3. Rooms the current user belongs to
      final roomsData = await supabase
          .from('chat_rooms')
          .select('room_id, user1_id, user2_id')
          .or('user1_id.eq.$_currentUserId,user2_id.eq.$_currentUserId');

      debugPrint('✅ Rooms found: ${(roomsData as List).length}');

      // Map: otherUserId → roomId
      final Map<String, String> userRoomMap = {};
      for (final row in (roomsData as List<dynamic>)) {
        final roomId = row['room_id'] as String;
        final u1 = row['user1_id'] as String;
        final u2 = row['user2_id'] as String;
        final otherId = (u1 == _currentUserId) ? u2 : u1;
        userRoomMap[otherId] = roomId;
      }

      // 4. Build conversation previews for neighbours with existing rooms
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

        final lastMsg = (msgs as List<dynamic>).isNotEmpty
            ? msgs[0]['content'] as String
            : 'Tap to start chatting';
        final lastTime = msgs.isNotEmpty
            ? DateTime.parse(msgs[0]['created_at'] as String)
            : DateTime.now().subtract(const Duration(days: 999));

        convos.add(ConversationPreview(
          resident: neighbour,
          lastMessage: lastMsg,
          lastTime: lastTime,
          roomId: roomId,
        ));
      }

      convos.sort((a, b) => b.lastTime.compareTo(a.lastTime));

      setState(() {
        _blockNeighbours = neighbours;
        _conversations = convos;
        _loading = false;
      });
    } catch (e, stack) {
      debugPrint('❌ Error loading chat list: $e');
      debugPrint(stack.toString());
      setState(() => _loading = false);
    }
  }

  // ── Room helpers ──────────────────────────────

  Future<String> _generateRoomId() async {
    final existing = await supabase.from('chat_rooms').select('room_id');
    final count = (existing as List<dynamic>).length + 1;
    return 'ROOM_${count.toString().padLeft(2, '0')}';
  }

  Future<void> _openOrCreateChat(ResidentProfile resident) async {
    try {
      final existing = await supabase
          .from('chat_rooms')
          .select('room_id')
          .or(
        'and(user1_id.eq.$_currentUserId,user2_id.eq.${resident.id}),'
            'and(user1_id.eq.${resident.id},user2_id.eq.$_currentUserId)',
      )
          .maybeSingle();

      String roomId;
      if (existing != null) {
        roomId = existing['room_id'] as String;
        debugPrint('✅ Existing room found: $roomId');
      } else {
        roomId = await _generateRoomId();
        await supabase.from('chat_rooms').insert({
          'room_id': roomId,
          'user1_id': _currentUserId,
          'user2_id': resident.id,
        });
        debugPrint('✅ New room created: $roomId');
      }

      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CommunityChatScreen(
            roomId: roomId,
            communityName: resident.name,
            currentUserId: _currentUserId,
            currentUser: _currentUserEmail, // email matches messages.sender
          ),
        ),
      );

      _loadData(); // refresh list on return
    } catch (e) {
      debugPrint('❌ Error opening/creating chat: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Could not open chat. Please try again.')),
        );
      }
    }
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min';
    if (diff.inHours < 24) return '${diff.inHours} hr';
    if (diff.inDays == 1) return '1 day';
    return '${diff.inDays} days';
  }

  // ── UI ────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            _buildNeighboursStrip(),
            _buildDivider(),
            _buildSearchBar(),
            const SizedBox(height: 4),
            Expanded(child: _buildConversationList()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 4),
      child: Row(
        children: [
          Text(
            'Messages',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: _textDark,
              letterSpacing: -0.5,
            ),
          ),
          const Spacer(),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Icon(Icons.edit_outlined, color: _primary, size: 20),
          ),
        ],
      ),
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
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: _primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_blockNeighbours.length}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _primary,
                  ),
                ),
              ),
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
            itemBuilder: (context, i) => _NeighbourCard(
              profile: _blockNeighbours[i],
              primaryColor: _primary,
              onTap: () => _openOrCreateChat(_blockNeighbours[i]),
            ),
          ),
        ),
        const SizedBox(height: 6),
      ],
    );
  }

  Widget _buildDivider() => Container(
    height: 1,
    margin: const EdgeInsets.symmetric(horizontal: 22),
    color: Colors.black.withOpacity(0.07),
  );

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 14, 22, 0),
      child: Container(
        height: 44,
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
            hintText: 'Search neighbours…',
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

  Widget _buildConversationList() {
    final filtered = _searchQuery.isEmpty
        ? _conversations
        : _conversations
        .where((c) =>
        c.resident.name.toLowerCase().contains(_searchQuery))
        .toList();

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.chat_bubble_outline_rounded,
                size: 48, color: Colors.black26),
            SizedBox(height: 12),
            Text(
              'No conversations yet.\nTap a neighbour above to say hi!',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black45, height: 1.6),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(22, 12, 22, 100),
      itemCount: filtered.length,
      separatorBuilder: (_, __) => const SizedBox(height: 4),
      itemBuilder: (context, i) => _ConversationTile(
        preview: filtered[i],
        primaryColor: _primary,
        accentColor: _accent,
        formatTime: _formatTime,
        onTap: () => _openOrCreateChat(filtered[i].resident),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Sub-widgets
// ─────────────────────────────────────────────

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