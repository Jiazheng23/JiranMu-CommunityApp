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
  static const Color _primary = Color(0xFF9A4B3C);

  List<String> _blocks = [];
  String? _selectedBlock;
  List<Map<String, dynamic>> _residents = [];
  Set<String> _selectedIds = {};
  bool _loading = false;
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

  Future<void> _loadBlocks() async {
    try {
      final data = await supabase.from('resident').select('block').neq('block', '');
      final blocks = (data as List)
          .map((e) => e['block']?.toString() ?? '')
          .where((s) => s.isNotEmpty)
          .toSet()
          .toList()
        ..sort();
      if (mounted) setState(() => _blocks = blocks);
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
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent),
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
        roomId = existing['room_id'] as String;
      } else {
        groupChatId = const Uuid().v4();
        roomId = 'block_${_selectedBlock!.toLowerCase()}_community';
        await supabase.from('group_chats').insert({
          'id': groupChatId,
          'room_id': roomId,
          'block': _selectedBlock,
          'created_by': adminId,
          if (_groupNameCtrl.text.trim().isNotEmpty)
            'name': _groupNameCtrl.text.trim(),
        });
      }

      final List<String> newlyAdded = [];
      for (final userId in _selectedIds) {
        final alreadyInvited = await supabase
            .from('group_chat_invitations')
            .select('id')
            .eq('group_chat_id', groupChatId)
            .eq('invited_user_id', userId)
            .maybeSingle();

        if (alreadyInvited == null) {
          await supabase.from('group_chat_invitations').insert({
            'id': const Uuid().v4(),
            'group_chat_id': groupChatId,
            'invited_user_id': userId,
            'invited_by': adminId,
            'status': 'pending',
          });
          // Collect name for welcome message
          final resident = _residents.firstWhere(
                (r) => r['id'] == userId,
            orElse: () => {},
          );
          final name = resident['full_name'] as String? ?? 'New Member';
          newlyAdded.add(name);
        }
      }

      // Auto-send welcome messages for newly added members
      for (final name in newlyAdded) {
        final firstName = name.trim().split(' ').first;
        await supabase.from('messages').insert({
          'id': const Uuid().v4(),
          'room_id': roomId,
          'sender': 'System',
          'content': '👋 Welcome to the group, $firstName! We\'re glad to have you here.',
          'created_at': DateTime.now().toIso8601String(),
          'is_announcement': false,
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Chat created & ${_selectedIds.length} member(s) invited!'),
            backgroundColor: Colors.green,
          ),
        );
        setState(() {
          _selectedIds = {};
          _selectedBlock = null;
          _residents = [];
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F1ED),
      appBar: AppBar(
        title: const Text('Create New Chat'),
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Block selector ──
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'SELECT BLOCK',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _primary,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 10),
                if (_blocks.isEmpty)
                  const Text(
                    'No blocks found.',
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  )
                else
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _blocks.map((block) {
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
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: selected ? _primary : const Color(0xFFF5F1ED),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: selected ? _primary : Colors.black12,
                                  width: 1.5,
                                ),
                              ),
                              child: Text(
                                'Block $block',
                                style: TextStyle(
                                  color: selected ? Colors.white : Colors.black87,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // ── Residents list ──
          if (_selectedBlock != null) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
              child: Row(
                children: [
                  const Text(
                    'ADD MEMBERS',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _primary,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const Spacer(),
                  if (_residents.isNotEmpty)
                    TextButton(
                      onPressed: () => setState(() {
                        _selectedIds = _selectedIds.length == _residents.length
                            ? {}
                            : _residents.map((r) => r['id'] as String).toSet();
                      }),
                      child: Text(
                        _selectedIds.length == _residents.length
                            ? 'Deselect all'
                            : 'Select all',
                        style: const TextStyle(color: _primary, fontSize: 12),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: _primary))
                  : _residents.isEmpty
                  ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.person_off_outlined,
                        size: 48, color: Colors.black12),
                    const SizedBox(height: 12),
                    const Text(
                      'All residents are already in this group.',
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
                  : ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _residents.length,
                itemBuilder: (context, i) {
                  final r = _residents[i];
                  final id = r['id'] as String;
                  final name = r['full_name'] as String? ?? 'Unknown';
                  final unit = r['unit_number'] as String? ?? '';
                  final checked = _selectedIds.contains(id);

                  return GestureDetector(
                    onTap: () => setState(() {
                      checked ? _selectedIds.remove(id) : _selectedIds.add(id);
                    }),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: checked ? _primary : Colors.transparent,
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 22,
                            backgroundColor: _avatarColor(name),
                            child: Text(
                              _initials(name),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                                Text(
                                  'Unit $unit',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.black45,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: checked ? _primary : Colors.transparent,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: checked ? _primary : Colors.black26,
                                width: 1.5,
                              ),
                            ),
                            child: checked
                                ? const Icon(Icons.check,
                                color: Colors.white, size: 15)
                                : null,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ] else
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.apartment_outlined,
                        size: 56, color: Colors.black12),
                    const SizedBox(height: 12),
                    const Text(
                      'Select a block to add members',
                      style: TextStyle(color: Colors.black38, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),

          // ── Create button ──
          if (_selectedIds.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: ElevatedButton(
                onPressed: _loading ? null : _createChat,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primary,
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: _loading
                    ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2),
                )
                    : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.group_add_outlined,
                        size: 18, color: Colors.white),
                    const SizedBox(width: 8),
                    Text(
                      'Create Chat with ${_selectedIds.length} member${_selectedIds.length == 1 ? '' : 's'}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Color _avatarColor(String name) {
    final hue = (name.codeUnits.fold(0, (a, b) => a + b) % 360).toDouble();
    return HSLColor.fromAHSL(1, hue, 0.5, 0.5).toColor();
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }
}