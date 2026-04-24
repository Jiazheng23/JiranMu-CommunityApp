import 'package:assignment/chat/resident/resident_chatlist_screen.dart';
import 'package:flutter/material.dart';
import 'package:assignment/chat/user_session.dart';
import 'admin/admin_chatlist_screen.dart';

class CommunityChatsListScreen extends StatefulWidget {
  const CommunityChatsListScreen({Key? key}) : super(key: key);

  @override
  State<CommunityChatsListScreen> createState() =>
      CommunityChatsListScreenState();
}

class CommunityChatsListScreenState
    extends State<CommunityChatsListScreen> {
  bool _loading = true;
  bool _isAdmin = false;
  Key _childKey = UniqueKey();

  @override
  void initState() {
    super.initState();
    _initSession();
  }

  Future<void> _initSession() async {
    await UserSession.init();
    if (mounted) {
      setState(() {
        _isAdmin = UserSession.isAdmin;
        _loading = false;
      });
    }
  }

  void refresh() {
    if (mounted) setState(() => _childKey = UniqueKey());
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF5F1ED),
        body: Center(
          child: CircularProgressIndicator(
            color: Color(0xFF9A4B3C),
          ),
        ),
      );
    }

    return _isAdmin
        ? AdminChatsListScreen(key: ValueKey('admin_${UserSession.uid}'))
        : ResidentChatsListScreen(
        key: ValueKey('resident_${UserSession.uid}'));
  }
}