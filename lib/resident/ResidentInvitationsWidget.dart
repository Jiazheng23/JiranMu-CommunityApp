import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:assignment/chat/CommunityChatScreen.dart';

final supabase = Supabase.instance.client;

class ResidentInvitationsWidget extends StatefulWidget {
  final String currentUserId;
  final String currentUser;

  const ResidentInvitationsWidget({
    Key? key,
    required this.currentUserId,
    required this.currentUser,
  }) : super(key: key);

  @override
  State<ResidentInvitationsWidget> createState() =>
      _ResidentInvitationsWidgetState();
}

class _ResidentInvitationsWidgetState
    extends State<ResidentInvitationsWidget> {
  static const Color _primary = Color(0xFF9A4B3C);

  List<Map<String, dynamic>> _invitations = [];

  @override
  void initState() {
    super.initState();
    _loadInvitations();
  }

  Future<void> _loadInvitations() async {
    final data = await supabase
        .from('group_chat_invitations')
        .select('id, status, group_chat_id, group_chats(room_id, block)')
        .eq('invited_user_id', widget.currentUserId)
        .eq('status', 'pending');

    if (!mounted) return;

    setState(() {
      _invitations = List<Map<String, dynamic>>.from(data);
    });
  }

  Future<void> _respond(
      String invitationId,
      String groupChatId,
      String roomId,
      String block,
      bool accept,
      ) async {
    await supabase.from('group_chat_invitations').update({
      'status': accept ? 'accepted' : 'declined',
      'responded_at': DateTime.now().toIso8601String(),
    }).eq('id', invitationId);

    if (accept) {
      await supabase.from('group_chat_members').insert({
        'group_chat_id': groupChatId,
        'user_id': widget.currentUserId,
      });

      if (!mounted) return;

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CommunityChatScreen(
            roomId: roomId,
            communityName: 'Block $block Community',
            currentUserId: widget.currentUserId,
            currentUser: widget.currentUser,
          ),
        ),
      );
    }

    _loadInvitations();
  }

  @override
  Widget build(BuildContext context) {
    if (_invitations.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(22, 12, 22, 8),
          child: Text(
            'INVITATIONS',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: _primary,
              letterSpacing: 1.2,
            ),
          ),
        ),

        ..._invitations.map((inv) {
          final groupChat =
          inv['group_chats'] as Map<String, dynamic>?;

          // 🚨 SAFE NULL HANDLING
          final block = groupChat?['block']?.toString() ?? '';
          final roomId = groupChat?['room_id']?.toString();
          final groupChatId = inv['group_chat_id']?.toString() ?? '';
          final invitationId = inv['id']?.toString() ?? '';

          // ❌ If data broken, don't render widget
          if (roomId == null || roomId.isEmpty) {
            return const SizedBox.shrink();
          }

          return Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: const Color(0xFFD85A30), width: 0.8),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: const BoxDecoration(
                    color: Color(0xFFFAECE7),
                    borderRadius:
                    BorderRadius.vertical(top: Radius.circular(15)),
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.group_add_rounded,
                          color: Color(0xFF993C1D), size: 15),
                      SizedBox(width: 6),
                      Text(
                        'Group chat invitation',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF993C1D),
                        ),
                      ),
                      Spacer(),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Block $block Community Chat',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        "You've been invited by admin to join your block community chat.",
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 12),

                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => _respond(
                                invitationId,
                                groupChatId,
                                roomId,
                                block,
                                true,
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _primary,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                padding:
                                const EdgeInsets.symmetric(vertical: 9),
                              ),
                              child: const Text(
                                'Accept',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),

                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => _respond(
                                invitationId,
                                groupChatId,
                                roomId,
                                block,
                                false,
                              ),
                              style: OutlinedButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                padding:
                                const EdgeInsets.symmetric(vertical: 9),
                              ),
                              child: const Text('Decline'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),

        const Divider(height: 1, indent: 22, endIndent: 22),
        const SizedBox(height: 4),
      ],
    );
  }
}