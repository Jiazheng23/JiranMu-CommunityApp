import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

final supabase = Supabase.instance.client;

class AdminCreateChatScreen extends StatefulWidget {
  const AdminCreateChatScreen({Key? key}) : super(key: key);

  @override
  State<AdminCreateChatScreen> createState() => _AdminCreateChatScreenState();
}

class _AdminCreateChatScreenState extends State<AdminCreateChatScreen> {
  // ── Palette ────────────────────────────────────────────────────────────────
  static const Color _primary   = Color(0xFF9A4B3C);
  static const Color _bg        = Color(0xFFF5F1ED);
  static const Color _surface   = Color(0xFFFFFFFF);
  static const Color _textDark  = Color(0xFF1A1614);
  static const Color _textMid   = Color(0xFF6B6460);
  static const Color _textLight = Color(0xFFADA8A5);
  static const Color _border    = Color(0xFFEDE9E5);

  // ── State ──────────────────────────────────────────────────────────────────
  List<String> _blocks              = [];
  Set<String>  _existingGroupBlocks = {};
  String?      _selectedBlock;
  List<Map<String, dynamic>> _residents = [];
  Set<String>  _selectedIds = {};
  bool         _loading     = false;
  final TextEditingController _groupNameCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadBlocks();
  }

  @override
  void dispose() {
    _groupNameCtrl.dispose();
    super.dispose();
  }

  // ── Data ───────────────────────────────────────────────────────────────────

  Future<void> _loadBlocks() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final data = await supabase
          .from('resident')
          .select('block')
          .neq('block', '');
      final blocks = (data as List)
          .map((e) => e['block']?.toString() ?? '')
          .where((s) => s.isNotEmpty)
          .toSet()
          .toList()
        ..sort();
      final existingGroups = await supabase
          .from('group_chats')
          .select('block');
      final existingBlocks = (existingGroups as List)
          .map((e) => e['block']?.toString() ?? '')
          .where((s) => s.isNotEmpty)
          .toSet();

      if (mounted) {
        setState(() {
          _blocks              = blocks;
          _existingGroupBlocks = existingBlocks;
        });
      }
    } catch (e) {
      debugPrint('Error loading blocks: $e');
    }
  }

  Future<void> _loadResidents(String block) async {
    setState(() => _loading = true);
    try {
      final user = supabase.auth.currentUser;
      if (user == null) throw Exception("User session not found.");
      final myId = user.id;

      final existingGroup = await supabase
          .from('group_chats')
          .select('id')
          .eq('block', block)
          .maybeSingle();

      Set<String> alreadyInvitedIds = {};
      if (existingGroup != null) {
        final groupChatId = existingGroup['id'] as String;
        final invitations = await supabase
            .from('group_chat_invitations')
            .select('invited_user_id')
            .eq('group_chat_id', groupChatId);
        alreadyInvitedIds = (invitations as List)
            .map((e) => e['invited_user_id'] as String)
            .toSet();
      }

      final data = await supabase
          .from('resident')
          .select('id, full_name, unit_number, block, role')
          .eq('block', block);

      if (mounted) {
        setState(() {
          _residents = (data as List)
              .map((e) => Map<String, dynamic>.from(e))
              .where((e) =>
          e['id'] != myId &&
              (e['role'] == 'resident' || e['role'] == null) &&
              !alreadyInvitedIds.contains(e['id']))
              .toList();
          _selectedIds = {};
        });
      }
    } catch (e) {
      debugPrint('Error loading residents: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:         Text('Error: $e'),
              backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _createChat() async {
    final user = supabase.auth.currentUser;
    if (user == null || _selectedIds.isEmpty || _selectedBlock == null) return;

    final adminId = user.id;
    setState(() => _loading = true);

    try {
      final existing = await supabase
          .from('group_chats')
          .select('id, room_id')
          .eq('block', _selectedBlock!)
          .maybeSingle();

      String groupChatId;
      String roomId;

      if (existing != null) {
        groupChatId = existing['id'] as String;
        roomId      = existing['room_id'] as String;
      } else {
        groupChatId = const Uuid().v4();
        roomId      = 'block_${_selectedBlock!.toLowerCase()}_community';
        await supabase.from('group_chats').insert({
          'id':         groupChatId,
          'room_id':    roomId,
          'block':      _selectedBlock,
          'created_by': adminId,
          if (_groupNameCtrl.text.trim().isNotEmpty)
            'name': _groupNameCtrl.text.trim(),
        });
      }

      for (final userId in _selectedIds) {
        final alreadyInvited = await supabase
            .from('group_chat_invitations')
            .select('id')
            .eq('group_chat_id', groupChatId)
            .eq('invited_user_id', userId)
            .maybeSingle();

        if (alreadyInvited == null) {
          await supabase.from('group_chat_invitations').insert({
            'id':              const Uuid().v4(),
            'group_chat_id':   groupChatId,
            'invited_user_id': userId,
            'invited_by':      adminId,
            'status':          'pending',
          });
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Chat created & ${_selectedIds.length} member(s) invited!'),
            backgroundColor: Colors.green,
          ),
        );
        setState(() {
          _selectedIds   = {};
          _selectedBlock = null;
          _residents     = [];
          _groupNameCtrl.clear();
        });
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('Error creating chat: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  Color _avatarColor(String name) {
    final hue =
    (name.codeUnits.fold(0, (a, b) => a + b) % 360).toDouble();
    return HSLColor.fromAHSL(1, hue, 0.45, 0.48).toColor();
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor:  _surface,
        foregroundColor:  _textDark,
        elevation:        0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon:      const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Add Community Members',
          style: TextStyle(
            fontSize:   16,
            fontWeight: FontWeight.w700,
            color:      _textDark,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: _border),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch, // stretch children to full width
        children: [
          // ── Selected members strip ───────────────────────────────────────
          if (_selectedIds.isNotEmpty) _selectedStrip(),

          // ── Block selector ───────────────────────────────────────────────
          _blockSelector(),

          const SizedBox(height: 4),

          // ── Members header ───────────────────────────────────────────────
          if (_selectedBlock != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 16, 6),
              child: Row(
                children: [
                  const Text(
                    'All Contacts',
                    style: TextStyle(
                      fontSize:      13,
                      fontWeight:    FontWeight.w700,
                      color:         _textDark,
                      letterSpacing: 0.1,
                    ),
                  ),
                  const Spacer(),
                  if (_residents.isNotEmpty)
                    GestureDetector(
                      onTap: () => setState(() {
                        _selectedIds =
                        _selectedIds.length == _residents.length
                            ? {}
                            : _residents
                            .map((r) => r['id'] as String)
                            .toSet();
                      }),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color:        _primary.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _selectedIds.length == _residents.length
                              ? 'Deselect all'
                              : 'Select all',
                          style: const TextStyle(
                            color:      _primary,
                            fontSize:   12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

          // ── Residents list ───────────────────────────────────────────────
          Expanded(child: _residentList()),

          // ── Create button ────────────────────────────────────────────────
          if (_selectedIds.isNotEmpty) _createButton(),
        ],
      ),
    );
  }

  // ── Selected strip ─────────────────────────────────────────────────────────
  Widget _selectedStrip() {
    final selectedResidents = _residents
        .where((r) => _selectedIds.contains(r['id'] as String))
        .toList();

    return Container(
      // Full width
      width:   double.infinity,
      color:   _surface,
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Chosen Contacts',
                style: TextStyle(
                  fontSize:      12,
                  fontWeight:    FontWeight.w700,
                  color:         _textMid,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color:        _primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${_selectedIds.length}',
                  style: const TextStyle(
                    color:      Colors.white,
                    fontSize:   11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 56,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics:         const BouncingScrollPhysics(),
              itemCount:       selectedResidents.length,
              itemBuilder: (context, i) {
                final r    = selectedResidents[i];
                final name = r['full_name'] as String? ?? '?';
                return Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: GestureDetector(
                    onTap: () =>
                        setState(() => _selectedIds.remove(r['id'])),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        CircleAvatar(
                          radius:          26,
                          backgroundColor: _avatarColor(name),
                          child: Text(
                            _initials(name),
                            style: const TextStyle(
                              color:      Colors.white,
                              fontSize:   13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Positioned(
                          top:   -2,
                          right: -2,
                          child: Container(
                            width:  18,
                            height: 18,
                            decoration: BoxDecoration(
                              color:  _primary,
                              shape:  BoxShape.circle,
                              border: Border.all(
                                  color: _surface, width: 1.5),
                            ),
                            child: const Icon(Icons.close,
                                color: Colors.white, size: 10),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── Block selector ─────────────────────────────────────────────────────────
  Widget _blockSelector() {
    final availableBlocks = _blocks
        .where((b) => !_existingGroupBlocks.contains(b))
        .toList();

    return Container(
      // KEY FIX: force full screen width so the white card never leaves a gap
      width:   double.infinity,
      color:   _surface,
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Select Block',
            style: TextStyle(
              fontSize:      12,
              fontWeight:    FontWeight.w700,
              color:         _textMid,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 10),
          if (_blocks.isEmpty)
            const Text(
              'No blocks found.',
              style: TextStyle(color: _textLight, fontSize: 13),
            )
          else if (availableBlocks.isEmpty)
          // All blocks already have a group chat
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color:        _primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.check_circle_outline_rounded,
                      color: _primary, size: 18),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'All blocks already have a group chat.\nManage members inside Chat Settings.',
                    style: TextStyle(
                      color:    _textMid,
                      fontSize: 13,
                      height:   1.5,
                    ),
                  ),
                ),
              ],
            )
          else
          // Horizontally scrollable chips with bouncy physics
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics:         const BouncingScrollPhysics(),
              child: Row(
                children: [
                  ...availableBlocks.map((block) {
                    final selected = _selectedBlock == block;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () {
                          setState(() => _selectedBlock = block);
                          _loadResidents(block);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 18, vertical: 9),
                          decoration: BoxDecoration(
                            color: selected ? _primary : _bg,
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(
                              color: selected ? _primary : _border,
                              width: 1.5,
                            ),
                            boxShadow: selected
                                ? [
                              BoxShadow(
                                color:      _primary.withOpacity(0.25),
                                blurRadius: 8,
                                offset:     const Offset(0, 3),
                              ),
                            ]
                                : [],
                          ),
                          child: Text(
                            'Block $block',
                            style: TextStyle(
                              color:      selected ? Colors.white : _textDark,
                              fontWeight: FontWeight.w600,
                              fontSize:   13,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                  // Extra trailing space so the last chip isn't clipped
                  const SizedBox(width: 4),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ── Resident list ──────────────────────────────────────────────────────────
  Widget _residentList() {
    if (_selectedBlock == null) {
      final availableBlocks = _blocks
          .where((b) => !_existingGroupBlocks.contains(b))
          .toList();

      if (_blocks.isNotEmpty && availableBlocks.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width:  72,
                height: 72,
                decoration: BoxDecoration(
                  color: _border,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle_outline_rounded,
                    size: 34, color: _textLight),
              ),
              const SizedBox(height: 16),
              const Text(
                'All blocks have been set up',
                style: TextStyle(
                    color:      _textMid,
                    fontSize:   14,
                    fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 4),
              const Text(
                'Use Chat Settings to manage members',
                style: TextStyle(color: _textLight, fontSize: 12),
              ),
            ],
          ),
        );
      }

      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width:  72,
              height: 72,
              decoration: BoxDecoration(
                color: _border,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.apartment_outlined,
                  size: 34, color: _textLight),
            ),
            const SizedBox(height: 16),
            const Text(
              'Select a block to see members',
              style: TextStyle(
                  color:      _textMid,
                  fontSize:   14,
                  fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 4),
            const Text(
              'Choose up to 1000 contacts',
              style: TextStyle(color: _textLight, fontSize: 12),
            ),
          ],
        ),
      );
    }

    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: _primary));
    }

    if (_residents.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width:  72,
              height: 72,
              decoration:
              BoxDecoration(color: _border, shape: BoxShape.circle),
              child: const Icon(Icons.person_off_outlined,
                  size: 34, color: _textLight),
            ),
            const SizedBox(height: 16),
            const Text(
              'All residents are already\nin this group.',
              style: TextStyle(
                  color:      _textMid,
                  fontSize:   14,
                  fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding:   const EdgeInsets.fromLTRB(16, 4, 16, 16),
      itemCount: _residents.length,
      itemBuilder: (context, i) {
        final r       = _residents[i];
        final id      = r['id'] as String;
        final name    = r['full_name'] as String? ?? 'Unknown';
        final unit    = r['unit_number'] as String? ?? '';
        final checked = _selectedIds.contains(id);

        return GestureDetector(
          onTap: () => setState(() {
            checked ? _selectedIds.remove(id) : _selectedIds.add(id);
          }),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            margin:   const EdgeInsets.only(bottom: 8),
            padding:  const EdgeInsets.symmetric(
                horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color:        _surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: checked ? _primary : Colors.transparent,
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color:      Colors.black.withOpacity(0.04),
                  blurRadius: 6,
                  offset:     const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                // Avatar
                Stack(
                  children: [
                    CircleAvatar(
                      radius:          24,
                      backgroundColor: _avatarColor(name),
                      child: Text(
                        _initials(name),
                        style: const TextStyle(
                          color:      Colors.white,
                          fontSize:   13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (checked)
                      Positioned.fill(
                        child: CircleAvatar(
                          backgroundColor: _primary.withOpacity(0.85),
                          child: const Icon(Icons.check,
                              color: Colors.white, size: 18),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 12),
                // Name + unit
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize:   14,
                          color:      checked ? _primary : _textDark,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        unit.isNotEmpty ? 'Unit $unit' : 'No unit',
                        style: const TextStyle(
                            fontSize: 12, color: _textLight),
                      ),
                    ],
                  ),
                ),
                // Status dot
                Container(
                  width:  8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: checked ? _primary : _border,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Create button ──────────────────────────────────────────────────────────
  Widget _createButton() {
    return Container(
      width:   double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
      decoration: BoxDecoration(
        color:  _surface,
        border: Border(top: BorderSide(color: _border)),
      ),
      child: ElevatedButton(
        onPressed: _loading ? null : _createChat,
        style: ElevatedButton.styleFrom(
          backgroundColor: _primary,
          minimumSize:     const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
        child: _loading
            ? const SizedBox(
          height: 20,
          width:  20,
          child:  CircularProgressIndicator(
              color: Colors.white, strokeWidth: 2),
        )
            : Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.group_add_outlined,
                size: 18, color: Colors.white),
            const SizedBox(width: 8),
            Text(
              'Create Chat · ${_selectedIds.length} '
                  'member${_selectedIds.length == 1 ? '' : 's'}',
              style: const TextStyle(
                color:      Colors.white,
                fontWeight: FontWeight.w600,
                fontSize:   15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}