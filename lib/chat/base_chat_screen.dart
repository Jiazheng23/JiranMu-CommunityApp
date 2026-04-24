import 'dart:convert';
import 'package:assignment/chat/shared/chat_utils.dart';
import 'package:assignment/chat/shared/chat_widgets.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:assignment/chat/NotificationService.dart';
import 'package:assignment/event/screen/event_details_screen.dart';
import 'package:assignment/event/service/event_service.dart';

import 'model/message.dart';

// ─────────────────────────────────────────────────────────────────────────────
// BaseChatScreenState  —  shared mixin
//
// Contains EVERY piece of state and every method that is identical between
// AdminChatScreen and ResidentChatScreen:
//
//   • Supabase client reference
//   • All state fields (messages, polls, pinned, mentions, search …)
//   • _fetchMessages / _sendMessage / _markMessagesAsRead
//   • Real-time subscription (_setupRealtime)
//   • Poll data loading & vote toggling
//   • Scroll helpers
//   • Display-name resolution cache
//   • All BUILD widgets:
//       - AppBar shell (actions injected by subclass via buildAppBarActions)
//       - Pinned strip
//       - Reply preview
//       - Message list (chat bubbles, event invites, poll bubbles)
//       - Search bar
//       - Mention suggestions
//       - Input bar
//
// Subclasses (AdminChatScreenState / ResidentChatScreenState) only add:
//   • Their own settings/dialog methods
//   • Override buildAppBarActions() to supply the correct action buttons
// ─────────────────────────────────────────────────────────────────────────────

final supabase = Supabase.instance.client;

// ignore: must_be_immutable — mixin is not a Widget itself
mixin BaseChatScreenState<T extends StatefulWidget> on State<T> {
  // ── Widget fields — subclass must expose these as getters ─────────────────
  String get roomId;
  String get communityName;
  String get currentUserId;
  String get currentUser;
  bool get isAdmin;

  // ── Colors ────────────────────────────────────────────────────────────────
  static const Color primary       = Color(0xFF9A4B3C);
  static const Color bubbleMe      = Color(0xFF9A4B3C);
  static const Color bubbleOther   = Color(0xFFF0F0F5);
  static const Color bgPage        = Color(0xFFF5F1ED);
  static const Color appBarBg      = Colors.white;
  static const Color adminBadge    = Color(0xFF9A4B3C);
  static const Color pinAccent     = Color(0xFF9A4B3C);
  static const Color pinBg         = Color(0xFFFAF7F5);

  // ── State fields ──────────────────────────────────────────────────────────
  final TextEditingController controller    = TextEditingController();
  final ScrollController    scrollController = ScrollController();
  final FocusNode           inputFocusNode  = FocusNode();
  final TextEditingController searchController = TextEditingController();

  final Map<String, String> senderNameCache = {};
  String myDisplayName = '';

  List<Message> messages = [];
  RealtimeChannel? subscription;

  Message? replyingTo;

  List<Message> pinnedAnnouncements = [];
  int pinnedIndex = 0;
  bool pinDismissed = true;

  final Map<String, Poll>               pollCache      = {};
  final Map<String, Set<String>>        myVotes        = {};
  final Map<String, int>                voteCounts     = {};
  final Map<String, Map<String, List<String>>> pollVoterNames = {};

  List<String> mentionSuggestions = [];
  bool showMentions = false;
  List<String> roomMembers = [];

  bool isDM = false;

  String searchQuery = '';
  bool showChatSearch = false;

  int unreadMentions = 0;

  // ── Derived getters ───────────────────────────────────────────────────────

  List<Message> get chatMessages {
    final msgs = messages.where((m) => !m.isAnnouncement).toList();
    if (searchQuery.isEmpty) return msgs;
    return msgs
        .where((m) =>
    m.text.toLowerCase().contains(searchQuery.toLowerCase()) ||
        m.senderName.toLowerCase().contains(searchQuery.toLowerCase()))
        .toList();
  }

  // ── Lifecycle helpers (call from initState / dispose) ─────────────────────

  void baseInitState() {
    _loadMyDisplayName().then((_) {
      _fetchMessages();
      _setupRealtime();
      _markMessagesAsRead();
    });
    _detectRoomType();
    _loadRoomMembers();
    controller.addListener(_onTextChanged);
  }

  void baseDispose() {
    subscription?.unsubscribe();
    controller.removeListener(_onTextChanged);
    controller.dispose();
    scrollController.dispose();
    inputFocusNode.dispose();
    searchController.dispose();
  }

  // ── Room type detection ───────────────────────────────────────────────────

  Future<void> _detectRoomType() async {
    try {
      final res = await supabase
          .from('group_chats')
          .select('id')
          .eq('room_id', roomId)
          .maybeSingle();
      setState(() => isDM = res == null);
    } catch (e) {
      debugPrint('Error detecting room type: $e');
    }
  }

  // ── Display name resolution ───────────────────────────────────────────────

  Future<void> _loadMyDisplayName() async {
    final name = await resolveDisplayName(currentUser);
    setState(() => myDisplayName = name);
  }

  Future<String> resolveDisplayName(String raw) async {
    if (raw.isEmpty) return raw;
    if (senderNameCache.containsKey(raw)) return senderNameCache[raw]!;
    if (!raw.contains('@')) {
      senderNameCache[raw] = raw;
      return raw;
    }
    try {
      final result = await supabase
          .from('resident')
          .select('full_name')
          .eq('email', raw)
          .maybeSingle();
      if (result != null && result['full_name'] != null) {
        final name = result['full_name'] as String;
        senderNameCache[raw] = name;
        return name;
      }
    } catch (e) {
      debugPrint('Error resolving name for $raw: $e');
    }
    final fallback = raw.split('@').first;
    senderNameCache[raw] = fallback;
    return fallback;
  }

  // ── Pin helpers ───────────────────────────────────────────────────────────

  void showPin() => setState(() => pinDismissed = false);
  void hidePin() => setState(() => pinDismissed = true);

  // ── Reply helpers ─────────────────────────────────────────────────────────

  void setReply(Message msg) {
    setState(() => replyingTo = msg);
    inputFocusNode.requestFocus();
  }

  void cancelReply() => setState(() => replyingTo = null);

  // ── Mention helpers ───────────────────────────────────────────────────────

  List<String> extractMentions(String text) {
    final regex = RegExp(r'@(\w+(?:\s+\w+)*)');
    return regex.allMatches(text).map((m) => m.group(1)!).toList();
  }

  void _onTextChanged() {
    final text   = controller.text;
    final cursor = controller.selection.baseOffset;
    if (cursor < 0) return;
    final before = text.substring(0, cursor);
    final match  = RegExp(r'@(\w*)$').firstMatch(before);
    if (match != null) {
      final query = match.group(1)!.toLowerCase();
      final suggestions =
      roomMembers.where((n) => n.toLowerCase().contains(query)).toList();
      setState(() {
        mentionSuggestions = suggestions;
        showMentions        = suggestions.isNotEmpty;
      });
    } else {
      setState(() => showMentions = false);
    }
  }

  void insertMention(String name) {
    final text   = controller.text;
    final cursor = controller.selection.baseOffset;
    final before = text.substring(0, cursor);
    final after  = text.substring(cursor);
    final replaced =
    before.replaceAllMapped(RegExp(r'@\w*$'), (_) => '@$name ');
    controller.value = TextEditingValue(
      text:      replaced + after,
      selection: TextSelection.collapsed(offset: replaced.length),
    );
    setState(() => showMentions = false);
    inputFocusNode.requestFocus();
  }

  // ── Room members ──────────────────────────────────────────────────────────

  Future<void> _loadRoomMembers() async {
    try {
      final groupRes = await supabase
          .from('group_chats')
          .select('id')
          .eq('room_id', roomId)
          .maybeSingle();
      if (groupRes == null) return;

      final groupChatId = groupRes['id'] as String;
      final memberRes   = await supabase
          .from('group_chat_members')
          .select('user_id')
          .eq('group_chat_id', groupChatId);
      final userIds =
      (memberRes as List).map((e) => e['user_id'] as String).toList();
      if (userIds.isEmpty) return;

      final profiles = await supabase
          .from('resident')
          .select('full_name')
          .inFilter('id', userIds);
      setState(() {
        roomMembers =
            (profiles as List).map((e) => e['full_name'] as String).toList();
      });
    } catch (e) {
      debugPrint('Error loading members: $e');
    }
  }

  // ── Fetch messages ────────────────────────────────────────────────────────

  Future<void> _fetchMessages() async {
    try {
      final data = await supabase
          .from('messages')
          .select(
          'id, room_id, sender, content, created_at, is_announcement, '
              'is_poll, poll_id, reply_to_id, reply_to_sender, reply_to_text, '
              'is_event_invite, mentioned_users')
          .eq('room_id', roomId)
          .order('created_at', ascending: true);

      final List<Message> result = [];
      int mentionCount = 0;

      for (final msg in (data as List<dynamic>)) {
        final rawSender     = msg['sender'] as String;
        final displayName   = await resolveDisplayName(rawSender);
        String? replyToDisplay;
        final rawReply = msg['reply_to_sender'] as String?;
        if (rawReply != null) replyToDisplay = await resolveDisplayName(rawReply);

        List<String> mentionedUsers = [];
        final raw = msg['mentioned_users'];
        if (raw != null) {
          if (raw is List) {
            mentionedUsers = raw.map((e) => e.toString()).toList();
          } else if (raw is String && raw.isNotEmpty) {
            try {
              final decoded = jsonDecode(raw);
              if (decoded is List) {
                mentionedUsers = decoded.map((e) => e.toString()).toList();
              }
            } catch (_) {}
          }
        }

        final message = Message(
          id:             msg['id'] as String,
          senderName:     displayName,
          senderRaw:      rawSender,
          text:           msg['content'] as String,
          timestamp:      DateTime.parse(msg['created_at'] as String),
          isMe:           rawSender == currentUser,
          isAnnouncement: msg['is_announcement'] == true,
          isPoll:         msg['is_poll'] as bool? ?? false,
          pollId:         msg['poll_id'] as String?,
          isEventInvite:  msg['is_event_invite'] == true,
          replyToId:      msg['reply_to_id'] as String?,
          replyToSender:  replyToDisplay,
          replyToText:    msg['reply_to_text'] as String?,
          mentionedUsers: mentionedUsers,
        );

        result.add(message);

        if (!message.isMe &&
            message.mentions(
                myDisplayName.isNotEmpty ? myDisplayName : currentUser)) {
          mentionCount++;
        }
      }

      final pins = result.where((m) => m.isAnnouncement).toList();
      setState(() {
        messages            = result;
        pinnedAnnouncements = pins;
        pinnedIndex         = pins.isEmpty ? 0 : pins.length - 1;
        pinDismissed        = pins.isEmpty;
        unreadMentions      = mentionCount;
      });

      for (final msg
      in result.where((m) => m.isPoll && m.pollId != null)) {
        await loadPollData(msg.pollId!, msg.id);
      }
      scrollToBottom();
    } catch (e) {
      debugPrint('Error fetching messages: $e');
    }
  }

  // ── Poll data ─────────────────────────────────────────────────────────────

  Future<void> loadPollData(String pollId, String messageId) async {
    try {
      final pollRes = await supabase
          .from('polls')
          .select('id, message_id, room_id, question, created_by, created_at')
          .eq('id', pollId)
          .single();

      final optionsRes = await supabase
          .from('poll_options')
          .select('id, poll_id, option_text, display_order')
          .eq('poll_id', pollId)
          .order('display_order', ascending: true);

      final options = (optionsRes as List)
          .map((o) => PollOption(
        id:           o['id'] as String,
        pollId:       o['poll_id'] as String,
        optionText:   o['option_text'] as String,
        displayOrder: o['display_order'] as int,
      ))
          .toList();

      final poll = Poll(
        id:        pollRes['id'] as String,
        messageId: pollRes['message_id'] as String,
        roomId:    pollRes['room_id'] as String,
        question:  pollRes['question'] as String,
        createdBy: pollRes['created_by'] as String,
        createdAt: DateTime.parse(pollRes['created_at'] as String),
        options:   options,
      );

      final votesRes = await supabase
          .from('poll_votes')
          .select('option_id, user_id')
          .eq('poll_id', pollId);

      final Map<String, int>         counts         = {};
      final Set<String>              myVotedOptions = {};
      final Map<String, List<String>> voterNames    = {};

      final voterUserIds = (votesRes as List)
          .map((v) => v['user_id'] as String)
          .toSet()
          .toList();

      Map<String, String> userIdToName = {};
      if (voterUserIds.isNotEmpty) {
        final profiles = await supabase
            .from('resident')
            .select('id, full_name')
            .inFilter('id', voterUserIds);
        for (final p in (profiles as List)) {
          userIdToName[p['id'] as String] = p['full_name'] as String;
        }
      }

      for (final v in (votesRes as List)) {
        final optId  = v['option_id'] as String;
        final userId = v['user_id'] as String;
        counts[optId] = (counts[optId] ?? 0) + 1;
        if (userId == currentUserId) myVotedOptions.add(optId);
        final name = userIdToName[userId] ?? 'Unknown';
        voterNames[optId] = [...(voterNames[optId] ?? []), name];
      }

      setState(() {
        pollCache[messageId]      = poll;
        myVotes[pollId]           = myVotedOptions;
        voteCounts.addAll(counts);
        pollVoterNames[pollId]    = voterNames;
      });
    } catch (e) {
      debugPrint('Error loading poll $pollId: $e');
    }
  }

  // ── Real-time subscription ────────────────────────────────────────────────

  void _setupRealtime() {
    subscription = supabase
        .channel('room_$roomId')
        .onPostgresChanges(
      event:    PostgresChangeEvent.insert,
      schema:   'public',
      table:    'messages',
      callback: (payload) async {
        final msg = payload.newRecord;
        if (msg['room_id'] != roomId) return;

        final senderEmail = msg['sender'] as String? ?? '';
        if (senderEmail == currentUser) return;
        // NotificationService.showNotification('New Message', msg['content'] ?? '');

        final rawSender   = msg['sender'] as String;
        final displayName = await resolveDisplayName(rawSender);
        String? replyToDisplay;
        final rawReply = msg['reply_to_sender'] as String?;
        if (rawReply != null) {
          replyToDisplay = await resolveDisplayName(rawReply);
        }

        List<String> mentionedUsers = [];
        final rawM = msg['mentioned_users'];
        if (rawM is List) {
          mentionedUsers = rawM.map((e) => e.toString()).toList();
        }

        final newMessage = Message(
          id:             msg['id'] as String,
          senderName:     displayName,
          senderRaw:      rawSender,
          text:           msg['content'] as String,
          timestamp:      DateTime.parse(msg['created_at'] as String),
          isMe:           rawSender == currentUser,
          isAnnouncement: msg['is_announcement'] == true,
          isPoll:         msg['is_poll'] as bool? ?? false,
          pollId:         msg['poll_id'] as String?,
          isEventInvite:  msg['is_event_invite'] == true,
          replyToId:      msg['reply_to_id'] as String?,
          replyToSender:  replyToDisplay,
          replyToText:    msg['reply_to_text'] as String?,
          mentionedUsers: mentionedUsers,
        );

        setState(() {
          final alreadyExists = messages.any((m) =>
          m.id == newMessage.id ||
              (m.text == newMessage.text &&
                  m.senderRaw == newMessage.senderRaw &&
                  m.timestamp
                      .difference(newMessage.timestamp)
                      .inSeconds
                      .abs() <
                      2));
          if (!alreadyExists) {
            messages.add(newMessage);
            messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
            if (newMessage.isAnnouncement) {
              pinnedAnnouncements.add(newMessage);
              pinnedIndex = pinnedAnnouncements.length - 1;
              showPin();
            }
            if (!newMessage.isMe &&
                newMessage.mentions(myDisplayName.isNotEmpty
                    ? myDisplayName
                    : currentUser)) {
              unreadMentions++;
              showMentionBanner(newMessage);
            }
          }
        });
        if (!newMessage.isAnnouncement) scrollToBottom();
        if (newMessage.isPoll && newMessage.pollId != null) {
          await loadPollData(newMessage.pollId!, newMessage.id);
        }
      },
    )
        .onPostgresChanges(
      event:    PostgresChangeEvent.insert,
      schema:   'public',
      table:    'poll_votes',
      callback: (payload) async {
        final v      = payload.newRecord;
        final optId  = v['option_id'] as String;
        final pollId = v['poll_id'] as String;
        final userId = v['user_id'] as String;
        String voterName = 'Unknown';
        try {
          final profile = await supabase
              .from('resident')
              .select('full_name')
              .eq('id', userId)
              .single();
          voterName = profile['full_name'] as String;
        } catch (_) {}
        setState(() {
          voteCounts[optId] = (voteCounts[optId] ?? 0) + 1;
          if (userId == currentUserId) {
            myVotes[pollId] = {...?myVotes[pollId], optId};
          }
          final current = pollVoterNames[pollId] ?? {};
          pollVoterNames[pollId] = {
            ...current,
            optId: [...(current[optId] ?? []), voterName],
          };
        });
      },
    )
        .subscribe();
  }

  // ── Mention banner ────────────────────────────────────────────────────────

  void showMentionBanner(Message msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior:         SnackBarBehavior.floating,
        backgroundColor:  Colors.transparent,
        elevation:        0,
        duration:         const Duration(seconds: 4),
        content: GestureDetector(
          onTap: () {
            ScaffoldMessenger.of(context).clearSnackBars();
            scrollToBottom();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color:        const Color(0xFF2B2B2B),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                    color:      Colors.black.withOpacity(0.2),
                    blurRadius: 12,
                    offset:     const Offset(0, 4)),
              ],
            ),
            child: Row(children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                    color: primary.withOpacity(0.2), shape: BoxShape.circle),
                child: Center(
                  child: Text(
                    initialsFromName(msg.senderName),
                    style: const TextStyle(
                        color:      primary,
                        fontWeight: FontWeight.w700,
                        fontSize:   13),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize:       MainAxisSize.min,
                    children: [
                      Row(children: [
                        Text(msg.senderName,
                            style: const TextStyle(
                                color:      Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize:   13)),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                              color:        primary,
                              borderRadius: BorderRadius.circular(8)),
                          child: const Text('@you',
                              style: TextStyle(
                                  color:      Colors.white,
                                  fontSize:   10,
                                  fontWeight: FontWeight.w700)),
                        ),
                      ]),
                      const SizedBox(height: 2),
                      Text(msg.text,
                          maxLines:  1,
                          overflow:  TextOverflow.ellipsis,
                          style: const TextStyle(
                              color:    Colors.white70, fontSize: 12)),
                    ]),
              ),
              const Icon(Icons.keyboard_arrow_down_rounded,
                  color: Colors.white54, size: 20),
            ]),
          ),
        ),
      ),
    );
  }

  // ── Vote toggle ───────────────────────────────────────────────────────────

  Future<void> toggleVote(Poll poll, PollOption option) async {
    final pollId       = poll.id;
    final optionId     = option.id;
    final currentVotes = myVotes[pollId] ?? {};
    final alreadyVoted = currentVotes.contains(optionId);
    final myName       = myDisplayName.isNotEmpty ? myDisplayName : currentUser;

    setState(() {
      if (alreadyVoted) {
        myVotes[pollId]       = currentVotes.difference({optionId});
        voteCounts[optionId]  = (voteCounts[optionId] ?? 1) - 1;
        final cur             = pollVoterNames[pollId] ?? {};
        final updatedList     = List<String>.from(cur[optionId] ?? [])
          ..remove(myName);
        pollVoterNames[pollId] = {...cur, optionId: updatedList};
      } else {
        myVotes[pollId]       = {...currentVotes, optionId};
        voteCounts[optionId]  = (voteCounts[optionId] ?? 0) + 1;
        final cur             = pollVoterNames[pollId] ?? {};
        pollVoterNames[pollId] = {
          ...cur,
          optionId: [...(cur[optionId] ?? []), myName],
        };
      }
    });

    try {
      if (alreadyVoted) {
        await supabase
            .from('poll_votes')
            .delete()
            .eq('poll_id', pollId)
            .eq('option_id', optionId)
            .eq('user_id', currentUserId);
      } else {
        await supabase.from('poll_votes').insert({
          'id':        const Uuid().v4(),
          'poll_id':   pollId,
          'option_id': optionId,
          'user_id':   currentUserId,
          'voted_at':  DateTime.now().toIso8601String(),
        });
      }
    } catch (e) {
      debugPrint('Vote error: $e');
      // Revert optimistic update
      setState(() {
        if (alreadyVoted) {
          myVotes[pollId]       = {...?myVotes[pollId], optionId};
          voteCounts[optionId]  = (voteCounts[optionId] ?? 0) + 1;
          final cur             = pollVoterNames[pollId] ?? {};
          pollVoterNames[pollId] = {
            ...cur,
            optionId: [...(cur[optionId] ?? []), myName],
          };
        } else {
          final updated = {...?myVotes[pollId]}..remove(optionId);
          myVotes[pollId]       = updated;
          voteCounts[optionId]  = (voteCounts[optionId] ?? 1) - 1;
          final cur             = pollVoterNames[pollId] ?? {};
          final updatedList     = List<String>.from(cur[optionId] ?? [])
            ..remove(myName);
          pollVoterNames[pollId] = {...cur, optionId: updatedList};
        }
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to record vote.')));
      }
    }
  }

  // ── Send message ──────────────────────────────────────────────────────────

  Future<void> sendMessage(
      {bool isAnnouncement = false, String? announcementText}) async {
    final text = (announcementText ?? controller.text).trim();
    if (text.isEmpty) return;
    final reply = replyingTo;
    if (announcementText == null) controller.clear();
    setState(() {
      showMentions = false;
      replyingTo   = null;
    });

    final mentions     = extractMentions(text);
    final optimisticId = const Uuid().v4();
    final displayName  = myDisplayName.isNotEmpty ? myDisplayName : currentUser;

    final optimisticMsg = Message(
      id:             optimisticId,
      senderName:     displayName,
      senderRaw:      currentUser,
      text:           text,
      timestamp:      DateTime.now(),
      isMe:           true,
      isAnnouncement: isAnnouncement,
      replyToId:      reply?.id,
      replyToSender:  reply?.senderName,
      replyToText:    reply?.text,
      mentionedUsers: mentions,
    );

    setState(() {
      messages.add(optimisticMsg);
      if (isAnnouncement) {
        pinnedAnnouncements.add(optimisticMsg);
        pinnedIndex = pinnedAnnouncements.length - 1;
        showPin();
      }
    });
    if (!isAnnouncement) scrollToBottom();

    try {
      await supabase.from('messages').insert({
        'id':              optimisticId,
        'room_id':         roomId,
        'sender':          currentUser,
        'content':         text,
        'is_announcement': isAnnouncement,
        'is_event_invite': false,
        'mentioned_users': mentions,
        if (reply != null) ...{
          'reply_to_id':     reply.id,
          'reply_to_sender': reply.senderRaw,
          'reply_to_text':   reply.text,
        },
      });
    } catch (e) {
      debugPrint('Error sending message: $e');
      setState(() {
        messages.removeWhere((m) => m.id == optimisticId);
        if (isAnnouncement) {
          pinnedAnnouncements.removeWhere((m) => m.id == optimisticId);
          pinnedIndex = pinnedAnnouncements.isEmpty
              ? 0
              : pinnedAnnouncements.length - 1;
          if (pinnedAnnouncements.isEmpty) hidePin();
        }
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to send message.')));
      }
    }
  }

  // ── Mark as read ──────────────────────────────────────────────────────────

  Future<void> _markMessagesAsRead() async {
    try {
      await supabase
          .from('messages')
          .update({'is_read': true})
          .eq('room_id', roomId)
          .neq('sender', currentUser)
          .eq('is_read', false);
    } catch (e) {
      debugPrint('Error marking messages as read: $e');
    }
  }

  // ── Scroll ────────────────────────────────────────────────────────────────

  void scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scrollController.hasClients) {
        scrollController.animateTo(
            scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve:    Curves.easeOut);
      }
    });
  }

  // ── Event details ─────────────────────────────────────────────────────────

  Future<void> navigateToEventDetails(String? eventId) async {
    if (eventId == null) return;
    try {
      final event = await EventService().fetchEventById(eventId);
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => EventDetailsScreen(
            event:           event,
            currentRole:     'resident',
            currentUserId:   currentUserId,
            currentUserName: myDisplayName.isNotEmpty ? myDisplayName : currentUser,
            onRefresh:       () {},
          ),
        ),
      );
    } catch (e) {
      debugPrint('Error fetching event details: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not load event details.')));
      }
    }
  }

  // ── Shared settings tile widget ───────────────────────────────────────────

  Widget buildSettingsTile({
    required IconData     icon,
    required String       title,
    required String       subtitle,
    required VoidCallback onTap,
    Color? titleColor,
    Color? iconColor,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
            color:        (iconColor ?? primary).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: iconColor ?? primary, size: 20),
      ),
      title: Text(title,
          style: TextStyle(
              fontSize:   14,
              fontWeight: FontWeight.w700,
              color:      titleColor ?? Colors.black87)),
      subtitle: Text(subtitle,
          style: const TextStyle(fontSize: 12, color: Colors.grey)),
      trailing: const Icon(Icons.chevron_right_rounded,
          color: Colors.black26, size: 20),
      onTap: onTap,
    );
  }

  // ── Navigate to members screen ────────────────────────────────────────────

  void navigateToMembers() {
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => GroupMembersScreen(members: roomMembers)));
  }

  // ══════════════════════════════════════════════════════════════════════════
  // BUILD WIDGETS — identical in both admin and resident
  // ══════════════════════════════════════════════════════════════════════════

  // Subclasses supply their own action widgets (settings button, mention badge…)
  List<Widget> buildAppBarActions();

  // ── App bar ───────────────────────────────────────────────────────────────

  PreferredSizeWidget buildAppBar() {
    return AppBar(
      backgroundColor: appBarBg,
      elevation:       0,
      centerTitle:     true,
      leading: IconButton(
          icon:      const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.black87, size: 20),
          onPressed: () => Navigator.pop(context)),
      title: Text(communityName,
          style: const TextStyle(
              color:       Colors.black87,
              fontSize:    16,
              fontWeight:  FontWeight.w700,
              letterSpacing: -0.3)),
      actions: buildAppBarActions(),
    );
  }

  // ── Pinned strip ──────────────────────────────────────────────────────────

  Widget buildPinnedStrip() {
    if (pinnedAnnouncements.isEmpty || pinDismissed) {
      return const SizedBox.shrink();
    }
    final ann   = pinnedAnnouncements[pinnedIndex];
    final total = pinnedAnnouncements.length;
    return Container(
      color: pinBg,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(height: 1, color: Colors.black.withOpacity(0.07)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            const Icon(Icons.push_pin_rounded, size: 14, color: pinAccent),
            const SizedBox(width: 10),
            Container(
                width: 3, height: 34,
                decoration: BoxDecoration(
                    color:        pinAccent,
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize:       MainAxisSize.min,
                  children: [
                    Row(children: [
                      const Text('Pinned Message',
                          style: TextStyle(
                              fontSize:     11,
                              fontWeight:   FontWeight.w700,
                              color:        pinAccent,
                              letterSpacing: 0.1)),
                      if (total > 1) ...[
                        const SizedBox(width: 4),
                        Text('(${pinnedIndex + 1}/$total)',
                            style: const TextStyle(
                                fontSize:   11,
                                fontWeight: FontWeight.w600,
                                color:      pinAccent)),
                      ],
                    ]),
                    const SizedBox(height: 2),
                    Text(ann.text,
                        maxLines:  1,
                        overflow:  TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 13,
                            color:    Colors.black87,
                            height:   1.3)),
                  ]),
            ),
            if (total > 1) ...[
              const SizedBox(width: 4),
              Column(mainAxisSize: MainAxisSize.min, children: [
                GestureDetector(
                    onTap: () => setState(() =>
                    pinnedIndex = (pinnedIndex - 1 + total) % total),
                    child: const Icon(Icons.keyboard_arrow_up_rounded,
                        size: 18, color: pinAccent)),
                GestureDetector(
                    onTap: () => setState(
                            () => pinnedIndex = (pinnedIndex + 1) % total),
                    child: const Icon(Icons.keyboard_arrow_down_rounded,
                        size: 18, color: pinAccent)),
              ]),
            ],
          ]),
        ),
        Container(height: 1, color: Colors.black.withOpacity(0.07)),
      ]),
    );
  }

  // ── Reply preview bar ─────────────────────────────────────────────────────

  Widget buildReplyPreview() {
    final r = replyingTo!;
    return Container(
      color:   Colors.white,
      padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
      child: Row(children: [
        Container(
            width: 3, height: 36,
            decoration: BoxDecoration(
                color:        primary,
                borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize:       MainAxisSize.min,
              children: [
                Text(r.isMe ? 'You' : r.senderName,
                    style: const TextStyle(
                        fontSize:   12,
                        fontWeight: FontWeight.w700,
                        color:      primary)),
                const SizedBox(height: 1),
                Text(r.isPoll ? '📊 Poll' : r.text,
                    maxLines:  1,
                    overflow:  TextOverflow.ellipsis,
                    style:     const TextStyle(
                        fontSize: 12, color: Colors.black54)),
              ]),
        ),
        IconButton(
            icon:      const Icon(Icons.close, size: 18, color: Colors.black45),
            onPressed: cancelReply),
      ]),
    );
  }

  // ── Search bar ────────────────────────────────────────────────────────────

  Widget buildSearchBar() {
    return Container(
      color:   Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Row(children: [
        Expanded(
          child: Container(
            height: 50,
            decoration: BoxDecoration(
                color:        const Color(0xFFF0F0F5),
                borderRadius: BorderRadius.circular(20)),
            child: TextField(
              controller: searchController,
              autofocus:  true,
              onChanged:  (v) => setState(() => searchQuery = v),
              style: const TextStyle(fontSize: 14, color: Colors.black87),
              decoration: const InputDecoration(
                hintText:     'Search in chat…',
                hintStyle:    TextStyle(color: Colors.grey, fontSize: 14),
                prefixIcon:   Icon(Icons.search_rounded,
                    color: Colors.grey, size: 18),
                border:       InputBorder.none,
                contentPadding:
                EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                isDense: true,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () => setState(() {
            showChatSearch  = false;
            searchQuery = '';
            searchController.clear();
          }),
          child: const Text('Cancel',
              style: TextStyle(
                  color:      primary,
                  fontWeight: FontWeight.w600,
                  fontSize:   14)),
        ),
      ]),
    );
  }

  // ── Mention suggestions ───────────────────────────────────────────────────

  Widget buildMentionSuggestions() {
    return Container(
      constraints: const BoxConstraints(maxHeight: 160),
      decoration: const BoxDecoration(
          color:  Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFEEEEEE)))),
      child: ListView.builder(
        shrinkWrap: true,
        padding:    EdgeInsets.zero,
        itemCount:  mentionSuggestions.length,
        itemBuilder: (context, i) {
          final name = mentionSuggestions[i];
          return ListTile(
            dense: true,
            leading: CircleAvatar(
                radius:          16,
                backgroundColor: avatarColorFromName(name),
                child: Text(initialsFromName(name),
                    style: const TextStyle(
                        color:      Colors.white,
                        fontSize:   11,
                        fontWeight: FontWeight.w700))),
            title: Text(name,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w600)),
            onTap: () => insertMention(name),
          );
        },
      ),
    );
  }

  // ── Input bar ─────────────────────────────────────────────────────────────
  // Admin sees a poll button on the left; resident does not.
  // Subclasses pass showPollButton = true/false.

  Widget buildInputBar({required bool showPollButton, VoidCallback? onPollTap}) {
    return Container(
      color:   Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 12),
      child: SafeArea(
        top: false,
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          if (showPollButton) ...[
            GestureDetector(
              onTap: onPollTap,
              child: Container(
                  width: 40, height: 40,
                  margin: const EdgeInsets.only(right: 6),
                  decoration: BoxDecoration(
                      color:  primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: primary.withOpacity(0.3), width: 1)),
                  child: const Icon(Icons.poll_outlined,
                      color: primary, size: 20)),
            ),
          ],
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                  color:        const Color(0xFFF0F0F5),
                  borderRadius: BorderRadius.circular(24)),
              child: ConstrainedBox(
                constraints:
                const BoxConstraints(minHeight: 40, maxHeight: 120),
                child: Scrollbar(
                  child: TextField(
                    controller:          controller,
                    focusNode:           inputFocusNode,
                    textCapitalization:  TextCapitalization.sentences,
                    style: const TextStyle(
                        fontSize: 15, color: Colors.black87, height: 1.4),
                    maxLines:          null,
                    minLines:          1,
                    keyboardType:      TextInputType.multiline,
                    textInputAction:   TextInputAction.newline,
                    decoration: const InputDecoration(
                      hintText:       'Type a message…',
                      hintStyle:      TextStyle(color: Colors.grey, fontSize: 15),
                      border:         InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      isDense: true,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => sendMessage(),
            child: Container(
                width:  42, height: 42,
                decoration: const BoxDecoration(
                    color: primary, shape: BoxShape.circle),
                child: const Icon(Icons.send_rounded,
                    color: Colors.white, size: 20)),
          ),
        ]),
      ),
    );
  }

  // ── Message list ──────────────────────────────────────────────────────────

  Widget buildMessageList() {
    final msgs = chatMessages;
    if (msgs.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (showChatSearch && searchQuery.isNotEmpty) ...[
            const Icon(Icons.search_off_rounded, size: 48, color: Colors.black26),
            const SizedBox(height: 12),
            Text('No messages matching\n"$searchQuery"',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey, height: 1.6)),
          ] else ...[
            const Text('No messages yet.\nBe the first to say hello!',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.grey, fontSize: 14, height: 1.6)),
          ]
        ]),
      );
    }
    return ListView.builder(
      controller: scrollController,
      padding:    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount:  msgs.length,
      itemBuilder: (context, index) {
        final msg        = msgs[index];
        final showSender = !msg.isMe && (index == 0 || msgs[index - 1].isMe);
        if (msg.isEventInvite) {
          return buildSwipeable(msg, buildEventInviteBubble(msg, showSender));
        }
        if (msg.isPoll) {
          final poll = pollCache[msg.id];
          if (poll == null) return buildLoadingPollBubble(msg);
          return buildSwipeable(msg, buildPollBubble(msg, poll));
        }
        return buildSwipeable(msg, buildMessageBubble(msg, showSender));
      },
    );
  }

  // ── Swipeable wrapper ─────────────────────────────────────────────────────

  Widget buildSwipeable(Message msg, Widget child) {
    return SwipeToReply(
        key:     ValueKey('swipe_${msg.id}'),
        isMe:    msg.isMe,
        onReply: () => setReply(msg),
        child:   child);
  }

  // ── Loading poll placeholder ──────────────────────────────────────────────

  Widget buildLoadingPollBubble(Message msg) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment:
        msg.isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          Container(
            constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
                color:        msg.isMe ? bubbleMe : bubbleOther,
                borderRadius: BorderRadius.circular(18)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              SizedBox(
                  width:  16, height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color:
                      msg.isMe ? Colors.white54 : Colors.black38)),
              const SizedBox(width: 10),
              Text('Loading poll…',
                  style: TextStyle(
                      color:    msg.isMe ? Colors.white70 : Colors.black54,
                      fontSize: 14)),
            ]),
          ),
        ],
      ),
    );
  }

  // ── Poll bubble ───────────────────────────────────────────────────────────
  // showResultsButton: true for admin, false for resident

  Widget buildPollBubble(Message msg, Poll poll,
      {bool showResultsButton = false, VoidCallback? onViewResults}) {
    final votes      = myVotes[poll.id] ?? {};
    final totalVotes = poll.options
        .fold<int>(0, (sum, o) => sum + (voteCounts[o.id] ?? 0));

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment:
        msg.isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!msg.isMe) ...[
            MiniAvatar(name: msg.senderName),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
              msg.isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 3, left: 4),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    if (!msg.isMe)
                      Text(msg.senderName,
                          style: const TextStyle(
                              fontSize:   11,
                              fontWeight: FontWeight.w600,
                              color:      Colors.grey)),
                    if (msg.isMe)
                      Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                              color:        adminBadge,
                              borderRadius: BorderRadius.circular(6)),
                          child: const Text('Admin',
                              style: TextStyle(
                                  color:      Colors.white,
                                  fontSize:   9,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5))),
                  ]),
                ),
                Container(
                  constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.78,
                      minWidth: MediaQuery.of(context).size.width * 0.55),
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                          color: primary.withOpacity(0.25), width: 1.2),
                      boxShadow: [
                        BoxShadow(
                            color:      Colors.black.withOpacity(0.06),
                            blurRadius: 8,
                            offset:     const Offset(0, 3))
                      ]),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Poll header
                        Container(
                          padding:
                          const EdgeInsets.fromLTRB(14, 12, 14, 10),
                          decoration: BoxDecoration(
                              color: primary.withOpacity(0.07),
                              borderRadius: const BorderRadius.only(
                                  topLeft:  Radius.circular(17),
                                  topRight: Radius.circular(17))),
                          child: Row(children: [
                            const Icon(Icons.poll_rounded,
                                color: primary, size: 16),
                            const SizedBox(width: 6),
                            const Text('Poll',
                                style: TextStyle(
                                    color:      primary,
                                    fontSize:   11,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.3)),
                            const Spacer(),
                            Text(
                                '$totalVotes vote${totalVotes == 1 ? '' : 's'}',
                                style: const TextStyle(
                                    color:    Colors.black45,
                                    fontSize: 11)),
                          ]),
                        ),
                        // Question
                        Padding(
                            padding:
                            const EdgeInsets.fromLTRB(14, 12, 14, 10),
                            child: Text(poll.question,
                                style: const TextStyle(
                                    fontSize:   14,
                                    fontWeight: FontWeight.w700,
                                    color:      Colors.black87,
                                    height:     1.35))),
                        // Options
                        Padding(
                          padding:
                          const EdgeInsets.fromLTRB(10, 0, 10, 10),
                          child: Column(
                            children: poll.options.map((opt) {
                              final count   = voteCounts[opt.id] ?? 0;
                              final isVoted = votes.contains(opt.id);
                              final pct     = totalVotes == 0
                                  ? 0.0
                                  : count / totalVotes;
                              return GestureDetector(
                                onTap: () => toggleVote(poll, opt),
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  decoration: BoxDecoration(
                                      borderRadius:
                                      BorderRadius.circular(10),
                                      border: Border.all(
                                          color: isVoted
                                              ? primary
                                              : Colors.black12,
                                          width:
                                          isVoted ? 1.5 : 1)),
                                  child: ClipRRect(
                                    borderRadius:
                                    BorderRadius.circular(9),
                                    child: Stack(children: [
                                      FractionallySizedBox(
                                          widthFactor: pct,
                                          child: Container(
                                              height: 42,
                                              color: isVoted
                                                  ? primary.withOpacity(0.13)
                                                  : Colors.black
                                                  .withOpacity(0.04))),
                                      SizedBox(
                                        height: 42,
                                        child: Padding(
                                          padding: const EdgeInsets
                                              .symmetric(horizontal: 12),
                                          child: Row(children: [
                                            if (isVoted)
                                              const Padding(
                                                  padding: EdgeInsets.only(
                                                      right: 6),
                                                  child: Icon(
                                                      Icons
                                                          .check_circle_rounded,
                                                      color:  primary,
                                                      size:   16)),
                                            Expanded(
                                                child: Text(
                                                    opt.optionText,
                                                    style: TextStyle(
                                                        fontSize: 13,
                                                        fontWeight: isVoted
                                                            ? FontWeight.w700
                                                            : FontWeight.w500,
                                                        color: isVoted
                                                            ? primary
                                                            : Colors
                                                            .black87))),
                                            Text(
                                                totalVotes == 0
                                                    ? '0%'
                                                    : '${(pct * 100).round()}%',
                                                style: TextStyle(
                                                    fontSize:   12,
                                                    fontWeight: FontWeight.w600,
                                                    color: isVoted
                                                        ? primary
                                                        : Colors.black45)),
                                          ]),
                                        ),
                                      ),
                                    ]),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                        // Timestamp
                        Padding(
                            padding:
                            const EdgeInsets.fromLTRB(14, 0, 14, 10),
                            child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Text(formatTimestamp(msg.timestamp),
                                      style: const TextStyle(
                                          fontSize: 10,
                                          color:    Colors.black38))
                                ])),
                      ]),
                ),
                // "View Results" shown only for admin
                if (showResultsButton)
                  Padding(
                    padding: const EdgeInsets.only(top: 6, right: 4),
                    child: GestureDetector(
                      onTap: onViewResults,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                            color:        primary.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(20),
                            border:       Border.all(
                                color: primary.withOpacity(0.3))),
                        child: const Row(mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.bar_chart_rounded,
                                  size: 13, color: primary),
                              SizedBox(width: 4),
                              Text('View Results',
                                  style: TextStyle(
                                      fontSize:   11,
                                      color:      primary,
                                      fontWeight: FontWeight.w600)),
                            ]),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (msg.isMe) const SizedBox(width: 4),
        ],
      ),
    );
  }

  // ── Event invite bubble ───────────────────────────────────────────────────

  Widget buildEventInviteBubble(Message msg, bool showSender) {
    Map<String, dynamic>? data;
    try {
      data = jsonDecode(msg.text) as Map<String, dynamic>;
    } catch (_) {
      return buildMessageBubble(msg, showSender);
    }

    final eventId   = data['event_id'] as String?;
    final isPrivate = data['is_private'] == true;
    const cardColor = Color(0xFFAD8762);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment:
        msg.isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!msg.isMe) ...[
            MiniAvatar(name: msg.senderName),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
              msg.isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (showSender || msg.isMe)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4, left: 4),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      if (!msg.isMe)
                        Text(msg.senderName,
                            style: const TextStyle(
                                fontSize:   11,
                                fontWeight: FontWeight.w600,
                                color:      Colors.grey)),
                      if (msg.isMe && isAdmin) ...[
                        Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                                color:        adminBadge,
                                borderRadius: BorderRadius.circular(6)),
                            child: const Text('Admin',
                                style: TextStyle(
                                    color:       Colors.white,
                                    fontSize:    9,
                                    fontWeight:  FontWeight.w700,
                                    letterSpacing: 0.5))),
                      ],
                    ]),
                  ),
                Container(
                  width: 260,
                  decoration: BoxDecoration(
                      color:        Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border:       Border.all(
                          color: cardColor.withOpacity(0.3), width: 1.5),
                      boxShadow: [
                        BoxShadow(
                            color:      Colors.black.withOpacity(0.07),
                            blurRadius: 10,
                            offset:     const Offset(0, 3))
                      ]),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding:
                          const EdgeInsets.fromLTRB(14, 10, 14, 10),
                          decoration: BoxDecoration(
                              color: cardColor.withOpacity(0.08),
                              borderRadius: const BorderRadius.only(
                                  topLeft:  Radius.circular(17),
                                  topRight: Radius.circular(17))),
                          child: Row(children: [
                            const Icon(Icons.calendar_month_rounded,
                                size: 14, color: cardColor),
                            const SizedBox(width: 6),
                            const Text('EVENT INVITATION',
                                style: TextStyle(
                                    fontSize:     10,
                                    fontWeight:   FontWeight.w800,
                                    color:        cardColor,
                                    letterSpacing: 0.8)),
                            const Spacer(),
                            if (isPrivate)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                    color:        Colors.purple.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(10)),
                                child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.lock_outline,
                                          size: 9, color: Colors.purple),
                                      SizedBox(width: 3),
                                      Text('Private',
                                          style: TextStyle(
                                              fontSize:   9,
                                              color:      Colors.purple,
                                              fontWeight: FontWeight.w700)),
                                    ]),
                              ),
                          ]),
                        ),
                        Padding(
                            padding:
                            const EdgeInsets.fromLTRB(14, 12, 14, 8),
                            child: Text(
                                data['title'] as String? ?? 'Event',
                                style: const TextStyle(
                                    fontSize:   16,
                                    fontWeight: FontWeight.w800,
                                    color:      Color(0xFF2B2B2B),
                                    height:     1.2))),
                        Padding(
                          padding:
                          const EdgeInsets.fromLTRB(14, 0, 14, 12),
                          child: Column(children: [
                            _inviteRow(Icons.location_on_outlined,
                                data['location'] as String? ?? ''),
                            const SizedBox(height: 5),
                            _inviteRow(Icons.calendar_today_outlined,
                                data['date'] as String? ?? ''),
                            const SizedBox(height: 5),
                            _inviteRow(Icons.access_time_outlined,
                                '${data['start_time'] ?? ''} – ${data['end_time'] ?? ''}'),
                            const SizedBox(height: 5),
                            _inviteRow(Icons.people_outline,
                                'Max ${data['max_capacity'] ?? '?'} people'),
                          ]),
                        ),
                        Divider(height: 1, color: cardColor.withOpacity(0.15)),
                        Padding(
                          padding:
                          const EdgeInsets.fromLTRB(12, 10, 12, 12),
                          child: SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () =>
                                  navigateToEventDetails(eventId),
                              label: const Text('VIEW EVENT',
                                  style: TextStyle(
                                      fontSize:   13,
                                      fontWeight: FontWeight.w700)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: pinAccent,
                                foregroundColor: Colors.white,
                                padding:
                                const EdgeInsets.symmetric(vertical: 10),
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                    BorderRadius.circular(12)),
                                elevation: 0,
                              ),
                            ),
                          ),
                        ),
                        Padding(
                            padding:
                            const EdgeInsets.fromLTRB(14, 0, 14, 8),
                            child: Align(
                                alignment: Alignment.centerRight,
                                child: Text(
                                    formatTimestamp(msg.timestamp),
                                    style: const TextStyle(
                                        fontSize: 10,
                                        color:    Colors.black38)))),
                      ]),
                ),
              ],
            ),
          ),
          if (msg.isMe) const SizedBox(width: 4),
        ],
      ),
    );
  }

  Widget _inviteRow(IconData icon, String text) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, size: 13, color: Colors.black38),
      const SizedBox(width: 7),
      Expanded(
          child: Text(text,
              style: const TextStyle(fontSize: 12, color: Colors.black54))),
    ]);
  }

  // ── Message bubble ────────────────────────────────────────────────────────

  Widget buildMessageBubble(Message msg, bool showSender) {
    final showAdminBadge = msg.isMe && isAdmin;
    final bubbleColor    = msg.isMe ? bubbleMe : bubbleOther;
    final timeColor      = msg.isMe ? Colors.white.withOpacity(0.6) : Colors.black38;
    final textColor      = msg.isMe ? Colors.white : Colors.black87;

    final isMentionedMe = !msg.isMe &&
        msg.mentions(myDisplayName.isNotEmpty ? myDisplayName : currentUser);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment:
        msg.isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!msg.isMe) ...[
            MiniAvatar(name: msg.senderName),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
              msg.isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (showSender || showAdminBadge)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 3, left: 4),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      if (showSender)
                        Text(msg.senderName,
                            style: const TextStyle(
                                fontSize:   11,
                                fontWeight: FontWeight.w600,
                                color:      Colors.grey)),
                      if (showAdminBadge) ...[
                        if (showSender) const SizedBox(width: 6),
                        Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                                color:        adminBadge,
                                borderRadius: BorderRadius.circular(6)),
                            child: const Text('Admin',
                                style: TextStyle(
                                    color:       Colors.white,
                                    fontSize:    9,
                                    fontWeight:  FontWeight.w700,
                                    letterSpacing: 0.5))),
                      ],
                    ]),
                  ),
                if (isMentionedMe)
                  Container(
                    margin: const EdgeInsets.only(bottom: 3),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                        color:        primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.alternate_email_rounded,
                          size: 11, color: primary),
                      const SizedBox(width: 4),
                      const Text('Mentioned you',
                          style: TextStyle(
                              fontSize:   10,
                              color:      primary,
                              fontWeight: FontWeight.w600)),
                    ]),
                  ),
                Container(
                  constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.72),
                  decoration: BoxDecoration(
                    color: isMentionedMe
                        ? primary.withOpacity(0.06)
                        : bubbleColor,
                    borderRadius: BorderRadius.only(
                        topLeft:     const Radius.circular(18),
                        topRight:    const Radius.circular(18),
                        bottomLeft:  Radius.circular(msg.isMe ? 18 : 4),
                        bottomRight: Radius.circular(msg.isMe ? 4 : 18)),
                    border: isMentionedMe
                        ? Border.all(
                        color: primary.withOpacity(0.35), width: 1.5)
                        : null,
                    boxShadow: [
                      BoxShadow(
                          color:      Colors.black.withOpacity(0.05),
                          blurRadius: 4,
                          offset:     const Offset(0, 2))
                    ],
                  ),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize:       MainAxisSize.min,
                      children: [
                        if (msg.replyToText != null)
                          Container(
                            margin:  const EdgeInsets.fromLTRB(8, 8, 8, 0),
                            padding: const EdgeInsets.fromLTRB(10, 7, 10, 7),
                            decoration: BoxDecoration(
                              color: msg.isMe
                                  ? Colors.white.withOpacity(0.15)
                                  : Colors.black.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(10),
                              border: Border(
                                  left: BorderSide(
                                      color: msg.isMe
                                          ? Colors.white.withOpacity(0.7)
                                          : primary,
                                      width: 3)),
                            ),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize:       MainAxisSize.min,
                                children: [
                                  Text(
                                    msg.replyToSender ==
                                        (myDisplayName.isNotEmpty
                                            ? myDisplayName
                                            : currentUser)
                                        ? 'You'
                                        : (msg.replyToSender ?? ''),
                                    style: TextStyle(
                                        fontSize:   11,
                                        fontWeight: FontWeight.w700,
                                        color: msg.isMe
                                            ? Colors.white
                                            : primary),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(msg.replyToText!,
                                      maxLines:  2,
                                      overflow:  TextOverflow.ellipsis,
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: msg.isMe
                                              ? Colors.white.withOpacity(0.75)
                                              : Colors.black54,
                                          height: 1.3)),
                                ]),
                          ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                          child: _buildInlineTextWithTime(
                              msg:       msg,
                              textColor: isMentionedMe
                                  ? Colors.black87
                                  : textColor,
                              timeColor: isMentionedMe
                                  ? Colors.black38
                                  : timeColor),
                        ),
                      ]),
                ),
              ],
            ),
          ),
          if (msg.isMe) const SizedBox(width: 4),
        ],
      ),
    );
  }

  Widget _buildInlineTextWithTime({
    required Message msg,
    required Color   textColor,
    required Color   timeColor,
  }) {
    final timestamp    = formatTimestamp(msg.timestamp);
    final text         = msg.text;
    final mentionRegex = RegExp(r'@\w+');
    final spans        = <InlineSpan>[];
    int last           = 0;

    for (final match in mentionRegex.allMatches(text)) {
      if (match.start > last) {
        spans.add(TextSpan(
            text:  text.substring(last, match.start),
            style: TextStyle(color: textColor, fontSize: 15, height: 1.4)));
      }
      spans.add(TextSpan(
          text:  match.group(0),
          style: TextStyle(
              color:      msg.isMe ? Colors.white : primary,
              fontSize:   15,
              fontWeight: FontWeight.w700,
              height:     1.4)));
      last = match.end;
    }
    if (last < text.length) {
      spans.add(TextSpan(
          text:  text.substring(last),
          style: TextStyle(color: textColor, fontSize: 15, height: 1.4)));
    }
    spans.add(const WidgetSpan(child: SizedBox(width: 6)));
    spans.add(WidgetSpan(
        alignment: PlaceholderAlignment.bottom,
        child: Padding(
            padding: const EdgeInsets.only(bottom: 1),
            child: Text(timestamp,
                style: TextStyle(
                    fontSize: 10, color: timeColor, height: 1.2)))));

    return RichText(text: TextSpan(children: spans));
  }

  // ── Shared scaffold body layout ───────────────────────────────────────────
  // Subclasses call this inside their build() after passing the right widgets.

  Widget buildScaffoldBody({
    required bool       showPollButton,
    VoidCallback?       onPollTap,
  }) {
    return Column(children: [
      buildPinnedStrip(),
      if (showChatSearch) buildSearchBar(),
      Expanded(child: buildMessageList()),
      if (showMentions) buildMentionSuggestions(),
      if (replyingTo != null) buildReplyPreview(),
      buildInputBar(showPollButton: showPollButton, onPollTap: onPollTap),
    ]);
  }
}