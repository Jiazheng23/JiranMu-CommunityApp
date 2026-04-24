import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PersonalInformationPage extends StatefulWidget {
  final Map<String, dynamic> user;

  const PersonalInformationPage({super.key, required this.user});

  @override
  State<PersonalInformationPage> createState() => _PersonalInformationPageState();
}

class _PersonalInformationPageState extends State<PersonalInformationPage> {
  // ── Design Tokens ──
  static const Color bgColor = Color(0xFFF5F1ED);
  static const Color primaryColor = Color(0xFF9A4B3C);
  static const Color textDark = Color(0xFF2B2B2B);

  // 基本信息 Controllers
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _icController = TextEditingController();

  // 生理信息 Controllers
  final _ageController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();

  // 血型下拉菜单状态
  String? _selectedBloodType;
  final List<String> _bloodTypes = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];

  // 密码 Controller
  final _newPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // 初始化时，把数据库传来的值填入框中
    _nameController.text = widget.user['full_name'] ?? widget.user['username'] ?? '';
    _emailController.text = widget.user['email'] ?? '';
    _phoneController.text = widget.user['phone'] ?? '';
    _icController.text = widget.user['ic'] ?? '';

    _ageController.text = widget.user['age']?.toString() ?? '';
    _heightController.text = widget.user['height']?.toString() ?? '';
    _weightController.text = widget.user['weight']?.toString() ?? '';

    // 初始化血型 (如果数据库里的值合法，就选中它)
    if (_bloodTypes.contains(widget.user['blood'])) {
      _selectedBloodType = widget.user['blood'];
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _icController.dispose();
    _ageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }

  // 保存更改
  Future<void> _saveChanges() async {
    setState(() => _isLoading = true);

    try {
      final userId = widget.user['id'];

      // 1. 准备要更新的数据包
      final updates = {
        'full_name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'ic': _icController.text.trim(),
        'age': int.tryParse(_ageController.text.trim()),
        'height': double.tryParse(_heightController.text.trim()),
        'weight': double.tryParse(_weightController.text.trim()),
        'blood': _selectedBloodType,
      };

      // 2. 调用 Supabase 更新 admin_new 表
      await Supabase.instance.client
          .from('admin_new')
          .update(updates)
          .eq('id', userId);

      // 3. 更新密码
      if (_newPasswordController.text.isNotEmpty) {
        await Supabase.instance.client.auth.updateUser(
          UserAttributes(password: _newPasswordController.text),
        );
      }

      if (mounted) {
        widget.user['full_name'] = _nameController.text.trim();
        widget.user['phone'] = _phoneController.text.trim();
        widget.user['ic'] = _icController.text.trim();
        widget.user['age'] = int.tryParse(_ageController.text.trim());
        widget.user['height'] = double.tryParse(_heightController.text.trim());
        widget.user['weight'] = double.tryParse(_weightController.text.trim());
        widget.user['blood'] = _selectedBloodType;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Profile updated successfully!"),
            backgroundColor: Color(0xFF6B8E6B),
          ),
        );

        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error updating profile: $e"), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: textDark),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Personal Information",
          style: TextStyle(color: textDark, fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- 1. 基础信息区 ---
            _buildSectionHeader("Basic Details"),
            _buildTextField("Full Name", Icons.person_outline_rounded, _nameController),
            const SizedBox(height: 16),
            _buildTextField("Email Address", Icons.email_outlined, _emailController, readOnly: true),
            const SizedBox(height: 16),
            _buildTextField("Phone Number", Icons.phone_outlined, _phoneController, keyboardType: TextInputType.phone),
            const SizedBox(height: 16),
            _buildTextField("IC Number", Icons.badge_outlined, _icController),

            const SizedBox(height: 35),

            // --- 2. 生理信息区 ---
            _buildSectionHeader("Physical Attributes"),
            Row(
              children: [
                Expanded(child: _buildTextField("Age", Icons.cake_outlined, _ageController, keyboardType: TextInputType.number)),
                const SizedBox(width: 16),
                Expanded(
                  child: Container(
                    height: 58, // 匹配 TextField 的高度
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 2)),
                      ],
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        icon: const Icon(Icons.bloodtype, color: primaryColor),
                        value: _selectedBloodType,
                        hint: const Text("Blood Type", style: TextStyle(color: Colors.black45, fontSize: 14)),
                        isExpanded: true,
                        dropdownColor: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        items: _bloodTypes.map((String type) {
                          return DropdownMenuItem(value: type, child: Text(type, style: const TextStyle(fontSize: 15, color: textDark)));
                        }).toList(),
                        onChanged: (String? newValue) {
                          setState(() { _selectedBloodType = newValue; });
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _buildTextField("Height (cm)", Icons.height_rounded, _heightController, keyboardType: TextInputType.number)),
                const SizedBox(width: 16),
                Expanded(child: _buildTextField("Weight (kg)", Icons.monitor_weight_outlined, _weightController, keyboardType: TextInputType.number)),
              ],
            ),

            const SizedBox(height: 35),

            // --- 3. 安全区 ---
            _buildSectionHeader("Security"),
            Container(
              decoration: BoxDecoration(
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 2))],
              ),
              child: TextField(
                controller: _newPasswordController,
                obscureText: _obscurePassword,
                style: const TextStyle(fontSize: 15, color: textDark),
                decoration: InputDecoration(
                  labelText: "New Password",
                  labelStyle: const TextStyle(color: Colors.black45, fontSize: 14),
                  hintText: "Enter a new password",
                  hintStyle: const TextStyle(color: Colors.black26, fontSize: 14),
                  prefixIcon: const Icon(Icons.lock_outline_rounded, color: primaryColor),
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded, color: Colors.black38),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(vertical: 18),
                ),
              ),
            ),

            const SizedBox(height: 45),

            // --- 4. 保存按钮 ---
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveChanges,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  disabledBackgroundColor: primaryColor.withOpacity(0.5),
                  elevation: 4,
                  shadowColor: primaryColor.withOpacity(0.4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: _isLoading
                    ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                    : const Text("Save Changes", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 0.5)),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // 辅助组件：Section 标题
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Text(
        title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textDark, letterSpacing: 0.3),
      ),
    );
  }

  // 辅助组件：快速构建文本输入框
  Widget _buildTextField(String label, IconData icon, TextEditingController controller, {bool readOnly = false, TextInputType? keyboardType}) {
    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          if (!readOnly) BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: TextField(
        controller: controller,
        readOnly: readOnly,
        keyboardType: keyboardType,
        style: TextStyle(fontSize: 15, color: readOnly ? Colors.black54 : textDark),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: readOnly ? Colors.black38 : Colors.black45, fontSize: 14),
          prefixIcon: Icon(icon, color: readOnly ? Colors.black26 : primaryColor),
          filled: true,
          fillColor: readOnly ? Colors.black.withOpacity(0.04) : Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(vertical: 18), // 增加高度使其更饱满
        ),
      ),
    );
  }
}