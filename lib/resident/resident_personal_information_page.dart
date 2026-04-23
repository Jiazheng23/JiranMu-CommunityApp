import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ResidentPersonalInformationPage extends StatefulWidget {
  final Map<String, dynamic> user;

  const ResidentPersonalInformationPage({
    super.key,
    required this.user,
  });

  @override
  State<ResidentPersonalInformationPage> createState() =>
      _ResidentPersonalInformationPageState();
}

class _ResidentPersonalInformationPageState
    extends State<ResidentPersonalInformationPage> {
  static const Color _bgColor = Color(0xFFF5F1ED);
  static const Color _primaryColor = Color(0xFF9A4B3C);

  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _blockController = TextEditingController();
  final _unitController = TextEditingController();
  final _residentTypeController = TextEditingController();
  final _ageController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  final List<String> _bloodTypes = const [
    'A',
    'B',
    'AB',
    'O',
  ];

  String? _selectedBloodType;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();

    _nameController.text = widget.user['full_name']?.toString() ?? '';
    _emailController.text = widget.user['email']?.toString() ??
        Supabase.instance.client.auth.currentUser?.email ??
        '';
    _phoneController.text = widget.user['phone_number']?.toString() ?? '';
    _blockController.text = widget.user['block']?.toString() ?? '-';
    _unitController.text = widget.user['unit_number']?.toString() ?? '-';
    _residentTypeController.text =
        _formatResidentType(widget.user['resident_type']?.toString());
    _ageController.text = widget.user['age']?.toString() ?? '';
    _heightController.text = widget.user['height']?.toString() ?? '';
    _weightController.text = widget.user['weight']?.toString() ?? '';

    final bloodValue = widget.user['blood']?.toString();
    if (_bloodTypes.contains(bloodValue)) {
      _selectedBloodType = bloodValue;
    }
  }

  String _formatResidentType(String? value) {
    if (value == null || value.trim().isEmpty) return '-';

    final raw = value.trim().toLowerCase();
    switch (raw) {
      case 'owner':
        return 'Owner';
      case 'tenant':
        return 'Tenant';
      case 'family_member':
        return 'Family Member';
      default:
        return raw
            .split('_')
            .map((e) => e.isEmpty ? e : '${e[0].toUpperCase()}${e.substring(1)}')
            .join(' ');
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _blockController.dispose();
    _unitController.dispose();
    _residentTypeController.dispose();
    _ageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String? _validateRequired(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter $fieldName';
    }
    return null;
  }

  String? _validatePhone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter phone number';
    }

    final phoneRegex = RegExp(r'^[0-9+\-\s]{9,15}$');
    if (!phoneRegex.hasMatch(value.trim())) {
      return 'Invalid phone number';
    }

    return null;
  }

  String? _validatePositiveInt(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) return null;

    final number = int.tryParse(value.trim());
    if (number == null || number <= 0) {
      return '$fieldName must be more than 0';
    }

    return null;
  }

  String? _validatePositiveDouble(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) return null;

    final number = double.tryParse(value.trim());
    if (number == null || number <= 0) {
      return '$fieldName must be more than 0';
    }

    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return null;

    if (value.length < 6) {
      return 'Password must be at least 6 characters';
    }

    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (_newPasswordController.text.trim().isEmpty &&
        (value == null || value.isEmpty)) {
      return null;
    }

    if (value == null || value.isEmpty) {
      return 'Please confirm new password';
    }

    if (value != _newPasswordController.text.trim()) {
      return 'Passwords do not match';
    }

    return null;
  }

  String? _nullableText(String text) {
    final value = text.trim();
    return value.isEmpty ? null : value;
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      final userId = widget.user['id'] ?? currentUser?.id;

      if (userId == null) {
        throw Exception('Resident user id not found.');
      }

      final updates = {
        'full_name': _nameController.text.trim(),
        'phone_number': _phoneController.text.trim(),
        'age': _nullableText(_ageController.text) == null
            ? null
            : int.parse(_ageController.text.trim()),
        'height': _nullableText(_heightController.text) == null
            ? null
            : double.parse(_heightController.text.trim()),
        'weight': _nullableText(_weightController.text) == null
            ? null
            : double.parse(_weightController.text.trim()),
        'blood': _selectedBloodType,
      };

      await Supabase.instance.client
          .from('resident')
          .update(updates)
          .eq('id', userId);

      final newPassword = _newPasswordController.text.trim();
      if (newPassword.isNotEmpty) {
        await Supabase.instance.client.auth.updateUser(
          UserAttributes(password: newPassword),
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Resident profile updated successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating resident profile: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: const Color(0xFF9A4B3C),
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Personal Details',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle('Basic Details'),
              const SizedBox(height: 14),
              _buildTextFormField(
                label: 'Full Name',
                icon: Icons.person_outline,
                controller: _nameController,
                validator: (value) => _validateRequired(value, 'full name'),
              ),
              const SizedBox(height: 14),
              _buildTextFormField(
                label: 'Email Address',
                icon: Icons.email_outlined,
                controller: _emailController,
                readOnly: true,
              ),
              const SizedBox(height: 14),
              _buildTextFormField(
                label: 'Phone Number',
                icon: Icons.phone_outlined,
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                validator: _validatePhone,
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _buildTextFormField(
                      label: 'Block',
                      icon: Icons.apartment_outlined,
                      controller: _blockController,
                      readOnly: true,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _buildTextFormField(
                      label: 'Unit Number',
                      icon: Icons.home_outlined,
                      controller: _unitController,
                      readOnly: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _buildTextFormField(
                label: 'Resident Type',
                icon: Icons.groups_outlined,
                controller: _residentTypeController,
                readOnly: true,
              ),
              const SizedBox(height: 28),
              _buildSectionTitle('Physical Attributes'),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _buildTextFormField(
                      label: 'Age',
                      icon: Icons.cake_outlined,
                      controller: _ageController,
                      keyboardType: TextInputType.number,
                      validator: (value) =>
                          _validatePositiveInt(value, 'Age'),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _buildDropdownField<String>(
                      value: _selectedBloodType,
                      label: 'Blood Type',
                      icon: Icons.bloodtype_outlined,
                      items: _bloodTypes
                          .map(
                            (type) => DropdownMenuItem<String>(
                          value: type,
                          child: Text(type),
                        ),
                      )
                          .toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedBloodType = value;
                        });
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _buildTextFormField(
                      label: 'Height (cm)',
                      icon: Icons.height,
                      controller: _heightController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      validator: (value) =>
                          _validatePositiveDouble(value, 'Height'),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _buildTextFormField(
                      label: 'Weight (kg)',
                      icon: Icons.monitor_weight_outlined,
                      controller: _weightController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      validator: (value) =>
                          _validatePositiveDouble(value, 'Weight'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              _buildSectionTitle('Security'),
              const SizedBox(height: 14),
              _buildTextFormField(
                label: 'New Password',
                icon: Icons.lock_outline,
                controller: _newPasswordController,
                obscureText: _obscureNewPassword,
                validator: _validatePassword,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureNewPassword
                        ? Icons.visibility_off
                        : Icons.visibility,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscureNewPassword = !_obscureNewPassword;
                    });
                  },
                ),
              ),
              const SizedBox(height: 14),
              _buildTextFormField(
                label: 'Confirm New Password',
                icon: Icons.lock_reset_outlined,
                controller: _confirmPasswordController,
                obscureText: _obscureConfirmPassword,
                validator: _validateConfirmPassword,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureConfirmPassword
                        ? Icons.visibility_off
                        : Icons.visibility,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscureConfirmPassword = !_obscureConfirmPassword;
                    });
                  },
                ),
              ),
              const SizedBox(height: 34),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveChanges,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                      : const Text(
                    'Save Changes',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
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

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
    );
  }

  Widget _buildTextFormField({
    required String label,
    required IconData icon,
    required TextEditingController controller,
    bool readOnly = false,
    bool obscureText = false,
    TextInputType? keyboardType,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      readOnly: readOnly,
      obscureText: obscureText,
      keyboardType: keyboardType,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: readOnly ? Colors.grey.shade200 : Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: _primaryColor, width: 1.2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.2),
        ),
      ),
    );
  }

  Widget _buildDropdownField<T>({
    required T? value,
    required String label,
    required IconData icon,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return DropdownButtonFormField<T>(
      value: value,
      items: items,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: _primaryColor, width: 1.2),
        ),
      ),
      dropdownColor: Colors.white,
      borderRadius: BorderRadius.circular(16),
    );
  }
}