import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';

class EmergencyForm extends StatefulWidget {
  const EmergencyForm({super.key});

  @override
  State<EmergencyForm> createState() => _EmergencyFormState();
}

class _EmergencyFormState extends State<EmergencyForm> {
  final supabase = Supabase.instance.client;
  final ImagePicker _picker = ImagePicker();

  // ── Design tokens ──
  static const Color bgColor      = Color(0xFFF5F1ED);
  static const Color primaryColor = Color(0xFF9A4B3C);
  static const Color textDark     = Color(0xFF2B2B2B);

  // ── State variables ──
  String? selectedType;
  File? evidenceFile;
  final TextEditingController _descController = TextEditingController(); // 📝 新增：描述控制器

  double? latitude;
  double? longitude;
  bool isLocating  = false;
  bool isSubmitting = false;

  bool useHomeAddress = false; // 🏠 新增：是否使用家庭住址

  // Emergency type options
  final List<Map<String, dynamic>> emergencyTypes = [
    {'type': 'Fire',            'icon': Icons.local_fire_department_rounded, 'color': Color(0xFFFF5A5A), 'label': 'Fire'},
    {'type': 'Medical',         'icon': Icons.medical_services_rounded,      'color': Color(0xFFFF8C42), 'label': 'Medical'},
    {'type': 'Suspicious',      'icon': Icons.visibility_rounded,            'color': Color(0xFF758BFD), 'label': 'Suspicious'},
    {'type': 'Elderly',         'icon': Icons.elderly_rounded,               'color': Color(0xFF4BC0B8), 'label': 'Elderly'},
    {'type': 'Flood',           'icon': Icons.water_rounded,                 'color': Color(0xFF2196F3), 'label': 'Flood'},
    {'type': 'Break-in',        'icon': Icons.lock_open_rounded,             'color': Color(0xFFE96B9E), 'label': 'Break-in'},
    {'type': 'Gas Leak',        'icon': Icons.air_rounded,                   'color': Color(0xFFFFCA28), 'label': 'Gas Leak'},
    {'type': 'Other',           'icon': Icons.help_rounded,                  'color': Color(0xFF9E9E9E), 'label': 'Other'},
  ];

  @override
  void dispose() {
    _descController.dispose();
    super.dispose();
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

  // ── Submit to Supabase ──
  Future<void> _submit() async {
    if (selectedType == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Please select an emergency type."),
          backgroundColor: Colors.red));
      return;
    }

    // 🚨 拦截验证：如果不是家庭住址，且没有 GPS，不让提交
    if (!useHomeAddress && (latitude == null || longitude == null)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Please provide your current location or select 'Home Address'."),
          backgroundColor: Colors.orange));
      return;
    }

    setState(() => isSubmitting = true);

    try {
      final userId = supabase.auth.currentUser?.id;
      String? evidenceUrl;

      // Upload evidence image
      if (evidenceFile != null) {
        final fileName = 'report_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final path = 'public/$fileName';
        await supabase.storage.from('emergency_evidence').upload(path, evidenceFile!);
        evidenceUrl = supabase.storage.from('emergency_evidence').getPublicUrl(path);
      }

      // Insert emergency record
      await supabase.from('emergency').insert({
        'user_id':      userId,
        'type':         selectedType,
        'status':       'active', // 🔥 已修正：直接变成 active 让保安看到
        'latitude':     useHomeAddress ? null : latitude,
        'longitude':    useHomeAddress ? null : longitude,
        'is_home_address': useHomeAddress, // 🏠 记录是否是家庭住址
        'description':  _descController.text.trim().isEmpty ? null : _descController.text.trim(), // 📝 保存描述
        'report_evidence_url': evidenceUrl,
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("🚨 Emergency reported! Help is on the way."),
            backgroundColor: Color(0xFF6B8E6B),
            duration: Duration(seconds: 4)));
      }
    } catch (e) {
      debugPrint("Submit error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("Failed to submit: $e"),
            backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => isSubmitting = false);
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
          "Report Emergency",
          style: TextStyle(color: textDark, fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header / Alert Info ──
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

              // ── Emergency type grid ──
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

              // ── Location Section ──
              const Text("Where is the emergency?", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textDark)),
              const SizedBox(height: 12),

              // 🏠 切换：当前位置 vs 家庭地址
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

              // 根据选择显示不同的内容
              if (useHomeAddress)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: primaryColor.withOpacity(0.08), borderRadius: BorderRadius.circular(16)),
                  child: const Row(
                    children: [
                      Icon(Icons.home_rounded, color: primaryColor, size: 24),
                      SizedBox(width: 14),
                      Expanded(child: Text("Help will be dispatched to your registered apartment unit.", style: TextStyle(color: primaryColor, fontWeight: FontWeight.w600, fontSize: 13, height: 1.4))),
                    ],
                  ),
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

              // ── Description (Optional) ──
              // 📝 新增：选填描述框
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

              // ── Evidence photo ──
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

              // ── Submit button ──
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
      ),
    );
  }
}