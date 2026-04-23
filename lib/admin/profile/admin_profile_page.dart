import 'dart:io';

import 'package:assignment/admin/AdminQRScannerScreen.dart';
import 'package:assignment/admin/admin_login_page.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'personal_information_page.dart';

class AdminProfilePage extends StatefulWidget {
  final Map<String, dynamic> user;

  const AdminProfilePage({super.key, required this.user});

  @override
  State<AdminProfilePage> createState() => _AdminProfilePageState();
}

class _AdminProfilePageState extends State<AdminProfilePage> {
  static const Color _bgColor = Color(0xFFF5F1ED);
  static const Color _primaryColor = Color(0xFF9A4B3C);
  static const Color _accentColor = Color(0xFFF26A3D);
  static const Color _softBrown = Color(0xFFEADFD6);

  final ImagePicker _picker = ImagePicker();

  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic>? _admin;
  File? _imageFile;

  @override
  void initState() {
    super.initState();
    _loadAdminProfile();
  }

  Future<void> _loadAdminProfile() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      final userId = currentUser?.id ?? widget.user['id'];

      if (userId == null) {
        throw Exception('No active admin session found.');
      }

      final profile = await Supabase.instance.client
          .from('admin_new')
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (profile == null) {
        throw Exception('Admin profile not found.');
      }

      if (!mounted) return;

      setState(() {
        _admin = {
          ...widget.user,
          ...profile,
          'id': userId,
          'email':
          profile['email'] ??
              currentUser?.email ??
              widget.user['email'] ??
              'admin@system.com',
        };
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _openPersonalInformationPage() async {
    if (_admin == null) return;

    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => PersonalInformationPage(user: _admin!),
      ),
    );

    if (updated == true) {
      await _loadAdminProfile();
    }
  }

  Future<void> _pickImage() async {
    try {
      final pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 60,
      );

      if (pickedFile == null) return;

      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      final currentUser = Supabase.instance.client.auth.currentUser;
      final userId = currentUser?.id ?? _admin?['id'] ?? widget.user['id'];

      if (userId == null) {
        throw Exception('Unable to identify current admin.');
      }

      final file = File(pickedFile.path);
      final fileName = '$userId/${DateTime.now().millisecondsSinceEpoch}.jpg';

      await Supabase.instance.client.storage
          .from('admin_image')
          .upload(fileName, file);

      final imageUrl = Supabase.instance.client.storage
          .from('admin_image')
          .getPublicUrl(fileName);

      await Supabase.instance.client
          .from('admin_new')
          .update({'image_url': imageUrl})
          .eq('id', userId);

      if (!mounted) return;
      Navigator.pop(context);

      setState(() {
        _imageFile = file;
      });

      await _loadAdminProfile();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile photo updated successfully!'),
          backgroundColor: Color(0xFF6B8E6B),
        ),
      );
    } catch (e) {
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save image: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _logout(BuildContext context) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      await Supabase.instance.client.auth.signOut();

      if (!context.mounted) return;

      Navigator.pop(context);
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AdminLoginPage()),
            (route) => false,
      );
    } catch (e) {
      if (context.mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Logout failed: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  String _initialsFromName(String? fullName) {
    if (fullName == null || fullName.trim().isEmpty) return 'A';

    final parts = fullName
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();

    if (parts.isEmpty) return 'A';
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }

    return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
        .toUpperCase();
  }

  String _displayValue(dynamic value, {String fallback = '-'}) {
    if (value == null) return fallback;
    final text = value.toString().trim();
    return text.isEmpty ? fallback : text;
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return Colors.green;
      case 'inactive':
        return Colors.orange;
      case 'suspended':
        return Colors.redAccent;
      default:
        return Colors.grey;
    }
  }

  Widget _buildLoadingState() {
    return const Center(child: CircularProgressIndicator());
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
            const SizedBox(height: 12),
            Text(
              _errorMessage ?? 'Unable to load admin profile.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadAdminProfile,
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
                foregroundColor: Colors.white,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final admin = _admin;

    if (_isLoading) {
      return _buildLoadingState();
    }

    if (admin == null) {
      return _buildErrorState();
    }

    final name = _displayValue(admin['full_name'], fallback: 'Administrator');
    final email = _displayValue(admin['email'], fallback: 'admin@system.com');
    final role = _displayValue(admin['role'], fallback: 'Administrator');
    final status = _displayValue(admin['status'], fallback: 'active');

    ImageProvider? avatarImage;
    if (_imageFile != null) {
      avatarImage = FileImage(_imageFile!);
    } else if ((admin['image_url'] ?? '').toString().trim().isNotEmpty) {
      avatarImage = NetworkImage(admin['image_url']);
    }

    return Container(
      color: _bgColor,
      child: RefreshIndicator(
        onRefresh: _loadAdminProfile,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: _pickImage,
                      child: Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          CircleAvatar(
                            radius: 46,
                            backgroundColor: _softBrown,
                            backgroundImage: avatarImage,
                            child: avatarImage == null
                                ? Text(
                              _initialsFromName(admin['full_name']),
                              style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: _primaryColor,
                              ),
                            )
                                : null,
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
                                color: _primaryColor,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.camera_alt_rounded,
                                size: 14,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      name,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      email,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: [
                        _buildChip(
                          label: role.toUpperCase(),
                          background: _primaryColor.withOpacity(0.12),
                          textColor: _primaryColor,
                        ),
                        _buildChip(
                          label: status.toUpperCase(),
                          background: _statusColor(status).withOpacity(0.12),
                          textColor: _statusColor(status),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              _buildSectionTitle('Admin Details'),
              Container(
                decoration: _cardDecoration(),
                padding: const EdgeInsets.all(18),
                child: Column(
                  children: [
                    _buildInfoRow(
                      icon: Icons.phone_outlined,
                      label: 'Phone Number',
                      value: _displayValue(admin['phone']),
                    ),
                    const SizedBox(height: 14),
                    _buildInfoRow(
                      icon: Icons.badge_outlined,
                      label: 'IC Number',
                      value: _displayValue(admin['ic']),
                    ),
                    const SizedBox(height: 14),
                    _buildInfoRow(
                      icon: Icons.bloodtype_outlined,
                      label: 'Blood Type',
                      value: _displayValue(admin['blood']),
                    ),
                    const SizedBox(height: 14),
                    _buildInfoRow(
                      icon: Icons.key_outlined,
                      label: 'Invite Code',
                      value: _displayValue(admin['invite_code']),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              _buildSectionTitle('Account Settings'),
              Container(
                decoration: _cardDecoration(),
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _accentColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.edit_outlined,
                      color: _accentColor,
                    ),
                  ),
                  title: const Text(
                    'Personal Information',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text(
                    'Edit admin details and change password',
                    style: TextStyle(fontSize: 12),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: _openPersonalInformationPage,
                ),
              ),
              const SizedBox(height: 28),

              _buildSectionTitle('Tools'),
              Container(
                decoration: _cardDecoration(),
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _primaryColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.qr_code_scanner_rounded,
                      color: _primaryColor,
                    ),
                  ),
                  title: const Text(
                    'Scan Visitor Pass',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text(
                    'Verify visitor QR codes at entry',
                    style: TextStyle(fontSize: 12),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AdminQRScannerScreen(),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 40),

              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton.icon(
                  onPressed: () => _logout(context),
                  icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
                  label: const Text(
                    'Log Out',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.redAccent,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.withOpacity(0.08),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 60),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChip({
    required String label,
    required Color background,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _softBrown,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: _primaryColor, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 6, bottom: 10),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
    );
  }

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
}