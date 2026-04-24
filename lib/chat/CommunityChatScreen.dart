import 'package:flutter/material.dart';
import 'package:assignment/chat/user_session.dart';
import 'admin/admin_chat_screen.dart';
import 'resident/resident_chat_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CommunityChatScreen — Router
//
// Mirrors the same pattern as CommunityChatsListScreen:
//   • Receives the same constructor fields that the old monolithic screen had.
//   • Decides at build-time which concrete screen to show based on isAdmin.
//   • AdminChatScreen  → polls, announcements, group settings, rename/delete
//   • ResidentChatScreen → DM settings, leave group, invite to group chat
// ─────────────────────────────────────────────────────────────────────────────

class CommunityChatScreen extends StatelessWidget {
  final String roomId;
  final String communityName;
  final String currentUserId;
  final String currentUser;
  final bool? isAdmin;

  const CommunityChatScreen({
    Key? key,
    required this.roomId,
    required this.communityName,
    required this.currentUserId,
    required this.currentUser,
    this.isAdmin,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Resolve isAdmin: explicit parameter wins; fall back to session value.
    final bool admin = isAdmin ?? UserSession.isAdmin;

    if (admin) {
      return AdminChatScreen(
        roomId: roomId,
        communityName: communityName,
        currentUserId: currentUserId,
        currentUser: currentUser,
      );
    }

    return ResidentChatScreen(
      roomId: roomId,
      communityName: communityName,
      currentUserId: currentUserId,
      currentUser: currentUser,
    );
  }
}