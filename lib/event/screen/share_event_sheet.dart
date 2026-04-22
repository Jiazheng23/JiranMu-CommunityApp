import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../model/event_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ShareEventSheet extends StatefulWidget {
  final CommunityEvent event;
  final String currentUserId;
  final String currentUserName; // kept for display purposes only

  const ShareEventSheet({
    super.key,
    required this.event,
    required this.currentUserId,
    required this.currentUserName,
  });

  @override
  State<ShareEventSheet> createState() => _ShareEventSheetState();
}

class _ShareEventSheetState extends State<ShareEventSheet> {
  final supabase = Supabase.instance.client;

  bool _loading = true;
  List<_ChatTarget> _dmChats = [];
  List<_ChatTarget> _groupChats = [];

  final Set<String> _sharedTo = {};

  // ── Resolved email for current user ──────────
  String _currentUserEmail = '';

  @override
  void initState() {
    super.initState();
    _loadCurrentUserEmail().then((_) => _loadChats());
  }

  // Fetch the auth email so sender is stored consistently as email
  Future<void> _loadCurrentUserEmail() async {
    try {
      // First try from Supabase auth session directly
      final authUser = supabase.auth.currentUser;
      if (authUser?.email != null) {
        _currentUserEmail = authUser!.email!;
        return;
      }

      // Fallback: read from resident table if email column exists
      final profile = await supabase
          .from('resident')
          .select('email')
          .eq('id', widget.currentUserId)
          .maybeSingle();

      if (profile != null && profile['email'] != null) {
        _currentUserEmail = profile['email'] as String;
      }
    } catch (e) {
      debugPrint('Error loading current user email: $e');
      // Last resort fallback — shouldn't normally reach here
      _currentUserEmail = supabase.auth.currentUser?.email ?? '';
    }
  }

  Future<void> _loadChats() async {
    try {
      final roomsData = await supabase
          .from('chat_rooms')
          .select('room_id, user1_id, user2_id')
          .or('user1_id.eq.${widget.currentUserId},user2_id.eq.${widget.currentUserId}');

      final dmChats = <_ChatTarget>[];
      for (final row in (roomsData as List)) {
        final roomId = row['room_id'] as String;
        final otherId = row['user1_id'] == widget.currentUserId
            ? row['user2_id'] as String
            : row['user1_id'] as String;

        final profileData = await supabase
            .from('resident')
            .select('full_name')
            .eq('id', otherId)
            .maybeSingle();

        if (profileData != null) {
          dmChats.add(_ChatTarget(
            roomId: roomId,
            name: profileData['full_name'] as String,
            isGroup: false,
          ));
        }
      }

      List<_ChatTarget> groupChats = [];

      if (!widget.event.isPrivate) {
        final invitations = await supabase
            .from('group_chat_invitations')
            .select('group_chat_id')
            .eq('invited_user_id', widget.currentUserId)
            .eq('status', 'accepted');

        for (final inv in (invitations as List)) {
          final groupData = await supabase
              .from('group_chats')
              .select('id, room_id, name, block')
              .eq('id', inv['group_chat_id'] as String)
              .maybeSingle();

          if (groupData != null) {
            groupChats.add(_ChatTarget(
              roomId: groupData['room_id'] as String,
              name: groupData['name'] as String? ??
                  'Block ${groupData['block']}',
              isGroup: true,
              groupId: groupData['id'] as String,
            ));
          }
        }
      }

      setState(() {
        _dmChats = dmChats;
        _groupChats = groupChats;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Error loading chats: $e');
      setState(() => _loading = false);
    }
  }

  Future<void> _shareToChat(_ChatTarget target) async {
    if (_sharedTo.contains(target.roomId)) return;

    final event = widget.event;
    final dateStr = DateFormat('dd MMM yyyy').format(event.eventDate);

    // Store as structured JSON so CommunityChatScreen renders a rich card
    final sharePayload = jsonEncode({
      'type': 'event_invitation',
      'event_id': event.id,
      'title': event.title,
      'location': event.location,
      'date': dateStr,
      'start_time': event.startTime,
      'end_time': event.endTime,
      'max_capacity': event.maxCapacity,
      'is_private': event.isPrivate,
    });

    try {
      await supabase.from('messages').insert({
        'room_id': target.roomId,
        // ✅ Use email (same as CommunityChatScreen) so isMe check works correctly
        'sender': _currentUserEmail,
        'content': sharePayload,
        'created_at': DateTime.now().toIso8601String(),
        'is_announcement': false,
        'is_poll': false,
        'is_event_invite': true,
      });

      setState(() => _sharedTo.add(target.roomId));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Shared to ${target.name}!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      debugPrint('Share error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to share event.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFFAD8762);
    const apricot = Color(0xFFFFB38A);

    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (_, scrollCtrl) => Column(
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black12,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
            child: Row(
              children: [
                const Icon(Icons.share_outlined, color: primary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Share Event',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                        ),
                      ),
                      Text(
                        widget.event.isPrivate
                            ? 'Private event · Share via direct messages only'
                            : 'Public event · Share via direct messages or group chats',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black45,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 16),
          if (_loading)
            const Expanded(
              child: Center(child: CircularProgressIndicator()),
            )
          else
            Expanded(
              child: ListView(
                controller: scrollCtrl,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  if (_dmChats.isNotEmpty) ...[
                    _buildSectionHeader(
                        'Direct Messages', Icons.person_outline, apricot),
                    ..._dmChats.map((chat) => _buildChatTile(chat, primary)),
                    const SizedBox(height: 8),
                  ],
                  if (!widget.event.isPrivate && _groupChats.isNotEmpty) ...[
                    _buildSectionHeader(
                        'Group Chats', Icons.groups_outlined, apricot),
                    ..._groupChats.map((chat) => _buildChatTile(chat, primary)),
                  ],
                  if (_dmChats.isEmpty && _groupChats.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          children: [
                            Icon(Icons.chat_bubble_outline,
                                size: 48, color: primary.withOpacity(0.3)),
                            const SizedBox(height: 12),
                            const Text(
                              'No chats available to share to.',
                              style: TextStyle(
                                  color: Colors.grey, fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String label, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: 1.1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatTile(_ChatTarget chat, Color primary) {
    final shared = _sharedTo.contains(chat.roomId);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: shared ? Colors.green.withOpacity(0.05) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: shared
              ? Colors.green.withOpacity(0.3)
              : Colors.black.withOpacity(0.07),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: chat.isGroup
                ? primary.withOpacity(0.15)
                : _avatarColor(chat.name).withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: chat.isGroup
                ? Icon(Icons.groups_rounded, color: primary, size: 22)
                : Text(
              _initials(chat.name),
              style: TextStyle(
                color: _avatarColor(chat.name),
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
          ),
        ),
        title: Text(
          chat.name,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: Colors.black87,
          ),
        ),
        subtitle: Text(
          chat.isGroup ? 'Group Chat' : 'Direct Message',
          style: const TextStyle(fontSize: 12, color: Colors.black38),
        ),
        trailing: shared
            ? Container(
          padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.green.withOpacity(0.3)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check, color: Colors.green, size: 14),
              SizedBox(width: 4),
              Text('Sent',
                  style: TextStyle(color: Colors.green, fontSize: 12)),
            ],
          ),
        )
            : ElevatedButton(
          onPressed: () => _shareToChat(chat),
          style: ElevatedButton.styleFrom(
            backgroundColor: primary,
            foregroundColor: Colors.white,
            padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20)),
            elevation: 0,
          ),
          child: const Text('Send', style: TextStyle(fontSize: 12)),
        ),
      ),
    );
  }

  Color _avatarColor(String name) {
    final hue =
    (name.codeUnits.fold(0, (a, b) => a + b) % 360).toDouble();
    return HSLColor.fromAHSL(1, hue, 0.5, 0.45).toColor();
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }
}

class _ChatTarget {
  final String roomId;
  final String name;
  final bool isGroup;
  final String? groupId;

  _ChatTarget({
    required this.roomId,
    required this.name,
    required this.isGroup,
    this.groupId,
  });
}