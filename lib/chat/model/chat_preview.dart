import 'package:flutter/material.dart';

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