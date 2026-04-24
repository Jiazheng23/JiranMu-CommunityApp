import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../base_chat_screen.dart';
import '../model/message.dart';
import '../shared/chat_utils.dart';


// ─────────────────────────────────────────────────────────────────────────────
// AdminChatScreen
//
// Extends the shared base with admin-only capabilities:
//   • Poll creation dialog + poll results sheet
//   • Post Announcement dialog
//   • Edit / Delete Announcements sheet
//   • Group Settings sheet (rename, delete, view members)
//
// Every shared behaviour (message list, realtime, send, search …) lives in
// BaseChatScreenState and is reused without any duplication.
// ─────────────────────────────────────────────────────────────────────────────

class AdminChatScreen extends StatefulWidget {
  final String roomId;
  final String communityName;
  final String currentUserId;
  final String currentUser;

  const AdminChatScreen({
    Key? key,
    required this.roomId,
    required this.communityName,
    required this.currentUserId,
    required this.currentUser,
  }) : super(key: key);

  @override
  State<AdminChatScreen> createState() => _AdminChatScreenState();
}

class _AdminChatScreenState extends State<AdminChatScreen>
    with BaseChatScreenState<AdminChatScreen> {
  // ── BaseChatScreenState required getters ──────────────────────────────────
  @override String get roomId        => widget.roomId;
  @override String get communityName => widget.communityName;
  @override String get currentUserId => widget.currentUserId;
  @override String get currentUser   => widget.currentUser;
  @override bool   get isAdmin       => true;   // always true for admin screen

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
  // AppBar actions — admin sees: settings gear only
  // ══════════════════════════════════════════════════════════════════════════

  @override
  List<Widget> buildAppBarActions() {
    return [
      IconButton(
          icon:      const Icon(Icons.settings_outlined,
              color: BaseChatScreenState.primary),
          tooltip:   'Group Settings',
          onPressed: _showGroupSettings),
    ];
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Poll results sheet  (admin-only)
  // ══════════════════════════════════════════════════════════════════════════

  void _showPollResults(Poll poll) {
    final voterMap   = pollVoterNames[poll.id] ?? {};
    final totalVotes = poll.options
        .fold<int>(0, (sum, o) => sum + (voteCounts[o.id] ?? 0));

    showModalBottomSheet(
      context:            context,
      backgroundColor:    Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize:     0.4,
        maxChildSize:     0.9,
        expand:           false,
        builder: (_, scrollCtrl) => Column(children: [
          Container(
              width: 40, height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                  color:        Colors.black12,
                  borderRadius: BorderRadius.circular(2))),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
            child: Row(children: [
              const Icon(Icons.bar_chart_rounded,
                  color: BaseChatScreenState.primary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                  child: Text(poll.question,
                      style: const TextStyle(
                          fontSize:   15,
                          fontWeight: FontWeight.w700,
                          color:      Colors.black87))),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Row(children: [
              const SizedBox(width: 28),
              Text('$totalVotes vote${totalVotes == 1 ? '' : 's'} total',
                  style: const TextStyle(fontSize: 13, color: Colors.grey)),
            ]),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              controller: scrollCtrl,
              padding:    const EdgeInsets.all(16),
              itemCount:  poll.options.length,
              itemBuilder: (_, i) {
                final opt    = poll.options[i];
                final count  = voteCounts[opt.id] ?? 0;
                final pct    = totalVotes == 0 ? 0.0 : count / totalVotes;
                final voters = voterMap[opt.id] ?? [];
                return Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                      color:        const Color(0xFFFAF7F5),
                      borderRadius: BorderRadius.circular(14),
                      border:       Border.all(
                          color: BaseChatScreenState.primary.withOpacity(0.15))),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(children: [
                                  Expanded(
                                      child: Text(opt.optionText,
                                          style: const TextStyle(
                                              fontSize:   14,
                                              fontWeight: FontWeight.w700,
                                              color:      Colors.black87))),
                                  Text(
                                      '$count vote${count == 1 ? '' : 's'} · ${(pct * 100).round()}%',
                                      style: const TextStyle(
                                          fontSize:   12,
                                          color:      BaseChatScreenState.primary,
                                          fontWeight: FontWeight.w600)),
                                ]),
                                const SizedBox(height: 8),
                                ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                        value:           pct,
                                        minHeight:       6,
                                        backgroundColor: Colors.black.withOpacity(0.07),
                                        valueColor:      const AlwaysStoppedAnimation(
                                            BaseChatScreenState.primary))),
                              ]),
                        ),
                        if (voters.isEmpty)
                          const Padding(
                              padding: EdgeInsets.fromLTRB(14, 0, 14, 12),
                              child:   Text('No votes yet',
                                  style: TextStyle(
                                      fontSize: 12, color: Colors.black38)))
                        else ...[
                          const Divider(height: 1),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
                            child: Wrap(
                              spacing:    6,
                              runSpacing: 6,
                              children: voters.map((name) => Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                    color: BaseChatScreenState.primary
                                        .withOpacity(0.09),
                                    borderRadius: BorderRadius.circular(20)),
                                child: Row(mainAxisSize: MainAxisSize.min,
                                    children: [
                                      CircleAvatar(
                                          radius:          9,
                                          backgroundColor: avatarColorFromName(name),
                                          child: Text(initialsFromName(name),
                                              style: const TextStyle(
                                                  fontSize:   7,
                                                  color:      Colors.white,
                                                  fontWeight: FontWeight.w700))),
                                      const SizedBox(width: 5),
                                      Text(name,
                                          style: const TextStyle(
                                              fontSize:   12,
                                              color:      BaseChatScreenState.primary,
                                              fontWeight: FontWeight.w600)),
                                    ]),
                              )).toList(),
                            ),
                          ),
                        ],
                      ]),
                );
              },
            ),
          ),
        ]),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Group settings sheet  (admin-only)
  // ══════════════════════════════════════════════════════════════════════════

  void _showGroupSettings() {
    showModalBottomSheet(
      context:         context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                  color:        Colors.black12,
                  borderRadius: BorderRadius.circular(2))),
          ListTile(
              leading: const Icon(Icons.people_outline,
                  color: BaseChatScreenState.primary),
              title: const Text('View Members',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(context);
                navigateToMembers();
              }),
          ListTile(
              leading: const Icon(Icons.campaign_outlined,
                  color: BaseChatScreenState.primary),
              title: const Text('Post Announcement',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(context);
                _showAnnouncementDialog();
              }),
          ListTile(
            leading: const Icon(Icons.push_pin_outlined,
                color: BaseChatScreenState.primary),
            title: const Text('Edit Announcements',
                style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text('${pinnedAnnouncements.length} pinned',
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
            onTap: () {
              Navigator.pop(context);
              _showEditAnnouncementsSheet();
            },
          ),
          ListTile(
              leading: const Icon(Icons.edit_outlined,
                  color: BaseChatScreenState.primary),
              title: const Text('Rename Group',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(context);
                _showRenameDialog();
              }),
          ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Delete Group',
                  style:
                  TextStyle(fontWeight: FontWeight.w600, color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _confirmDeleteGroup();
              }),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Announcement dialog  (admin-only)
  // ══════════════════════════════════════════════════════════════════════════

  void _showAnnouncementDialog() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [
          Icon(Icons.campaign_outlined,
              color: BaseChatScreenState.primary),
          SizedBox(width: 8),
          Text('Post Announcement'),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 12),
          TextField(
              controller: ctrl,
              maxLines:   3,
              decoration: InputDecoration(
                  hintText:  'Write your announcement…',
                  filled:    true,
                  fillColor: const Color(0xFFF5F1ED),
                  border:    OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:   BorderSide.none))),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel',
                  style: TextStyle(color: Colors.black54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: BaseChatScreenState.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            onPressed: () {
              final t = ctrl.text.trim();
              if (t.isEmpty) return;
              Navigator.pop(context);
              sendMessage(isAnnouncement: true, announcementText: t);
            },
            child: const Text('Post'),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Edit announcements sheet  (admin-only)
  // ══════════════════════════════════════════════════════════════════════════

  void _showEditAnnouncementsSheet() {
    showModalBottomSheet(
      context:            context,
      backgroundColor:    Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final announcements = List<Message>.from(pinnedAnnouncements);
          return DraggableScrollableSheet(
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
                  Text('Announcements (${announcements.length})',
                      style: const TextStyle(
                          fontSize:   16,
                          fontWeight: FontWeight.w700,
                          color:      Colors.black87)),
                ]),
              ),
              const Divider(height: 1),
              Expanded(
                child: announcements.isEmpty
                    ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.push_pin_outlined,
                            size: 48, color: Colors.black26),
                        SizedBox(height: 12),
                        Text('No announcements yet.',
                            style:
                            TextStyle(color: Colors.grey, fontSize: 14)),
                      ]),
                    ))
                    : ListView.separated(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  itemCount: announcements.length,
                  separatorBuilder: (_, __) =>
                  const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final ann = announcements[i];
                    return Container(
                      decoration: BoxDecoration(
                          color: BaseChatScreenState.pinBg,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: BaseChatScreenState.pinAccent
                                  .withOpacity(0.2))),
                      child: Padding(
                        padding:
                        const EdgeInsets.fromLTRB(14, 12, 8, 12),
                        child: Row(
                            crossAxisAlignment:
                            CrossAxisAlignment.start,
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
                                            formatTimestamp(
                                                ann.timestamp),
                                            style: const TextStyle(
                                                fontSize: 11,
                                                color:    Colors.black38)),
                                      ])),
                              IconButton(
                                  icon: const Icon(
                                      Icons.delete_outline,
                                      color: Colors.red,
                                      size:  20),
                                  tooltip:  'Delete announcement',
                                  onPressed: () =>
                                      _confirmDeleteAnnouncement(ann,
                                          onDeleted: () =>
                                              setSheetState(() {}))),
                            ]),
                      ),
                    );
                  },
                ),
              ),
            ]),
          );
        },
      ),
    );
  }

  // ── Delete announcement confirm ───────────────────────────────────────────

  void _confirmDeleteAnnouncement(Message ann,
      {required VoidCallback onDeleted}) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Announcement'),
        content: Column(
            mainAxisSize:     MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Permanently delete this announcement?'),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                    color:        const Color(0xFFF5F1ED),
                    borderRadius: BorderRadius.circular(10),
                    border:       Border.all(
                        color: BaseChatScreenState.primary.withOpacity(0.25))),
                child: Text(ann.text,
                    maxLines:  3,
                    overflow:  TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, height: 1.4)),
              ),
            ]),
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
                    .from('messages')
                    .delete()
                    .eq('id', ann.id);
                setState(() {
                  messages.removeWhere((m) => m.id == ann.id);
                  pinnedAnnouncements.removeWhere((m) => m.id == ann.id);
                  if (pinnedAnnouncements.isEmpty) {
                    pinnedIndex = 0;
                    hidePin();
                  } else {
                    pinnedIndex =
                        pinnedIndex.clamp(0, pinnedAnnouncements.length - 1);
                  }
                });
                onDeleted();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content:          Text('Announcement deleted.'),
                      backgroundColor: Colors.red));
                }
              } catch (e) {
                debugPrint('Error deleting announcement: $e');
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Failed to delete announcement.')));
                }
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Poll creation dialog  (admin-only)
  // ══════════════════════════════════════════════════════════════════════════

  void _showPollDialog() {
    final questionCtrl = TextEditingController();
    final List<TextEditingController> optionCtrls = [
      TextEditingController(),
      TextEditingController(),
    ];
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          title: const Row(children: [
            Icon(Icons.poll_outlined,
                color: BaseChatScreenState.primary),
            SizedBox(width: 8),
            Text('Create Poll'),
          ]),
          content: SingleChildScrollView(
            child: Column(
                mainAxisSize:       MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  TextField(
                      controller: questionCtrl,
                      decoration: InputDecoration(
                          hintText:  'Ask a question…',
                          filled:    true,
                          fillColor: const Color(0xFFF5F1ED),
                          border:    OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide:   BorderSide.none))),
                  const SizedBox(height: 16),
                  const Text('Options',
                      style: TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 13)),
                  const SizedBox(height: 8),
                  ...optionCtrls.asMap().entries.map((entry) {
                    final i = entry.key;
                    return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(children: [
                          Expanded(
                              child: TextField(
                                  controller: entry.value,
                                  decoration: InputDecoration(
                                      hintText:       'Option ${i + 1}',
                                      filled:         true,
                                      fillColor:      const Color(0xFFF5F1ED),
                                      border:         OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          borderSide:   BorderSide.none),
                                      contentPadding: const EdgeInsets.symmetric(
                                          horizontal: 14, vertical: 10)))),
                          if (i >= 2) ...[
                            const SizedBox(width: 6),
                            GestureDetector(
                                onTap: () => setDialogState(
                                        () => optionCtrls.removeAt(i)),
                                child: const Icon(Icons.remove_circle_outline,
                                    color: Colors.red, size: 20)),
                          ],
                        ]));
                  }),
                  if (optionCtrls.length < 5)
                    TextButton.icon(
                        onPressed: () => setDialogState(
                                () => optionCtrls.add(TextEditingController())),
                        icon:  const Icon(Icons.add, size: 18),
                        label: const Text('Add option'),
                        style: TextButton.styleFrom(
                            foregroundColor:
                            BaseChatScreenState.primary)),
                ]),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel',
                    style: TextStyle(color: Colors.black54))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: BaseChatScreenState.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10))),
              onPressed: () {
                final question = questionCtrl.text.trim();
                final options  = optionCtrls
                    .map((c) => c.text.trim())
                    .where((t) => t.isNotEmpty)
                    .toList();
                if (question.isEmpty || options.length < 2) return;
                Navigator.pop(ctx);
                _createPoll(question, options);
              },
              child: const Text('Post Poll'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Create poll ───────────────────────────────────────────────────────────

  Future<void> _createPoll(String question, List<String> optionTexts) async {
    final pollId     = const Uuid().v4();
    final messageId  = const Uuid().v4();
    final now        = DateTime.now();
    final displayName =
    myDisplayName.isNotEmpty ? myDisplayName : currentUser;

    final options = optionTexts
        .asMap()
        .entries
        .map((e) => PollOption(
      id:           const Uuid().v4(),
      pollId:       pollId,
      optionText:   e.value,
      displayOrder: e.key,
    ))
        .toList();

    final poll = Poll(
        id:        pollId,
        messageId: messageId,
        roomId:    roomId,
        question:  question,
        createdBy: currentUser,
        createdAt: now,
        options:   options);

    final optimisticMsg = Message(
        id:         messageId,
        senderName: displayName,
        senderRaw:  currentUser,
        text:       question,
        timestamp:  now,
        isMe:       true,
        isPoll:     true,
        pollId:     pollId);

    setState(() {
      messages.add(optimisticMsg);
      pollCache[messageId]   = poll;
      myVotes[pollId]        = {};
      pollVoterNames[pollId] = {};
    });
    scrollToBottom();

    try {
      await supabase.from('polls').insert({
        'id':         pollId,
        'message_id': messageId,
        'room_id':    roomId,
        'question':   question,
        'created_by': currentUser,
        'created_at': now.toIso8601String(),
      });
      for (final opt in options) {
        await supabase.from('poll_options').insert({
          'id':            opt.id,
          'poll_id':       pollId,
          'option_text':   opt.optionText,
          'display_order': opt.displayOrder,
        });
      }
      await supabase.from('messages').insert({
        'id':              messageId,
        'room_id':         roomId,
        'sender':          currentUser,
        'content':         question,
        'created_at':      now.toIso8601String(),
        'is_poll':         true,
        'poll_id':         pollId,
        'is_announcement': false,
        'is_event_invite': false,
      });
    } catch (e, stack) {
      debugPrint('Error creating poll: $e\n$stack');
      setState(() {
        messages.removeWhere((m) => m.id == messageId);
        pollCache.remove(messageId);
        myVotes.remove(pollId);
        pollVoterNames.remove(pollId);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to create poll: $e')));
      }
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Rename / Delete group  (admin-only)
  // ══════════════════════════════════════════════════════════════════════════

  void _showRenameDialog() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Rename Group'),
        content: TextField(
            controller: ctrl,
            decoration: InputDecoration(
                hintText:  communityName,
                filled:    true,
                fillColor: const Color(0xFFF5F1ED),
                border:    OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:   BorderSide.none))),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: BaseChatScreenState.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            onPressed: () async {
              final newName = ctrl.text.trim();
              if (newName.isEmpty) return;
              try {
                await supabase
                    .from('group_chats')
                    .update({'name': newName})
                    .eq('room_id', roomId);
                Navigator.pop(context);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Group renamed')));
                }
              } catch (e) {
                debugPrint('Rename error: $e');
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteGroup() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title:   const Text('Delete Group'),
        content: const Text(
            'This will permanently delete the group and all messages. Continue?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white),
            onPressed: () async {
              try {
                await supabase
                    .from('group_chats')
                    .delete()
                    .eq('room_id', roomId);
                Navigator.pop(context);
                Navigator.pop(context);
              } catch (e) {
                debugPrint('Delete error: $e');
              }
            },
            child: const Text('Delete'),
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
      // Admin sees the poll button in the input bar
      body: buildScaffoldBody(
        showPollButton: true,
        onPollTap:      _showPollDialog,
      ),
    );
  }

  // ── Override poll bubble to attach "View Results" ─────────────────────────

  @override
  Widget buildPollBubble(Message msg, Poll poll,
      {bool showResultsButton = true, VoidCallback? onViewResults}) {
    return super.buildPollBubble(
      msg,
      poll,
      showResultsButton: true,
      onViewResults:     () => _showPollResults(poll),
    );
  }
}