import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

final supabase = Supabase.instance.client;

class AdminGroupInviteScreen extends StatefulWidget {
  const AdminGroupInviteScreen({Key? key}) : super(key: key);

  @override
  State<AdminGroupInviteScreen> createState() => _AdminGroupInviteScreenState();
}

class _AdminGroupInviteScreenState extends State<AdminGroupInviteScreen> {
  static const Color _primary = Color(0xFF9A4B3C);

  List<String> _blocks = [];
  String? _selectedBlock;
  List<Map<String, dynamic>> _residents = [];
  Set<String> _selectedIds = {};
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadBlocks();
  }

  Future<void> _loadBlocks() async {
    try {
      final data = await supabase
          .from('resident')
          .select('block')
          .neq('block', '');

      // if (data == null) return;

      final blocks = (data as List)
          .map((e) => e['block']?.toString() ?? '')
          .where((s) => s.isNotEmpty)
          .toSet()
          .toList()
        ..sort();

      if (mounted) {
        setState(() => _blocks = blocks);
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

      // 1. Get the group chat for this block (if it exists)
      final existingGroup = await supabase
          .from('group_chats')
          .select('id')
          .eq('block', block)
          .maybeSingle();

      Set<String> alreadyInvitedIds = {};

      if (existingGroup != null) {
        final groupChatId = existingGroup['id'] as String;

        // 2. Fetch all already-invited user IDs for this group
        final invitations = await supabase
            .from('group_chat_invitations')
            .select('invited_user_id')
            .eq('group_chat_id', groupChatId);

        alreadyInvitedIds = (invitations as List)
            .map((e) => e['invited_user_id'] as String)
            .toSet();
      }

      // 3. Fetch all residents in the block
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
              !alreadyInvitedIds.contains(e['id'])) // ← exclude already invited
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

  Future<void> _sendInvitations() async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User not authenticated')),
      );
      return;
    }

    if (_selectedIds.isEmpty || _selectedBlock == null) return;

    final adminId = user.id;
    setState(() => _loading = true);

    try {
      // 1. Check if group chat already exists for this block
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
        // 2. Create new group chat for this block
        groupChatId = const Uuid().v4();
        roomId = 'block_${_selectedBlock!.toLowerCase()}_community';

        await supabase.from('group_chats').insert({
          'id': groupChatId,
          'room_id': roomId,
          'block': _selectedBlock,
          'created_by': adminId,
        });
      }

      // 3. Insert invitations (skip duplicates)
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
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Invitations sent to ${_selectedIds.length} resident(s)!')),
        );
        setState(() {
          _selectedIds = {};
          _selectedBlock = null;
          _residents = [];
        });
      }
    } catch (e) {
      debugPrint('Error sending invitations: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send invitations: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F1ED),
      appBar: AppBar(
        title: const Text('Invite to Group Chat'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Block selector
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('SELECT BLOCK',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                        color: _primary, letterSpacing: 1.2)),
                const SizedBox(height: 10),
                if (_blocks.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Text("No blocks found in profiles table", style: TextStyle(color: Colors.grey, fontSize: 13)),
                  )
                else
                  Wrap(
                    spacing: 8,
                    children: _blocks.map((block) {
                      final selected = _selectedBlock == block;
                      return ChoiceChip(
                        label: Text('Block $block'),
                        selected: selected,
                        selectedColor: _primary,
                        labelStyle: TextStyle(
                          color: selected ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.w600,
                        ),
                        onSelected: (bool selected) {
                          if (selected) {
                            setState(() => _selectedBlock = block);
                            _loadResidents(block);
                          }
                        },
                      );
                    }).toList(),
                  ),
              ],
            ),
          ),

          // Residents list
          if (_selectedBlock != null) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
              child: Row(
                children: [
                  const Text('RESIDENTS',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                          color: _primary, letterSpacing: 1.2)),
                  const Spacer(),
                  if (_residents.isNotEmpty)
                    TextButton(
                      onPressed: () => setState(() {
                        if (_selectedIds.length == _residents.length) {
                          _selectedIds = {};
                        } else {
                          _selectedIds = _residents.map((r) => r['id'] as String).toSet();
                        }
                      }),
                      child: Text(
                        _selectedIds.length == _residents.length ? 'Deselect all' : 'Select all',
                        style: const TextStyle(color: _primary, fontSize: 12),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _residents.isEmpty
                  ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.person_off_outlined, size: 48, color: Colors.grey),
                    SizedBox(height: 12),
                    Text("No residents found in this block", style: TextStyle(color: Colors.grey)),
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

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: checked ? _primary : Colors.transparent,
                        width: checked ? 1.5 : 0,
                      ),
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: _avatarColor(name),
                        child: Text(_initials(name),
                            style: const TextStyle(color: Colors.white,
                                fontSize: 13, fontWeight: FontWeight.w700)),
                      ),
                      title: Text(name,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text('Unit $unit'),
                      trailing: Checkbox(
                        value: checked,
                        activeColor: _primary,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4)),
                        onChanged: (v) {
                          setState(() {
                            v! ? _selectedIds.add(id) : _selectedIds.remove(id);
                          });
                        },
                      ),
                      onTap: () {
                        setState(() {
                          checked ? _selectedIds.remove(id) : _selectedIds.add(id);
                        });
                      },
                    ),
                  );
                },
              ),
            ),
          ],

          // Send button
          if (_selectedIds.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: ElevatedButton(
                onPressed: _loading ? null : _sendInvitations,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primary,
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: _loading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text(
                  'Send Invitations (${_selectedIds.length} selected)',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
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
