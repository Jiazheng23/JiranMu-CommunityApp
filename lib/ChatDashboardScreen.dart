import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'CommunityChatScreen.dart';

final supabase = Supabase.instance.client;

class ChatDashboardScreen extends StatefulWidget {
  final String currentUser;

  const ChatDashboardScreen({Key? key, required this.currentUser}) : super(key: key);

  @override
  State<ChatDashboardScreen> createState() => _ChatDashboardScreenState();
}

class _ChatDashboardScreenState extends State<ChatDashboardScreen> {
  List<ChatRoom> _chatRooms = [];
  RealtimeChannel? _subscription;

  @override
  void initState() {
    super.initState();
    fetchChatRooms();
    setupRealtime();
  }

  @override
  void dispose() {
    _subscription?.unsubscribe();
    super.dispose();
  }

  Future<void> fetchChatRooms() async {
    final data = await supabase
        .from('messages')
        .select()
        .order('created_at', ascending: true);

    final Map<String, ChatRoom> roomMap = {};

    for (var msg in data) {
      final roomId = msg['room_id'];
      if (!roomMap.containsKey(roomId)) {
        roomMap[roomId] = ChatRoom(
          id: roomId,
          name: roomId == 'community_chat' ? 'Condo Community' : roomId,
          lastMessage: msg['content'],
          lastMessageTime: DateTime.parse(msg['created_at']),
          isGroup: true,
          avatarUrl: roomId == 'community_chat'
              ? 'https://images.unsplash.com/photo-1522071820081-009f0129c71c?w=150'
              : null,
        );
      } else {
        // Keep latest message
        final current = DateTime.parse(msg['created_at']);
        if (current.isAfter(roomMap[roomId]!.lastMessageTime)) {
          roomMap[roomId] = roomMap[roomId]!.copyWith(
            lastMessage: msg['content'],
            lastMessageTime: current,
          );
        }
      }
    }

    setState(() {
      _chatRooms = roomMap.values.toList();
      _chatRooms.sort((a, b) => b.lastMessageTime.compareTo(a.lastMessageTime));
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
        final roomId = msg['room_id'];
        final createdAt = DateTime.parse(msg['created_at']);

        final roomIndex = _chatRooms.indexWhere((r) => r.id == roomId);
        if (roomIndex != -1) {
          setState(() {
            _chatRooms[roomIndex] = _chatRooms[roomIndex].copyWith(
              lastMessage: msg['content'],
              lastMessageTime: createdAt,
            );
            _chatRooms.sort((a, b) => b.lastMessageTime.compareTo(a.lastMessageTime));
          });
        } else {
          setState(() {
            _chatRooms.add(ChatRoom(
              id: roomId,
              name: roomId == 'community_chat' ? 'Condo Community' : roomId,
              lastMessage: msg['content'],
              lastMessageTime: createdAt,
              isGroup: true,
            ));
            _chatRooms.sort((a, b) => b.lastMessageTime.compareTo(a.lastMessageTime));
          });
        }
      },
    )
        .subscribe();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Chats',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w600,
                      )),
                ],
              ),
            ),
            Expanded(
              child: _chatRooms.isEmpty
                  ? const Center(child: Text("No chats yet"))
                  : ListView.builder(
                itemCount: _chatRooms.length,
                itemBuilder: (context, index) {
                  final room = _chatRooms[index];
                  return ListTile(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CommunityChatScreen(
                            roomId: room.id,
                            communityName: room.name,
                            currentUser: widget.currentUser,
                          ),
                        ),
                      );
                    },
                    leading: room.avatarUrl != null
                        ? CircleAvatar(
                      backgroundImage: NetworkImage(room.avatarUrl!),
                    )
                        : CircleAvatar(child: Text(room.name[0])),
                    title: Text(room.name),
                    subtitle: Text(room.lastMessage),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ChatRoom {
  final String id;
  final String name;
  final String lastMessage;
  final DateTime lastMessageTime;
  final bool isGroup;
  final String? avatarUrl;

  ChatRoom({
    required this.id,
    required this.name,
    required this.lastMessage,
    required this.lastMessageTime,
    this.isGroup = true,
    this.avatarUrl,
  });

  ChatRoom copyWith({String? lastMessage, DateTime? lastMessageTime}) {
    return ChatRoom(
      id: id,
      name: name,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      isGroup: isGroup,
      avatarUrl: avatarUrl,
    );
  }
}