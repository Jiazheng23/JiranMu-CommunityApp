import 'dart:async';
import 'package:flutter/material.dart';
import 'package:assignment/admin/AdminCreateChatScreen.dart';
import 'package:assignment/admin/request/admin_request_page.dart';
import '../../chat/CommunityChatsListScreen.dart';
import '../emergency/emergency_list_page.dart';
import '../user/user_management.dart';
import 'dashboard_page.dart';

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

  final List<Widget> pages = [
    const AdminProfilePage(),
    const UserManagementPage(),
    const AdminRequestsPage(),
    const CommunityChatsListScreen(),
    EmergencyListPage(),
  ];

  final List<Map<String, dynamic>> navItems = [
    {'icon': Icons.home_outlined, 'label': 'Dashboard'},
    {'icon': Icons.person_outline, 'label': 'Users'},
    {'icon': Icons.file_copy_outlined, 'label': 'Requests'},
    {'icon': Icons.chat_bubble_outline, 'label': 'Chat'},
    {'icon': Icons.warning_amber_rounded, 'label': 'Alerts'},
  ];

  void resetState() {
    _timer?.cancel();

    if (!mounted) return;

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

    if (isWaiting) return;

    setState(() {
      isWaiting = true;
      countdown = 10;
    });

    StateSetter? dialogSetState;

    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }

      if (countdown > 1) {
        setState(() => countdown--);
        dialogSetState?.call(() {});
      } else {
        t.cancel();

        setState(() {
          isWaiting = false;
          isEmergency = true;
        });

        if (Navigator.of(context).canPop()) {
          Navigator.of(context, rootNavigator: true).pop();
        }
      }
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          content: StatefulBuilder(
            builder: (context, setStepState) {
              dialogSetState = setStepState;

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.orange,
                    size: 70,
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "Confirm sending emergency notification?",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 25),
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 80,
                        height: 80,
                        child: CircularProgressIndicator(
                          value: countdown / 10,
                          strokeWidth: 6,
                          backgroundColor: Colors.grey.shade200,
                          valueColor:
                          const AlwaysStoppedAnimation<Color>(Colors.orange),
                        ),
                      ),
                      Text(
                        "$countdown",
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor: const Color(0xFFF0F0F5),
      body: pages[selectedIndex],

      floatingActionButton: SizedBox(
        width: 65,
        height: 65,
        child: FloatingActionButton(
          onPressed: () {
            if (selectedIndex == 3) {
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
          backgroundColor: selectedIndex == 3
              ? const Color(0xFF9A4B3C)
              : (isEmergency
              ? Colors.red
              : (isWaiting ? Colors.orange : Colors.red)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(60),
          ),
          elevation: 4,
          child: Icon(
            selectedIndex == 3
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
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 20,
                  spreadRadius: 5,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(navItems.length, (index) {
                return _buildNavItem(
                  navItems[index]['icon'],
                  navItems[index]['label'],
                  index,
                );
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
        padding: EdgeInsets.symmetric(
          horizontal: isSelected ? 10 : 12,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1E88E5) : Colors.transparent,
          borderRadius: BorderRadius.circular(25),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : Colors.black54,
              size: 26,
            ),
            if (isSelected)
              Padding(
                padding: const EdgeInsets.only(left: 3.0),
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
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