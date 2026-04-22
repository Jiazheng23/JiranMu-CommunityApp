import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ResidentRegisterPage extends StatefulWidget {
  const ResidentRegisterPage({super.key});

  @override
  State<ResidentRegisterPage> createState() => _ResidentRegisterPageState();
}

class _ResidentRegisterPageState extends State<ResidentRegisterPage> {
  final fullNameController = TextEditingController();
  final emailController = TextEditingController();
  final phoneController = TextEditingController();
  final blockController = TextEditingController();
  final unitController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  String selectedResidentType = 'Owner';
  final List<String> residentTypes = ['Owner', 'Tenant', 'Family Member'];

  bool isLoading = false;
  bool obscurePassword = true;
  bool obscureConfirmPassword = true;

  @override
  void dispose() {
    fullNameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    blockController.dispose();
    unitController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  InputDecoration inputDecoration(String label, {Widget? suffixIcon}) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.white,
      suffixIcon: suffixIcon,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFD8CCC2)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFD8CCC2)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFF8B5E4A), width: 1.4),
      ),
    );
  }

  Future<void> registerResident() async {
    final supabase = Supabase.instance.client;

    final fullName = fullNameController.text.trim();
    final email = emailController.text.trim();
    final phone = phoneController.text.trim();
    final block = blockController.text.trim();
    final unit = unitController.text.trim();
    final password = passwordController.text.trim();
    final confirmPassword = confirmPasswordController.text.trim();

    if (fullName.isEmpty ||
        email.isEmpty ||
        phone.isEmpty ||
        block.isEmpty ||
        unit.isEmpty ||
        password.isEmpty ||
        confirmPassword.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill in all fields")),
      );
      return;
    }

    // 修复：去掉了重复的密码校验
    if (password != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Passwords do not match")),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      // ===== STEP 1: CREATE AUTH USER =====
      final AuthResponse response = await supabase.auth.signUp(
        email: email,
        password: password,
      );

      final user = response.user;
      if (user == null) {
        throw Exception("User registration failed");
      }

      // ===== STEP 2: INSERT MAIN REQUEST =====
      final requestData = await supabase.from('requests').insert({
        'user_id': user.id,
        'type': 'resident',
        'title': 'Resident Registration',
        'description': 'Block $block, Unit $unit',
        'status': 'pending', // ✅ 修复: 将 status 放入 requests 主表中 (如果数据库有默认值这行不加也行，但加上更保险)
      }).select('request_id').single();

      final String requestId = requestData['request_id'];

      // ===== STEP 3: INSERT SUB-REQUEST =====
      await supabase.from('resident_requests').insert({
        'request_id': requestId,
        'full_name': fullName,
        'email': email,
        'phone_number': phone,
        'block': block,
        'unit_number': unit,
        'role': 'resident', // ✅ 修复: 去掉了重复的 role 和报错的 status 字段
        'resident_type': selectedResidentType,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Registration submitted. Waiting for Admin approval."),
          backgroundColor: Color(0xFF6B8E6B),
        ),
      );
      Navigator.pop(context);
    } on AuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: Colors.redAccent),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.redAccent),
      );
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F3EE),
      appBar: AppBar(
        title: const Text("Resident Register", style: TextStyle(color: Color(0xFF2B2B2B))),
        backgroundColor: const Color(0xFFF8F3EE),
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF2B2B2B)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              const Text(
                "Create Resident Account",
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2B2B2B),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "Fill in your community details to continue.",
                style: TextStyle(fontSize: 15, color: Colors.black54),
              ),
              const SizedBox(height: 24),

              TextField(
                controller: fullNameController,
                decoration: inputDecoration("Full Name"),
              ),
              const SizedBox(height: 14),

              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: inputDecoration("Email"),
              ),
              const SizedBox(height: 14),

              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: inputDecoration("Phone Number"),
              ),
              const SizedBox(height: 14),

              TextField(
                controller: blockController,
                decoration: inputDecoration("Block"),
              ),
              const SizedBox(height: 14),

              TextField(
                controller: unitController,
                decoration: inputDecoration("Unit Number"),
              ),
              const SizedBox(height: 14),

              DropdownButtonFormField<String>(
                value: selectedResidentType,
                decoration: inputDecoration("I am a..."),
                items: residentTypes.map((String type) {
                  return DropdownMenuItem(
                    value: type,
                    child: Text(type),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    selectedResidentType = value!;
                  });
                },
              ),

              const SizedBox(height: 14),
              TextField(
                controller: passwordController,
                obscureText: obscurePassword,
                decoration: inputDecoration(
                  "Password",
                  suffixIcon: IconButton(
                    onPressed: () {
                      setState(() {
                        obscurePassword = !obscurePassword;
                      });
                    },
                    icon: Icon(
                      obscurePassword ? Icons.visibility_off : Icons.visibility,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              TextField(
                controller: confirmPasswordController,
                obscureText: obscureConfirmPassword,
                decoration: inputDecoration(
                  "Confirm Password",
                  suffixIcon: IconButton(
                    onPressed: () {
                      setState(() {
                        obscureConfirmPassword = !obscureConfirmPassword;
                      });
                    },
                    icon: Icon(
                      obscureConfirmPassword
                          ? Icons.visibility_off
                          : Icons.visibility,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: isLoading ? null : registerResident,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8B5E4A),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: isLoading
                      ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                      : const Text(
                    "Register",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}