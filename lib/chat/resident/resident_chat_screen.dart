import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:assignment/chat/chat_shared_widget.dart';
import 'package:assignment/chat/base_chat_screen.dart';

import '../shared/chat_utils.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ResidentChatScreen
//
// Extends the shared base with resident-only capabilities:
//   • DM settings sheet  (view profile, invite to group, clear chat)
//   • Group settings sheet  (view members, search, pinned, leave group)
//   • Read-only pinned announcements sheet
//   • Invite-to-group flow
//   • Confirm leave / confirm clear chat
//
// Every shared behaviour (message list, realtime, send, search …) lives in
// BaseChatScreenState and is reused without any duplication.
// ─────────────────────────────────────────────────────────────────────────────

class ResidentChatScreen extends StatefulWidget {
  final String roomId;
  final String communityName;
  final String currentUserId;
  final String currentUser;

  const ResidentChatScreen({
    Key? key,
    required this.roomId,
    required this.communityName,
    required this.currentUserId,
    required this.currentUser,
  }) : super(key: key);

  @override
  State<ResidentChatScreen> createState() => _ResidentChatScreenState();
}

class _ResidentChatScreenState extends State<ResidentChatScreen>
    with BaseChatScreenState<ResidentChatScreen> {
  // ── BaseChatScreenState required getters ──────────────────────────────────
  @override String get roomId        => widget.roomId;
  @override String get communityName => widget.communityName;
  @override String get currentUserId => widget.currentUserId;
  @override String get currentUser   => widget.currentUser;
  @override bool   get isAdmin       => false;  // always false for resident screen

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    baseInitState(); // runs all shared setup from the mixin
  }

  @override
  void dispose() {
    baseDispose(); // cleans up shared resources
    super.dispose();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // AppBar actions — resident sees: @mention badge + settings (⋮)
  // ══════════════════════════════════════════════════════════════════════════

  @override
  List<Widget> buildAppBarActions() {
    return [
      // @mention badge (only shown when there are unread mentions)
      if (unreadMentions > 0)
        Stack(
          alignment: Alignment.center,
          children: [
            IconButton(
                icon:      const Icon(Icons.alternate_email_rounded,
                    color: BaseChatScreenState.primary),
                tooltip:   'Mentions',
                onPressed: scrollToBottom),
            Positioned(
              top: 8, right: 8,
              child: Container(
                width: 16, height: 16,
                decoration: const BoxDecoration(
                    color: Colors.red, shape: BoxShape.circle),
                child: Center(
                  child: Text(
                    '$unreadMentions',
                    style: const TextStyle(
                        color:      Colors.white,
                        fontSize:   9,
                        fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
          ],
        ),
      // Settings button — routes to DM or Group sheet based on room type
      IconButton(
          icon:      const Icon(Icons.more_vert_rounded,
              color: BaseChatScreenState.primary),
          tooltip:   'Chat Settings',
          onPressed: isDM ? _showDMSettings : _showResidentGroupSettings),
    ];
  }

  // ══════════════════════════════════════════════════════════════════════════
  // DM settings sheet  (resident-only)
  // ══════════════════════════════════════════════════════════════════════════

  void _showDMSettings() {
    showModalBottomSheet(
      context:            context,
      backgroundColor:    Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.only(bottom: 24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Handle
          Container(
              width: 40, height: 4,
              margin: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                  color:        Colors.black12,
                  borderRadius: BorderRadius.circular(2))),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Row(children: [
              Container(
                width: 46, height: 46,
                decoration: BoxDecoration(
                    color:        avatarColorFromName(communityName),
                    borderRadius: BorderRadius.circular(14)),
                child: Center(
                  child: Text(
                    initialsFromName(communityName),
                    style: const TextStyle(
                        color:      Colors.white,
                        fontSize:   16,
                        fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(communityName,
                          style: const TextStyle(
                              fontSize:   16,
                              fontWeight: FontWeight.w800,
                              color:      Colors.black87)),
                      const Text('Direct Message',
                          style: TextStyle(fontSize: 12, color: Colors.grey)),
                    ]),
              ),
            ]),
          ),

          const Divider(height: 1),

          buildSettingsTile(
            icon:     Icons.search_rounded,
            title:    'Search Messages',
            subtitle: 'Find a message in this conversation',
              onTap: () {
                Navigator.pop(context);
                Future.delayed(const Duration(milliseconds: 300), () {
                  if (mounted) setState(() => showChatSearch = true);
                  searchController.clear();
                });
              },

          ),

          buildSettingsTile(
            icon:     Icons.person_outline_rounded,
            title:    'View Profile',
            subtitle: 'See this resident\'s details',
            onTap: () {
              Navigator.pop(context);
              _showOtherResidentProfile();
            },
          ),
          buildSettingsTile(
            icon:       Icons.cleaning_services_outlined,
            title:      'Clear Chat',
            subtitle:   'Remove messages from your view only',
            titleColor: Colors.red,
            iconColor:  Colors.red,
            onTap: () {
              Navigator.pop(context);
              _confirmClearChat();
            },
          ),
        ]),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Group settings sheet  (resident-only, read-only vs admin's edit version)
  // ══════════════════════════════════════════════════════════════════════════

  void _showResidentGroupSettings() {
    showModalBottomSheet(
      context:            context,
      backgroundColor:    Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // Handle
            Container(
                width: 40, height: 4,
                margin: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                    color:        Colors.black12,
                    borderRadius: BorderRadius.circular(2))),

            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Row(children: [
                Container(
                  width: 46, height: 46,
                  decoration: BoxDecoration(
                      gradient: LinearGradient(
                          colors: [
                            BaseChatScreenState.primary,
                            BaseChatScreenState.primary.withOpacity(0.7)
                          ],
                          begin: Alignment.topLeft,
                          end:   Alignment.bottomRight),
                      borderRadius: BorderRadius.circular(14)),
                  child: const Icon(Icons.groups_rounded,
                      color: Colors.white, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(communityName,
                            style: const TextStyle(
                                fontSize:   16,
                                fontWeight: FontWeight.w800,
                                color:      Colors.black87)),
                        Text('${roomMembers.length} members',
                            style: const TextStyle(
                                fontSize: 12, color: Colors.grey)),
                      ]),
                ),
              ]),
            ),

            const Divider(height: 1),

            buildSettingsTile(
              icon:     Icons.people_outline_rounded,
              title:    'View Members',
              subtitle: '${roomMembers.length} people in this group',
              onTap: () {
                Navigator.pop(ctx);
                navigateToMembers();
              },
            ),

            buildSettingsTile(
              icon:     Icons.search_rounded,
              title:    'Search Messages',
              subtitle: 'Find a message in this chat',
              onTap: () {
                Navigator.pop(ctx);
                setState(() => showChatSearch = true);
                Future.delayed(
                    const Duration(milliseconds: 100), searchController.clear);
              },
            ),

            buildSettingsTile(
              icon:     Icons.push_pin_outlined,
              title:    'Pinned Announcements',
              subtitle:
              '${pinnedAnnouncements.length} pinned message${pinnedAnnouncements.length == 1 ? '' : 's'}',
              onTap: () {
                Navigator.pop(ctx);
                _showResidentPinnedSheet();
              },
            ),

            buildSettingsTile(
              icon:       Icons.exit_to_app_rounded,
              title:      'Leave Group',
              subtitle:   'You won\'t receive messages from this group',
              titleColor: Colors.red,
              iconColor:  Colors.red,
              onTap: () {
                Navigator.pop(ctx);
                _confirmLeaveGroup();
              },
            ),
          ]),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // View resident profile  (resident DM-only)
  // ══════════════════════════════════════════════════════════════════════════

  void _showOtherResidentProfile() async {
    Map<String, dynamic>? profile;
    try {
      final res = await supabase
          .from('resident')
          .select('full_name, unit_number, block, email, phone_number')
          .eq('full_name', communityName)
          .maybeSingle();
      profile = res;
    } catch (e) {
      debugPrint('Profile fetch error: $e');
    }
    if (!mounted) return;

    showModalBottomSheet(
      context:            context,
      backgroundColor:    Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.only(bottom: 32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
              width: 40, height: 4,
              margin: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                  color:        Colors.black12,
                  borderRadius: BorderRadius.circular(2))),
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
                color:  avatarColorFromName(communityName),
                shape: BoxShape.circle),
            child: Center(
              child: Text(
                initialsFromName(communityName),
                style: const TextStyle(
                    color:      Colors.white,
                    fontSize:   26,
                    fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            profile?['full_name'] as String? ?? communityName,
            style: const TextStyle(
                fontSize:   18,
                fontWeight: FontWeight.w800,
                color:      Colors.black87),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
                color:        BaseChatScreenState.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20)),
            child: const Text('Resident',
                style: TextStyle(
                    color:      BaseChatScreenState.primary,
                    fontSize:   11,
                    fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 20),
          const Divider(height: 1),
          if (profile != null) ...[
            if (profile['unit_number'] != null)
              _profileRow(Icons.door_front_door_outlined, 'Unit',
                  profile['unit_number'].toString()),
            if (profile['block'] != null)
              _profileRow(Icons.apartment_outlined, 'Block',
                  profile['block'].toString()),
            if (profile['email'] != null)
              _profileRow(Icons.email_outlined, 'Email',
                  profile['email'].toString()),
            if (profile['phone_number'] != null)
              _profileRow(Icons.phone_outlined, 'Phone',
                  profile['phone_number'].toString()),
          ] else ...[
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('No profile details available.',
                  style: TextStyle(color: Colors.grey, fontSize: 14)),
            ),
          ],
        ]),
      ),
    );
  }

  Widget _profileRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      child: Row(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
              color:        BaseChatScreenState.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: BaseChatScreenState.primary, size: 18),
        ),
        const SizedBox(width: 14),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: const TextStyle(fontSize: 11, color: Colors.grey)),
          Text(value,
              style: const TextStyle(
                  fontSize:   14,
                  fontWeight: FontWeight.w600,
                  color:      Colors.black87)),
        ]),
      ]),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Read-only pinned announcements sheet  (resident-only)
  // ══════════════════════════════════════════════════════════════════════════

  void _showResidentPinnedSheet() {
    showModalBottomSheet(
      context:            context,
      backgroundColor:    Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.55,
        minChildSize:     0.35,
        maxChildSize:     0.85,
        expand:           false,
        builder: (_, scrollCtrl) => Column(children: [
          Container(
              width: 40, height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                  color:        Colors.black12,
                  borderRadius: BorderRadius.circular(2))),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Row(children: [
              const Icon(Icons.push_pin_rounded,
                  color: BaseChatScreenState.pinAccent, size: 20),
              const SizedBox(width: 8),
              Text(
                  'Pinned Announcements (${pinnedAnnouncements.length})',
                  style: const TextStyle(
                      fontSize:   16,
                      fontWeight: FontWeight.w700,
                      color:      Colors.black87)),
            ]),
          ),
          const Divider(height: 1),
          Expanded(
            child: pinnedAnnouncements.isEmpty
                ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.push_pin_outlined,
                        size: 48, color: Colors.black26),
                    SizedBox(height: 12),
                    Text('No announcements yet.',
                        style: TextStyle(
                            color: Colors.grey, fontSize: 14)),
                  ]),
                ))
                : ListView.separated(
              controller: scrollCtrl,
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 12),
              itemCount:        pinnedAnnouncements.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                final ann = pinnedAnnouncements[i];
                return Container(
                  decoration: BoxDecoration(
                      color: BaseChatScreenState.pinBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: BaseChatScreenState.pinAccent
                              .withOpacity(0.2))),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                              padding: EdgeInsets.only(top: 2),
                              child: Icon(Icons.push_pin_rounded,
                                  size:  16,
                                  color: BaseChatScreenState.pinAccent)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                                crossAxisAlignment:
                                CrossAxisAlignment.start,
                                children: [
                                  Text(ann.text,
                                      style: const TextStyle(
                                          fontSize: 14,
                                          color:    Colors.black87,
                                          height:   1.4)),
                                  const SizedBox(height: 4),
                                  Text(
                                      formatTimestamp(ann.timestamp),
                                      style: const TextStyle(
                                          fontSize: 11,
                                          color:    Colors.black38)),
                                ]),
                          ),
                        ]),
                  ),
                );
              },
            ),
          ),
        ]),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Confirm leave group  (resident-only)
  // ══════════════════════════════════════════════════════════════════════════

  void _confirmLeaveGroup() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title:   const Text('Leave Group'),
        content: Text(
            'Leave "$communityName"? You won\'t receive messages unless re-invited.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel',
                  style: TextStyle(color: Colors.black54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            onPressed: () async {
              Navigator.pop(context);
              try {
                await supabase
                    .from('group_chat_invitations')
                    .delete()
                    .eq('invited_user_id', currentUserId)
                    .eq('status', 'accepted');
                if (mounted) Navigator.pop(context);
              } catch (e) {
                debugPrint('Leave error: $e');
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Could not leave group.')));
                }
              }
            },
            child: const Text('Leave'),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Confirm clear chat  (resident DM-only)
  // ══════════════════════════════════════════════════════════════════════════

  void _confirmClearChat() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title:   const Text('Clear Chat'),
        content: const Text(
            'This removes all messages from your view only. '
                'The other person will still see the conversation.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel',
                  style: TextStyle(color: Colors.black54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            onPressed: () {
              Navigator.pop(context);
              setState(() => messages.clear());
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Chat cleared from your view.')));
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BaseChatScreenState.bgPage,
      appBar:          buildAppBar(),
      // Resident has no poll button in the input bar
      body: buildScaffoldBody(showPollButton: false),
    );
  }
}