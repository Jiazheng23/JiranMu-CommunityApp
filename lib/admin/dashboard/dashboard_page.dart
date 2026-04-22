import 'dart:io';
import 'package:assignment/admin/emergency/emergency_list_page.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../request/request_list_page.dart';
import 'package:image_picker/image_picker.dart';
import '../dashboard/admin_dashboard.dart';
import 'admin_notifications_page.dart';
import 'package:assignment/resident/announcement_list_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final supabase = Supabase.instance.client;
  final ImagePicker _picker = ImagePicker();

  static const Color bgColor = Color(0xFFF5F1ED);
  static const Color primaryColor = Color(0xFF9A4B3C);
  static const Color softYellow = Color(0xFFF0E6B8);
  static const Color textDark = Color(0xFF2B2B2B);

  bool hasUserNotif = false;
  bool hasEventNotif = false;
  bool hasFacilityNotif = false;
  bool hasVisitorNotif = false;
  bool hasEmergencyNotif = false;

  List<dynamic> announcements = [];
  String adminName = 'Admin';
  String? adminAvatarUrl;

  @override
  void initState() {
    super.initState();
    refreshAllData();
    _fetchAdminProfile();
  }

  Future<void> _fetchAdminProfile() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final data = await supabase
          .from('admin_new') // ⚠️ 请确保数据库里表名是这个
          .select('full_name, image_url')
          .eq('id', user.id)
          .single();

      if (mounted) {
        setState(() {
          adminName = data['full_name'] ?? 'Admin';
          adminAvatarUrl = data['image_url'];
        });
      }
    } catch (e) {
      debugPrint("Fetch admin error: $e");
    }
  }

  Future<void> refreshAllData() async {
    await fetchNotificationStatus();
    await fetchAnnouncements();
  }

  Future<void> fetchAnnouncements() async {
    try {
      final response = await supabase
          .from('announcements')
          .select()
          .order('created_at', ascending: false)
          .limit(5);
      if (mounted) setState(() => announcements = response);
    } catch (e) {
      debugPrint("Fetch Announcements Error: $e");
    }
  }

  Future<void> fetchNotificationStatus() async {
    try {
      final requests = await supabase.from('requests').select('type').eq(
          'status', 'pending');
      final emergencies = await supabase.from('emergency').select(
          'emergency_id').neq('status', 'solved');
      if (mounted) {
        setState(() {
          hasUserNotif = requests.any((r) =>
          r['type'] == 'admin' ||
              r['type'] == 'resident');
          hasEventNotif = requests.any((r) => r['type'] == 'complaint');
          hasFacilityNotif = requests.any((r) => r['type'] == 'booking');
          hasVisitorNotif = requests.any((r) => r['type'] == 'visitor');
          hasEmergencyNotif = emergencies.isNotEmpty;
        });
      }
    } catch (e) {
      debugPrint("Fetch Notifications Error: $e");
    }
  }

  void navigateTo(String type) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => RequestListPage(type: type)),
    ).then((_) => refreshAllData());
  }

  Widget buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(title,
          style: const TextStyle(
              fontSize: 18, fontWeight: FontWeight.bold, color: textDark)),
    );
  }

  Widget buildTopButton(String title,
      IconData icon,
      VoidCallback onTap, {
        Color iconColor = primaryColor,
        bool hasNotification = false,
      }) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(icon, color: iconColor, size: 26),
                ),
                if (hasNotification)
                  Positioned(
                    right: -2, top: -2,
                    child: Container(
                      width: 12, height: 12,
                      decoration: BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                          border: Border.all(color: bgColor, width: 2)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            FittedBox(
              child: Text(title,
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: textDark)),
            ),
          ],
        ),
      ),
    );
  }


  // ─────────────────────────────────────────────
  // DELETE announcement
  // ─────────────────────────────────────────────
  Future<void> _deleteAnnouncement(BuildContext dialogContext,
      String id) async {
    Navigator.pop(dialogContext);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) =>
          AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22)),
            title: const Text("Delete Announcement"),
            content: const Text(
                "Are you sure you want to delete this announcement? This cannot be undone."),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text(
                      "Cancel", style: TextStyle(color: Colors.grey))),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12))),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text(
                    "Delete", style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
    );

    if (confirmed != true) return;

    try {
      await supabase.from('announcements').delete().eq('id', id);
      fetchAnnouncements();
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("Announcement deleted."),
            backgroundColor: Colors.red));
    } catch (e) {
      debugPrint("Delete Error: $e");
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("Failed to delete."), backgroundColor: Colors.red));
    }
  }

  // ─────────────────────────────────────────────
  // EDIT announcement
  // ─────────────────────────────────────────────
  void _showEditAnnouncementSheet(BuildContext dialogContext,
      Map<String, dynamic> data) {
    Navigator.pop(dialogContext);

    final titleController = TextEditingController(text: data['title']);
    final contentController = TextEditingController(text: data['content']);
    DateTime? selectedDate = data['event_date'] != null
        ? DateTime.parse(data['event_date']).toLocal() : null;
    bool isUrgent = data['is_urgent'] ?? false;
    String selectedCategory = data['category'] ?? 'General';
    File? newImageFile;
    String? existingImageUrl = data['image_url'];
    bool isUploading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          StatefulBuilder(
            builder: (context, setModalState) =>
                Container(
                  padding: EdgeInsets.only(
                      bottom: MediaQuery
                          .of(context)
                          .viewInsets
                          .bottom,
                      top: 25, left: 20, right: 20),
                  decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(
                          top: Radius.circular(25))),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Center(
                            child: Text("Edit Announcement",
                                style: TextStyle(fontSize: 18,
                                    fontWeight: FontWeight.bold))),
                        const SizedBox(height: 20),

                        GestureDetector(
                          onTap: () async {
                            final XFile? pickedFile = await _picker.pickImage(
                                source: ImageSource.gallery, imageQuality: 70);
                            if (pickedFile != null)
                              setModalState(() =>
                              newImageFile = File(pickedFile.path));
                          },
                          child: Stack(
                            children: [
                              Container(
                                height: 140, width: double.infinity,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF9F9F9),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                      color: const Color(0xFFE0E0E0)),
                                ),
                                child: newImageFile != null
                                    ? ClipRRect(
                                    borderRadius: BorderRadius.circular(14),
                                    child: Image.file(
                                        newImageFile!, fit: BoxFit.cover,
                                        width: double.infinity))
                                    : existingImageUrl != null
                                    ? ClipRRect(
                                    borderRadius: BorderRadius.circular(14),
                                    child: Image.network(
                                        existingImageUrl!, fit: BoxFit.cover,
                                        width: double.infinity))
                                    : const Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.add_photo_alternate_outlined,
                                        color: Colors.grey, size: 40),
                                    SizedBox(height: 8),
                                    Text("Add Photo (Optional)",
                                        style: TextStyle(
                                            color: Colors.grey, fontSize: 13)),
                                  ],
                                ),
                              ),
                              if (newImageFile != null ||
                                  existingImageUrl != null)
                                Positioned(
                                  top: 8, right: 8,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                        color: Colors.black54,
                                        borderRadius: BorderRadius.circular(
                                            20)),
                                    child: const Text("Change",
                                        style: TextStyle(
                                            color: Colors.white, fontSize: 11)),
                                  ),
                                ),
                              if (newImageFile != null ||
                                  existingImageUrl != null)
                                Positioned(
                                  top: 8, left: 8,
                                  child: GestureDetector(
                                    onTap: () =>
                                        setModalState(() {
                                          newImageFile = null;
                                          existingImageUrl = null;
                                        }),
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: const BoxDecoration(
                                          color: Colors.red,
                                          shape: BoxShape.circle),
                                      child: const Icon(
                                          Icons.close, color: Colors.white,
                                          size: 14),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 15),

                        TextField(
                            controller: titleController,
                            decoration: InputDecoration(
                                labelText: "Title",
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                        color: primaryColor)))),
                        const SizedBox(height: 15),
                        TextField(
                            controller: contentController,
                            maxLines: 3,
                            decoration: InputDecoration(
                                labelText: "Message",
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                        color: primaryColor)))),
                        const SizedBox(height: 15),

                        DropdownButtonFormField<String>(
                          value: selectedCategory,
                          decoration: InputDecoration(
                              labelText: "Category",
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12))),
                          items: ['Notice', 'Maintenance', 'Event', 'General']
                              .map((v) =>
                              DropdownMenuItem<String>(value: v, child: Text(
                                  v)))
                              .toList(),
                          onChanged: (val) =>
                              setModalState(() => selectedCategory = val!),
                        ),

                        const SizedBox(height: 15),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            TextButton.icon(
                              onPressed: () async {
                                final picked = await showDatePicker(
                                    context: context,
                                    initialDate: selectedDate ?? DateTime.now(),
                                    firstDate: DateTime(2020),
                                    lastDate: DateTime(2030));
                                if (picked != null) setModalState(() =>
                                selectedDate = picked);
                              },
                              icon: const Icon(
                                  Icons.calendar_month, color: primaryColor),
                              label: Text(selectedDate == null
                                  ? "Set Event Date"
                                  : "${selectedDate!.day}/${selectedDate!
                                  .month}/${selectedDate!.year}"),
                            ),
                            Row(children: [
                              const Text("Urgent", style: TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold)),
                              Switch(value: isUrgent, activeColor: Colors.red,
                                  onChanged: (val) =>
                                      setModalState(() => isUrgent = val)),
                            ]),
                          ],
                        ),
                        const SizedBox(height: 20),

                        SizedBox(
                          width: double.infinity, height: 50,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                                backgroundColor: primaryColor,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14))),
                            onPressed: isUploading ? null : () async {
                              if (titleController.text.isEmpty ||
                                  contentController.text.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text(
                                        "Title and Message required")));
                                return;
                              }
                              setModalState(() => isUploading = true);
                              try {
                                String? finalImageUrl = existingImageUrl;
                                if (newImageFile != null) {
                                  final fileName = '${DateTime
                                      .now()
                                      .millisecondsSinceEpoch}.jpg';
                                  final path = 'public/$fileName';
                                  await supabase.storage.from(
                                      'announcement_images').upload(
                                      path, newImageFile!);
                                  finalImageUrl = supabase.storage.from(
                                      'announcement_images').getPublicUrl(path);
                                }
                                await supabase.from('announcements').update({
                                  'title': titleController.text,
                                  'content': contentController.text,
                                  'category': selectedCategory,
                                  'event_date': selectedDate?.toIso8601String(),
                                  'is_urgent': isUrgent,
                                  'image_url': finalImageUrl,
                                }).eq('id', data['id']);
                                if (context.mounted) {
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content: Text(
                                              "Announcement updated!"),
                                          backgroundColor: Colors.green));
                                  fetchAnnouncements();
                                }
                              } catch (e) {
                                debugPrint("Edit Error: $e");
                                if (context.mounted)
                                  ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content: Text("Failed to update."),
                                          backgroundColor: Colors.red));
                              } finally {
                                setModalState(() => isUploading = false);
                              }
                            },
                            child: isUploading
                                ? const SizedBox(height: 20, width: 20,
                                child: CircularProgressIndicator(color: Colors
                                    .white, strokeWidth: 2))
                                : const Text("Save Changes",
                                style: TextStyle(color: Colors.white,
                                    fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(height: 30),
                      ],
                    ),
                  ),
                ),
          ),
    );
  }

  // ─────────────────────────────────────────────
  // VIEW announcement detail
  // ─────────────────────────────────────────────
  void _showAnnouncementDetails(Map<String, dynamic> data) {
    final dt = data['event_date'] != null
        ? DateTime.parse(data['event_date']).toLocal() : null;
    final dateDisplay = dt != null
        ? "${dt.day}/${dt.month}/${dt.year}"
        : "No specific date";
    final bool hasImage = data['image_url'] != null;

    showDialog(
      context: context,
      builder: (dialogContext) =>
          AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22)),
            contentPadding: EdgeInsets.zero,
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (hasImage)
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(22)),
                    child: Image.network(data['image_url'],
                        width: double.infinity, height: 180, fit: BoxFit.cover),
                  ),
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Icon(data['is_urgent'] ? Icons.warning : Icons.campaign,
                            color: data['is_urgent']
                                ? Colors.red
                                : primaryColor),
                        const SizedBox(width: 10),
                        Expanded(
                            child: Text(data['title'],
                                style: const TextStyle(fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: textDark))),
                      ]),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                            color: primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20)),
                        child: Text(data['category'] ?? '',
                            style: const TextStyle(
                                color: primaryColor,
                                fontWeight: FontWeight.w600,
                                fontSize: 12)),
                      ),
                      const SizedBox(height: 8),
                      Row(children: [
                        const Icon(Icons.calendar_today_outlined, size: 13,
                            color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(dateDisplay, style: const TextStyle(
                            color: Colors.grey, fontSize: 12)),
                      ]),
                      const Divider(height: 24),
                      Text(data['content'],
                          style: const TextStyle(fontSize: 14, height: 1.6)),
                    ],
                  ),
                ),
              ],
            ),
            actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            actions: [
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.pop(dialogContext),
                    icon: const Icon(Icons.close, size: 16, color: Colors.grey),
                    label: const Text(
                        "Close", style: TextStyle(color: Colors.grey)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.grey, width: 1),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        _showEditAnnouncementSheet(dialogContext, data),
                    icon: const Icon(
                        Icons.edit_outlined, size: 16, color: primaryColor),
                    label: const Text(
                        "Edit", style: TextStyle(color: primaryColor)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: primaryColor, width: 1),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        _deleteAnnouncement(dialogContext, data['id']),
                    icon: const Icon(
                        Icons.delete_outline, size: 16, color: Colors.red),
                    label: const Text(
                        "Delete", style: TextStyle(color: Colors.red)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red, width: 1),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ]),
            ],
          ),
    );
  }

  // ─────────────────────────────────────────────
  // NEW HEADER WIDGET
  // ─────────────────────────────────────────────
  Widget _buildDashboardHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 26),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFF4E2A23), // 深棕
            Color(0xFF7B3F33), // 中棕
            Color(0xFFA45A44), // 浅棕
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          // 👤 Avatar
          CircleAvatar(
            radius: 26,
            backgroundColor: Colors.white24,
            backgroundImage:
            adminAvatarUrl != null ? NetworkImage(adminAvatarUrl!) : null,
            child: adminAvatarUrl == null
                ? const Icon(Icons.person, color: Colors.white, size: 26)
                : null,
          ),

          const SizedBox(width: 14),

          // 👋 Text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Hello $adminName !!",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
              ],
            ),
          ),

          // 🔔 Notification (这里加了点击事件)
          GestureDetector(
            onTap: () {
              // 🔥 点击跳转到 AdminNotificationsPage
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AdminNotificationsPage(),
                ),
              );
            },
            child: Stack(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: const Icon(
                    Icons.notifications_outlined,
                    color: Colors.white,
                    size: 24,
                  ),
                ),

                if (hasUserNotif ||
                    hasEventNotif ||
                    hasFacilityNotif ||
                    hasVisitorNotif ||
                    hasEmergencyNotif)
                  Positioned(
                    right: -1,
                    top: -1,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFF7B3F33), width: 2),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void showCreateAnnouncementSheet(BuildContext context) {
    final titleController = TextEditingController();
    final contentController = TextEditingController();
    DateTime? selectedDate;
    bool isUrgent = false;
    String selectedCategory = 'Notice';
    File? imageFile;
    bool isUploading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              top: 25,
              left: 20,
              right: 20),
          decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Center(
                  child: Text("Create Announcement",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textDark)),
                ),
                const SizedBox(height: 20),

                // 图片选择区域
                GestureDetector(
                  onTap: () async {
                    final XFile? pickedFile = await _picker.pickImage(
                        source: ImageSource.gallery, imageQuality: 70);
                    if (pickedFile != null) {
                      setModalState(() => imageFile = File(pickedFile.path));
                    }
                  },
                  child: Container(
                    height: 160,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9F9F9),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE0E0E0)),
                    ),
                    child: imageFile == null
                        ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_photo_alternate_outlined, color: Colors.grey.shade400, size: 45),
                        const SizedBox(height: 8),
                        const Text("Add Cover Photo", style: TextStyle(color: Colors.grey, fontSize: 13)),
                      ],
                    )
                        : ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.file(imageFile!, fit: BoxFit.cover, width: double.infinity),
                    ),
                  ),
                ),
                const SizedBox(height: 15),

                // 标题输入
                TextField(
                    controller: titleController,
                    decoration: InputDecoration(
                        labelText: "Title",
                        labelStyle: const TextStyle(color: Colors.grey),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: primaryColor)))),
                const SizedBox(height: 15),

                // 内容输入
                TextField(
                    controller: contentController,
                    maxLines: 4,
                    decoration: InputDecoration(
                        labelText: "Message",
                        alignLabelWithHint: true,
                        labelStyle: const TextStyle(color: Colors.grey),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: primaryColor)))),
                const SizedBox(height: 15),

                // 类别选择
                DropdownButtonFormField<String>(
                  value: selectedCategory,
                  decoration: InputDecoration(
                      labelText: "Category",
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                  items: ['Notice', 'Maintenance', 'Event', 'General']
                      .map((v) => DropdownMenuItem<String>(value: v, child: Text(v)))
                      .toList(),
                  onChanged: (val) => setModalState(() => selectedCategory = val!),
                ),

                const SizedBox(height: 15),

                // 日期与紧急程度
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton.icon(
                      onPressed: () async {
                        final picked = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now(),
                            firstDate: DateTime.now(),
                            lastDate: DateTime(2030));
                        if (picked != null) setModalState(() => selectedDate = picked);
                      },
                      icon: const Icon(Icons.calendar_month, color: primaryColor),
                      label: Text(
                        selectedDate == null
                            ? "Set Event Date"
                            : "${selectedDate!.day}/${selectedDate!.month}/${selectedDate!.year}",
                        style: const TextStyle(color: primaryColor, fontWeight: FontWeight.bold),
                      ),
                    ),
                    Row(children: [
                      const Text("Urgent", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                      Switch(
                          value: isUrgent,
                          activeColor: Colors.red,
                          onChanged: (val) => setModalState(() => isUrgent = val)),
                    ]),
                  ],
                ),
                const SizedBox(height: 20),

                // 发布按钮
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                    onPressed: isUploading ? null : () async {
                      if (titleController.text.trim().isEmpty || contentController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Please fill in Title and Message")));
                        return;
                      }

                      setModalState(() => isUploading = true);
                      try {
                        String? imageUrl;
                        // 1. 如果有图片，先上传到存储桶
                        if (imageFile != null) {
                          final fileName = 'ann_${DateTime.now().millisecondsSinceEpoch}.jpg';
                          final path = 'public/$fileName';
                          await supabase.storage.from('announcement_images').upload(path, imageFile!);
                          imageUrl = supabase.storage.from('announcement_images').getPublicUrl(path);
                        }

                        // 2. 写入数据库
                        await supabase.from('announcements').insert({
                          'title': titleController.text.trim(),
                          'content': contentController.text.trim(),
                          'category': selectedCategory,
                          'event_date': selectedDate?.toIso8601String(),
                          'is_urgent': isUrgent,
                          if (imageUrl != null) 'image_url': imageUrl,
                        });

                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                              content: Text("Announcement published!"), backgroundColor: Colors.green));

                          // 如果你需要刷新 Dashboard 页面，可以在这里发送通知或调用刷新逻辑
                        }
                      } catch (e) {
                        debugPrint("Upload Error: $e");
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                              content: Text("Failed to publish. Check your connection."), backgroundColor: Colors.red));
                        }
                      } finally {
                        setModalState(() => isUploading = false);
                      }
                    },
                    child: isUploading
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text("Publish Now", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: refreshAllData,
          child: ListView(
            padding: EdgeInsets.zero,
            children: [

              /// HEADER（全宽）
              _buildDashboardHeader(),

              /// CONTENT
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    buildSectionTitle("Management"),

                    const SizedBox(height: 16),

                    /// TOP BUTTONS
                    Row(
                      children: [
                        buildTopButton(
                          "Users",
                          Icons.person_outline,
                              () => navigateTo("Users"),
                          iconColor: const Color(0xFF758BFD),
                          hasNotification: hasUserNotif,
                        ),
                        const SizedBox(width: 6),

                        buildTopButton(
                          "Event",
                          Icons.event_note_outlined,
                              () => navigateTo("Event"),
                          iconColor: const Color(0xFF4BC0B8),
                          hasNotification: hasEventNotif,
                        ),
                        const SizedBox(width: 6),

                        buildTopButton(
                          "Facilities",
                          Icons.home_work_outlined,
                              () => navigateTo("Facilities"),
                          iconColor: primaryColor,
                          hasNotification: hasFacilityNotif,
                        ),
                        const SizedBox(width: 6),

                        buildTopButton(
                          "Visitor",
                          Icons.badge_outlined,
                              () => navigateTo("Visitor"),
                          iconColor: const Color(0xFFE96B9E),
                          hasNotification: hasVisitorNotif,
                        ),
                        const SizedBox(width: 6),

                        buildTopButton(
                          "Emergency",
                          Icons.warning_amber_rounded,
                              () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const EmergencyListPage(),
                              ),
                            ).then((_) => refreshAllData());
                          },
                          iconColor: const Color(0xFFFF5A5A),
                          hasNotification: hasEmergencyNotif,
                        ),
                      ],
                    ),

                    const SizedBox(height: 30),

                    /// ANNOUNCEMENT HEADER
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        buildSectionTitle("Announcements"),

                        // 🔥 换成了 View All 按钮
                        TextButton(
                          onPressed: () {
                            // 跳转到全部公告列表页
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const AnnouncementListPage(),
                              ),
                            );
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: primaryColor,
                            backgroundColor: primaryColor.withOpacity(0.1),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                "View All",
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              SizedBox(width: 4),
                              Icon(Icons.arrow_forward_ios_rounded, size: 12), // 向右的小箭头
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    /// ANNOUNCEMENTS LIST
                    if (announcements.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(40),
                        child: Center(
                          child: Text(
                            "No announcements yet.",
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      )
                    else
                      ...announcements.map((item) {
                        final bool urgent = item['is_urgent'] ?? false;
                        final bool hasImage = item['image_url'] != null;

                        return GestureDetector(
                          onTap: () => _showAnnouncementDetails(item),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(22),
                              border: urgent
                                  ? Border.all(
                                color: Colors.red.withOpacity(0.35),
                                width: 1.5,
                              )
                                  : null,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.04),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                hasImage
                                    ? ClipOval(
                                  child: Image.network(
                                    item['image_url'],
                                    width: 46,
                                    height: 46,
                                    fit: BoxFit.cover,
                                  ),
                                )
                                    : Container(
                                  width: 46,
                                  height: 46,
                                  decoration: BoxDecoration(
                                    color: (urgent
                                        ? Colors.red
                                        : primaryColor)
                                        .withOpacity(0.12),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    urgent
                                        ? Icons.priority_high
                                        : Icons.campaign_outlined,
                                    color: urgent
                                        ? Colors.red
                                        : primaryColor,
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item['title'],
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 15,
                                          color: textDark,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        item['content'],
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.black54,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Icon(
                                  Icons.chevron_right,
                                  color: Colors.black26,
                                  size: 20,
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}