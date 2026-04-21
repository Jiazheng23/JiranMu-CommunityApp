import 'dart:async';
import 'package:flutter/material.dart';
import '../../chat/CommunityChatsListScreen.dart';
import '../AdminCreateChatScreen.dart';
import '../emergency/location.dart';
import 'dashboard_page.dart';
import '../profile/admin_profile_page.dart';

class AdminDashboard extends StatefulWidget {
  final Map<String, dynamic> user;

  const AdminDashboard({super.key, required this.user});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int selectedIndex = 0;

  bool isWaiting = false;
  bool isEmergency = false;
  Timer? _timer;
  int countdown = 10;

  // 🔥 使用 getter 完美解决了 widget.user 的初始化报错
  List<Widget> get pages => [
    const DashboardPage(),
    const CommunityChatsListScreen(),
    AdminProfilePage(user: widget.user),
  ];

  final List<Map<String, dynamic>> navItems = [
    {'icon': Icons.home_outlined, 'label': 'Dashboard'},
    {'icon': Icons.chat_bubble_outline, 'label': 'Message'},
    {'icon': Icons.person_outline, 'label': 'Profile'},
  ];

  void resetState() {
    _timer?.cancel();
    setState(() {
      isWaiting = false;
      isEmergency = false;
      countdown = 10;
    });
  }

  void handleEmergency() {
    if (isEmergency) {
      resetState();
      return;
    }

    if (!isWaiting) {
      setState(() {
        isWaiting = true;
        countdown = 10;
      });
      StateSetter? dialogSetState;

      _timer = Timer.periodic(const Duration(seconds: 1), (t) async {
        if (countdown > 1) {
          if (mounted) {
            setState(() {
              countdown--;
            });
          }
          if (dialogSetState != null) {
            dialogSetState!(() {});
          }
        } else {
          t.cancel();

          setState(() {
            isWaiting = false;
            isEmergency = true;
          });

          if (mounted) {
            Navigator.of(context, rootNavigator: true).pop();
          }

          final userId = widget.user['id'] ?? widget.user['admin_id'];

          if (userId != null) {
            try {
              final position = await getCurrentLocation();
              await createEmergency(userId.toString(), 'SOS', position);

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Emergency SOS Sent with Location!"),
                    backgroundColor: Color(0xFF6B8E6B), // 莫兰迪绿
                  ),
                );
              }
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text("Failed to send SOS: $e"),
                    backgroundColor: const Color(0xFFC67B75), // 砖红色
                  ),
                );
              }
              resetState();
            }
          }
        }
      });

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            content: StatefulBuilder(
              builder: (context, setStepState) {
                dialogSetState = setStepState;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Color(0xFFD49A6A), size: 70), // 焦糖橙
                    const SizedBox(height: 20),
                    const Text("Confirm sending emergency notification?", textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF2B2B2B))),
                    const SizedBox(height: 25),
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 80, height: 80,
                          child: CircularProgressIndicator(
                            value: countdown / 10,
                            strokeWidth: 6,
                            backgroundColor: Colors.grey.shade200,
                            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFD49A6A)), // 焦糖橙
                          ),
                        ),
                        Text("$countdown", style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF2B2B2B))),
                      ],
                    ),
                    const SizedBox(height: 30),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF8B5E4A),
                          side: const BorderSide(color: Color(0xFF8B5E4A)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () {
                          resetState();
                          Navigator.pop(context);
                        },
                        child: const Text("Cancel Emergency"),
                      ),
                    ),
                  ],
                );
              },
            ),
          );
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor: const Color(0xFFF5EBE6), // 🔥 统一的浅米棕色背景
      body: SafeArea(child: pages[selectedIndex]),

      floatingActionButton: SizedBox(
        width: 65,
        height: 65,
        child: FloatingActionButton(
          onPressed: () {
            if (selectedIndex == 1) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AdminCreateChatScreen(),
                ),
              );
            } else {
              handleEmergency();
            }
          },
          backgroundColor: selectedIndex == 1
              ? const Color(0xFF9A4B3C)
              : (isEmergency
              ? Colors.red
              : (isWaiting ? Colors.orange : Colors.red)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(60),
          ),
          elevation: 4,
          child: Icon(
            selectedIndex == 1
                ? Icons.add
                : (isEmergency
                ? Icons.warning
                : (isWaiting ? Icons.access_time : Icons.add)),
            size: 30,
            color: Colors.white,
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,

      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(left: 15, right: 15, bottom: 15),
          child: Container(
            height: 70,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(35),
              boxShadow: [
                // 🔥 阴影带有一点点温暖的棕色调
                BoxShadow(color: const Color(0xFF8B5E4A).withOpacity(0.08), blurRadius: 20, spreadRadius: 5, offset: const Offset(0, 5)),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(navItems.length, (index) {
                return _buildNavItem(navItems[index]['icon'], navItems[index]['label'], index);
              }),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
    bool isSelected = selectedIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          selectedIndex = index;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(horizontal: isSelected ? 12 : 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF8B5E4A) : Colors.transparent, // 🔥 选中背景：深棕色
          borderRadius: BorderRadius.circular(25),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: isSelected ? Colors.white : Colors.grey.shade400, size: 26), // 🔥 未选中图标：柔和灰
            if (isSelected)
              Padding(
                padding: const EdgeInsets.only(left: 6.0),
                child: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}