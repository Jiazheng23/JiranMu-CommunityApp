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

  InputDecoration inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 16,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: Color(0xFF8D6E63),
          width: 1.4,
        ),
      ),
    );
  }

  void showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> login() async {
    final supabase = Supabase.instance.client;

    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      showMessage("Please fill all fields");
      return;
    }

    setState(() => isLoading = true);

    try {
      final response = await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      final user = response.user;
      if (user == null) {
        throw Exception("Login failed");
      }

      final resident = await supabase
          .from('resident')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      if (resident == null) {
        await supabase.auth.signOut();
        throw Exception("This is not a resident account");
      }

      final status = resident['status'] as String?;

      if (status == 'pending') {
        showMessage("Account pending approval");
        await supabase.auth.signOut();
        return;
      }

      if (status == 'rejected') {
        showMessage("Account rejected");
        await supabase.auth.signOut();
        return;
      }

      if (status != 'approved') {
        showMessage("Account is not approved");
        await supabase.auth.signOut();
        return;
      }

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const ResidentHomePage()),
      );
    } on AuthException catch (e) {
      showMessage(e.message);
    } catch (e) {
      showMessage("Error: $e");
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
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
                    obscurePassword
                        ? Icons.visibility_off
                        : Icons.visibility,
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
                    ? const SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                )
                    : const Text("Login"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}