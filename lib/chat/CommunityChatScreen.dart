import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

final supabase = Supabase.instance.client;

// ─────────────────────────────────────────────
// Models
// ─────────────────────────────────────────────

class Message {
  final String senderName;
  final String text;
  final DateTime timestamp;
  final bool isMe;

  Message({
    required this.senderName,
    required this.text,
    required this.timestamp,
    required this.isMe,
  });
}

// ─────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────

class CommunityChatScreen extends StatefulWidget {
  final String roomId;
  final String communityName;

  /// UUID from supabase.auth.currentUser.id
  final String currentUserId;

  /// Display name from profiles.name
  final String currentUser;

  const CommunityChatScreen({
    Key? key,
    required this.roomId,
    required this.communityName,
    required this.currentUserId,
    required this.currentUser,
  }) : super(key: key);

  @override
  State<CommunityChatScreen> createState() => _CommunityChatScreenState();
}

class _CommunityChatScreenState extends State<CommunityChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<Message> _messages = [];
  RealtimeChannel? _subscription;

  static const Color _primary = Color(0xFF9A4B3C);
  static const Color _bubbleMe = Color(0xFF9A4B3C);
  static const Color _bubbleOther = Color(0xFFF0F0F5);
  static const Color _bgPage = Color(0xFFF5F1ED);
  static const Color _appBarBg = Colors.white;

  @override
  void initState() {
    super.initState();
    _fetchMessages();
    _setupRealtime();
  }

  @override
  void dispose() {
    _subscription?.unsubscribe();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ── Data ──────────────────────────────────────

  Future<void> _fetchMessages() async {
    try {
      final data = await supabase
          .from('messages')
          .select('id, room_id, sender, content, created_at')
          .eq('room_id', widget.roomId)
          .order('created_at', ascending: true);

      setState(() {
        _messages = (data as List<dynamic>).map<Message>((msg) {
          return Message(
            senderName: msg['sender'] as String,
            text: msg['content'] as String,
            timestamp: DateTime.parse(msg['created_at'] as String),
            // sender column stores the display name
            isMe: msg['sender'] == widget.currentUser,
          );
        }).toList();
      });

      _scrollToBottom();
    } catch (e) {
      debugPrint('Error fetching messages: $e');
    }
  }

  void _setupRealtime() {
    _subscription = supabase
        .channel('room:${widget.roomId}')
        .onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'messages',
      callback: (payload) {
        final msg = payload.newRecord;
        if (msg['room_id'] != widget.roomId) return;

        final newMessage = Message(
          senderName: msg['sender'] as String,
          text: msg['content'] as String,
          timestamp: DateTime.parse(msg['created_at'] as String),
          isMe: msg['sender'] == widget.currentUser,
        );

        setState(() {
          // Avoid duplicates (optimistic insert may already be in the list)
          final alreadyExists = _messages.any(
                (m) =>
            m.text == newMessage.text &&
                m.senderName == newMessage.senderName &&
                m.timestamp.difference(newMessage.timestamp).inSeconds.abs() < 2,
          );
          if (!alreadyExists) {
            _messages.add(newMessage);
            _messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
          }
        });

        _scrollToBottom();
      },
    )
        .subscribe();
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    _controller.clear();

    // Optimistic insert so the sender sees the message immediately
    setState(() {
      _messages.add(Message(
        senderName: widget.currentUser,
        text: text,
        timestamp: DateTime.now(),
        isMe: true,
      ));
    });
    _scrollToBottom();

    try {
      await supabase.from('messages').insert({
        'id': const Uuid().v4(),
        'room_id': widget.roomId,
        'sender': widget.currentUser, // store display name
        'content': text,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Error sending message: $e');
      // Remove the optimistic message on failure
      setState(() => _messages.removeLast());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to send message.')),
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

  // ── UI ────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgPage,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          const Divider(height: 1, thickness: 1, color: Color(0xFFE8E8EE)),
          Expanded(child: _buildMessageList()),
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
          const Text(
            'Private Chat',
            style: TextStyle(
                color: Colors.grey, fontSize: 11, fontWeight: FontWeight.w400),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.video_call_rounded, color: _primary),
          onPressed: () {},
        ),
        IconButton(
          icon: const Icon(Icons.call_rounded, color: _primary),
          onPressed: () {},
        ),
      ],
    );
  }

  // ── Message list ──────────────────────────────

  Widget _buildMessageList() {
    if (_messages.isEmpty) {
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
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final msg = _messages[index];
        final showSender =
            !msg.isMe && (index == 0 || _messages[index - 1].isMe);
        return _buildMessageBubble(msg, showSender);
      },
    );
  }

  Widget _buildMessageBubble(Message msg, bool showSender) {
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
                if (showSender)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 3, left: 4),
                    child: Text(
                      msg.senderName,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.68,
                  ),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: msg.isMe ? _bubbleMe : _bubbleOther,
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
                  child: Text(
                    msg.text,
                    style: TextStyle(
                      color: msg.isMe ? Colors.white : Colors.black87,
                      fontSize: 15,
                      height: 1.35,
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

  // ── Input bar ─────────────────────────────────

  Widget _buildInputBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 12),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F0F5),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TextField(
                  controller: _controller,
                  textCapitalization: TextCapitalization.sentences,
                  style: const TextStyle(fontSize: 15, color: Colors.black87),
                  decoration: const InputDecoration(
                    hintText: 'Type a message…',
                    hintStyle:
                    TextStyle(color: Colors.grey, fontSize: 15),
                    border: InputBorder.none,
                    contentPadding:
                    EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _sendMessage,
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
}

// ─────────────────────────────────────────────
// Sub-widgets
// ─────────────────────────────────────────────

class _MiniAvatar extends StatelessWidget {
  final String name;
  const _MiniAvatar({required this.name});

  Color get _color {
    final hue = (name.codeUnits.fold(0, (a, b) => a + b) % 360).toDouble();
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
        child: Text(
          _initials,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}