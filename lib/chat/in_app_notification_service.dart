import 'dart:async';
import 'package:flutter/material.dart';

class InAppNotification {
  final String title;
  final String body;
  final String roomId;
  final VoidCallback? onTap;

  InAppNotification({
    required this.title,
    required this.body,
    required this.roomId,
    this.onTap,
  });
}

class InAppNotificationService extends ChangeNotifier {
  static final InAppNotificationService instance = InAppNotificationService._();
  InAppNotificationService._();

  InAppNotification? _current;
  Timer? _dismissTimer;
  static String? activeRoomId;

  InAppNotification? get current => _current;

  void show(InAppNotification notification) {
    if (activeRoomId != null && activeRoomId == notification.roomId) return;

    _dismissTimer?.cancel();
    _current = notification;
    notifyListeners();

    _dismissTimer = Timer(const Duration(seconds: 4), dismiss);
  }

  void dismiss() {
    _current = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    super.dispose();
  }
}