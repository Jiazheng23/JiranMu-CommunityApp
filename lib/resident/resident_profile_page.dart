import 'package:assignment/resident/resident_personal_information_page.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ResidentProfilePage extends StatefulWidget {
  const ResidentProfilePage({super.key});

  @override
  State<ResidentProfilePage> createState() => _ResidentProfilePageState();
}

class _ResidentProfilePageState extends State<ResidentProfilePage> {
  static const Color _bgColor = Color(0xFFF5F1ED);
  static const Color _primaryColor = Color(0xFF9A4B3C);
  static const Color _accentColor = Color(0xFFF26A3D);
  static const Color _softBrown = Color(0xFFEADFD6);

  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic>? _resident;

  @override
  void initState() {
    super.initState();
    _loadResidentProfile();
  }

  Future<void> _loadResidentProfile() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) {
        throw Exception('No active user session found.');
      }

      final profile = await Supabase.instance.client
          .from('resident')
          .select()
          .eq('id', currentUser.id)
          .maybeSingle();

      if (profile == null) {
        throw Exception('Resident profile not found.');
      }

      if (!mounted) return;
      setState(() {
        _resident = {
          ...profile,
          'email': profile['email'] ?? currentUser.email,
          'id': currentUser.id,
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
    if (_resident == null) return;

    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ResidentPersonalInformationPage(user: _resident!),
      ),
    );

    if (updated == true) {
      await _loadResidentProfile();
    }
  }

  String _initialsFromName(String? fullName) {
    if (fullName == null || fullName.trim().isEmpty) return 'R';

    final parts = fullName
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();

    if (parts.isEmpty) return 'R';
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
      case 'moved_out':
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
              _errorMessage ?? 'Unable to load resident profile.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadResidentProfile,
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
    final resident = _resident;

    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        title: const Text('My Profile'),
      ),
      body: _isLoading
          ? _buildLoadingState()
          : resident == null
          ? _buildErrorState()
          : RefreshIndicator(
        onRefresh: _loadResidentProfile,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 46,
                      backgroundColor: _softBrown,
                      child: Text(
                        _initialsFromName(resident['full_name']),
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: _primaryColor,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _displayValue(resident['full_name'], fallback: 'Resident'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _displayValue(resident['email']),
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
                          label: _displayValue(
                            resident['resident_type'],
                            fallback: 'owner',
                          ).toUpperCase(),
                          background: _primaryColor.withOpacity(0.12),
                          textColor: _primaryColor,
                        ),
                        _buildChip(
                          label: _displayValue(
                            resident['status'],
                            fallback: 'unknown',
                          ).toUpperCase(),
                          background: _statusColor(
                            _displayValue(resident['status'], fallback: 'unknown'),
                          ).withOpacity(0.12),
                          textColor: _statusColor(
                            _displayValue(resident['status'], fallback: 'unknown'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              _buildSectionTitle('Resident Details'),
              Container(
                decoration: _cardDecoration(),
                padding: const EdgeInsets.all(18),
                child: Column(
                  children: [
                    _buildInfoRow(
                      icon: Icons.apartment_outlined,
                      label: 'Block',
                      value: _displayValue(resident['block']),
                    ),
                    const SizedBox(height: 14),
                    _buildInfoRow(
                      icon: Icons.home_outlined,
                      label: 'Unit Number',
                      value: _displayValue(resident['unit_number']),
                    ),
                    const SizedBox(height: 14),
                    _buildInfoRow(
                      icon: Icons.phone_outlined,
                      label: 'Phone Number',
                      value: _displayValue(resident['phone_number']),
                    ),
                    const SizedBox(height: 14),
                    _buildInfoRow(
                      icon: Icons.bloodtype_outlined,
                      label: 'Blood Type',
                      value: _displayValue(resident['blood']),
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
                    'Edit resident details and change password',
                    style: TextStyle(fontSize: 12),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: _openPersonalInformationPage,
                ),
              ),
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
                style: const TextStyle(fontSize: 12, color: Colors.black54),
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
