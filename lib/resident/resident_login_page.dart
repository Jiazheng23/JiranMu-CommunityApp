import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'resident_home_page.dart';

class ResidentLoginPage extends StatefulWidget {
  const ResidentLoginPage({super.key});

  @override
  State<ResidentLoginPage> createState() => _ResidentLoginPageState();
}

class _ResidentLoginPageState extends State<ResidentLoginPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool isLoading = false;
  bool obscurePassword = true;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> login() async {
    final supabase = Supabase.instance.client;

    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill all fields")),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final response = await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      final user = response.user;

      if (user == null) {
        throw Exception("Login failed");
      }

      // 1. 先查 resident 表，看看是不是已经是正式入驻的住户
      final residentData = await supabase
          .from('resident')
          .select()
          .eq('id', user.id) // 假设 resident 表里用 id 关联 auth 用户的 id
          .maybeSingle();

      if (residentData != null) {
        // 如果在 resident 表里找到了，说明已经 approve 并且落库了
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const ResidentHomePage(),
          ),
        );
        return; // 登录成功，直接结束
      }

      // 2. 如果 resident 表里没找到，去 requests 表查他的申请状态
      // 注意：这里的 'user_id' 需要替换成你 requests 表里实际关联用户ID的字段名（可能是 'id' 或 'user_id'）
      final requestData = await supabase
          .from('requests')
          .select('status')
          .eq('user_id', user.id) // 🔥 请根据你数据库实际的外键名字修改这里
          .eq('type', 'resident')
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      // 因为他目前还不是正式 resident，安全起见先强制登出他的 Auth
      await supabase.auth.signOut();

      if (requestData != null) {
        final status = requestData['status'];

        if (status == 'pending') {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Your account is still pending approval by the Admin.")),
          );
        } else if (status == 'rejected') {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Your account application was rejected.")),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Account state unknown. Please contact support.")),
          );
        }
      } else {
        // 3. 两个表都找不到数据
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Account profile not found. Please register first.")),
        );
      }

    } on AuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  InputDecoration inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F3EE),
      appBar: AppBar(
        title: const Text("Resident Login"),
        backgroundColor: const Color(0xFFF8F3EE),
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 20),

            TextField(
              controller: emailController,
              decoration: inputDecoration("Email"),
            ),

            const SizedBox(height: 14),

            TextField(
              controller: passwordController,
              obscureText: obscurePassword,
              decoration: inputDecoration("Password").copyWith(
                suffixIcon: IconButton(
                  icon: Icon(
                    obscurePassword ? Icons.visibility_off : Icons.visibility,
                  ),
                  onPressed: () {
                    setState(() {
                      obscurePassword = !obscurePassword;
                    });
                  },
                ),
              ),
            ),

            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: isLoading ? null : login,
                child: isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("Login"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}