import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:assignment/resident/Resident_Emergency_Detail_Page.dart';

class EmergencyForm extends StatefulWidget {
  const EmergencyForm({super.key});

  @override
  State<EmergencyForm> createState() => _EmergencyFormState();
}

class _EmergencyFormState extends State<EmergencyForm> with SingleTickerProviderStateMixin {
  final supabase = Supabase.instance.client;
  final ImagePicker _picker = ImagePicker();

  static const double CONDO_LAT = 3.1578;
  static const double CONDO_LNG = 101.7118;

  late double targetLat;
  late double targetLng;

  // ── User Data variables ──
  String? homeUnitNumber;
  bool _isLoadingUserData = true;

  // ── Tab Controller
  TabController? _tabController;

  // ── Design tokens ──
  static const Color bgColor      = Color(0xFFF5F1ED);
  static const Color primaryColor = Color(0xFF9A4B3C);
  static const Color textDark     = Color(0xFF2B2B2B);

  // ── Form State variables ──
  String? selectedType;
  File? evidenceFile;
  final TextEditingController _descController = TextEditingController();

  double? latitude;
  double? longitude;
  bool isLocating  = false;
  bool isSubmitting = false;
  bool useHomeAddress = false;

  // ── History State variables ──
  List<Map<String, dynamic>> _historyData = [];
  bool _isLoadingHistory = true;

  // Emergency type options
  final List<Map<String, dynamic>> emergencyTypes = [
    {'type': 'Fire',            'icon': Icons.local_fire_department_rounded, 'color': const Color(0xFFFF5A5A), 'label': 'Fire'},
    {'type': 'Medical',         'icon': Icons.medical_services_rounded,      'color': const Color(0xFFFF8C42), 'label': 'Medical'},
    {'type': 'Suspicious',      'icon': Icons.visibility_rounded,            'color': const Color(0xFF758BFD), 'label': 'Suspicious'},
    {'type': 'Elderly',         'icon': Icons.elderly_rounded,               'color': const Color(0xFF4BC0B8), 'label': 'Elderly'},
    {'type': 'Flood',           'icon': Icons.water_rounded,                 'color': const Color(0xFF2196F3), 'label': 'Flood'},
    {'type': 'Break-in',        'icon': Icons.lock_open_rounded,             'color': const Color(0xFFE96B9E), 'label': 'Break-in'},
    {'type': 'Gas Leak',        'icon': Icons.air_rounded,                   'color': const Color(0xFFFFCA28), 'label': 'Gas Leak'},
    {'type': 'Other',           'icon': Icons.help_rounded,                  'color': const Color(0xFF9E9E9E), 'label': 'Other'},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchHistory();
    _fetchUserData();
  }

  @override
  void dispose() {
    _descController.dispose();
    _tabController?.dispose();
    super.dispose();
  }

  Future<void> _fetchUserData() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      final response = await supabase
          .from('resident')
          .select('unit_number')
          .eq('id', userId)
          .single();

      if (mounted) {
        setState(() {
          homeUnitNumber = response['unit_number'];
          _isLoadingUserData = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching user data: $e");
      if (mounted) setState(() => _isLoadingUserData = false);
    }
  }

  // ── Fetch User's Emergency History ──
  Future<void> _fetchHistory() async {
    setState(() => _isLoadingHistory = true);
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      final response = await supabase
          .from('emergency')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _historyData = List<Map<String, dynamic>>.from(response);
        });
      }
    } catch (e) {
      debugPrint("Error fetching history: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoadingHistory = false);
      }
    }
  }

  // ── Get GPS location ──
  Future<void> _getLocation() async {
    setState(() => isLocating = true);
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text("Location permission denied. Please enable in settings."),
              backgroundColor: Colors.red));
        }
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      setState(() {
        latitude  = pos.latitude;
        longitude = pos.longitude;
      });
    } catch (e) {
      debugPrint("Location error: $e");
    } finally {
      setState(() => isLocating = false);
    }
  }

  // ── Pick evidence photo ──
  Future<void> _pickEvidence() async {
    final XFile? file = await _picker.pickImage(source: ImageSource.camera, imageQuality: 70);
    if (file != null) setState(() => evidenceFile = File(file.path));
  }

  Future<void> _submit() async {
    if (selectedType == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Please select an emergency type."),
          backgroundColor: Colors.red));
      return;
    }

    if (useHomeAddress) {
      if (homeUnitNumber == null || homeUnitNumber!.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("Your profile does not include an address. Please use your current location or update your information."),
            backgroundColor: Colors.orange));
        return;
      }
    }
    else if (latitude == null || longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Please capture your GPS location."),
          backgroundColor: Colors.orange));
      return;
    }

    setState(() => isSubmitting = true);

    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) throw "User not logged in";

      String? evidenceUrl;

      if (evidenceFile != null) {

        final fileExt = evidenceFile!.path.split('.').last;
        final fileName = 'emergency_${DateTime.now().millisecondsSinceEpoch}.$fileExt';
        final filePath = '$userId/$fileName';

        await supabase.storage.from('emergency_evidence').upload(
          filePath,
          evidenceFile!,
          fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
        );

        evidenceUrl = supabase.storage.from('emergency_evidence').getPublicUrl(filePath);
      }

      await supabase.from('emergency').insert({
        'user_id': userId,
        'type': selectedType,
        'status': 'active',
        'latitude': useHomeAddress ? null : latitude,
        'longitude': useHomeAddress ? null : longitude,
        'is_home_address': useHomeAddress,
        'description': _descController.text.trim().isEmpty ? null : _descController.text.trim(),
        'report_evidence_url': evidenceUrl,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("An emergency alert has been sent! Help is on its way."),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3)));

        setState(() {
          selectedType = null;
          evidenceFile = null;
          _descController.clear();
          latitude = null;
          longitude = null;
          useHomeAddress = false;
        });

        await _fetchHistory();

        _tabController?.animateTo(1);
      }
    } catch (e) {
      debugPrint("Submission failed Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("Submission failed: $e"),
            backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) {
        setState(() => isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_tabController == null) {
      return const Scaffold(
        backgroundColor: bgColor,
        body: Center(child: CircularProgressIndicator(color: primaryColor)),
      );
    }

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: textDark),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Emergency",
          style: TextStyle(color: textDark, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: primaryColor,
          unselectedLabelColor: Colors.grey,
          indicatorColor: primaryColor,
          indicatorWeight: 3,
          tabs: const [
            Tab(text: "Report"),
            Tab(text: "History"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // ── TAB 1: Report Form ──
          _buildReportForm(),

          // ── TAB 2: History List ──
          _buildHistoryTab(),
        ],
      ),
    );
  }

  // ==============================================================
  // UI: Report Form Tab
  // ==============================================================
  Widget _buildReportForm() {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header / Alert Info
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(18),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: const Color(0xFFFF5A5A).withOpacity(0.12), borderRadius: BorderRadius.circular(14)),
                    child: const Icon(Icons.warning_amber_rounded, color: Color(0xFFFF5A5A), size: 28),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Stay Calm", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textDark)),
                        SizedBox(height: 4),
                        Text("Help will be notified immediately after submission.", style: TextStyle(fontSize: 13, color: Colors.black54, height: 1.3)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // Emergency type grid
            const Text("What is happening?", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textDark)),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 4, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 0.85,
              children: emergencyTypes.map((e) {
                final bool isSelected = selectedType == e['type'];
                final Color typeColor = e['color'] as Color;
                return GestureDetector(
                  onTap: () => setState(() => selectedType = e['type']),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    decoration: BoxDecoration(
                      color: isSelected ? typeColor.withOpacity(0.15) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: isSelected ? typeColor : Colors.transparent, width: 2),
                      boxShadow: [if (!isSelected) BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 2))],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(e['icon'] as IconData, color: isSelected ? typeColor : Colors.black38, size: 28),
                        const SizedBox(height: 6),
                        Text(e['label'] as String, textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isSelected ? typeColor : Colors.black45)),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 28),

            // Location Section
            const Text("Where is the emergency?", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textDark)),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => useHomeAddress = false),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: !useHomeAddress ? const Color(0xFF4BC0B8) : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF4BC0B8)),
                      ),
                      child: Center(
                        child: Text("Current Location", style: TextStyle(fontWeight: FontWeight.bold, color: !useHomeAddress ? Colors.white : const Color(0xFF4BC0B8))),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => useHomeAddress = true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: useHomeAddress ? primaryColor : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: primaryColor),
                      ),
                      child: Center(
                        child: Text("My Home Address", style: TextStyle(fontWeight: FontWeight.bold, color: useHomeAddress ? Colors.white : primaryColor)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (useHomeAddress)
              Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: primaryColor.withOpacity(0.08), borderRadius: BorderRadius.circular(16)),
                  child: _isLoadingUserData
                      ? const Center(child: CircularProgressIndicator())
                      : homeUnitNumber != null && homeUnitNumber!.isNotEmpty
                      ? Row(
                    children: [
                      const Icon(Icons.home_rounded, color: primaryColor, size: 24),
                      const SizedBox(width: 14),
                      Expanded(
                          child: Text(
                              "Help will be dispatched to your unit:\n$homeUnitNumber",
                              style: const TextStyle(color: primaryColor, fontWeight: FontWeight.w600, fontSize: 14, height: 1.4)
                          )
                      ),
                    ],
                  )
                      : const Row(
                    children: [
                      Icon(Icons.error_outline_rounded, color: Colors.red, size: 24),
                      SizedBox(width: 14),
                      Expanded(
                          child: Text(
                              "No home address found in your profile. Please use GPS or update your profile first.",
                              style: TextStyle(color: Colors.red, fontWeight: FontWeight.w500, fontSize: 13, height: 1.4)
                          )
                      ),
                    ],
                  )
              )
            else
              GestureDetector(
                onTap: isLocating ? null : _getLocation,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  decoration: BoxDecoration(
                    color: latitude != null ? const Color(0xFF4BC0B8).withOpacity(0.08) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: latitude != null ? const Color(0xFF4BC0B8) : Colors.transparent, width: 1.5),
                  ),
                  child: Row(
                    children: [
                      Icon(latitude != null ? Icons.location_on_rounded : Icons.location_searching_rounded, color: latitude != null ? const Color(0xFF4BC0B8) : Colors.black38, size: 24),
                      const SizedBox(width: 14),
                      Expanded(
                        child: isLocating
                            ? const Text("Getting your location...", style: TextStyle(color: Colors.black45, fontSize: 14))
                            : latitude != null
                            ? Text("Location captured  ✓\nLat: ${latitude!.toStringAsFixed(4)}, Lng: ${longitude!.toStringAsFixed(4)}", style: const TextStyle(color: Color(0xFF4BC0B8), fontWeight: FontWeight.w600, fontSize: 13, height: 1.4))
                            : const Text("Tap to get current GPS location", style: TextStyle(color: Colors.black45, fontSize: 14)),
                      ),
                      if (isLocating) const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 28),

            // Description (Optional)
            const Text("Additional Details (Optional)", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textDark)),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 2))],
              ),
              child: TextField(
                controller: _descController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: "E.g., Grandpa fell in the bathroom...",
                  hintStyle: const TextStyle(color: Colors.black38, fontSize: 14),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.all(16),
                ),
              ),
            ),

            const SizedBox(height: 28),

            // Evidence photo
            const Text("Evidence (Optional)", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textDark)),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: _pickEvidence,
              child: Container(
                height: evidenceFile != null ? 180 : 100, width: double.infinity,
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 2))]),
                child: evidenceFile != null
                    ? Stack(
                  children: [
                    ClipRRect(borderRadius: BorderRadius.circular(16), child: Image.file(evidenceFile!, width: double.infinity, height: 180, fit: BoxFit.cover)),
                    Positioned(top: 10, right: 10, child: GestureDetector(onTap: () => setState(() => evidenceFile = null), child: Container(padding: const EdgeInsets.all(6), decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle), child: const Icon(Icons.close, color: Colors.white, size: 16)))),
                  ],
                )
                    : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.camera_alt_outlined, color: Colors.black38, size: 32),
                    SizedBox(height: 8),
                    Text("Take a photo", style: TextStyle(color: Colors.black45, fontSize: 13)),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 36),

            // Submit button
            SizedBox(
              width: double.infinity, height: 56,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF5A5A), disabledBackgroundColor: Colors.red.withOpacity(0.4), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)), elevation: 4, shadowColor: const Color(0xFFFF5A5A).withOpacity(0.5)),
                onPressed: isSubmitting ? null : _submit,
                child: isSubmitting
                    ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                    : const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.emergency_rounded, color: Colors.white, size: 22), SizedBox(width: 10), Text("Send Emergency Alert", style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold))]),
              ),
            ),

            const SizedBox(height: 16),
            const Center(child: Text("Only use for real emergencies.\nFalse reports may result in penalties.", textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.black45, height: 1.4))),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  // ==============================================================
  // UI: History List Tab
  // ==============================================================
  Widget _buildHistoryTab() {
    if (_isLoadingHistory) {
      return const Center(child: CircularProgressIndicator(color: primaryColor));
    }

    if (_historyData.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history_rounded, size: 60, color: Colors.black26),
            SizedBox(height: 16),
            Text("No emergency history found.", style: TextStyle(color: Colors.black54, fontSize: 16)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: primaryColor,
      onRefresh: _fetchHistory,
      child: ListView.separated(
        padding: const EdgeInsets.all(20),
        itemCount: _historyData.length,
        separatorBuilder: (context, index) => const SizedBox(height: 16),
        itemBuilder: (context, index) {
          final item = _historyData[index];
          final type = item['type'] ?? 'Unknown';
          final status = item['status'] ?? 'unknown';
          final isSolved = status == 'solved';
          final dateStr = item['created_at']?.toString().substring(0, 16).replaceFirst('T', ' ') ?? '';

          // Find icon and color based on type
          final typeInfo = emergencyTypes.firstWhere(
                (e) => e['type'] == type,
            orElse: () => emergencyTypes.last, // 'Other'
          );

          // 🔥 这里加了 GestureDetector，点击卡片跳转到详情页
          return GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ResidentEmergencyDetailPage(emergency: item),
                ),
              );
            },
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 3)),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: (typeInfo['color'] as Color).withOpacity(0.15),
                      child: Icon(typeInfo['icon'] as IconData, color: typeInfo['color'] as Color),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(type, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textDark)),
                          const SizedBox(height: 4),
                          Text(dateStr, style: const TextStyle(fontSize: 12, color: Colors.black45)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isSolved ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: isSolved ? Colors.green : Colors.orange),
                      ),
                      child: Text(
                        status.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isSolved ? Colors.green : Colors.orange,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // 加一个小箭头，暗示用户可以点击查看详情
                    const Icon(Icons.chevron_right_rounded, color: Colors.black26),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}