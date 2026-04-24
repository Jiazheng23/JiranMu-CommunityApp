import 'package:flutter/material.dart';

// ─────────────────────────────────────────────
// Models
// ─────────────────────────────────────────────

class ResidentProfile {
  final String id;
  final String name;
  final String block;
  final String email;

  ResidentProfile({
    required this.id,
    required this.name,
    required this.block,
    required this.email,
  });

  factory ResidentProfile.fromMap(Map<String, dynamic> map) => ResidentProfile(
    id: map['id']?.toString() ?? '',
    name: map['full_name']?.toString() ?? 'Unknown',
    block: map['block']?.toString() ?? '',
    email: map['email']?.toString() ?? '',
  );

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  String get firstName => name.trim().split(RegExp(r'\s+')).first;

  Color get avatarColor {
    final hue = (name.codeUnits.fold(0, (a, b) => a + b) % 360).toDouble();
    return HSLColor.fromAHSL(1, hue, 0.55, 0.55).toColor();
  }
}

class ConversationPreview {
  final ResidentProfile resident;
  final String lastMessage;
  final DateTime lastTime;
  final int unreadCount;
  final String roomId;

  ConversationPreview({
    required this.resident,
    required this.lastMessage,
    required this.lastTime,
    required this.roomId,
    int? unreadCount,
  }) : unreadCount = unreadCount ?? 0;
}

class GroupChatPreview {
  final String groupId;
  final String roomId;
  final String name;
  final String block;
  final String lastMessage;
  final DateTime lastTime;
  final int unreadCount;

  GroupChatPreview({
    required this.groupId,
    required this.roomId,
    required this.name,
    required this.block,
    required this.lastMessage,
    required this.lastTime,
    int? unreadCount,
  }) : unreadCount = unreadCount ?? 0;
}

// ─────────────────────────────────────────────
// Shared colour / text helpers
// ─────────────────────────────────────────────

Color chatAvatarColor(String name) {
  final hue = (name.codeUnits.fold(0, (a, b) => a + b) % 360).toDouble();
  return HSLColor.fromAHSL(1, hue, 0.55, 0.55).toColor();
}

String chatInitials(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts[0][0].toUpperCase();
  return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
}

// ─────────────────────────────────────────────
// GroupChatTile
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
          border: hasUnread
              ? Border(left: BorderSide(color: primaryColor, width: 4))
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [primaryColor, primaryColor.withOpacity(0.7)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: Text(
                  group.block,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 17),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  HighlightText(
                    text: group.name,
                    query: searchQuery,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight:
                      hasUnread ? FontWeight.w800 : FontWeight.w700,
                      color: const Color(0xFF2B2B2B),
                    ),
                    highlightColor: primaryColor,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    group.lastMessage,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      color: hasUnread
                          ? const Color(0xFF2B2B2B)
                          : Colors.black45,
                      fontWeight:
                      hasUnread ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  formatTime(group.lastTime),
                  style: TextStyle(
                    fontSize: 12,
                    color: hasUnread ? primaryColor : Colors.black38,
                    fontWeight:
                    hasUnread ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
                if (hasUnread) ...[
                  const SizedBox(height: 5),
                  Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                        color: primaryColor, shape: BoxShape.circle),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// ConversationTile
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
          border: hasUnread
              ? Border(left: BorderSide(color: primaryColor, width: 4))
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    resident.avatarColor,
                    resident.avatarColor.withOpacity(0.7),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: Text(
                  resident.initials,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 17),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  HighlightText(
                    text: resident.name,
                    query: searchQuery,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight:
                      hasUnread ? FontWeight.w800 : FontWeight.w700,
                      color: const Color(0xFF2B2B2B),
                    ),
                    highlightColor: primaryColor,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    preview.lastMessage,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      color: hasUnread
                          ? const Color(0xFF2B2B2B)
                          : Colors.black45,
                      fontWeight:
                      hasUnread ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  formatTime(preview.lastTime),
                  style: TextStyle(
                    fontSize: 12,
                    color: hasUnread ? primaryColor : Colors.black38,
                    fontWeight:
                    hasUnread ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
                if (hasUnread) ...[
                  const SizedBox(height: 5),
                  Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                        color: primaryColor, shape: BoxShape.circle),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// HighlightText
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
      return Text(text,
          style: style, maxLines: 1, overflow: TextOverflow.ellipsis);
    }
    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();
    final matchIndex = lowerText.indexOf(lowerQuery);
    if (matchIndex == -1) {
      return Text(text,
          style: style, maxLines: 1, overflow: TextOverflow.ellipsis);
    }
    return RichText(
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        style: style,
        children: [
          if (matchIndex > 0) TextSpan(text: text.substring(0, matchIndex)),
          TextSpan(
            text: text.substring(matchIndex, matchIndex + query.length),
            style: style.copyWith(
                color: highlightColor, fontWeight: FontWeight.w900),
          ),
          if (matchIndex + query.length < text.length)
            TextSpan(text: text.substring(matchIndex + query.length)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// NeighbourCard
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
        child: Column(
          children: [
            Stack(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        profile.avatarColor,
                        profile.avatarColor.withOpacity(0.7),
                      ],
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
                  child: Center(
                    child: Text(
                      profile.initials,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 18),
                    ),
                  ),
                ),
                if (isOnline)
                  Positioned(
                    bottom: 1,
                    right: 1,
                    child: Container(
                      width: 13,
                      height: 13,
                      decoration: BoxDecoration(
                        color: const Color(0xFF22C55E),
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: const Color(0xFFF5F1ED), width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              profile.firstName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2B2B2B)),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// CountBadge
// ─────────────────────────────────────────────

class CountBadge extends StatelessWidget {
  final int count;
  final Color color;
  const CountBadge({Key? key, required this.count, required this.color})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$count',
        style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// FabOption (admin only)
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
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(label,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 10),
          Container(
            width: 44,
            height: 44,
            decoration:
            BoxDecoration(color: color.withOpacity(0.85), shape: BoxShape.circle),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Shared profile header widget
// ─────────────────────────────────────────────

class ChatProfileHeader extends StatelessWidget {
  final String name;
  final String subtitle;
  static const Color _textDark = Color(0xFF2B2B2B);

  const ChatProfileHeader({
    Key? key,
    required this.name,
    required this.subtitle,
  }) : super(key: key);

  String _getInitials(String n) {
    final parts = n.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final displayName = name.isNotEmpty ? name : 'Hello';
    final avatarColor = chatAvatarColor(displayName);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [avatarColor, avatarColor.withOpacity(0.7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Center(
              child: Text(
                _getInitials(displayName),
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 15),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(displayName,
                    style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: _textDark)),
                Text(subtitle,
                    style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black45,
                        fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Shared search bar widget
// ─────────────────────────────────────────────

class ChatSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool isActive;
  final String searchQuery;
  final VoidCallback onTap;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onClear;
  static const Color _primary = Color(0xFF9A4B3C);
  static const Color _textDark = Color(0xFF2B2B2B);

  const ChatSearchBar({
    Key? key,
    required this.controller,
    required this.hint,
    required this.isActive,
    required this.searchQuery,
    required this.onTap,
    required this.onChanged,
    required this.onSubmitted,
    required this.onClear,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 4, 22, 4),
      child: Container(
        height: 53,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isActive ? _primary.withOpacity(0.5) : Colors.transparent,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: TextField(
          controller: controller,
          onTap: onTap,
          onChanged: onChanged,
          onSubmitted: onSubmitted,
          style: const TextStyle(fontSize: 14, color: _textDark),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.black38, fontSize: 14),
            prefixIcon:
            const Icon(Icons.search_rounded, color: Colors.black38, size: 20),
            suffixIcon: searchQuery.isNotEmpty
                ? GestureDetector(
              onTap: onClear,
              child: const Icon(Icons.close_rounded,
                  color: Colors.black38, size: 18),
            )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 10),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Error / empty states
// ─────────────────────────────────────────────

class ChatErrorState extends StatelessWidget {
  final String? message;
  final VoidCallback onRetry;
  static const Color _primary = Color(0xFF9A4B3C);

  const ChatErrorState({Key? key, this.message, required this.onRetry})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 56, color: Colors.redAccent),
            const SizedBox(height: 16),
            const Text('Something went wrong',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2B2B2B))),
            const SizedBox(height: 8),
            Text(message ?? '',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: Colors.black45)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12))),
            ),
          ],
        ),
      ),
    );
  }
}

class ChatUnknownRoleState extends StatelessWidget {
  final String userId;
  final String role;
  final VoidCallback onRetry;
  static const Color _primary = Color(0xFF9A4B3C);

  const ChatUnknownRoleState({
    Key? key,
    required this.userId,
    required this.role,
    required this.onRetry,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.person_off_outlined, size: 56, color: Colors.black38),
            const SizedBox(height: 16),
            const Text('Account not recognised',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2B2B2B))),
            const SizedBox(height: 8),
            Text('UID: $userId\nRole: $role',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: Colors.black45)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12))),
            ),
          ],
        ),
      ),
    );
  }
}