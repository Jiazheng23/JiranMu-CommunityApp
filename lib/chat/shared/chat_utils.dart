import 'package:flutter/material.dart';

// All functions are public (no underscore prefix)

String formatTimestamp(DateTime dt) {
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

// Slightly different from formatTimestamp — used in chat list
// shows "X min", "X hr", "X days" instead of HH:MM
String formatChatListTime(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 1) return 'now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min';
  if (diff.inHours < 24) return '${diff.inHours} hr';
  if (diff.inDays == 1) return '1 day';
  return '${diff.inDays} days';
}

Color avatarColorFromName(String name) {
  final hue = (name.codeUnits.fold(0, (a, b) => a + b) % 360).toDouble();
  return HSLColor.fromAHSL(1, hue, 0.5, 0.55).toColor();
}

String initialsFromName(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts[0][0].toUpperCase();
  return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
}