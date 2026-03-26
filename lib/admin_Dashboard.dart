import 'dart:async';
import 'package:flutter/material.dart';
import 'dashboard_page.dart';
import 'admin_emergency_page.dart';


class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

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
    DashboardPage(),
    Center(child: Text("Requests")),
    Center(child: Text("Users")),
    Center(child: Text("Notices")),
    AdminEmergencyPage(profile: const {}),
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

      _timer = Timer.periodic(const Duration(seconds: 1), (t) {
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
              isEmergency = true; // 进入紧急状态
            });
            if (mounted) {
              Navigator.of(context, rootNavigator: true).pop(); // 关闭弹窗
            }
        }
      });

      // 2. 显示弹窗
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            content: StatefulBuilder( // 使用 StatefulBuilder 包裹弹窗内容
              builder: (context, setStepState) {
                // 把内部刷新函数赋给外部变量
                dialogSetState = setStepState;

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 70),
                    const SizedBox(height: 20),
                    const Text("Confirm sending emergency notification?", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    const SizedBox(height: 25),

                    // 倒计时进度圆圈
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 80,
                          height: 80,
                          child: CircularProgressIndicator(
                            value: countdown / 10, // 进度条根据秒数变化
                            strokeWidth: 6,
                            backgroundColor: Colors.grey.shade200,
                            valueColor: const AlwaysStoppedAnimation<Color>(Colors.orange),
                          ),
                        ),
                        Text(
                          "$countdown",
                          style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),

                    const SizedBox(height: 30),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () {
                          resetState(); // 取消计时并重置
                          Navigator.pop(context);
                        },
                        child: const Text("Cancel Emergency"),
                      ),
                    )
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
      body: pages[selectedIndex],

      floatingActionButton: SizedBox(
        width: 70,
        height: 70,
        child: FloatingActionButton(
          onPressed: handleEmergency,

          backgroundColor: isEmergency
              ? Colors.red
              : (isWaiting ? Colors.orange : Colors.red),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(60),
          ),
          child: Icon(
            isEmergency
                ? Icons.warning
                : (isWaiting ? Icons.access_time : Icons.add),
            size: 30,
          ),
        ),
      ),

      floatingActionButtonLocation:
      FloatingActionButtonLocation.endFloat,

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: selectedIndex,

        onTap: (index) {
          setState(() {
            selectedIndex = index;
          });
        },

        type: BottomNavigationBarType.fixed,

        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Dashboard"),
          BottomNavigationBarItem(
            icon: Icon(Icons.file_copy),
            label: "Requests",
          ),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "Users"),
          BottomNavigationBarItem(
            icon: Icon(Icons.notifications),
            label: "Notices",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.emergency),
            label: "Emergency",
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
