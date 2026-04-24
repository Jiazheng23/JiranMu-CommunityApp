import 'package:supabase_flutter/supabase_flutter.dart';

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

class Message {
  final String id;
  final String senderName;
  final String senderRaw;
  final String text;
  final DateTime timestamp;
  final bool isMe;
  final bool isPoll;
  final String? pollId;
  final bool isAnnouncement;
  final bool isEventInvite;
  final String? replyToId;
  final String? replyToSender;
  final String? replyToText;
  final List<String> mentionedUsers;

  Message({
    required this.id,
    required this.senderName,
    required this.senderRaw,
    required this.text,
    required this.timestamp,
    required this.isMe,
    this.isPoll = false,
    this.pollId,
    this.isAnnouncement = false,
    this.isEventInvite = false,
    this.replyToId,
    this.replyToSender,
    this.replyToText,
    this.mentionedUsers = const [],
  });

  bool mentions(String displayName) =>
      mentionedUsers.any((m) => m.toLowerCase() == displayName.toLowerCase());
}