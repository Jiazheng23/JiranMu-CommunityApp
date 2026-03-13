import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

final supabase = Supabase.instance.client;

class CommunityChatScreen extends StatefulWidget {
  final String roomId;
  final String communityName;
  final String currentUser;

  const CommunityChatScreen({
    Key? key,
    required this.roomId,
    required this.communityName,
    required this.currentUser,
  }) : super(key: key);

  @override
  State<CommunityChatScreen> createState() => _CommunityChatScreenState();
}

class _CommunityChatScreenState extends State<CommunityChatScreen> {
  final TextEditingController _controller = TextEditingController();
  List<Message> _messages = [];
  RealtimeChannel? _subscription;

  @override
  void initState() {
    super.initState();
    fetchMessages();
    setupRealtime();
  }

  @override
  void dispose() {
    _subscription?.unsubscribe();
    super.dispose();
  }

  Future<void> fetchMessages() async {
    final data = await supabase
        .from('messages')
        .select()
        .eq('room_id', widget.roomId)
        .order('created_at', ascending: true);

    setState(() {
      _messages = data.map<Message>((msg) {
        return Message(
          senderName: msg['sender'],
          text: msg['content'],
          timestamp: DateTime.parse(msg['created_at']),
          isMe: msg['sender'] == widget.currentUser,
        );
      }).toList();
    });
  }

  void setupRealtime() {
    _subscription = supabase
        .channel('public:messages')
        .onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'messages',
      callback: (payload) {
        final msg = payload.newRecord;
        if (msg['room_id'] != widget.roomId) return;

        setState(() {
          _messages.add(Message(
            senderName: msg['sender'],
            text: msg['content'],
            timestamp: DateTime.parse(msg['created_at']),
            isMe: msg['sender'] == widget.currentUser,
          ));
          _messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
        });
      },
    )
        .subscribe();
  }

  Future<void> sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    await supabase.from('messages').insert({
      'id': const Uuid().v4(),
      'room_id': widget.roomId,
      'sender': widget.currentUser,
      'content': text,
      'created_at': DateTime.now().toIso8601String(),
    });

    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.communityName), backgroundColor: Colors.teal),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                return Align(
                  alignment: msg.isMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: msg.isMe ? Colors.teal : Colors.grey[200],
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(msg.text,
                        style: TextStyle(color: msg.isMe ? Colors.white : Colors.black87)),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                        hintText: "Message the community...",
                        border: OutlineInputBorder()),
                  ),
                ),
                IconButton(icon: const Icon(Icons.send), onPressed: sendMessage)
              ],
            ),
          )
        ],
      ),
    );
  }
}

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