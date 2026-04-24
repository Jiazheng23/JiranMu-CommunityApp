import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:assignment/admin/emergency/admin_emergency_page.dart';

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
      final data = await supabase
          .from('emergency')
          .select('*')
          .match(filter == "all" ? {} : {'status': filter})
          .order('created_at', ascending: false);

      List<Map<String, dynamic>> processedEmergencies = [];

      for (var e in data) {
        final userId = e['user_id'];
        Map<String, dynamic>? userData;

        if (userId != null) {
          userData = await supabase.from('resident').select().eq('id', userId).maybeSingle();

          if (userData == null) {
            userData = await supabase.from('admin_new').select().eq('id', userId).maybeSingle();
          }
        }

        processedEmergencies.add({
          ...e,
          'user_data': userData,
        });
      }

      // 🔥 核心逻辑：在这里进行自定义排序，把 Active 强行置顶
      processedEmergencies.sort((a, b) {
        String statusA = (a['status'] ?? '').toString().toLowerCase();
        String statusB = (b['status'] ?? '').toString().toLowerCase();

        // 如果 A 是 active 而 B 不是，A 排在前面 (-1)
        if (statusA == 'active' && statusB != 'active') return -1;
        // 如果 B 是 active 而 A 不是，B 排在前面 (1)
        if (statusA != 'active' && statusB == 'active') return 1;

        // 如果状态相同（都是 active 或都是 solved），按时间倒序排列 (最新的在最上面)
        DateTime timeA = DateTime.tryParse(a['created_at'] ?? '') ?? DateTime.now();
        DateTime timeB = DateTime.tryParse(b['created_at'] ?? '') ?? DateTime.now();
        return timeB.compareTo(timeA);
      });

      if (mounted) {
        setState(() {
          // 赋值已经排好序的数据
          emergencies = processedEmergencies;
        });
      }
    } catch (e) {
      debugPrint("Fetch error: $e");
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
      backgroundColor: const Color(0xFFF5EBE6), // 🔥 统一高级浅米棕背景
      appBar: AppBar(
        title: const Text("Emergency Alerts", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFFF5EBE6),
        foregroundColor: const Color(0xFF2B2B2B),
        elevation: 0,
        centerTitle: true,
      ),
      body: Column(
        children: [
          const SizedBox(height: 10),

          // 🔥 优化后的分类药丸按钮
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(child: filterButton("all", "All")),
                const SizedBox(width: 10),
                Expanded(child: filterButton("active", "Active")),
                const SizedBox(width: 10),
                Expanded(child: filterButton("solved", "Solved")),
              ],
            ),
          ),

          const SizedBox(height: 15),

          // 🔥 列表区
          Expanded(
            child: isLoading
                ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8B5E4A)),
              ),
            )
                : emergencies.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_outline, size: 60, color: Colors.grey.shade400),
                  const SizedBox(height: 10),
                  Text(
                    "No emergencies found",
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 16),
                  ),
                ],
              ),
            )
                : ListView.builder(
              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 40),
              itemCount: emergencies.length,
              itemBuilder: (context, index) {
                final e = emergencies[index];
                final user = e['user_data'];

                // 防御性：用户被删
                if (user == null) {
                  return _buildUnknownUserCard();
                }

                final name = user['full_name'] ?? user['username'] ?? "Unknown";
                final block = user['block'] ?? "-";
                final unit = user['unit_number'] ?? "Admin";
                final status = (e['status'] ?? "").toString().toLowerCase();

                return _buildEmergencyCard(e, name, block, unit, status);
              },
            ),
          ),
        ],
      ),
    );
  }

  /// 🔥 统一的精美紧急卡片
  // 替换前：
// Widget _buildEmergencyCard(Map e, String name, String block, String unit, String status) {

// 替换后（加上 <String, dynamic>）：
  /// 🔥 统一的精美紧急卡片：图标已换成用户头像照片
  Widget _buildEmergencyCard(Map<String, dynamic> e, String name, String block, String unit, String status) {
    final bool isActive = status == 'active';
    final Color statusColor = isActive ? const Color(0xFFC67B75) : const Color(0xFF6B8E6B);

    // 🔥 获取用户头像 URL (假设字段名为 image_url，这是基于你之前的设置)
    final String? userImageUrl = e['user_data']?['image_url'];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8B5E4A).withOpacity(0.06),
            blurRadius: 15,
            spreadRadius: 0,
            offset: const Offset(0, 5),
          )
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AdminEmergencyPage(emergency: e),
              ),
            ).then((_) => fetchEmergency());
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // 🔥 1. 原来的图标区域换成了照片区域
                Container(
                  padding: const EdgeInsets.all(2), // 边框
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1), // 状态颜色的柔光边框
                    shape: BoxShape.circle,
                  ),
                  child: CircleAvatar(
                    radius: 24, // 头像大小
                    backgroundColor: const Color(0xFFF0F0F5), // 加载中或无图时的背景色

                    // 👉 这里尝试加载网络图片
                    backgroundImage: (userImageUrl != null && userImageUrl.isNotEmpty)
                        ? NetworkImage(userImageUrl)
                        : null,

                    // 👉 如果没有图片，显示一个默认的图标占位
                    child: (userImageUrl == null || userImageUrl.isEmpty)
                        ? Icon(Icons.person, color: Colors.grey.shade400, size: 28)
                        : null,
                  ),
                ),
                const SizedBox(width: 16),

                // 中间信息
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF2B2B2B)),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Block $block - $unit",
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                      ),
                    ],
                  ),
                ),

                // 右侧状态与时间
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        status.toUpperCase(),
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      e['type']?.toString().toUpperCase() ?? "SOS",
                      style: TextStyle(color: Colors.grey.shade400, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 🔥 未知用户的占位卡片
  Widget _buildUnknownUserCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.grey.shade100, shape: BoxShape.circle),
              child: const Icon(Icons.help_outline, color: Colors.grey),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Unknown User", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                  const SizedBox(height: 4),
                  Text("User data deleted", style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 🔥 优化后的筛选按钮
  Widget filterButton(String dbValue, String displayValue) {
    final isSelected = filter == dbValue;

    return InkWell(
      onTap: () {
        setState(() {
          filter = dbValue;
        });
        fetchEmergency();
      },
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF8B5E4A) : Colors.white, // 深棕色 / 白色
          borderRadius: BorderRadius.circular(20),
          boxShadow: isSelected
              ? [BoxShadow(color: const Color(0xFF8B5E4A).withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3))]
              : [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2))],
        ),
        alignment: Alignment.center,
        child: Text(
          displayValue,
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFF8B5E4A),
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}