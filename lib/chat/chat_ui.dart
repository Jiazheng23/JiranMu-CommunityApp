// import 'package:flutter/material.dart';
//
// /// -----------------------------
// /// Message Model
// /// -----------------------------
// class Message {
//   final String senderName;
//   final String text;
//   final DateTime timestamp;
//   final bool isMe;
//   final bool isManager;
//
//   Message({
//     required this.senderName,
//     required this.text,
//     required this.timestamp,
//     required this.isMe,
//     this.isManager = false,
//   });
// }
//
// /// -----------------------------
// /// User Status Model
// /// -----------------------------
// class UserStatus {
//   final String name;
//   final String imageUrl;
//   final bool isMe;
//   final bool hasStory;
//
//   UserStatus({
//     required this.name,
//     required this.imageUrl,
//     this.isMe = false,
//     this.hasStory = false,
//   });
// }
//
// /// -----------------------------
// /// Chat Room Model
// /// -----------------------------
// class ChatRoom {
//   final String id;
//   final String name;
//   final String lastMessage;
//   final DateTime lastMessageTime;
//   final int unreadCount;
//   final bool isGroup;
//   final String? avatarUrl;
//   final bool isOnline;
//
//   ChatRoom({
//     required this.id,
//     required this.name,
//     required this.lastMessage,
//     required this.lastMessageTime,
//     this.unreadCount = 0,
//     required this.isGroup,
//     this.avatarUrl,
//     this.isOnline = false,
//   });
// }
//
// /// -----------------------------
// /// Helper: Format Time for Messages
// /// -----------------------------
// String formatTime(DateTime time) {
//   final hour = time.hour > 12
//       ? time.hour - 12
//       : (time.hour == 0 ? 12 : time.hour);
//   final minute = time.minute.toString().padLeft(2, '0');
//   final amPm = time.hour >= 12 ? 'PM' : 'AM';
//   return '$hour:$minute $amPm';
// }