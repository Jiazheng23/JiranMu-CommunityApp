import 'dart:io';
import 'package:assignment/admin/admin_login_page.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import '../AdminQRScannerScreen.dart';
import 'personal_information_page.dart';

class AdminProfilePage extends StatefulWidget {
  final Map<String, dynamic> user;

  const AdminProfilePage({super.key, required this.user});

  @override
  State<AdminProfilePage> createState() => _AdminProfilePageState();
}

class _AdminProfilePageState extends State<AdminProfilePage> {
  File? _imageFile;
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 50,
      );

      if (pickedFile == null) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final File file = File(pickedFile.path);
      final String userId = widget.user['id'];

      final String fileName = '$userId/${DateTime.now().millisecondsSinceEpoch}.jpg';

      await Supabase.instance.client.storage
          .from('admin_image')
          .upload(fileName, file);

      final String imageUrl = Supabase.instance.client.storage
          .from('admin_image')
          .getPublicUrl(fileName);

      await Supabase.instance.client
          .from('admin_new')
          .update({'image_url': imageUrl})
          .eq('id', userId);

      if (mounted) {
        Navigator.pop(context);

        setState(() {
          _imageFile = file;
          widget.user['image_url'] = imageUrl;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Profile photo saved successfully!"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      debugPrint("Upload error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Failed to save image: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _logout(BuildContext context) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      await Supabase.instance.client.auth.signOut();

      if (context.mounted) {
        Navigator.pop(context);
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const AdminLoginPage()),
              (route) => false,
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Logout failed: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final String name = widget.user['full_name'] ?? widget.user['username'] ?? 'System Admin';
    final String email = widget.user['email'] ?? Supabase.instance.client.auth.currentUser?.email ?? 'admin@system.com';
    final String role = widget.user['role'] ?? 'Administrator';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 20),

          // ── Avatar & Info ──────────────────────────────────────────────
          Center(
            child: Column(
              children: [
                GestureDetector(
                  onTap: _pickImage,
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      Builder(
                        builder: (context) {
                          ImageProvider? currentImage;
                          if (_imageFile != null) {
                            currentImage = FileImage(_imageFile!);
                          } else if (widget.user['image_url'] != null &&
                              widget.user['image_url'].toString().isNotEmpty) {
                            currentImage = NetworkImage(widget.user['image_url']);
                          }

                          return CircleAvatar(
                            radius: 50,
                            backgroundColor: const Color(0xFF1E88E5).withOpacity(0.1),
                            backgroundImage: currentImage,
                            onBackgroundImageError: currentImage != null
                                ? (exception, stackTrace) {
                              debugPrint("Image load error: $exception");
                            }
                                : null,
                            child: currentImage == null
                                ? const Icon(Icons.person, size: 50, color: Color(0xFF1E88E5))
                                : null,
                          );
                        },
                      ),
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: Color(0xFF1E88E5),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 15),
                Text(name,
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 5),
                Text(email,
                    style: const TextStyle(fontSize: 14, color: Colors.grey)),
                const SizedBox(height: 5),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E88E5).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    role.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E88E5),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 40),

          // ── Account Settings ───────────────────────────────────────────
          _buildSectionTitle("Account Settings"),
          Container(
            decoration: _cardDecoration(),
            child: Column(
              children: [
                _buildListTile(Icons.person_outline, "Personal Information", () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PersonalInformationPage(user: widget.user),
                    ),
                  );
                }),
              ],
            ),
          ),

          const SizedBox(height: 30),

          // ── ✅ NEW: Tools Section ──────────────────────────────────────
          _buildSectionTitle("Tools"),
          Container(
            decoration: _cardDecoration(),
            child: _buildListTile(
              Icons.qr_code_scanner,
              "Scan Visitor Pass",
                  () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AdminQRScannerScreen(),
                  ),
                );
              },
              subtitle: "Verify visitor QR codes at entry",
              iconColor: const Color(0xFF9A4B3C),
            ),
          ),

          const SizedBox(height: 40),

          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton.icon(
              onPressed: () => _logout(context),
              icon: const Icon(Icons.logout, color: Colors.redAccent),
              label: const Text(
                "Log Out",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.redAccent,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.withOpacity(0.1),
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15)),
              ),
            ),
          ),

          const SizedBox(height: 80),
        ],
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 10,
          spreadRadius: 2,
          offset: const Offset(0, 5),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 10, bottom: 10),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ),
    );
  }

  /// Supports optional [subtitle] and [iconColor]
  Widget _buildListTile(
      IconData icon,
      String title,
      VoidCallback onTap, {
        String? trailingText,
        String? subtitle,
        Color iconColor = Colors.black87,
      }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: iconColor == Colors.black87
              ? const Color(0xFFF0F0F5)
              : iconColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: subtitle != null
          ? Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey))
          : null,
      trailing: trailingText != null
          ? Text(trailingText, style: const TextStyle(color: Colors.grey))
          : const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
      onTap: onTap,
    );
  }

  Widget _buildDivider() {
    return Divider(
      height: 1,
      thickness: 1,
      color: Colors.grey.shade100,
      indent: 60,
      endIndent: 20,
    );
  }
}