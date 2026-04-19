import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../emergency/admin_emergency_page.dart';

class EmergencyListPage extends StatefulWidget {
  const EmergencyListPage({super.key});

  @override
  State<EmergencyListPage> createState() => _EmergencyListPageState();
}

class _EmergencyListPageState extends State<EmergencyListPage> {
  final supabase = Supabase.instance.client;

  List<Map<String, dynamic>> emergencies = [];
  String filter = "all";
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchEmergency();
  }

  Future<void> fetchEmergency() async {
    setState(() {
      isLoading = true;
    });

    try {
      // 🔥 1. 只查 emergency 表本身，去掉会导致崩溃的连表查询
      final data = await supabase
          .from('emergency')
          .select('*')
          .match(filter == "all" ? {} : {'status': filter})
          .order('created_at', ascending: false);

      List<Map<String, dynamic>> processedEmergencies = [];

      // 🔥 2. 手动匹配用户信息 (兼容 Resident 和 Admin)
      for (var e in data) {
        final userId = e['user_id']; // 从之前建好的表里拿到 user_id
        Map<String, dynamic>? userData;

        if (userId != null) {
          // 先去 resident 表找找看是不是住户求救
          userData = await supabase.from('resident').select().eq('id', userId).maybeSingle();

          // 如果 resident 表里没这个人，那可能是 Admin 自己按的求救
          if (userData == null) {
            // ⚠️ 注意：如果你的 admin 表主键叫 admin_id，把这里改成 eq('admin_id', userId)
            userData = await supabase.from('admin_new').select().eq('id', userId).maybeSingle();
          }
        }

        // 把拼装好的数据放进列表
        processedEmergencies.add({
          ...e,
          'user_data': userData, // 我们统一叫 user_data
        });
      }

      if (mounted) {
        setState(() {
          emergencies = processedEmergencies;
        });
      }

    } catch (e) {
      print("Fetch error: $e");
    }

    if (mounted) {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Emergency List")),

      body: Column(
        children: [
          const SizedBox(height: 10),

          // 🔥 FILTER BUTTONS
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              filterButton("all"),
              filterButton("active"),
              filterButton("solved"),
            ],
          ),

          const SizedBox(height: 10),

          // 🔥 LIST
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : emergencies.isEmpty
                ? const Center(child: Text("No emergency found"))
                : ListView.builder(
              itemCount: emergencies.length,
              itemBuilder: (context, index) {
                final e = emergencies[index];
                final user = e['user_data'];

                // 🔥 防御性代码：如果连用户都被删了，给个默认显示
                if (user == null) {
                  return const Card(
                    margin: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: ListTile(
                      leading: Icon(Icons.warning, color: Colors.grey),
                      title: Text("Unknown User"),
                      subtitle: Text("User data not found or deleted"),
                    ),
                  );
                }

                // 🔥 兼容住户和 Admin 的显示：Admin 可能没有 Block 和 Unit Number
                final name = user['full_name'] ?? user['username'] ?? "Unknown";
                final block = user['block'] ?? "-";
                final unit = user['unit_number'] ?? "Admin";

                return Card(
                  margin: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),

                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.red[100],
                      child: const Icon(Icons.warning,
                          color: Colors.red),
                    ),

                    title: Text(
                      name,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold),
                    ),

                    subtitle: Text(
                      "Block $block - $unit",
                    ),

                    trailing: Column(
                      mainAxisAlignment:
                      MainAxisAlignment.center,
                      children: [
                        Text(
                          e['status'],
                          style: TextStyle(
                            color: e['status'] == 'active'
                                ? Colors.red
                                : Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          e['type'],
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),

                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              AdminEmergencyPage(
                                  emergency: e),
                        ),
                      ).then((_) {
                        // 回来自动 refresh
                        fetchEmergency();
                      });
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // 🔥 FILTER BUTTON
  Widget filterButton(String value) {
    final isSelected = filter == value;

    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor:
        isSelected ? Colors.red : Colors.grey[300],
        foregroundColor:
        isSelected ? Colors.white : Colors.black,
      ),
      onPressed: () {
        setState(() {
          filter = value;
        });
        fetchEmergency();
      },
      child: Text(value.toUpperCase()),
    );
  }
}