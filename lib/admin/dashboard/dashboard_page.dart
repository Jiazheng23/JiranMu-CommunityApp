import 'dart:io';
import 'package:assignment/admin/emergency/emergency_list_page.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:assignment/admin/AdminVisitorPassScreen.dart';
import 'package:assignment/admin/request/request_list_page.dart';
import 'package:image_picker/image_picker.dart';
import 'admin_announcement_detail_page.dart';
import 'admin_announcement_page.dart';
import 'admin_notifications_page.dart';
import 'manage_facility_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage>
    with TickerProviderStateMixin {
  final supabase = Supabase.instance.client;
  final ImagePicker _picker = ImagePicker();

  // ── Palette ───────────────────────────────────────────────────────────────
  static const Color bg = Color(0xFFF7F5F2);
  static const Color primary = Color(0xFF8B3A2A);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color textDark = Color(0xFF1A1614);
  static const Color textMid = Color(0xFF6B6460);
  static const Color textLight = Color(0xFFADA8A5);
  static const Color border = Color(0xFFEDE9E5);
  static const Color cardShadow = Color(0x0A000000);

  static const Color chartBlue = Color(0xFF4B7CF3);
  static const Color chartTeal = Color(0xFF2DBFAD);
  static const Color chartRose = Color(0xFFD95B6B);
  static const Color chartAmber = Color(0xFFE8961A);
  static const Color chartGreen = Color(0xFF3DB87A);
  static const Color chartRed = Color(0xFFE85040);

  // ── State ─────────────────────────────────────────────────────────────────
  bool _loading = true;
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  bool hasUserNotif = false;
  bool hasEventNotif = false;
  bool hasFacilityNotif = false;
  bool hasVisitorNotif = false;
  bool hasEmergencyNotif = false;

  int pendingTotal = 0;
  int approvedToday = 0;
  int totalResidents = 0;
  int totalRequestsThisWeek = 0;

  List<Map<String, dynamic>> recentActivity = [];
  List<Map<String, dynamic>> activeEmergencies = [];
  List<dynamic> announcements = [];

  List<Map<String, dynamic>> facilityOverview = [];
  List<Map<String, dynamic>> weekSchedule = [];

  String adminName = 'Admin';
  String? adminAvatarUrl;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fetchAdminProfile();
    refreshAllData();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  // ── FETCH ─────────────────────────────────────────────────────────────────

  Future<void> _fetchAdminProfile() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;
      final data = await supabase
          .from('admin_new')
          .select('full_name, image_url')
          .eq('id', user.id)
          .single();
      if (mounted)
        setState(() {
          adminName = data['full_name'] ?? 'Admin';
          adminAvatarUrl = data['image_url'];
        });
    } catch (e) {
      debugPrint("Admin profile error: $e");
    }
  }

  Future<void> refreshAllData() async {
    setState(() => _loading = true);
    _fadeCtrl.reset();
    await Future.wait([
      fetchNotificationStatus(),
      fetchAnnouncements(),
      _fetchSummaryStats(),
      _fetchFacilityOverview(),
      _fetchWeekSchedule(),
      _fetchRecentActivity(),
      _fetchActiveEmergencies(),
    ]);
    if (mounted) {
      setState(() => _loading = false);
      _fadeCtrl.forward();
    }
  }

  Future<void> fetchAnnouncements() async {
    try {
      final r = await supabase
          .from('announcements')
          .select()
          .order('created_at', ascending: false)
          .limit(3);
      if (mounted) setState(() => announcements = r);
    } catch (e) {
      debugPrint("Announcements error: $e");
    }
  }

  Future<void> fetchNotificationStatus() async {
    try {
      // 1. Fetch pending requests from the main 'requests' table
      final req = await supabase
          .from('requests')
          .select('type')
          .eq('status', 'pending');

      // 2. Fetch unresolved emergencies
      final emg = await supabase
          .from('emergency')
          .select('emergency_id')
          .neq('status', 'solved');

      // 3. Fetch pending visitor passes directly from the 'visitor_passes' table
      final passes = await supabase
          .from('visitor_passes')
          .select('id')
          .eq('status', 'pending');

      if (mounted) {
        setState(() {
          hasUserNotif = req.any((r) => r['type'] == 'admin' || r['type'] == 'resident');
          hasEventNotif = req.any((r) => r['type'] == 'booking');
          hasFacilityNotif = req.any((r) => r['type'] == 'facility');
          hasVisitorNotif = req.any((r) => r['type'] == 'visitor') || passes.isNotEmpty;
          hasEmergencyNotif = emg.isNotEmpty;
        });
      }
    } catch (e) {
      debugPrint("Notification error: $e");
    }
  }

  void navigateTo(String type) {
    if (type.toLowerCase() == 'visitor') {
      Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => const AdminVisitorPassScreen()))
          .then((_) => refreshAllData());
    } else {
      Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => RequestListPage(type: type)))
          .then((_) => refreshAllData());
    }
  }

  Future<void> _fetchSummaryStats() async {
    try {
      final today = DateTime.now();
      final todayStr =
      DateTime(today.year, today.month, today.day).toIso8601String();
      final weekAgo = today.subtract(const Duration(days: 7)).toIso8601String();
      final allReq = await supabase.from('requests').select('status, created_at');
      final res =
      await supabase.from('resident').select('id').eq('status', 'active');
      int pending = 0, approved = 0, weekCount = 0;
      for (final r in allReq) {
        if (r['status'] == 'pending') pending++;
        final c = r['created_at']?.toString() ?? '';
        if (c.compareTo(todayStr) >= 0 && r['status'] == 'approved') approved++;
        if (c.compareTo(weekAgo) >= 0) weekCount++;
      }
      if (mounted)
        setState(() {
          pendingTotal = pending;
          approvedToday = approved;
          totalResidents = res.length;
          totalRequestsThisWeek = weekCount;
        });
    } catch (e) {
      debugPrint("Summary stats error: $e");
    }
  }

  Future<void> _fetchFacilityOverview() async {
    try {
      // Fetch all facilities regardless of active status
      final d = await supabase
          .from('facilities')
          .select('id, name, capacity, is_active')
          .order('name');

      // Sum participants from approved bookings today per facility
      final today = DateTime.now().toIso8601String().substring(0, 10);
      final bookings = await supabase
          .from('facility_bookings')
          .select('facility_id, participants')
          .eq('booking_date', today)
          .eq('status', 'approved');

      // Sum participants (not row count) per facility_id
      final Map<String, int> usedMap = {};
      for (final b in bookings) {
        final fid = b['facility_id']?.toString() ?? '';
        final p = (b['participants'] as num?)?.toInt() ?? 1;
        if (fid.isNotEmpty) usedMap[fid] = (usedMap[fid] ?? 0) + p;
      }

      if (mounted) {
        setState(() {
          facilityOverview = List<Map<String, dynamic>>.from(d).map((f) {
            final fid = f['id']?.toString() ?? '';
            final cap = (f['capacity'] as num?)?.toInt() ?? 1;
            final used = usedMap[fid] ?? 0;
            return {...f, 'used': used, 'capacity': cap};
          }).toList();
        });
      }
    } catch (e) {
      debugPrint("Facility overview error: $e");
    }
  }

  // ── UPDATED: fetch from events table ─────────────────────────────────────
  Future<void> _fetchWeekSchedule() async {
    try {
      final now = DateTime.now();
      final weekEnd = now.add(const Duration(days: 7));

      final events = await supabase
          .from('events')
          .select(
          'id, title, description, location, event_date, start_time, '
              'end_time, image_url, is_private, max_capacity, participants')
          .gte('event_date', now.toIso8601String().substring(0, 10))
          .lte('event_date', weekEnd.toIso8601String().substring(0, 10))
          .order('event_date')
          .order('start_time')
          .limit(8);

      if (mounted)
        setState(
                () => weekSchedule = List<Map<String, dynamic>>.from(events));
    } catch (e) {
      debugPrint("Week schedule error: $e");
    }
  }

  Future<void> _fetchRecentActivity() async {
    try {
      final d = await supabase
          .from('requests')
          .select('request_id, type, status, created_at, title')
          .order('created_at', ascending: false)
          .limit(6);
      if (mounted)
        setState(() => recentActivity = List<Map<String, dynamic>>.from(d));
    } catch (e) {
      debugPrint("Activity error: $e");
    }
  }

  Future<void> _fetchActiveEmergencies() async {
    try {
      final d = await supabase
          .from('emergency')
          .select('emergency_id, title, description, status, created_at')
          .neq('status', 'solved')
          .order('created_at', ascending: false)
          .limit(3);
      if (mounted)
        setState(
                () => activeEmergencies = List<Map<String, dynamic>>.from(d));
    } catch (e) {
      debugPrint("Emergency error: $e");
    }
  }

  // ── Announcement CRUD ─────────────────────────────────────────────────────

  Future<void> _deleteAnnouncement(BuildContext dCtx, String id) async {
    Navigator.pop(dCtx);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Delete Announcement",
            style: TextStyle(fontWeight: FontWeight.w700, color: textDark)),
        content: const Text("Are you sure? This cannot be undone.",
            style: TextStyle(color: textMid)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child:
              const Text("Cancel", style: TextStyle(color: textMid))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: chartRed,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Delete",
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await supabase.from('announcements').delete().eq('id', id);
      fetchAnnouncements();
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("Deleted."), backgroundColor: chartRed));
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("Failed to delete."), backgroundColor: chartRed));
    }
  }

  void _showEditAnnouncementSheet(
      BuildContext dCtx, Map<String, dynamic> data) {
    Navigator.pop(dCtx);
    final tCtrl = TextEditingController(text: data['title']);
    final cCtrl = TextEditingController(text: data['content']);
    DateTime? date = data['event_date'] != null
        ? DateTime.parse(data['event_date']).toLocal()
        : null;
    bool urgent = data['is_urgent'] ?? false;
    String cat = data['category'] ?? 'General';
    File? newImg;
    String? exUrl = data['image_url'];
    bool uploading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
          builder: (ctx, set) => _sheet(
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _handle(),
                  const Text("Edit Announcement",
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: textDark)),
                  const SizedBox(height: 16),
                  _imgPick(newImg, exUrl,
                      onTap: () async {
                        final f = await _picker.pickImage(
                            source: ImageSource.gallery,
                            imageQuality: 70);
                        if (f != null) set(() => newImg = File(f.path));
                      },
                      onRm: () => set(() {
                        newImg = null;
                        exUrl = null;
                      })),
                  const SizedBox(height: 12),
                  _tf(tCtrl, "Title"),
                  const SizedBox(height: 10),
                  _tf(cCtrl, "Message", lines: 3),
                  const SizedBox(height: 10),
                  _dd(cat, (v) => set(() => cat = v!)),
                  const SizedBox(height: 10),
                  _dateUrgent(date, urgent,
                      onDate: () async {
                        final p = await showDatePicker(
                            context: ctx,
                            initialDate: date ?? DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2030));
                        if (p != null) set(() => date = p);
                      },
                      onUrgent: (v) => set(() => urgent = v)),
                  const SizedBox(height: 16),
                  _btn(uploading, "Save Changes", () async {
                    if (tCtrl.text.isEmpty || cCtrl.text.isEmpty) return;
                    set(() => uploading = true);
                    try {
                      String? finalUrl = exUrl;
                      if (newImg != null) {
                        final path =
                            'public/${DateTime.now().millisecondsSinceEpoch}.jpg';
                        await supabase.storage
                            .from('announcement_images')
                            .upload(path, newImg!);
                        finalUrl = supabase.storage
                            .from('announcement_images')
                            .getPublicUrl(path);
                      }
                      await supabase.from('announcements').update({
                        'title': tCtrl.text,
                        'content': cCtrl.text,
                        'category': cat,
                        'event_date': date?.toIso8601String(),
                        'is_urgent': urgent,
                        'image_url': finalUrl,
                      }).eq('id', data['id']);
                      if (ctx.mounted) {
                        Navigator.pop(ctx);
                        fetchAnnouncements();
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text("Updated!"),
                                backgroundColor: chartGreen));
                      }
                    } catch (e) {
                      if (ctx.mounted)
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text("Failed."),
                                backgroundColor: chartRed));
                    } finally {
                      set(() => uploading = false);
                    }
                  }),
                  const SizedBox(height: 28),
                ]),
          )),
    );
  }

  void showCreateAnnouncementSheet(BuildContext context) {
    final tCtrl = TextEditingController();
    final cCtrl = TextEditingController();
    DateTime? date;
    bool urgent = false;
    String cat = 'Notice';
    File? imgFile;
    bool uploading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
          builder: (ctx, set) => _sheet(
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _handle(),
                  const Text("New Announcement",
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: textDark)),
                  const SizedBox(height: 16),
                  _imgPick(imgFile, null,
                      onTap: () async {
                        final f = await _picker.pickImage(
                            source: ImageSource.gallery,
                            imageQuality: 70);
                        if (f != null) set(() => imgFile = File(f.path));
                      },
                      onRm: () => set(() => imgFile = null)),
                  const SizedBox(height: 12),
                  _tf(tCtrl, "Title"),
                  const SizedBox(height: 10),
                  _tf(cCtrl, "Message", lines: 4),
                  const SizedBox(height: 10),
                  _dd(cat, (v) => set(() => cat = v!)),
                  const SizedBox(height: 10),
                  _dateUrgent(date, urgent,
                      onDate: () async {
                        final p = await showDatePicker(
                            context: ctx,
                            initialDate: DateTime.now(),
                            firstDate: DateTime.now(),
                            lastDate: DateTime(2030));
                        if (p != null) set(() => date = p);
                      },
                      onUrgent: (v) => set(() => urgent = v)),
                  const SizedBox(height: 16),
                  _btn(uploading, "Publish Now", () async {
                    if (tCtrl.text.trim().isEmpty ||
                        cCtrl.text.trim().isEmpty) return;
                    set(() => uploading = true);
                    try {
                      String? imgUrl;
                      if (imgFile != null) {
                        final path =
                            'public/ann_${DateTime.now().millisecondsSinceEpoch}.jpg';
                        await supabase.storage
                            .from('announcement_images')
                            .upload(path, imgFile!);
                        imgUrl = supabase.storage
                            .from('announcement_images')
                            .getPublicUrl(path);
                      }
                      await supabase.from('announcements').insert({
                        'title': tCtrl.text.trim(),
                        'content': cCtrl.text.trim(),
                        'category': cat,
                        'event_date': date?.toIso8601String(),
                        'is_urgent': urgent,
                        if (imgUrl != null) 'image_url': imgUrl,
                      });
                      if (ctx.mounted) {
                        Navigator.pop(ctx);
                        fetchAnnouncements();
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text("Published!"),
                                backgroundColor: chartGreen));
                      }
                    } catch (e) {
                      if (ctx.mounted)
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text("Failed."),
                                backgroundColor: chartRed));
                    } finally {
                      set(() => uploading = false);
                    }
                  }),
                  const SizedBox(height: 10),
                ]),
          )),
    );
  }

  // ── Sheet helpers ─────────────────────────────────────────────────────────
  Widget _sheet({required Widget child}) => Container(
    padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        top: 20,
        left: 20,
        right: 20),
    decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    child: SingleChildScrollView(child: child),
  );

  Widget _handle() => Center(
      child: Container(
          width: 40,
          height: 4,
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2))));

  InputDecoration _dec(String l) => InputDecoration(
    labelText: l,
    labelStyle: const TextStyle(color: textMid, fontSize: 13),
    filled: true,
    fillColor: const Color(0xFFF8F6F3),
    border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: border)),
    enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: border)),
    focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: primary, width: 1.5)),
    contentPadding:
    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
  );

  Widget _tf(TextEditingController c, String l, {int lines = 1}) => TextField(
      controller: c,
      maxLines: lines,
      style: const TextStyle(fontSize: 14, color: textDark),
      decoration: _dec(l));

  Widget _dd(String val, ValueChanged<String?> onChange) =>
      DropdownButtonFormField<String>(
          value: val,
          decoration: _dec("Category"),
          items: ['Notice', 'Maintenance', 'Event', 'General']
              .map((v) => DropdownMenuItem(value: v, child: Text(v)))
              .toList(),
          onChanged: onChange);

  Widget _dateUrgent(DateTime? d, bool u,
      {required VoidCallback onDate,
        required ValueChanged<bool> onUrgent}) =>
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        TextButton.icon(
            onPressed: onDate,
            icon: const Icon(Icons.calendar_month_outlined,
                color: primary, size: 15),
            label: Text(
                d == null
                    ? "Set Event Date"
                    : "${d.day}/${d.month}/${d.year}",
                style: const TextStyle(color: primary, fontSize: 13))),
        Row(children: [
          Text("Urgent",
              style: TextStyle(
                  color: chartRed,
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
          Switch(value: u, activeColor: chartRed, onChanged: onUrgent),
        ]),
      ]);

  Widget _imgPick(File? f, String? url,
      {required VoidCallback onTap, required VoidCallback onRm}) =>
      GestureDetector(
          onTap: onTap,
          child: Stack(children: [
            Container(
              height: 110,
              width: double.infinity,
              decoration: BoxDecoration(
                  color: const Color(0xFFF5F3F0),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: border)),
              child: f != null
                  ? ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.file(f,
                      fit: BoxFit.cover, width: double.infinity))
                  : url != null
                  ? ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.network(url,
                      fit: BoxFit.cover, width: double.infinity))
                  : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_photo_alternate_outlined,
                        color: Colors.grey.shade400, size: 30),
                    const SizedBox(height: 6),
                    Text("Tap to add photo",
                        style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 12)),
                  ]),
            ),
            if (f != null || url != null) ...[
              Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 3),
                      decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(20)),
                      child: const Text("Change",
                          style:
                          TextStyle(color: Colors.white, fontSize: 11)))),
              Positioned(
                  top: 8,
                  left: 8,
                  child: GestureDetector(
                      onTap: onRm,
                      child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                              color: chartRed, shape: BoxShape.circle),
                          child: const Icon(Icons.close,
                              color: Colors.white, size: 13)))),
            ],
          ]));

  Widget _btn(bool loading, String label, VoidCallback onTap) => SizedBox(
    width: double.infinity,
    height: 50,
    child: ElevatedButton(
      style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          elevation: 0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14))),
      onPressed: loading ? null : onTap,
      child: loading
          ? const SizedBox(
          height: 18,
          width: 18,
          child: CircularProgressIndicator(
              color: Colors.white, strokeWidth: 2))
          : Text(label,
          style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 15)),
    ),
  );

  // ─────────────────────────────────────────────────────────────────────────
  // UI SECTIONS
  // ─────────────────────────────────────────────────────────────────────────

  // ── 1. Header ─────────────────────────────────────────────────────────────
  Widget _header() {
    final hasAny = hasUserNotif ||
        hasEventNotif ||
        hasFacilityNotif ||
        hasVisitorNotif ||
        hasEmergencyNotif;
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF5C1F14), Color(0xFF8B3A2A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      child: Column(children: [
        Row(children: [
          GestureDetector(
            onTap: () {},
            child: Container(
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: Colors.white.withOpacity(0.3), width: 2)),
              child: CircleAvatar(
                radius: 24,
                backgroundColor: Colors.white.withOpacity(0.15),
                backgroundImage: adminAvatarUrl != null
                    ? NetworkImage(adminAvatarUrl!)
                    : null,
                child: adminAvatarUrl == null
                    ? const Icon(Icons.person_outline,
                    color: Colors.white, size: 24)
                    : null,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Good ${_greeting()},",
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.6), fontSize: 12)),
                    const SizedBox(height: 2),
                    Text(adminName,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3)),
                  ])),
          GestureDetector(
            onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const AdminNotificationsPage())),
            child: Stack(children: [
              Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: Colors.white.withOpacity(0.15))),
                  child: const Icon(Icons.notifications_outlined,
                      color: Colors.white, size: 20)),
              if (hasAny)
                Positioned(
                    right: 9,
                    top: 9,
                    child: Container(
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(
                            color: const Color(0xFFFF5252),
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: const Color(0xFF5C1F14), width: 1.5)))),
            ]),
          ),
        ]),
        const SizedBox(height: 20),
        Row(children: [
          _headerStat(
              pendingTotal.toString(), "Pending", Icons.pending_outlined),
          _headerDivider(),
          _headerStat(approvedToday.toString(), "Approved",
              Icons.check_circle_outline),
          _headerDivider(),
          _headerStat(
              totalResidents.toString(), "Residents", Icons.people_outline),
          _headerDivider(),
          _headerStat(totalRequestsThisWeek.toString(), "This Week",
              Icons.trending_up_outlined),
        ]),
      ]),
    );
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return "morning";
    if (h < 17) return "afternoon";
    return "evening";
  }

  Widget _headerStat(String value, String label, IconData icon) => Expanded(
    child: Column(children: [
      Text(value,
          style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5)),
      const SizedBox(height: 3),
      Text(label,
          style:
          TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 10),
          textAlign: TextAlign.center),
    ]),
  );

  Widget _headerDivider() => Container(
      height: 28,
      width: 1,
      color: Colors.white.withOpacity(0.15),
      margin: const EdgeInsets.symmetric(horizontal: 4));

  // ── 2. Emergency Banner ────────────────────────────────────────────────────
  Widget _emergencyBanner() {
    if (activeEmergencies.isEmpty) return const SizedBox.shrink();
    return GestureDetector(
      onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const EmergencyListPage()))
          .then((_) => refreshAllData()),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
            gradient: LinearGradient(
                colors: [
                  chartRed.withOpacity(0.12),
                  chartRed.withOpacity(0.06)
                ],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: chartRed.withOpacity(0.3))),
        child: Row(children: [
          Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                  color: chartRed.withOpacity(0.12), shape: BoxShape.circle),
              child: Icon(Icons.warning_amber_rounded,
                  color: chartRed, size: 18)),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        "${activeEmergencies.length} Active Emergency${activeEmergencies.length > 1 ? ' Issues' : ''}",
                        style: TextStyle(
                            color: chartRed,
                            fontWeight: FontWeight.w700,
                            fontSize: 13)),
                    const SizedBox(height: 2),
                    Text(
                        activeEmergencies.first['title'] ?? 'Requires attention',
                        style: TextStyle(
                            color: chartRed.withOpacity(0.7), fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ])),
          Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                  color: chartRed,
                  borderRadius: BorderRadius.circular(8)),
              child: const Text("View",
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600))),
        ]),
      ),
    );
  }

  // ── 3. Quick Access ────────────────────────────────────────────────────────
  Widget _quickAccess() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
    child:
    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionHeader("Quick Access"),
      const SizedBox(height: 14),
      GridView.count(
        crossAxisCount: 3,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.95,
        children: [
          _accessCard(
            "Users",
            Icons.people_outline,
            chartBlue,
                () => navigateTo("Users"),
            hasNotif: hasUserNotif,
            subtitle: "Manage",
          ),
          _accessCard(
            "Events",
            Icons.event_outlined,
            chartTeal,
                () => navigateTo("Event"),
            hasNotif: hasEventNotif,
            subtitle: "Bookings",
          ),
          _accessCard(
            "Facility",
            Icons.apartment_outlined,
            primary,
                () => navigateTo("Facilities"),
            hasNotif: hasFacilityNotif,
            subtitle: "Requests",
          ),
          _accessCard(
            "Visitor",
            Icons.badge_outlined,
            chartRose,
                () => navigateTo("Visitor"),
            hasNotif: hasVisitorNotif,
            subtitle: "Passes",
          ),
          _accessCard(
            "Emergency",
            Icons.warning_amber_outlined,
            chartRed,
                () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const EmergencyListPage()))
                .then((_) => refreshAllData()),
            hasNotif: hasEmergencyNotif,
            subtitle: activeEmergencies.isNotEmpty
                ? "${activeEmergencies.length} active"
                : "Alerts",
          ),
          _accessCard(
            "Manage",
            Icons.settings_outlined,
            textMid,
                () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const ManageFacilityPage()))
                .then((_) => refreshAllData()),
            subtitle: "Facilities",
          ),
        ],
      ),
    ]),
  );

  Widget _accessCard(
      String title,
      IconData icon,
      Color color,
      VoidCallback onTap, {
        bool hasNotif = false,
        String subtitle = "",
      }) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 12, 10, 10),
          decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: border),
              boxShadow: [
                BoxShadow(
                    color: cardShadow,
                    blurRadius: 8,
                    offset: const Offset(0, 2))
              ]),
          child: Stack(clipBehavior: Clip.none, children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10)),
                  child: Icon(icon, color: color, size: 19)),
              const SizedBox(height: 8),
              Text(title,
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: textDark)),
              if (subtitle.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(subtitle,
                    style: const TextStyle(fontSize: 10, color: textMid),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ]),
            if (hasNotif)
              Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                          color: chartRed,
                          shape: BoxShape.circle,
                          border:
                          Border.all(color: surface, width: 1.5)))),
          ]),
        ),
      );

  // ── 4. Facility Overview ── UPDATED ───────────────────────────────────────
  Widget _facilityOverview() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
    child:
    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        _sectionHeader("Facility Overview"),
        GestureDetector(
          onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const ManageFacilityPage()))
              .then((_) => refreshAllData()),
          child: Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
                color: primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(9)),
            child: const Text("Manage",
                style: TextStyle(
                    color: primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ),
        ),
      ]),
      const SizedBox(height: 14),
      facilityOverview.isEmpty
          ? _card(
          child: const Padding(
            padding: EdgeInsets.all(24),
            child: Center(
                child: Text("No facilities configured",
                    style:
                    TextStyle(color: textLight, fontSize: 13))),
          ))
          : GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.6,
        children: facilityOverview
            .map((f) => _facilityTile(f))
            .toList(),
      ),
    ]),
  );

  // ── UPDATED: uses is_active boolean from facilities table ─────────────────
  Widget _facilityTile(Map<String, dynamic> f) {
    final String name = f['name'] ?? 'Facility';
    final int used = f['used'] ?? 0;
    final int cap = (f['capacity'] as num?)?.toInt() ?? 1;
    final bool isActive = f['is_active'] ?? true;

    final bool isClosed = !isActive;
    final double pct = cap > 0 ? (used / cap).clamp(0.0, 1.0) : 0;
    final bool isFull = !isClosed && used >= cap;

    final Color barColor = isClosed
        ? textLight
        : isFull ? chartRed : pct > 0.6 ? chartAmber : chartGreen;

    final Color chipBg = isClosed
        ? border
        : isFull ? chartRed.withOpacity(0.1) : chartGreen.withOpacity(0.1);
    final Color chipText = isClosed
        ? textMid
        : isFull ? chartRed : chartGreen;

    final String chipLabel = isClosed ? "Inactive" : isFull ? "Full" : "Open";

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border),
          boxShadow: [BoxShadow(color: cardShadow, blurRadius: 6, offset: const Offset(0, 2))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Expanded(
              child: Text(name,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textDark),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis)),
          Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(color: chipBg, borderRadius: BorderRadius.circular(6)),
              child: Text(chipLabel,
                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: chipText))),
        ]),
        const Spacer(),
        ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
                value: isClosed ? 0 : pct,
                backgroundColor: barColor.withOpacity(0.1),
                valueColor: AlwaysStoppedAnimation(barColor),
                minHeight: 5)),
        const SizedBox(height: 7),
        Text(isClosed ? "Unavailable" : "$used / $cap slots",
            style: const TextStyle(fontSize: 10, color: textMid)),
      ]),
    );
  }

  // ── 5. Week Schedule ──────────────────────────────────────────────────────
  Widget _weekSchedule() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
    child:
    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionHeader("This Week's Schedule"),
      const SizedBox(height: 14),
      _card(
        child: weekSchedule.isEmpty
            ? Padding(
            padding: const EdgeInsets.all(20),
            child: Column(children: [
              Icon(Icons.calendar_today_outlined,
                  color: textLight, size: 28),
              const SizedBox(height: 8),
              const Text("No events scheduled this week",
                  style:
                  TextStyle(color: textLight, fontSize: 13)),
            ]))
            : Column(
            children:
            weekSchedule.asMap().entries.map((e) {
              final i = e.key;
              final item = e.value;

              final isPrivate = item['is_private'] == true;
              final dateStr = item['event_date']?.toString() ?? '';
              final timeStr = item['start_time']?.toString() ?? '';
              final eventDate = dateStr.isNotEmpty
                  ? DateTime.tryParse(dateStr)
                  : null;

              final Color dotColor =
              isPrivate ? primary : chartTeal;
              final String typeLabel =
              isPrivate ? 'Private' : 'Public';
              final IconData typeIcon = isPrivate
                  ? Icons.lock_outline
                  : Icons.public_outlined;

              const dayNames = [
                'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'
              ];
              final dayStr = eventDate != null
                  ? dayNames[
              (eventDate.weekday - 1).clamp(0, 6)]
                  : '';

              final displayTime = timeStr.length >= 5
                  ? timeStr.substring(0, 5)
                  : 'All day';

              final maxCap =
              (item['max_capacity'] as num?)?.toInt();
              final joined =
                  (item['participants'] as num?)?.toInt() ?? 0;
              final isFull =
                  maxCap != null && joined >= maxCap;

              return Column(children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                      vertical: 10, horizontal: 4),
                  child: Row(children: [
                    SizedBox(
                        width: 44,
                        child: Text(displayTime,
                            style: const TextStyle(
                                fontSize: 11,
                                color: textLight))),
                    const SizedBox(width: 8),
                    Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                            color: dotColor,
                            shape: BoxShape.circle)),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Column(
                            crossAxisAlignment:
                            CrossAxisAlignment.start,
                            children: [
                              Text(item['title'] ?? typeLabel,
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: textDark),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 3),
                              Row(children: [
                                if (dayStr.isNotEmpty) ...[
                                  Text(dayStr,
                                      style: const TextStyle(
                                          fontSize: 10,
                                          color: textLight)),
                                  const Text(' · ',
                                      style: TextStyle(
                                          fontSize: 10,
                                          color: textLight)),
                                ],
                                Icon(typeIcon,
                                    size: 11, color: dotColor),
                                const SizedBox(width: 3),
                                Text(typeLabel,
                                    style: TextStyle(
                                        fontSize: 10,
                                        color: dotColor,
                                        fontWeight:
                                        FontWeight.w500)),
                                if (maxCap != null) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                      padding:
                                      const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2),
                                      decoration: BoxDecoration(
                                          color: isFull
                                              ? chartRed
                                              .withOpacity(0.1)
                                              : chartGreen
                                              .withOpacity(0.1),
                                          borderRadius:
                                          BorderRadius.circular(
                                              4)),
                                      child: Text(
                                          isFull
                                              ? 'Full'
                                              : '$joined/$maxCap',
                                          style: TextStyle(
                                              fontSize: 9,
                                              fontWeight:
                                              FontWeight.w600,
                                              color: isFull
                                                  ? chartRed
                                                  : chartGreen))),
                                ],
                                if (item['location'] != null &&
                                    (item['location'] as String)
                                        .isNotEmpty) ...[
                                  const SizedBox(width: 6),
                                  const Icon(Icons.place_outlined,
                                      size: 10, color: textLight),
                                  const SizedBox(width: 2),
                                  Flexible(
                                      child: Text(
                                          item['location'],
                                          style: const TextStyle(
                                              fontSize: 10,
                                              color: textLight),
                                          maxLines: 1,
                                          overflow:
                                          TextOverflow.ellipsis)),
                                ],
                              ]),
                            ])),
                  ]),
                ),
                if (i < weekSchedule.length - 1)
                  Divider(
                      height: 1,
                      indent: 58,
                      endIndent: 4,
                      color: border),
              ]);
            }).toList()),
      ),
    ]),
  );

  // ── 6. Recent Activity ────────────────────────────────────────────────────
  Widget _recentActivity() {
    if (recentActivity.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionHeader("Recent Activity"),
        const SizedBox(height: 14),
        _card(
          child: Column(
              children: recentActivity.asMap().entries.map((e) {
                final i = e.key;
                final item = e.value;
                final type = item['type'] ?? '';
                final status = item['status'] ?? 'pending';
                final date =
                (item['created_at']?.toString() ?? '').length >= 10
                    ? item['created_at'].toString().substring(0, 10)
                    : '';
                final Color sColor = status == 'approved'
                    ? chartGreen
                    : status == 'rejected'
                    ? chartRed
                    : chartAmber;
                Color tColor;
                IconData tIcon;
                switch (type) {
                  case 'admin':
                  case 'resident':
                    tColor = chartBlue;
                    tIcon = Icons.person_outline;
                    break;
                  case 'booking':
                    tColor = chartTeal;
                    tIcon = Icons.event_outlined;
                    break;
                  case 'facility':
                    tColor = primary;
                    tIcon = Icons.apartment_outlined;
                    break;
                  case 'visitor':
                    tColor = chartRose;
                    tIcon = Icons.badge_outlined;
                    break;
                  default:
                    tColor = textLight;
                    tIcon = Icons.circle_outlined;
                }
                return Column(children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    child: Row(children: [
                      Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                              color: tColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(11)),
                          child: Icon(tIcon, color: tColor, size: 17)),
                      const SizedBox(width: 12),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item['title'] ?? type.toUpperCase(),
                                    style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: textDark),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                                const SizedBox(height: 2),
                                Text(date,
                                    style: const TextStyle(
                                        fontSize: 11, color: textLight)),
                              ])),
                      const SizedBox(width: 8),
                      Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                              color: sColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(7)),
                          child: Text(status.toUpperCase(),
                              style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: sColor,
                                  letterSpacing: 0.5))),
                    ]),
                  ),
                  if (i < recentActivity.length - 1)
                    Divider(
                        height: 1, indent: 16, endIndent: 16, color: border),
                ]);
              }).toList()),
        ),
      ]),
    );
  }

  // ── 7. Announcements ──────────────────────────────────────────────────────
  Widget _announcements() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
    child:
    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        _sectionHeader("Announcements"),
        Row(children: [
          GestureDetector(
            onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const AdminAnnouncementPage())),
            child: const Text("See all",
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: primary)),
          ),
        ]),
      ]),
      const SizedBox(height: 14),
      if (announcements.isEmpty)
        _card(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(children: [
              Icon(Icons.campaign_outlined, color: textLight, size: 32),
              const SizedBox(height: 8),
              const Text("No announcements yet.",
                  style: TextStyle(color: textLight, fontSize: 13)),
            ]),
          ),
        )
      else
        ...announcements.map((item) {
          final bool urgent = item['is_urgent'] ?? false;
          final bool hasImage = item['image_url'] != null &&
              item['image_url'].toString().isNotEmpty;
          return GestureDetector(
            onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) =>
                        AdminAnnouncementDetailPage(data: item))),
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                  color: surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: urgent
                          ? chartRed.withOpacity(0.3)
                          : border),
                  boxShadow: [
                    BoxShadow(
                        color: cardShadow,
                        blurRadius: 8,
                        offset: const Offset(0, 2))
                  ]),
              child: Row(children: [
                ClipRRect(
                    borderRadius: const BorderRadius.horizontal(
                        left: Radius.circular(10)),
                    child: SizedBox(
                        width: 72,
                        height: 96,
                        child: hasImage
                            ? Image.network(item['image_url'],
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                _annPlaceholder(urgent))
                            : _annPlaceholder(urgent))),
                Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (urgent)
                              Container(
                                  margin:
                                  const EdgeInsets.only(bottom: 4),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                      color:
                                      chartRed.withOpacity(0.1),
                                      borderRadius:
                                      BorderRadius.circular(5)),
                                  child: Text("URGENT",
                                      style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w700,
                                          color: chartRed,
                                          letterSpacing: 0.5))),
                            Text(item['title'] ?? 'No Title',
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: textDark),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 4),
                            Text(item['content'] ?? '',
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: textMid,
                                    height: 1.4),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis),
                          ]),
                    )),
                Padding(
                    padding: const EdgeInsets.only(right: 14),
                    child: Icon(Icons.arrow_forward_ios_rounded,
                        color: textLight, size: 14)),
              ]),
            ),
          );
        }),
    ]),
  );

  Widget _annPlaceholder(bool urgent) => Container(
      color:
      urgent ? chartRed.withOpacity(0.06) : const Color(0xFFF5F3F0),
      child: Center(
          child: Icon(
              urgent
                  ? Icons.warning_amber_rounded
                  : Icons.campaign_outlined,
              color: urgent ? chartRed.withOpacity(0.4) : textLight,
              size: 24)));

  // ── Helpers ───────────────────────────────────────────────────────────────

  Widget _card({required Widget child, Key? key}) => Container(
    key: key,
    width: double.infinity,
    decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
              color: cardShadow,
              blurRadius: 10,
              offset: const Offset(0, 3))
        ]),
    padding: const EdgeInsets.all(8),
    child: child,
  );

  Widget _sectionHeader(String t) => Text(t,
      style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: textDark,
          letterSpacing: -0.3));

  Widget _iconBtn(IconData icon, String label, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
                color: primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(9)),
            child: Row(children: [
              Icon(icon, color: primary, size: 14),
              const SizedBox(width: 4),
              Text(label,
                  style: const TextStyle(
                      color: primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ])),
      );

  // ── BUILD ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: RefreshIndicator(
          color: primary,
          displacement: 20,
          onRefresh: refreshAllData,
          child: _loading
              ? _loadingSkeleton()
              : FadeTransition(
            opacity: _fadeAnim,
            child: ListView(
                padding: const EdgeInsets.only(bottom: 48),
                children: [
                  _header(),
                  _emergencyBanner(),
                  _quickAccess(),
                  _facilityOverview(),
                  _weekSchedule(),
                  _recentActivity(),
                  _announcements(),
                  const SizedBox(height: 16),
                ]),
          ),
        ),
      ),
    );
  }

  // ── Skeleton loader ───────────────────────────────────────────────────────
  Widget _loadingSkeleton() => ListView(
    padding: const EdgeInsets.only(bottom: 40),
    children: [
      Container(
          height: 140,
          decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF5C1F14), Color(0xFF8B3A2A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ))),
      const SizedBox(height: 20),
      Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(children: [
            _shimmer(height: 44, radius: 14),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.05,
              children: List.generate(
                  6, (_) => _shimmer(height: 100, radius: 16)),
            ),
            const SizedBox(height: 20),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.6,
              children: List.generate(
                  4, (_) => _shimmer(height: 80, radius: 14)),
            ),
            const SizedBox(height: 14),
            _shimmer(height: 200, radius: 18),
            const SizedBox(height: 14),
            _shimmer(height: 120, radius: 14),
            const SizedBox(height: 14),
            _shimmer(height: 80, radius: 14),
            const SizedBox(height: 14),
            _shimmer(height: 80, radius: 14),
          ])),
    ],
  );

  Widget _shimmer({required double height, double radius = 8}) => Container(
      height: height,
      decoration: BoxDecoration(
          color: const Color(0xFFEDE9E5),
          borderRadius: BorderRadius.circular(radius)));
}