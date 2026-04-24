import 'package:flutter/material.dart';
import '../CommunityChatsListScreen.dart';
import '../chat_shared_widget.dart';
import 'chat_utils.dart';

// ─────────────────────────────────────────────
// Mini Avatar
// ─────────────────────────────────────────────

class MiniAvatar extends StatelessWidget {
  final String name;
  const MiniAvatar({Key? key, required this.name}) : super(key: key);

  @override
  Widget build(BuildContext context) => Container(
    width: 28,
    height: 28,
    decoration: BoxDecoration(
      color: avatarColorFromName(name),
      shape: BoxShape.circle,
    ),
    child: Center(
      child: Text(
        initialsFromName(name),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
  );
}

// ─────────────────────────────────────────────
// Swipe to Reply
// ─────────────────────────────────────────────

class SwipeToReply extends StatefulWidget {
  final bool isMe;
  final VoidCallback onReply;
  final Widget child;

  const SwipeToReply({
    Key? key,
    required this.isMe,
    required this.onReply,
    required this.child,
  }) : super(key: key);

  @override
  State<SwipeToReply> createState() => _SwipeToReplyState();
}

class _SwipeToReplyState extends State<SwipeToReply>
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
    )..addListener(() => setState(() => _offset = _snapFrom * (1 - _snapCtrl.value)));
  }

  @override
  void dispose() {
    _snapCtrl.dispose();
    super.dispose();
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    final effective = widget.isMe ? -details.delta.dx : details.delta.dx;
    if (effective < 0) return;
    setState(() {
      _offset = _offset < _maxDrag / 2
          ? (_offset + effective).clamp(0, _maxDrag)
          : (_offset + effective * 0.3).clamp(0, _maxDrag);
      if (_offset >= _triggerThreshold && !_triggered) _triggered = true;
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
      child: Stack(clipBehavior: Clip.none, children: [
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
                child: const Icon(Icons.reply_rounded, color: _primary, size: 18),
              ),
            ),
          ),
        ),
        Transform.translate(offset: Offset(dx, 0), child: widget.child),
      ]),
    );
  }
}

// ─────────────────────────────────────────────
// Group Members Screen
// ─────────────────────────────────────────────

class GroupMembersScreen extends StatelessWidget {
  final List<String> members;
  const GroupMembersScreen({Key? key, required this.members}) : super(key: key);

  static const Color _primary = Color(0xFF9A4B3C);
  static const Color _bgPage = Color(0xFFF5F1ED);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgPage,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black87, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Group Members',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
      ),
      body: members.isEmpty
          ? const Center(child: Text('No members found.',
          style: TextStyle(color: Colors.grey, fontSize: 14)))
          : Column(children: [
        Container(
          width: double.infinity,
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Text(
            '${members.length} member${members.length == 1 ? '' : 's'}',
            style: const TextStyle(
              color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            itemCount: members.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final name = members[index];
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                child: Row(children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: avatarColorFromName(name),
                    child: Text(initialsFromName(name),
                      style: const TextStyle(
                        color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(child: Text(name,
                    style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black87,
                    ),
                  )),
                ]),
              );
            },
          ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────
// Highlight Text
// ─────────────────────────────────────────────

class HighlightText extends StatelessWidget {
  final String text;
  final String query;
  final TextStyle style;
  final Color highlightColor;

  const HighlightText({
    Key? key,
    required this.text,
    required this.query,
    required this.style,
    required this.highlightColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (query.isEmpty) {
      return Text(text, style: style, maxLines: 1, overflow: TextOverflow.ellipsis);
    }
    final lowerText = text.toLowerCase();
    final matchIndex = lowerText.indexOf(query.toLowerCase());
    if (matchIndex == -1) {
      return Text(text, style: style, maxLines: 1, overflow: TextOverflow.ellipsis);
    }
    return RichText(
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(style: style, children: [
        if (matchIndex > 0)
          TextSpan(text: text.substring(0, matchIndex)),
        TextSpan(
          text: text.substring(matchIndex, matchIndex + query.length),
          style: style.copyWith(color: highlightColor, fontWeight: FontWeight.w900),
        ),
        if (matchIndex + query.length < text.length)
          TextSpan(text: text.substring(matchIndex + query.length)),
      ]),
    );
  }
}

// ─────────────────────────────────────────────
// Count Badge
// ─────────────────────────────────────────────

class CountBadge extends StatelessWidget {
  final int count;
  final Color color;

  const CountBadge({Key? key, required this.count, required this.color}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text('$count',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
    );
  }
}

// ─────────────────────────────────────────────
// FAB Option
// ─────────────────────────────────────────────

class FabOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const FabOption({
    Key? key,
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.black87,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(label,
              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
        ),
        const SizedBox(width: 10),
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(color: color.withOpacity(0.85), shape: BoxShape.circle),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────
// Neighbour Card
// ─────────────────────────────────────────────

class NeighbourCard extends StatelessWidget {
  final ResidentProfile profile;
  final Color primaryColor;
  final bool isOnline;
  final VoidCallback onTap;

  const NeighbourCard({
    Key? key,
    required this.profile,
    required this.primaryColor,
    required this.isOnline,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 64,
        child: Column(children: [
          Stack(children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [profile.avatarColor, profile.avatarColor.withOpacity(0.7)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(17),
                boxShadow: [
                  BoxShadow(
                    color: profile.avatarColor.withOpacity(0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Center(child: Text(profile.initials,
                style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18,
                ),
              )),
            ),
            if (isOnline)
              Positioned(
                bottom: 1, right: 1,
                child: Container(
                  width: 13, height: 13,
                  decoration: BoxDecoration(
                    color: const Color(0xFF22C55E),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFF5F1ED), width: 2),
                  ),
                ),
              ),
          ]),
          const SizedBox(height: 6),
          Text(profile.firstName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF2B2B2B),
            ),
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Group Chat Tile
// ─────────────────────────────────────────────

class GroupChatTile extends StatelessWidget {
  final GroupChatPreview group;
  final Color primaryColor;
  final String Function(DateTime) formatTime;
  final bool isAdmin;
  final String searchQuery;
  final VoidCallback onTap;

  const GroupChatTile({
    Key? key,
    required this.group,
    required this.primaryColor,
    required this.formatTime,
    required this.isAdmin,
    required this.searchQuery,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final hasUnread = group.unreadCount > 0;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
          ],
        ),
        child: Row(children: [
          Container(
            width: 50, height: 50,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [primaryColor, primaryColor.withOpacity(0.7)],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(child: Text(group.block,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17))),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            HighlightText(
              text: group.name, query: searchQuery,
              style: TextStyle(fontSize: 15,
                  fontWeight: hasUnread ? FontWeight.w800 : FontWeight.w700,
                  color: const Color(0xFF2B2B2B)),
              highlightColor: primaryColor,
            ),
            const SizedBox(height: 3),
            Text(group.lastMessage, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13,
                    color: hasUnread ? const Color(0xFF2B2B2B) : Colors.black45,
                    fontWeight: hasUnread ? FontWeight.w600 : FontWeight.w400)),
          ])),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(formatTime(group.lastTime),
                style: TextStyle(fontSize: 12,
                    color: hasUnread ? primaryColor : Colors.black38,
                    fontWeight: hasUnread ? FontWeight.w600 : FontWeight.w400)),
            if (hasUnread) ...[
              const SizedBox(height: 5),
              Container(width: 9, height: 9,
                  decoration: BoxDecoration(color: primaryColor, shape: BoxShape.circle)),
            ],
          ]),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Conversation Tile
// ─────────────────────────────────────────────

class ConversationTile extends StatelessWidget {
  final ConversationPreview preview;
  final Color primaryColor;
  final Color accentColor;
  final String Function(DateTime) formatTime;
  final String searchQuery;
  final VoidCallback onTap;

  const ConversationTile({
    Key? key,
    required this.preview,
    required this.primaryColor,
    required this.accentColor,
    required this.formatTime,
    required this.searchQuery,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final resident = preview.resident;
    final hasUnread = preview.unreadCount > 0;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
          ],
        ),
        child: Row(children: [
          Container(
            width: 50, height: 50,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [resident.avatarColor, resident.avatarColor.withOpacity(0.7)],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(child: Text(resident.initials,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17))),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            HighlightText(
              text: resident.name, query: searchQuery,
              style: TextStyle(fontSize: 15,
                  fontWeight: hasUnread ? FontWeight.w800 : FontWeight.w700,
                  color: const Color(0xFF2B2B2B)),
              highlightColor: primaryColor,
            ),
            const SizedBox(height: 3),
            Text(preview.lastMessage, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13,
                    color: hasUnread ? const Color(0xFF2B2B2B) : Colors.black45,
                    fontWeight: hasUnread ? FontWeight.w600 : FontWeight.w400)),
          ])),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(formatTime(preview.lastTime),
                style: TextStyle(fontSize: 12,
                    color: hasUnread ? primaryColor : Colors.black38,
                    fontWeight: hasUnread ? FontWeight.w600 : FontWeight.w400)),
            if (hasUnread) ...[
              const SizedBox(height: 5),
              Container(width: 9, height: 9,
                  decoration: BoxDecoration(color: primaryColor, shape: BoxShape.circle)),
            ],
          ]),
        ]),
      ),
    );
  }
}