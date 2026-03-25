import 'package:flutter/material.dart';
import 'resident/resident_login_page.dart';
import 'resident/resident_register_page.dart';
import 'admin/admin_login_page.dart';
import 'admin/admin_register_page.dart';

class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  void goTo(BuildContext context, Widget page) {
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => page));
  }

  Widget buildPrimaryButton(String text, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF8B5E4A),
          foregroundColor: Colors.white,
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Text(
          text,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget buildSecondaryButton(String text, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Color(0xFF8B5E4A), width: 1.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: Color(0xFF8B5E4A),
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F3EE),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            children: [
              const SizedBox(height: 20),

              Container(
                width: 92,
                height: 92,
                decoration: BoxDecoration(
                  color: const Color(0xFFEADFD6),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(
                  Icons.groups_rounded,
                  size: 50,
                  color: Color(0xFF8B5E4A),
                ),
              ),

              const SizedBox(height: 20),

              const Text(
                "JiranMu",
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2B2B2B),
                ),
              ),

              const SizedBox(height: 10),

              const Text(
                "Building a supportive and caring community.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.black54,
                  height: 1.5,
                ),
              ),

              const SizedBox(height: 28),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 14,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Resident",
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 12),
                    buildPrimaryButton(
                      "Resident Login",
                      () => goTo(context, const ResidentLoginPage()),
                    ),
                    const SizedBox(height: 12),
                    buildSecondaryButton(
                      "Resident Register",
                      () => goTo(context, const ResidentRegisterPage()),
                    ),

                    const SizedBox(height: 28),

                    const Text(
                      "Admin",
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 12),
                    buildPrimaryButton(
                      "Admin Login",
                      () => goTo(context, const AdminLoginPage()),
                    ),
                    const SizedBox(height: 12),
                    buildSecondaryButton(
                      "Admin Register",
                      () => goTo(context, const AdminRegisterPage()),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              const Text(
                "Secure access for residents and community management",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.black45),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
