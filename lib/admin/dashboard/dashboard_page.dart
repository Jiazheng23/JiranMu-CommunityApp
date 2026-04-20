import 'package:flutter/material.dart';
import 'package:assignment/admin/request/admin_request_page.dart';
import '../emergency/emergency_list_page.dart';
import '../user/user_management.dart';
import '../AdminQRScannerScreen.dart';
import '../AdminVisitorPassScreen.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  // 修改了 buildCard 方法，增加了 context 和 targetPage 参数
  Widget buildCard(BuildContext context, String title, String value, Color color, Widget targetPage) {
    return InkWell(
      onTap: () {
        // 🔥 点击后通过 Navigator 跳转到对应的页面
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => targetPage),
        );
      },
      borderRadius: BorderRadius.circular(16), // 让点击波纹效果和圆角一致
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 6,
              offset: Offset(0, 3),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            Align(
              alignment: Alignment.bottomRight,
              child: Text(
                value,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildQRScannerButton(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 20),
      child: ElevatedButton.icon(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AdminQRScannerScreen()),
        ),
        icon: const Icon(Icons.qr_code_scanner),
        label: const Text("Scan Visitor Pass"),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }

  Widget buildVisitorPassButton(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12),
      child: ElevatedButton.icon(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AdminVisitorPassScreen()),
        ),
        icon: const Icon(Icons.badge_outlined),
        label: const Text("Visitor Pass Requests"),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          backgroundColor: const Color(0xFF9A4B3C),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          const Text(
            "Dashboard",
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.5,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [

              buildCard(context, "Emergency", "2", Colors.red.shade300, EmergencyListPage()),
              buildCard(context, "Requests", "27", Colors.yellow.shade300, const AdminRequestsPage()),
              buildCard(context, "Users", "950", Colors.blue.shade300, const UserManagementPage()),

              // Notices 暂时用一个简单的 Scaffold 代替，你有真实的页面可以换掉
              buildCard(context, "Notices", "8", Colors.green.shade300, Scaffold(appBar: AppBar(title: const Text("Notices")), body: const Center(child: Text("Notices Page")))),
            ],
          ),
        ],
      ),
    );
  }
}