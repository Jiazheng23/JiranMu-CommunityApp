import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UserManagementPage extends StatefulWidget {
  const UserManagementPage({super.key});

  @override
  State<UserManagementPage> createState() => _UserManagementPageState();
}

class _UserManagementPageState extends State<UserManagementPage> with SingleTickerProviderStateMixin {
  final supabase = Supabase.instance.client;
  late TabController _tabController;

  List users = [];
  bool isLoading = true;
  String searchText = "";
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // 当切换 Tab 时重新抓取数据
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        fetchUsers();
      }
    });
    fetchUsers();
  }

  /// 根据当前 Tab 抓取 Admin 或 Resident 数据
  Future<void> fetchUsers() async {
    try {
      setState(() => isLoading = true);

      final table = _tabController.index == 0 ? 'admin_new' : 'resident';
      var query = supabase.from(table).select();

      // 如果有搜索文本
      if (searchText.isNotEmpty) {
        query = query.ilike('full_name', '%$searchText%');
      }

      final data = await query.order('full_name', ascending: true);

      setState(() {
        users = data;
        isLoading = false;
      });
    } catch (e) {
      debugPrint("Fetch Users Error: $e");
      setState(() => isLoading = false);
    }
  }

  /// 删除用户功能
  Future<void> deleteUser(String id) async {
    final table = _tabController.index == 0 ? 'admin_new' : 'resident';

    // 弹窗确认
    bool confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Confirm Delete"),
        content: const Text("Are you sure you want to remove this user?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Delete", style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm) {
      try {
        await supabase.from(table).delete().eq('id', id);
        fetchUsers(); // 刷新
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("User deleted")));
      } catch (e) {
        debugPrint("Delete Error: $e");
      }
    }
  }

  /// 延续你喜欢的卡片设计
  Widget buildUserCard(Map user) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundColor: Colors.blue.shade100,
          child: Text(user['full_name']?[0].toUpperCase() ?? "U"),
        ),
        title: Text(
          user['full_name'] ?? "Unknown User",
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(user['email'] ?? ""),
            if (user['unit_number'] != null) // 如果是居民，显示房号
              Text("Unit: ${user['block']}-${user['unit_number']}", style: const TextStyle(fontSize: 12)),
          ],
        ),
        trailing: PopupMenuButton(
          icon: const Icon(Icons.more_vert),
          onOpened: () {},
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'edit', child: Text("Edit")),
            const PopupMenuItem(value: 'delete', child: Text("Delete", style: TextStyle(color: Colors.red))),
          ],
          onSelected: (value) {
            if (value == 'delete') deleteUser(user['id']);
            if (value == 'edit') {

            }
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: const Text("User Management", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.blue,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.blue,
          tabs: const [
            Tab(text: "Admins"),
            Tab(text: "Residents"),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // 搜索框
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: "Search by name...",
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
              onChanged: (val) {
                searchText = val;
                fetchUsers();
              },
            ),
            const SizedBox(height: 16),

            // 用户列表
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : users.isEmpty
                  ? const Center(child: Text("No users found"))
                  : RefreshIndicator(
                onRefresh: fetchUsers,
                child: ListView.builder(
                  itemCount: users.length,
                  itemBuilder: (context, index) => buildUserCard(users[index]),
                ),
              ),
            ),
          ],
        ),
      ),
      // 新增用户按钮
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.blue,
        onPressed: () {

        },
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}