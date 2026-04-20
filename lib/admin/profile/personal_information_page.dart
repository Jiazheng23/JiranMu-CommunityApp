import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PersonalInformationPage extends StatefulWidget {
  final Map<String, dynamic> user;

  const PersonalInformationPage({super.key, required this.user});

  @override
  State<PersonalInformationPage> createState() => _PersonalInformationPageState();
}

class _PersonalInformationPageState extends State<PersonalInformationPage> {
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
      final userId = widget.user['id']; // 获取当前用户 ID

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
          .from('admin_new') // 替换成你实际的表名
          .update(updates)
          .eq('id', userId);

      // 3. (可选) 如果用户填了新密码，调用 Auth API 更新密码
      if (_newPasswordController.text.isNotEmpty) {
        await Supabase.instance.client.auth.updateUser(
          UserAttributes(password: _newPasswordController.text),
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Profile updated successfully!"), backgroundColor: Colors.green),
        );
        Navigator.pop(context); // 返回上一页
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error updating profile: $e"), backgroundColor: Colors.red),
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
      backgroundColor: const Color(0xFFF0F0F5),
      appBar: AppBar(
        title: const Text("Personal Information"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- 1. 基础信息区 ---
            const Text("Basic Details", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),
            _buildTextField("Full Name", Icons.person_outline, _nameController),
            const SizedBox(height: 15),
            _buildTextField("Email Address", Icons.email_outlined, _emailController, readOnly: true),
            const SizedBox(height: 15),
            _buildTextField("Phone Number", Icons.phone_outlined, _phoneController, keyboardType: TextInputType.phone),
            const SizedBox(height: 15),
            _buildTextField("IC Number", Icons.badge_outlined, _icController),

            const SizedBox(height: 30),

            // --- 2. 生理信息区 ---
            const Text("Physical Attributes", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),
            Row(
              children: [
                Expanded(child: _buildTextField("Age", Icons.cake_outlined, _ageController, keyboardType: TextInputType.number)),
                const SizedBox(width: 15),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedBloodType,
                        hint: const Text("Blood Type"),
                        isExpanded: true,
                        items: _bloodTypes.map((String type) {
                          return DropdownMenuItem(value: type, child: Text(type));
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
            const SizedBox(height: 15),
            Row(
              children: [
                Expanded(child: _buildTextField("Height (cm)", Icons.height, _heightController, keyboardType: TextInputType.number)),
                const SizedBox(width: 15),
                Expanded(child: _buildTextField("Weight (kg)", Icons.monitor_weight_outlined, _weightController, keyboardType: TextInputType.number)),
              ],
            ),

            const SizedBox(height: 30),

            // --- 3. 安全区 ---
            const Text("Security", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),
            TextField(
              controller: _newPasswordController,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                labelText: "New Password",
                hintText: "Enter a new password",
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                ),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
              ),
            ),

            const SizedBox(height: 40),

            // --- 4. 保存按钮 ---
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveChanges,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E88E5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("Save Changes", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // 辅助组件：快速构建文本输入框
  Widget _buildTextField(String label, IconData icon, TextEditingController controller, {bool readOnly = false, TextInputType? keyboardType}) {
    return TextField(
      controller: controller,
      readOnly: readOnly,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: readOnly ? Colors.grey.shade200 : Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
      ),
    );
  }
}