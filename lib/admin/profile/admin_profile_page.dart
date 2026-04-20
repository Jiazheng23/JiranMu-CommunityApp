import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'personal_information_page.dart';
import 'package:assignment/welcome_page.dart'; // 引入 Welcome 页面

class AdminProfilePage extends StatefulWidget {
  final Map<String, dynamic> user;

  const AdminProfilePage({super.key, required this.user});

  @override
  State<AdminProfilePage> createState() => _AdminProfilePageState();
}

class _AdminProfilePageState extends State<AdminProfilePage> {
  File? _imageFile; // 用来存储选中的本地照片
  final ImagePicker _picker = ImagePicker();

  // 🔥 1. 选择照片、上传到 Storage 并更新数据库的完整功能
  Future<void> _pickImage() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 50, // 压缩图片大小，上传更快
      );

      if (pickedFile == null) return;

      // 1. 显示加载圈（防止上传时用户乱点）
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final File file = File(pickedFile.path);
      final String userId = widget.user['id'];

      // 生成唯一文件名：用户ID + 时间戳
      final String fileName = '$userId/${DateTime.now().millisecondsSinceEpoch}.jpg';

      // 2. 上传图片到 Supabase Storage 的 'admin_image' 桶
      await Supabase.instance.client.storage
          .from('admin_image')
          .upload(fileName, file);

      // 3. 获取图片的公开访问 URL
      final String imageUrl = Supabase.instance.client.storage
          .from('admin_image')
          .getPublicUrl(fileName);

      // 4. 更新数据库 admin_new 表里的 image_url 字段
      await Supabase.instance.client
          .from('admin_new')
          .update({'image_url': imageUrl})
          .eq('id', userId);

      if (mounted) {
        // 关闭加载圈
        Navigator.pop(context);

        // 5. 更新本地 UI 状态
        setState(() {
          _imageFile = file;
          // 同时手动更新 widget.user 里的数据，保证即使不刷新页面也能立刻显示
          widget.user['image_url'] = imageUrl;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Profile photo saved successfully!"), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context); // 发生错误也关闭加载圈
      print("Upload error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to save image: $e"), backgroundColor: Colors.red),
      );
    }
  }

  // 🔥 2. 完美的退出登录功能 (清空路由历史)
  Future<void> _logout(BuildContext context) async {
    try {
      // 1. 显示加载圈
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      // 2. 执行 Supabase 的退出登录
      await Supabase.instance.client.auth.signOut();

      if (context.mounted) {
        // 3. 关闭加载圈
        Navigator.pop(context);

        // 4. 强制跳转回登录页面，并且清空所有的返回历史（防止按返回键又回到主页）
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => const WelcomePage(),
          ),
              (route) => false,
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Logout failed: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // 提取用户信息，防止 null
    final String name = widget.user['full_name'] ?? widget.user['username'] ?? 'System Admin';
    final String email = widget.user['email'] ?? Supabase.instance.client.auth.currentUser?.email ?? 'admin@system.com';
    final String role = widget.user['role'] ?? 'Administrator';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 20),

          // --- 顶部头像与信息区域 ---
          Center(
            child: Column(
              children: [
                GestureDetector(
                  onTap: _pickImage, // 点击头像触发选择照片上传
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      // 🔥 安全构建头像，修复 backgroundImage 报错问题
                      Builder(
                          builder: (context) {
                            // 判断当前到底有没有图片可以显示
                            ImageProvider? currentImage;
                            if (_imageFile != null) {
                              currentImage = FileImage(_imageFile!);
                            } else if (widget.user['image_url'] != null && widget.user['image_url'].toString().isNotEmpty) {
                              currentImage = NetworkImage(widget.user['image_url']);
                            }

                            return CircleAvatar(
                              radius: 50,
                              backgroundColor: const Color(0xFF1E88E5).withOpacity(0.1),

                              backgroundImage: currentImage,

                              // 核心修复：只有当 currentImage 不是 null 的时候，才加上错误拦截！
                              onBackgroundImageError: currentImage != null
                                  ? (exception, stackTrace) {
                                debugPrint("Image load error: $exception");
                              }
                                  : null,

                              // 如果什么图片都没有，就显示默认的蓝人 Icon
                              child: currentImage == null
                                  ? const Icon(Icons.person, size: 50, color: Color(0xFF1E88E5))
                                  : null,
                            );
                          }
                      ),
                      // 相机小图标装饰
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(color: Color(0xFF1E88E5), shape: BoxShape.circle),
                          child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 15),
                Text(name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 5),
                Text(email, style: const TextStyle(fontSize: 14, color: Colors.grey)),
                const SizedBox(height: 5),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(color: const Color(0xFF1E88E5).withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                  child: Text(role.toUpperCase(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E88E5))),
                ),
              ],
            ),
          ),

          const SizedBox(height: 40),

          // --- 账号设置卡片 ---
          _buildSectionTitle("Account Settings"),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, spreadRadius: 2, offset: const Offset(0, 5))],
            ),
            child: Column(
              children: [
                // 🔥 点击进入个人信息和修改密码页面
                _buildListTile(Icons.person_outline, "Personal Information", () {
                  Navigator.push(context, MaterialPageRoute(
                    builder: (context) => PersonalInformationPage(user: widget.user),
                  ));
                }),
                _buildDivider(),
                _buildListTile(Icons.notifications_none, "Notifications", () {}),
              ],
            ),
          ),

          const SizedBox(height: 30),

          // --- 系统与帮助卡片 ---
          _buildSectionTitle("System"),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, spreadRadius: 2, offset: const Offset(0, 5))],
            ),
            child: Column(
              children: [
                _buildListTile(Icons.help_outline, "Help & Support", () {}),
                _buildDivider(),
                _buildListTile(Icons.info_outline, "About App", () {}, trailingText: "v1.0.0"),
              ],
            ),
          ),

          const SizedBox(height: 40),

          // --- 退出登录按钮 ---
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton.icon(
              onPressed: () => _logout(context), // 🔥 调用 Logout
              icon: const Icon(Icons.logout, color: Colors.redAccent),
              label: const Text("Log Out", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.redAccent)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.withOpacity(0.1),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              ),
            ),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  // --- 辅助构建 UI 的小组件 ---
  Widget _buildSectionTitle(String title) {
    return Padding(padding: const EdgeInsets.only(left: 10, bottom: 10), child: Align(alignment: Alignment.centerLeft, child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87))));
  }

  Widget _buildListTile(IconData icon, String title, VoidCallback onTap, {String? trailingText}) {
    return ListTile(
      leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: const Color(0xFFF0F0F5), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: Colors.black87)),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      trailing: trailingText != null ? Text(trailingText, style: const TextStyle(color: Colors.grey)) : const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
      onTap: onTap,
    );
  }

  Widget _buildDivider() {
    return Divider(height: 1, thickness: 1, color: Colors.grey.shade100, indent: 60, endIndent: 20);
  }
}