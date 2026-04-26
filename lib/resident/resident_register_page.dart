import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:assignment/admin/admin_login_page.dart';
import 'resident_login_page.dart';

class ResidentRegisterPage extends StatefulWidget {
  const ResidentRegisterPage({super.key});

  @override
  State<ResidentRegisterPage> createState() => _ResidentRegisterPageState();
}

class _ResidentRegisterPageState extends State<ResidentRegisterPage> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController fullNameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController blockController = TextEditingController();
  final TextEditingController unitController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController = TextEditingController();

  bool obscurePassword = true;
  bool obscureConfirmPassword = true;
  bool isLoading = false;

  String selectedResidentType = 'owner';

  final List<Map<String, String>> residentTypes = [
    {'label': 'Owner', 'value': 'owner'},
    {'label': 'Tenant', 'value': 'tenant'},
    {'label': 'Family Member', 'value': 'family_member'},
  ];

  static const Color bgColor = Color(0xFFF8F3EE);
  static const Color primaryBrown = Color(0xFF8B5E4A);
  static const Color softBrown = Color(0xFFEADFD6);
  static const Color textDark = Color(0xFF2B2B2B);

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

  String? _validateRequired(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter $fieldName';
    }
    return null;
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter email';
    }

    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!emailRegex.hasMatch(value.trim())) {
      return 'Invalid email format';
    }

    return null;
  }

  String? _validatePhone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter phone number';
    }

    final phoneRegex = RegExp(r'^[0-9]{9,11}$');
    if (!phoneRegex.hasMatch(value.trim())) {
      return 'Invalid phone number';
    }

    return null;
  }

  String? _validateUnit(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter unit number';
    }
    final trimmed = value.trim();
    final unitRegex = RegExp(r'^\d+(-\d+)?$');
    if (!unitRegex.hasMatch(trimmed)) {
      return 'Invalid format (e.g. 10-15)';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter password';
    }

    if (value.length < 6) {
      return 'Password must be at least 6 characters';
    }

    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please confirm password';
    }

    if (value.trim() != passwordController.text.trim()) {
      return 'Passwords do not match';
    }

    return null;
  }

  Future<void> _registerResident() async {
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();
    setState(() => isLoading = true);

    final supabase = Supabase.instance.client;

    final fullName = fullNameController.text.trim();
    final email = emailController.text.trim();
    final phone = phoneController.text.trim();
    final block = blockController.text.trim();
    final unit = unitController.text.trim();
    final password = passwordController.text.trim();

    try {
      final AuthResponse response = await supabase.auth.signUp(
        email: email,
        password: password,
      );

      final user = response.user;
      if (user == null) {
        throw Exception('User registration failed');
      }

      final requestData = await supabase
          .from('requests')
          .insert({
        'user_id': user.id,
        'type': 'resident',
        'title': 'Resident Registration',
        'description': 'Block $block, Unit $unit',
        'status': 'pending',
      })
          .select('request_id')
          .single();

      final String requestId = requestData['request_id'] as String;

      await supabase.from('resident_requests').insert({
        'request_id': requestId,
        'full_name': fullName,
        'email': email,
        'phone_number': phone,
        'role': 'resident',
        'block': block,
        'unit_number': unit,
        'resident_type': selectedResidentType,
      });

      await supabase.auth.signOut();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Registration submitted. Waiting for Admin approval.'),
          backgroundColor: Color(0xFF6B8E6B),
        ),
      );

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const ResidentLoginPage()),
            (route) => false,
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: Colors.redAccent,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Widget _buildTextFormField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    required String? Function(String?) validator,
    bool obscureText = false,
    Widget? suffixIcon,
    TextInputType keyboardType = TextInputType.text,
    ValueChanged<String>? onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: TextFormField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        validator: validator,
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: const TextStyle(color: Colors.black38),
          prefixIcon: Icon(icon, color: Colors.black38),
          suffixIcon: suffixIcon,
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 18,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(
              color: primaryBrown,
              width: 1.2,
            ),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: Colors.redAccent),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(
              color: Colors.redAccent,
              width: 1.2,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResidentTypeDropdown() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: DropdownButtonFormField<String>(
        value: selectedResidentType,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        icon: const Icon(Icons.keyboard_arrow_down_rounded),
        decoration: InputDecoration(
          hintText: 'I am a...',
          hintStyle: const TextStyle(color: Colors.black38),
          prefixIcon: const Icon(Icons.people_outline, color: Colors.black38),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 18,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(
              color: primaryBrown,
              width: 1.2,
            ),
          ),
        ),
        items: residentTypes.map((type) {
          return DropdownMenuItem<String>(
            value: type['value'],
            child: Text(type['label']!),
          );
        }).toList(),
        onChanged: (value) {
          if (value == null) return;
          setState(() {
            selectedResidentType = value;
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back_ios_new_rounded),
                  color: textDark,
                  padding: EdgeInsets.zero,
                  alignment: Alignment.centerLeft,
                ),
                const SizedBox(height: 10),

                Center(
                  child: SizedBox(
                    width: 250,
                    height: 95,
                    child: ClipRect(
                      child: Align(
                        alignment: Alignment.topCenter,
                        heightFactor: 0.72,
                        child: Image.asset(
                          'assets/images/jiranmu_logo.png',
                          width: 250,
                          fit: BoxFit.fitWidth,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                const Center(
                  child: Text(
                    'JiranMu',
                    style: TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.w700,
                      color: primaryBrown,
                    ),
                  ),
                ),
                const SizedBox(height: 4),

                const Center(
                  child: Text(
                    'Resident register to continue',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.black45,
                      height: 1.35,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                _buildTextFormField(
                  controller: fullNameController,
                  hintText: 'Full Name',
                  icon: Icons.badge_outlined,
                  validator: (value) => _validateRequired(value, 'full name'),
                ),
                const SizedBox(height: 16),

                _buildTextFormField(
                  controller: emailController,
                  hintText: 'Email',
                  icon: Icons.person_outline,
                  validator: _validateEmail,
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),

                _buildTextFormField(
                  controller: phoneController,
                  hintText: 'Phone Number',
                  icon: Icons.phone_outlined,
                  validator: _validatePhone,
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 16),

                _buildTextFormField(
                  controller: blockController,
                  hintText: 'Block (e.g. A)',
                  icon: Icons.apartment_outlined,
                  validator: (value) => _validateRequired(value, 'block'),
                ),
                const SizedBox(height: 16),

                _buildTextFormField(
                  controller: unitController,
                  hintText: 'Unit Number (e.g 10-12)',
                  icon: Icons.home_outlined,
                  validator: _validateUnit,
                ),
                const SizedBox(height: 16),

                _buildResidentTypeDropdown(),
                const SizedBox(height: 16),

                _buildTextFormField(
                  controller: passwordController,
                  hintText: 'Password',
                  icon: Icons.lock_outline,
                  obscureText: obscurePassword,
                  validator: _validatePassword,
                  onChanged: (_) => setState(() {}),
                  suffixIcon: IconButton(
                    onPressed: () {
                      setState(() => obscurePassword = !obscurePassword);
                    },
                    icon: Icon(
                      obscurePassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: Colors.black45,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                _buildTextFormField(
                  controller: confirmPasswordController,
                  hintText: 'Confirm Password',
                  icon: Icons.lock_outline,
                  obscureText: obscureConfirmPassword,
                  validator: _validateConfirmPassword,
                  onChanged: (_) => setState(() {}),
                  suffixIcon: IconButton(
                    onPressed: () {
                      setState(() {
                        obscureConfirmPassword = !obscureConfirmPassword;
                      });
                    },
                    icon: Icon(
                      obscureConfirmPassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: Colors.black45,
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : _registerResident,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryBrown,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                    ),
                    child: isLoading
                        ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                        : const Text(
                      'Resident Register',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                Center(
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    children: [
                      const Text(
                        'Already have an account? ',
                        style: TextStyle(
                          fontSize: 14.5,
                          color: Colors.black54,
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ResidentLoginPage(),
                            ),
                          );
                        },
                        child: const Text(
                          'Resident Login',
                          style: TextStyle(
                            fontSize: 14.5,
                            color: primaryBrown,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),

                Center(
                  child: TextButton(
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AdminLoginPage(),
                        ),
                      );
                    },
                    child: const Text(
                      'Switch to Admin Login',
                      style: TextStyle(
                        fontSize: 14.5,
                        color: primaryBrown,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}