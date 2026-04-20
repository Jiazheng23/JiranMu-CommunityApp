import 'package:assignment/chat/user_session.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

// ─────────────────────────────────────────────
// Poll Models
// ─────────────────────────────────────────────

class PollOption {
  final String id;
  final String pollId;
  final String optionText;
  final int displayOrder;

  PollOption({
    required this.id,
    required this.pollId,
    required this.optionText,
    required this.displayOrder,
  });
}

class Poll {
  final String id;
  final String messageId;
  final String roomId;
  final String question;
  final String createdBy;
  final DateTime createdAt;
  final List<PollOption> options;

  Poll({
    required this.id,
    required this.messageId,
    required this.roomId,
    required this.question,
    required this.createdBy,
    required this.createdAt,
    required this.options,
  });
}

final supabase = Supabase.instance.client;

// ─────────────────────────────────────────────
// Models
// ─────────────────────────────────────────────

class Message {
  final String id;
  final String senderName;
  final String text;
  final DateTime timestamp;
  final bool isMe;
  final bool isPoll;
  final String? pollId;
  final bool isAnnouncement;
  final String? replyToId;
  final String? replyToSender;
  final String? replyToText;

  Message({
    required this.id,
    required this.senderName,
    required this.text,
    required this.timestamp,
    required this.isMe,
    this.isPoll = false,
    this.pollId,
    this.isAnnouncement = false,
    this.replyToId,
    this.replyToSender,
    this.replyToText,
  });
}

// ─────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────

class CommunityChatScreen extends StatefulWidget {
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
  State<CommunityChatScreen> createState() => _CommunityChatScreenState();
}

class _CommunityChatScreenState extends State<CommunityChatScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _inputFocusNode = FocusNode();

  List<Message> _messages = [];
  RealtimeChannel? _subscription;

  // Reply state
  Message? _replyingTo;

  // Pinned announcements state
  List<Message> _pinnedAnnouncements = [];
  int _pinnedIndex = 0;
  bool _pinDismissed = true;
  late final AnimationController _pinAnimCtrl;
  late final Animation<double> _pinHeightAnim;

  // Poll cache
  final Map<String, Poll> _pollCache = {};
  final Map<String, Set<String>> _myVotes = {};
  final Map<String, int> _voteCounts = {};
  // pollId -> optionId -> [voterNames]
  final Map<String, Map<String, List<String>>> _pollVoterNames = {};

  // @mention state
  List<String> _mentionSuggestions = [];
  bool _showMentions = false;
  List<String> _roomMembers = [];

  static const Color _primary = Color(0xFF9A4B3C);
  static const Color _bubbleMe = Color(0xFF9A4B3C);
  static const Color _bubbleOther = Color(0xFFF0F0F5);
  static const Color _bgPage = Color(0xFFF5F1ED);
  static const Color _appBarBg = Colors.white;
  static const Color _adminBadgeColor = Color(0xFF9A4B3C);
  static const Color _pinAccent = Color(0xFF9A4B3C);
  static const Color _pinBg = Color(0xFFFAF7F5);

  bool get _isAdmin => widget.isAdmin ?? UserSession.isAdmin;

  List<Message> get _chatMessages =>
      _messages.where((m) => !m.isAnnouncement).toList();

  @override
  void initState() {
    super.initState();
    _pinAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _pinHeightAnim = CurvedAnimation(
      parent: _pinAnimCtrl,
      curve: Curves.easeInOut,
    );
    _fetchMessages();
    _setupRealtime();
    _loadRoomMembers();
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _subscription?.unsubscribe();
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _scrollController.dispose();
    _inputFocusNode.dispose();
    _pinAnimCtrl.dispose();
    super.dispose();
  }

  void _showPin() => setState(() => _pinDismissed = false);
  void _hidePin() => setState(() => _pinDismissed = true);

  // ── Reply ─────────────────────────────────────

  void _setReply(Message msg) {
    setState(() => _replyingTo = msg);
    _inputFocusNode.requestFocus();
  }

  void _cancelReply() => setState(() => _replyingTo = null);

  // ── @mention ──────────────────────────────────

  void _onTextChanged() {
    if (!_isAdmin) return;
    final text = _controller.text;
    final cursor = _controller.selection.baseOffset;
    if (cursor < 0) return;

    final before = text.substring(0, cursor);
    final match = RegExp(r'@(\w*)$').firstMatch(before);

    if (match != null) {
      final query = match.group(1)!.toLowerCase();
      final suggestions = _roomMembers
          .where((name) => name.toLowerCase().contains(query))
          .toList();
      setState(() {
        _mentionSuggestions = suggestions;
        _showMentions = suggestions.isNotEmpty;
      });
    } else {
      setState(() => _showMentions = false);
    }
  }

  void _insertMention(String name) {
    final text = _controller.text;
    final cursor = _controller.selection.baseOffset;
    final before = text.substring(0, cursor);
    final after = text.substring(cursor);
    final replaced = before.replaceAllMapped(
      RegExp(r'@\w*$'),
          (_) => '@$name ',
    );
    _controller.value = TextEditingValue(
      text: replaced + after,
      selection: TextSelection.collapsed(offset: replaced.length),
    );
    setState(() => _showMentions = false);
    _inputFocusNode.requestFocus();
  }

  // ── Data ──────────────────────────────────────

  Future<void> _loadRoomMembers() async {
    try {
      final groupRes = await supabase
          .from('group_chats')
          .select('id')
          .eq('room_id', widget.roomId)
          .single();

      final groupChatId = groupRes['id'] as String;

      final memberRes = await supabase
          .from('group_chat_members')
          .select('user_id')
          .eq('group_chat_id', groupChatId);

      final userIds = (memberRes as List)
          .map((e) => e['user_id'] as String)
          .toList();

      if (userIds.isEmpty) return;

      final profiles = await supabase
          .from('resident')
          .select('full_name')
          .inFilter('id', userIds);

      setState(() {
        _roomMembers = (profiles as List)
            .map((e) => e['full_name'] as String)
            .toList();
      });
    } catch (e) {
      debugPrint("ERROR loading members: $e");
    }
  }

  Future<void> _fetchMessages() async {
    try {
      final data = await supabase
          .from('messages')
          .select(
          'id, room_id, sender, content, created_at, is_announcement, is_poll, poll_id, reply_to_id, reply_to_sender, reply_to_text')
          .eq('room_id', widget.roomId)
          .order('created_at', ascending: true);

      final messages = (data as List<dynamic>).map<Message>((msg) {
        return Message(
          id: msg['id'] as String,
          senderName: msg['sender'] as String,
          text: msg['content'] as String,
          timestamp: DateTime.parse(msg['created_at'] as String),
          isMe: msg['sender'] == widget.currentUser,
          isAnnouncement: msg['is_announcement'] == true,
          isPoll: msg['is_poll'] as bool? ?? false,
          pollId: msg['poll_id'] as String?,
          replyToId: msg['reply_to_id'] as String?,
          replyToSender: msg['reply_to_sender'] as String?,
          replyToText: msg['reply_to_text'] as String?,
        );
      }).toList();

      final pins = messages.where((m) => m.isAnnouncement).toList();

      setState(() {
        _messages = messages;
        _pinnedAnnouncements = pins;
        _pinnedIndex = pins.isEmpty ? 0 : pins.length - 1;
        _pinDismissed = pins.isEmpty;
      });

      final pollMessages = messages.where((m) => m.isPoll && m.pollId != null);
      for (final msg in pollMessages) {
        await _loadPollData(msg.pollId!, msg.id);
      }

      _scrollToBottom();
    } catch (e) {
      debugPrint('Error fetching messages: $e');
    }
  }

  Future<void> _loadPollData(String pollId, String messageId) async {
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
        id: o['id'] as String,
        pollId: o['poll_id'] as String,
        optionText: o['option_text'] as String,
        displayOrder: o['display_order'] as int,
      ))
          .toList();

      final poll = Poll(
        id: pollRes['id'] as String,
        messageId: pollRes['message_id'] as String,
        roomId: pollRes['room_id'] as String,
        question: pollRes['question'] as String,
        createdBy: pollRes['created_by'] as String,
        createdAt: DateTime.parse(pollRes['created_at'] as String),
        options: options,
      );

      final votesRes = await supabase
          .from('poll_votes')
          .select('option_id, user_id')
          .eq('poll_id', pollId);

      final Map<String, int> counts = {};
      final Set<String> myVotedOptions = {};
      final Map<String, List<String>> voterNames = {};

      final List<String> voterUserIds = (votesRes as List)
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
        final optId = v['option_id'] as String;
        final userId = v['user_id'] as String;
        counts[optId] = (counts[optId] ?? 0) + 1;
        if (userId == widget.currentUserId) {
          myVotedOptions.add(optId);
        }
        final name = userIdToName[userId] ?? 'Unknown';
        voterNames[optId] = [...(voterNames[optId] ?? []), name];
      }

      setState(() {
        _pollCache[messageId] = poll;
        _myVotes[pollId] = myVotedOptions;
        _voteCounts.addAll(counts);
        _pollVoterNames[pollId] = voterNames;
      });
    } catch (e) {
      debugPrint('Error loading poll $pollId: $e');
    }
  }

  void _setupRealtime() {
    _subscription = supabase
        .channel('room:${widget.roomId}')
        .onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'messages',
      callback: (payload) async {
        final msg = payload.newRecord;
        if (msg['room_id'] != widget.roomId) return;

        final newMessage = Message(
          id: msg['id'] as String,
          senderName: msg['sender'] as String,
          text: msg['content'] as String,
          timestamp: DateTime.parse(msg['created_at'] as String),
          isMe: msg['sender'] == widget.currentUser,
          isAnnouncement: msg['is_announcement'] == true,
          isPoll: msg['is_poll'] as bool? ?? false,
          pollId: msg['poll_id'] as String?,
          replyToId: msg['reply_to_id'] as String?,
          replyToSender: msg['reply_to_sender'] as String?,
          replyToText: msg['reply_to_text'] as String?,
        );

        setState(() {
          final alreadyExists = _messages.any(
                (m) =>
            m.text == newMessage.text &&
                m.senderName == newMessage.senderName &&
                m.timestamp
                    .difference(newMessage.timestamp)
                    .inSeconds
                    .abs() <
                    2,
          );
          if (!alreadyExists) {
            _messages.add(newMessage);
            _messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));

            if (newMessage.isAnnouncement) {
              _pinnedAnnouncements.add(newMessage);
              _pinnedIndex = _pinnedAnnouncements.length - 1;
              _showPin();
            }
          }
        });

        if (!newMessage.isAnnouncement) _scrollToBottom();

        if (newMessage.isPoll && newMessage.pollId != null) {
          await _loadPollData(newMessage.pollId!, newMessage.id);
        }
      },
    )
        .onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'poll_votes',
      callback: (payload) async {
        final v = payload.newRecord;
        final optId = v['option_id'] as String;
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
          _voteCounts[optId] = (_voteCounts[optId] ?? 0) + 1;
          if (userId == widget.currentUserId) {
            _myVotes[pollId] = {...?_myVotes[pollId], optId};
          }
          final current = _pollVoterNames[pollId] ?? {};
          _pollVoterNames[pollId] = {
            ...current,
            optId: [...(current[optId] ?? []), voterName],
          };
        });
      },
    )
        .subscribe();
  }

  // ── Poll voting ───────────────────────────────

  Future<void> _toggleVote(Poll poll, PollOption option) async {
    final pollId = poll.id;
    final optionId = option.id;
    final currentVotes = _myVotes[pollId] ?? {};
    final alreadyVoted = currentVotes.contains(optionId);
    final myName = widget.currentUser;

    setState(() {
      if (alreadyVoted) {
        _myVotes[pollId] = currentVotes.difference({optionId});
        _voteCounts[optionId] = (_voteCounts[optionId] ?? 1) - 1;
        final current = _pollVoterNames[pollId] ?? {};
        final updatedList = List<String>.from(current[optionId] ?? [])
          ..remove(myName);
        _pollVoterNames[pollId] = {...current, optionId: updatedList};
      } else {
        _myVotes[pollId] = {...currentVotes, optionId};
        _voteCounts[optionId] = (_voteCounts[optionId] ?? 0) + 1;
        final current = _pollVoterNames[pollId] ?? {};
        _pollVoterNames[pollId] = {
          ...current,
          optionId: [...(current[optionId] ?? []), myName],
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
            .eq('user_id', widget.currentUserId);
      } else {
        await supabase.from('poll_votes').insert({
          'id': const Uuid().v4(),
          'poll_id': pollId,
          'option_id': optionId,
          'user_id': widget.currentUserId,
          'voted_at': DateTime.now().toIso8601String(),
        });
      }
    } catch (e) {
      debugPrint('Vote error: $e');
      setState(() {
        if (alreadyVoted) {
          _myVotes[pollId] = {...?_myVotes[pollId], optionId};
          _voteCounts[optionId] = (_voteCounts[optionId] ?? 0) + 1;
          final current = _pollVoterNames[pollId] ?? {};
          _pollVoterNames[pollId] = {
            ...current,
            optionId: [...(current[optionId] ?? []), myName],
          };
        } else {
          final updated = {...?_myVotes[pollId]};
          updated.remove(optionId);
          _myVotes[pollId] = updated;
          _voteCounts[optionId] = (_voteCounts[optionId] ?? 1) - 1;
          final current = _pollVoterNames[pollId] ?? {};
          final updatedList = List<String>.from(current[optionId] ?? [])
            ..remove(myName);
          _pollVoterNames[pollId] = {...current, optionId: updatedList};
        }
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to record vote.')),
        );
      }
    }
  }

  // ── Send message ──────────────────────────────

  Future<void> _sendMessage({
    bool isAnnouncement = false,
    String? announcementText,
  }) async {
    final text = (announcementText ?? _controller.text).trim();
    if (text.isEmpty) return;

    final reply = _replyingTo;
    if (announcementText == null) _controller.clear();
    setState(() {
      _showMentions = false;
      _replyingTo = null;
    });

    final optimisticId = const Uuid().v4();
    final optimisticMsg = Message(
      id: optimisticId,
      senderName: widget.currentUser,
      text: text,
      timestamp: DateTime.now(),
      isMe: true,
      isAnnouncement: isAnnouncement,
      replyToId: reply?.id,
      replyToSender: reply?.senderName,
      replyToText: reply?.text,
    );

    setState(() {
      _messages.add(optimisticMsg);
      if (isAnnouncement) {
        _pinnedAnnouncements.add(optimisticMsg);
        _pinnedIndex = _pinnedAnnouncements.length - 1;
        _showPin();
      }
    });

    if (!isAnnouncement) _scrollToBottom();

    try {
      await supabase.from('messages').insert({
        'id': optimisticId,
        'room_id': widget.roomId,
        'sender': widget.currentUser,
        'content': text,
        'created_at': DateTime.now().toIso8601String(),
        'is_announcement': isAnnouncement,
        if (reply != null) ...{
          'reply_to_id': reply.id,
          'reply_to_sender': reply.senderName,
          'reply_to_text': reply.text,
        },
      });
    } catch (e) {
      debugPrint('Error sending message: $e');
      setState(() {
        _messages.removeWhere((m) => m.id == optimisticId);
        if (isAnnouncement) {
          _pinnedAnnouncements.removeWhere((m) => m.id == optimisticId);
          _pinnedIndex = _pinnedAnnouncements.isEmpty
              ? 0
              : _pinnedAnnouncements.length - 1;
          if (_pinnedAnnouncements.isEmpty) _hidePin();
        }
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to send message.')),
        );
      }
    }
  }

  // ── Create poll ───────────────────────────────

  Future<void> _createPoll(String question, List<String> optionTexts) async {
    final pollId = const Uuid().v4();
    final messageId = const Uuid().v4();
    final now = DateTime.now();

    final options = optionTexts
        .asMap()
        .entries
        .map((e) => PollOption(
      id: const Uuid().v4(),
      pollId: pollId,
      optionText: e.value,
      displayOrder: e.key,
    ))
        .toList();

    final poll = Poll(
      id: pollId,
      messageId: messageId,
      roomId: widget.roomId,
      question: question,
      createdBy: widget.currentUser,
      createdAt: now,
      options: options,
    );

    final optimisticMsg = Message(
      id: messageId,
      senderName: widget.currentUser,
      text: question,
      timestamp: now,
      isMe: true,
      isPoll: true,
      pollId: pollId,
    );

    setState(() {
      _messages.add(optimisticMsg);
      _pollCache[messageId] = poll;
      _myVotes[pollId] = {};
      _pollVoterNames[pollId] = {};
    });
    _scrollToBottom();

    try {
      await supabase.from('polls').insert({
        'id': pollId,
        'message_id': messageId,
        'room_id': widget.roomId,
        'question': question,
        'created_by': widget.currentUser,
        'created_at': now.toIso8601String(),
      });

      for (final opt in options) {
        await supabase.from('poll_options').insert({
          'id': opt.id,
          'poll_id': pollId,
          'option_text': opt.optionText,
          'display_order': opt.displayOrder,
        });
      }

      await supabase.from('messages').insert({
        'id': messageId,
        'room_id': widget.roomId,
        'sender': widget.currentUser,
        'content': question,
        'created_at': now.toIso8601String(),
        'is_poll': true,
        'poll_id': pollId,
        'is_announcement': false,
      });
    } catch (e, stack) {
      debugPrint('Error creating poll: $e');
      debugPrint('Stack: $stack');
      setState(() {
        _messages.removeWhere((m) => m.id == messageId);
        _pollCache.remove(messageId);
        _myVotes.remove(pollId);
        _pollVoterNames.remove(pollId);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create poll: $e')),
        );
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ── Poll Results ──────────────────────────────

  void _showPollResults(Poll poll) {
    final voterMap = _pollVoterNames[poll.id] ?? {};
    final totalVotes = poll.options
        .fold<int>(0, (sum, o) => sum + (_voteCounts[o.id] ?? 0));

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6,
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
                  const Icon(Icons.bar_chart_rounded,
                      color: _primary, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      poll.question,
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Row(
                children: [
                  const SizedBox(width: 28),
                  Text(
                    '$totalVotes vote${totalVotes == 1 ? '' : 's'} total',
                    style:
                    const TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                controller: scrollCtrl,
                padding: const EdgeInsets.all(16),
                itemCount: poll.options.length,
                itemBuilder: (_, i) {
                  final opt = poll.options[i];
                  final count = _voteCounts[opt.id] ?? 0;
                  final pct =
                  totalVotes == 0 ? 0.0 : count / totalVotes;
                  final voters = voterMap[opt.id] ?? [];

                  return Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFAF7F5),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: _primary.withOpacity(0.15)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding:
                          const EdgeInsets.fromLTRB(14, 12, 14, 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      opt.optionText,
                                      style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.black87),
                                    ),
                                  ),
                                  Text(
                                    '$count vote${count == 1 ? '' : 's'} · ${(pct * 100).round()}%',
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: _primary,
                                        fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: pct,
                                  minHeight: 6,
                                  backgroundColor:
                                  Colors.black.withOpacity(0.07),
                                  valueColor:
                                  const AlwaysStoppedAnimation(_primary),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (voters.isEmpty)
                          const Padding(
                            padding: EdgeInsets.fromLTRB(14, 0, 14, 12),
                            child: Text('No votes yet',
                                style: TextStyle(
                                    fontSize: 12, color: Colors.black38)),
                          )
                        else ...[
                          const Divider(height: 1),
                          Padding(
                            padding:
                            const EdgeInsets.fromLTRB(14, 8, 14, 12),
                            child: Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: voters
                                  .map((name) => Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color:
                                  _primary.withOpacity(0.09),
                                  borderRadius:
                                  BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    CircleAvatar(
                                      radius: 9,
                                      backgroundColor:
                                      _avatarColorFromName(
                                          name),
                                      child: Text(
                                        _initialsFromName(name),
                                        style: const TextStyle(
                                            fontSize: 7,
                                            color: Colors.white,
                                            fontWeight:
                                            FontWeight.w700),
                                      ),
                                    ),
                                    const SizedBox(width: 5),
                                    Text(name,
                                        style: const TextStyle(
                                            fontSize: 12,
                                            color: _primary,
                                            fontWeight:
                                            FontWeight.w600)),
                                  ],
                                ),
                              ))
                                  .toList(),
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Admin actions ─────────────────────────────

  void _showGroupSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.people_outline,
                  color: Color(0xFF9A4B3C)),
              title: const Text('View Members',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(context);
                _navigateToMembers();
              },
            ),
            ListTile(
              leading: const Icon(Icons.campaign_outlined,
                  color: Color(0xFF9A4B3C)),
              title: const Text('Post Announcement',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(context);
                _showAnnouncementDialog();
              },
            ),
            ListTile(
              leading: const Icon(Icons.push_pin_outlined,
                  color: Color(0xFF9A4B3C)),
              title: const Text('Edit Announcements',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(
                '${_pinnedAnnouncements.length} pinned',
                style:
                const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              onTap: () {
                Navigator.pop(context);
                _showEditAnnouncementsSheet();
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined,
                  color: Color(0xFF9A4B3C)),
              title: const Text('Rename Group',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(context);
                _showRenameDialog();
              },
            ),
            ListTile(
              leading:
              const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Delete Group',
                  style: TextStyle(
                      fontWeight: FontWeight.w600, color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _confirmDeleteGroup();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showEditAnnouncementsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final announcements = List<Message>.from(_pinnedAnnouncements);

          return DraggableScrollableSheet(
            initialChildSize: 0.55,
            minChildSize: 0.35,
            maxChildSize: 0.85,
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
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: Row(
                    children: [
                      const Icon(Icons.push_pin_rounded,
                          color: _pinAccent, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Announcements (${announcements.length})',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: announcements.isEmpty
                      ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.push_pin_outlined,
                              size: 48, color: Colors.black26),
                          SizedBox(height: 12),
                          Text(
                            'No announcements yet.',
                            style: TextStyle(
                                color: Colors.grey, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  )
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
                          color: _pinBg,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: _pinAccent.withOpacity(0.2),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(
                              14, 12, 8, 12),
                          child: Row(
                            crossAxisAlignment:
                            CrossAxisAlignment.start,
                            children: [
                              const Padding(
                                padding: EdgeInsets.only(top: 2),
                                child: Icon(
                                    Icons.push_pin_rounded,
                                    size: 16,
                                    color: _pinAccent),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                  CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      ann.text,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Colors.black87,
                                        height: 1.4,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _formatTimestamp(
                                          ann.timestamp),
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Colors.black38,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: Colors.red,
                                  size: 20,
                                ),
                                tooltip: 'Delete announcement',
                                onPressed: () =>
                                    _confirmDeleteAnnouncement(
                                      ann,
                                      onDeleted: () =>
                                          setSheetState(() {}),
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
        },
      ),
    );
  }

  void _confirmDeleteAnnouncement(
      Message ann, {
        required VoidCallback onDeleted,
      }) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Announcement'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Permanently delete this announcement?'),
            const SizedBox(height: 10),
            Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F1ED),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: const Color(0xFF9A4B3C).withOpacity(0.25)),
              ),
              child: Text(
                ann.text,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, height: 1.4),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel',
                style: TextStyle(color: Colors.black54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              Navigator.pop(context);
              try {
                await supabase.from('messages').delete().eq('id', ann.id);
                setState(() {
                  _messages.removeWhere((m) => m.id == ann.id);
                  _pinnedAnnouncements.removeWhere((m) => m.id == ann.id);
                  if (_pinnedAnnouncements.isEmpty) {
                    _pinnedIndex = 0;
                    _hidePin();
                  } else {
                    _pinnedIndex = _pinnedIndex.clamp(
                        0, _pinnedAnnouncements.length - 1);
                  }
                });
                onDeleted();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Announcement deleted.'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              } catch (e) {
                debugPrint('Error deleting announcement: $e');
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Failed to delete announcement.')),
                  );
                }
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _navigateToMembers() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GroupMembersScreen(members: _roomMembers),
      ),
    );
  }

  void _showAnnouncementDialog() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.campaign_outlined, color: Color(0xFF9A4B3C)),
            SizedBox(width: 8),
            Text('Post Announcement'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Write your announcement…',
                filled: true,
                fillColor: const Color(0xFFF5F1ED),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel',
                  style: TextStyle(color: Colors.black54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF9A4B3C),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              final announcementText = ctrl.text.trim();
              if (announcementText.isEmpty) return;
              Navigator.pop(context);
              _sendMessage(
                isAnnouncement: true,
                announcementText: announcementText,
              );
            },
            child: const Text('Post'),
          ),
        ],
      ),
    );
  }

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
          title: const Row(
            children: [
              Icon(Icons.poll_outlined, color: Color(0xFF9A4B3C)),
              SizedBox(width: 8),
              Text('Create Poll'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                TextField(
                  controller: questionCtrl,
                  decoration: InputDecoration(
                    hintText: 'Ask a question…',
                    filled: true,
                    fillColor: const Color(0xFFF5F1ED),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Options',
                    style: TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 13)),
                const SizedBox(height: 8),
                ...optionCtrls.asMap().entries.map((entry) {
                  final i = entry.key;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: entry.value,
                            decoration: InputDecoration(
                              hintText: 'Option ${i + 1}',
                              filled: true,
                              fillColor: const Color(0xFFF5F1ED),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                            ),
                          ),
                        ),
                        if (i >= 2) ...[
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: () => setDialogState(
                                    () => optionCtrls.removeAt(i)),
                            child: const Icon(
                                Icons.remove_circle_outline,
                                color: Colors.red,
                                size: 20),
                          ),
                        ],
                      ],
                    ),
                  );
                }),
                if (optionCtrls.length < 5)
                  TextButton.icon(
                    onPressed: () => setDialogState(
                            () => optionCtrls.add(TextEditingController())),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add option'),
                    style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF9A4B3C)),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel',
                  style: TextStyle(color: Colors.black54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF9A4B3C),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                final question = questionCtrl.text.trim();
                final options = optionCtrls
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

  void _showRenameDialog() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Rename Group'),
        content: TextField(
          controller: ctrl,
          decoration: InputDecoration(
            hintText: widget.communityName,
            filled: true,
            fillColor: const Color(0xFFF5F1ED),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              final newName = ctrl.text.trim();
              if (newName.isEmpty) return;
              try {
                await supabase
                    .from('group_chats')
                    .update({'name': newName}).eq('room_id', widget.roomId);
                Navigator.pop(context);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Group renamed')),
                  );
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
        title: const Text('Delete Group'),
        content: const Text(
            'This will permanently delete the group and all messages. Continue?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              try {
                await supabase
                    .from('group_chats')
                    .delete()
                    .eq('room_id', widget.roomId);
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

  // ── UI ────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgPage,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildPinnedStrip(),
          Expanded(child: _buildMessageList()),
          if (_showMentions) _buildMentionSuggestions(),
          if (_replyingTo != null) _buildReplyPreview(),
          _buildInputBar(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: _appBarBg,
      elevation: 0,
      centerTitle: true,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded,
            color: Colors.black87, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      title: Column(
        children: [
          Text(
            widget.communityName,
            style: const TextStyle(
              color: Colors.black87,
              fontSize: 16,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
          Text(
            _isAdmin ? 'Admin View' : 'Group Chat',
            style: TextStyle(
              color: _isAdmin ? _primary : Colors.grey,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
      actions: _isAdmin
          ? [
        IconButton(
          icon: const Icon(Icons.settings_outlined, color: _primary),
          tooltip: 'Group Settings',
          onPressed: _showGroupSettings,
        ),
      ]
          : [
        IconButton(
          icon:
          const Icon(Icons.video_call_rounded, color: _primary),
          onPressed: () {},
        ),
        IconButton(
          icon: const Icon(Icons.call_rounded, color: _primary),
          onPressed: () {},
        ),
      ],
    );
  }

  // ── Pinned strip ──────────────────────────────

  Widget _buildPinnedStrip() {
    if (_pinnedAnnouncements.isEmpty || _pinDismissed) {
      return const SizedBox.shrink();
    }

    final ann = _pinnedAnnouncements[_pinnedIndex];
    final total = _pinnedAnnouncements.length;

    return Container(
      color: _pinBg,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(height: 1, color: Colors.black.withOpacity(0.07)),
          Padding(
            padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Icon(Icons.push_pin_rounded,
                    size: 14, color: _pinAccent),
                const SizedBox(width: 10),
                Container(
                  width: 3,
                  height: 34,
                  decoration: BoxDecoration(
                    color: _pinAccent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Pinned Message',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: _pinAccent,
                              letterSpacing: 0.1,
                            ),
                          ),
                          if (total > 1) ...[
                            const SizedBox(width: 4),
                            Text(
                              '(${_pinnedIndex + 1}/$total)',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: _pinAccent,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        ann.text,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.black87,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                if (total > 1) ...[
                  const SizedBox(width: 4),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onTap: () => setState(() {
                          _pinnedIndex =
                              (_pinnedIndex - 1 + total) % total;
                        }),
                        child: const Icon(
                            Icons.keyboard_arrow_up_rounded,
                            size: 18,
                            color: _pinAccent),
                      ),
                      GestureDetector(
                        onTap: () => setState(() {
                          _pinnedIndex = (_pinnedIndex + 1) % total;
                        }),
                        child: const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 18,
                            color: _pinAccent),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          Container(height: 1, color: Colors.black.withOpacity(0.07)),
        ],
      ),
    );
  }

  void _confirmRemoveCurrentAnnouncement() {
    if (_pinnedAnnouncements.isEmpty) return;
    final target = _pinnedAnnouncements[_pinnedIndex];
    _confirmDeleteAnnouncement(target, onDeleted: () {});
  }

  // ── Reply preview bar ─────────────────────────

  Widget _buildReplyPreview() {
    final r = _replyingTo!;
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 36,
            decoration: BoxDecoration(
              color: _primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  r.isMe ? 'You' : r.senderName,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _primary,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  r.isPoll ? '📊 Poll' : r.text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18, color: Colors.black45),
            onPressed: _cancelReply,
          ),
        ],
      ),
    );
  }

  // ── Message list ──────────────────────────────

  Widget _buildMessageList() {
    final msgs = _chatMessages;

    if (msgs.isEmpty) {
      return const Center(
        child: Text(
          'No messages yet.\nBe the first to say hello! 👋',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey, fontSize: 14, height: 1.6),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: msgs.length,
      itemBuilder: (context, index) {
        final msg = msgs[index];
        final showSender =
            !msg.isMe && (index == 0 || msgs[index - 1].isMe);

        if (msg.isPoll) {
          final poll = _pollCache[msg.id];
          if (poll == null) return _buildLoadingPollBubble(msg);
          return _buildSwipeable(msg, _buildPollBubble(msg, poll));
        }

        return _buildSwipeable(msg, _buildMessageBubble(msg, showSender));
      },
    );
  }

  // ── Swipe-to-reply wrapper ────────────────────

  Widget _buildSwipeable(Message msg, Widget child) {
    return _SwipeToReply(
      key: ValueKey('swipe_${msg.id}'),
      isMe: msg.isMe,
      onReply: () => _setReply(msg),
      child: child,
    );
  }

  Widget _buildSwipeBg({required bool fromEnd}) {
    return Align(
      alignment: fromEnd ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: _primary.withOpacity(0.12),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.reply_rounded, color: _primary, size: 18),
        ),
      ),
    );
  }

  // ── Poll bubble ───────────────────────────────

  Widget _buildLoadingPollBubble(Message msg) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment:
        msg.isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: msg.isMe ? _bubbleMe : _bubbleOther,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: msg.isMe ? Colors.white54 : Colors.black38,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Loading poll…',
                  style: TextStyle(
                    color: msg.isMe ? Colors.white70 : Colors.black54,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPollBubble(Message msg, Poll poll) {
    final myVotes = _myVotes[poll.id] ?? {};
    final totalVotes = poll.options
        .fold<int>(0, (sum, o) => sum + (_voteCounts[o.id] ?? 0));

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment:
        msg.isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!msg.isMe) ...[
            _MiniAvatar(name: msg.senderName),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: msg.isMe
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 3, left: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!msg.isMe)
                        Text(msg.senderName,
                            style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey)),
                      if (msg.isMe)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _adminBadgeColor,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text('Admin',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5)),
                        ),
                    ],
                  ),
                ),
                Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.78,
                    minWidth: MediaQuery.of(context).size.width * 0.55,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                        color: _primary.withOpacity(0.25), width: 1.2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding:
                        const EdgeInsets.fromLTRB(14, 12, 14, 10),
                        decoration: BoxDecoration(
                          color: _primary.withOpacity(0.07),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(17),
                            topRight: Radius.circular(17),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.poll_rounded,
                                color: _primary, size: 16),
                            const SizedBox(width: 6),
                            const Text('Poll',
                                style: TextStyle(
                                    color: _primary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.3)),
                            const Spacer(),
                            Text(
                                '$totalVotes vote${totalVotes == 1 ? '' : 's'}',
                                style: const TextStyle(
                                    color: Colors.black45, fontSize: 11)),
                          ],
                        ),
                      ),
                      Padding(
                        padding:
                        const EdgeInsets.fromLTRB(14, 12, 14, 10),
                        child: Text(poll.question,
                            style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Colors.black87,
                                height: 1.35)),
                      ),
                      Padding(
                        padding:
                        const EdgeInsets.fromLTRB(10, 0, 10, 10),
                        child: Column(
                          children: poll.options.map((opt) {
                            final count = _voteCounts[opt.id] ?? 0;
                            final isVoted = myVotes.contains(opt.id);
                            final pct = totalVotes == 0
                                ? 0.0
                                : count / totalVotes;

                            return GestureDetector(
                              onTap: () => _toggleVote(poll, opt),
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                decoration: BoxDecoration(
                                  borderRadius:
                                  BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isVoted
                                        ? _primary
                                        : Colors.black12,
                                    width: isVoted ? 1.5 : 1,
                                  ),
                                ),
                                child: ClipRRect(
                                  borderRadius:
                                  BorderRadius.circular(9),
                                  child: Stack(
                                    children: [
                                      FractionallySizedBox(
                                        widthFactor: pct,
                                        child: Container(
                                          height: 42,
                                          color: isVoted
                                              ? _primary.withOpacity(0.13)
                                              : Colors.black
                                              .withOpacity(0.04),
                                        ),
                                      ),
                                      SizedBox(
                                        height: 42,
                                        child: Padding(
                                          padding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 12),
                                          child: Row(
                                            children: [
                                              if (isVoted)
                                                const Padding(
                                                  padding: EdgeInsets.only(
                                                      right: 6),
                                                  child: Icon(
                                                      Icons
                                                          .check_circle_rounded,
                                                      color: _primary,
                                                      size: 16),
                                                ),
                                              Expanded(
                                                child: Text(
                                                  opt.optionText,
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: isVoted
                                                        ? FontWeight.w700
                                                        : FontWeight.w500,
                                                    color: isVoted
                                                        ? _primary
                                                        : Colors.black87,
                                                  ),
                                                ),
                                              ),
                                              Text(
                                                totalVotes == 0
                                                    ? '0%'
                                                    : '${(pct * 100).round()}%',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight:
                                                  FontWeight.w600,
                                                  color: isVoted
                                                      ? _primary
                                                      : Colors.black45,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      // Timestamp inside poll bubble
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              _formatTimestamp(msg.timestamp),
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.black38,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (_isAdmin)
                  Padding(
                    padding: const EdgeInsets.only(top: 6, right: 4),
                    child: GestureDetector(
                      onTap: () => _showPollResults(poll),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _primary.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: _primary.withOpacity(0.3)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.bar_chart_rounded,
                                size: 13, color: _primary),
                            SizedBox(width: 4),
                            Text('View Results',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: _primary,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
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

  // ── Regular message bubble ────────────────────

  Widget _buildMessageBubble(Message msg, bool showSender) {
    final showAdminBadge = msg.isMe && _isAdmin;
    final bubbleColor = msg.isMe ? _bubbleMe : _bubbleOther;
    final timeColor = msg.isMe
        ? Colors.white.withOpacity(0.6)
        : Colors.black38;
    final textColor = msg.isMe ? Colors.white : Colors.black87;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment:
        msg.isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!msg.isMe) ...[
            _MiniAvatar(name: msg.senderName),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: msg.isMe
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                if (showSender || showAdminBadge)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 3, left: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (showSender)
                          Text(msg.senderName,
                              style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey)),
                        if (showAdminBadge) ...[
                          if (showSender) const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: _adminBadgeColor,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text('Admin',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.5)),
                          ),
                        ],
                      ],
                    ),
                  ),
                Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.72,
                  ),
                  decoration: BoxDecoration(
                    color: bubbleColor,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: Radius.circular(msg.isMe ? 18 : 4),
                      bottomRight: Radius.circular(msg.isMe ? 4 : 18),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Reply preview inside bubble
                      if (msg.replyToText != null)
                        Container(
                          margin: const EdgeInsets.fromLTRB(8, 8, 8, 0),
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
                                    : _primary,
                                width: 3,
                              ),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                msg.replyToSender == widget.currentUser
                                    ? 'You'
                                    : (msg.replyToSender ?? ''),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: msg.isMe
                                      ? Colors.white
                                      : _primary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                msg.replyToText!,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: msg.isMe
                                      ? Colors.white.withOpacity(0.75)
                                      : Colors.black54,
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      // Message text + inline timestamp
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                        child: _buildInlineTextWithTime(
                          msg: msg,
                          textColor: textColor,
                          timeColor: timeColor,
                        ),
                      ),
                    ],
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

  /// Renders message text with the timestamp "tucked" at the end —
  /// the same technique WhatsApp uses: an invisible spacer after the
  /// last word forces the timestamp to sit on the same or next line,
  /// always flush-right inside the bubble.
  Widget _buildInlineTextWithTime({
    required Message msg,
    required Color textColor,
    required Color timeColor,
  }) {
    final timestamp = _formatTimestamp(msg.timestamp);
    final color = textColor;
    final text = msg.text;
    final mentionRegex = RegExp(r'@\w+');
    final spans = <InlineSpan>[];
    int last = 0;

    for (final match in mentionRegex.allMatches(text)) {
      if (match.start > last) {
        spans.add(TextSpan(
          text: text.substring(last, match.start),
          style: TextStyle(color: color, fontSize: 15, height: 1.4),
        ));
      }
      spans.add(TextSpan(
        text: match.group(0),
        style: TextStyle(
          color: msg.isMe ? Colors.white : _primary,
          fontSize: 15,
          fontWeight: FontWeight.w700,
          height: 1.4,
        ),
      ));
      last = match.end;
    }

    if (last < text.length) {
      spans.add(TextSpan(
        text: text.substring(last),
        style: TextStyle(color: color, fontSize: 15, height: 1.4),
      ));
    }

    // Add timestamp inline as a WidgetSpan so it never overflows
    spans.add(const WidgetSpan(child: SizedBox(width: 6)));
    spans.add(WidgetSpan(
      alignment: PlaceholderAlignment.bottom,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 1),
        child: Text(
          timestamp,
          style: TextStyle(fontSize: 10, color: timeColor, height: 1.2),
        ),
      ),
    ));

    return RichText(
      text: TextSpan(children: spans),
    );
  }

  // ── @mention suggestions ──────────────────────

  Widget _buildMentionSuggestions() {
    return Container(
      constraints: const BoxConstraints(maxHeight: 160),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFEEEEEE))),
      ),
      child: ListView.builder(
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        itemCount: _mentionSuggestions.length,
        itemBuilder: (context, i) {
          final name = _mentionSuggestions[i];
          return ListTile(
            dense: true,
            leading: CircleAvatar(
              radius: 16,
              backgroundColor: _avatarColorFromName(name),
              child: Text(_initialsFromName(name),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700)),
            ),
            title: Text(name,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w600)),
            onTap: () => _insertMention(name),
          );
        },
      ),
    );
  }

  // ── Input bar ─────────────────────────────────

  Widget _buildInputBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 12),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (_isAdmin) ...[
              GestureDetector(
                onTap: _showPollDialog,
                child: Container(
                  width: 40,
                  height: 40,
                  margin: const EdgeInsets.only(right: 6),
                  decoration: BoxDecoration(
                    color: _primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: _primary.withOpacity(0.3), width: 1),
                  ),
                  child: const Icon(Icons.poll_outlined,
                      color: _primary, size: 20),
                ),
              ),
            ],
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F0F5),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                      minHeight: 40, maxHeight: 120),
                  child: Scrollbar(
                    child: TextField(
                      controller: _controller,
                      focusNode: _inputFocusNode,
                      textCapitalization: TextCapitalization.sentences,
                      style: const TextStyle(
                          fontSize: 15,
                          color: Colors.black87,
                          height: 1.4),
                      maxLines: null,
                      minLines: 1,
                      keyboardType: TextInputType.multiline,
                      textInputAction: TextInputAction.newline,
                      decoration: const InputDecoration(
                        hintText: 'Type a message/@',
                        hintStyle:
                        TextStyle(color: Colors.grey, fontSize: 15),
                        border: InputBorder.none,
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
              onTap: () => _sendMessage(),
              child: Container(
                width: 42,
                height: 42,
                decoration: const BoxDecoration(
                  color: _primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.send_rounded,
                    color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────

  String _formatTimestamp(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) {
      final h = dt.hour;
      final m = dt.minute.toString().padLeft(2, '0');
      final period = h >= 12 ? 'PM' : 'AM';
      final hour = h == 0 ? 12 : (h > 12 ? h - 12 : h);
      return '$hour:$m $period';
    }
    return '${dt.day}/${dt.month}';
  }

  Color _avatarColorFromName(String name) {
    final hue =
    (name.codeUnits.fold(0, (a, b) => a + b) % 360).toDouble();
    return HSLColor.fromAHSL(1, hue, 0.5, 0.55).toColor();
  }

  String _initialsFromName(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }
}

// ─────────────────────────────────────────────
// Group Members Screen
// ─────────────────────────────────────────────

class GroupMembersScreen extends StatelessWidget {
  final List<String> members;

  const GroupMembersScreen({Key? key, required this.members})
      : super(key: key);

  static const Color _primary = Color(0xFF9A4B3C);
  static const Color _bgPage = Color(0xFFF5F1ED);

  Color _avatarColorFromName(String name) {
    final hue =
    (name.codeUnits.fold(0, (a, b) => a + b) % 360).toDouble();
    return HSLColor.fromAHSL(1, hue, 0.5, 0.55).toColor();
  }

  String _initialsFromName(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgPage,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.black87, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Group Members',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
      ),
      body: members.isEmpty
          ? const Center(
          child: Text('No members found.',
              style: TextStyle(color: Colors.grey, fontSize: 14)))
          : Column(
        children: [
          Container(
            width: double.infinity,
            color: Colors.white,
            padding: const EdgeInsets.symmetric(
                horizontal: 20, vertical: 12),
            child: Text(
              '${members.length} member${members.length == 1 ? '' : 's'}',
              style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 13,
                  fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 4),
              itemCount: members.length,
              separatorBuilder: (_, __) =>
              const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final name = members[index];
                return Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
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
                        backgroundColor:
                        _avatarColorFromName(name),
                        child: Text(_initialsFromName(name),
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w700)),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(name,
                            style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87)),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Sub-widgets
// ─────────────────────────────────────────────

class _MiniAvatar extends StatelessWidget {
  final String name;
  const _MiniAvatar({required this.name});

  Color get _color {
    final hue =
    (name.codeUnits.fold(0, (a, b) => a + b) % 360).toDouble();
    return HSLColor.fromAHSL(1, hue, 0.5, 0.55).toColor();
  }

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(color: _color, shape: BoxShape.circle),
      child: Center(
        child: Text(_initials,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w700)),
      ),
    );
  }
}

class _SwipeToReply extends StatefulWidget {
  final bool isMe;
  final VoidCallback onReply;
  final Widget child;

  const _SwipeToReply({
    Key? key,
    required this.isMe,
    required this.onReply,
    required this.child,
  }) : super(key: key);

  @override
  State<_SwipeToReply> createState() => _SwipeToReplyState();
}

class _SwipeToReplyState extends State<_SwipeToReply>
    with SingleTickerProviderStateMixin {
  double _offset = 0;
  bool _triggered = false;
  late AnimationController _snapCtrl;
  late Animation<double> _snapAnim;
  double _snapFrom = 0;

  static const double _maxDrag = 64;
  static const double _triggerThreshold = 52;
  static const Color _primary = Color(0xFF9A4B3C);

  @override
  void initState() {
    super.initState();
    _snapCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _snapAnim = Tween<double>(begin: 0, end: 0).animate(
      CurvedAnimation(parent: _snapCtrl, curve: Curves.easeOut),
    )..addListener(() {
      setState(() => _offset = _snapFrom * (1 - _snapCtrl.value));
    });
  }

  @override
  void dispose() {
    _snapCtrl.dispose();
    super.dispose();
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    final delta = details.delta.dx;
    // Right-to-left for "isMe" bubbles, left-to-right for others
    final isRtl = widget.isMe;
    final effective = isRtl ? -delta : delta;
    if (effective < 0) return; // ignore wrong direction

    setState(() {
      // Rubber-band clamping: full drag up to half max, then slow
      if (_offset < _maxDrag / 2) {
        _offset = (_offset + effective).clamp(0, _maxDrag);
      } else {
        _offset = (_offset + effective * 0.3).clamp(0, _maxDrag);
      }
      if (_offset >= _triggerThreshold && !_triggered) {
        _triggered = true;
      }
    });
  }

  void _onHorizontalDragEnd(DragEndDetails _) {
    if (_triggered) widget.onReply();
    _triggered = false;
    _snapFrom = _offset;
    _snapCtrl.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final dx = widget.isMe ? -_offset : _offset;
    final iconOpacity = (_offset / _triggerThreshold).clamp(0.0, 1.0);
    final iconScale = 0.6 + 0.4 * iconOpacity;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragUpdate: _onHorizontalDragUpdate,
      onHorizontalDragEnd: _onHorizontalDragEnd,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Reply icon revealed behind the bubble
          Positioned(
            left: widget.isMe ? null : 0,
            right: widget.isMe ? 0 : null,
            top: 0,
            bottom: 0,
            child: Opacity(
              opacity: iconOpacity,
              child: Transform.scale(
                scale: iconScale,
                child: Container(
                  width: 36,
                  height: 36,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: _primary.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.reply_rounded,
                    color: _primary,
                    size: 18,
                  ),
                ),
              ),
            ),
          ),
          // The bubble, translated
          Transform.translate(
            offset: Offset(dx, 0),
            child: widget.child,
          ),
        ],
      ),
    );
  }
}