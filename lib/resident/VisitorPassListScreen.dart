import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

import 'VisitorPassRequestScreen.dart';

class VisitorPassListScreen extends StatefulWidget {
  const VisitorPassListScreen({super.key});
  @override
  State<VisitorPassListScreen> createState() => _VisitorPassListScreenState();
}

class _VisitorPassListScreenState extends State<VisitorPassListScreen>
    with SingleTickerProviderStateMixin {
  final _client = Supabase.instance.client;
  late TabController _tabController;

  List<Map<String, dynamic>> _pending = [];
  List<Map<String, dynamic>> _approved = [];
  List<Map<String, dynamic>> _rejected = [];
  List<Map<String, dynamic>> _used = [];
  bool _loading = true;

  final Color primary = const Color(0xFF9A4B3C);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this); // ← 4 tabs
    _loadPasses();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadPasses() async {
    setState(() => _loading = true);
    try {
      final res = await _client
          .from('visitor_passes')
          .select('*, events(title)')
          .eq('resident_id', _client.auth.currentUser!.id)
          .order('created_at', ascending: false);

      final all = List<Map<String, dynamic>>.from(res);
      setState(() {
        _pending  = all.where((p) => p['status'] == 'pending').toList();
        _approved = all.where((p) => p['status'] == 'approved').toList();
        _rejected = all.where((p) => p['status'] == 'rejected').toList();
        _used     = all.where((p) => p['status'] == 'used').toList();
        _loading  = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      _showSnack('Error loading passes: $e');
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _showQR(Map<String, dynamic> pass) {
    final primary = const Color(0xFF9A4B3C);

    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(Icons.verified_rounded, color: Colors.green),
                  const SizedBox(width: 6),
                  const Text(
                    "Approved Pass",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                pass['visitor_name'],
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: primary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                pass['purpose'] == 'event' ? 'Event Entry' : 'Visitor Entry',
                style: const TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    QrImageView(
                      data: pass['qr_token'],
                      size: 200,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "Scan at guardhouse",
                      style: TextStyle(fontSize: 12, color: Colors.black45),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F4F2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    _infoRow(Icons.calendar_today,
                        DateFormat('d MMM yyyy')
                            .format(DateTime.parse(pass['valid_date']))),
                    if (pass['visitor_ic'] != null &&
                        (pass['visitor_ic'] as String).isNotEmpty)
                      _infoRow(Icons.badge_outlined, pass['visitor_ic']),
                    if (pass['events'] != null)
                      _infoRow(Icons.event, pass['events']['title']),
                    if (pass['reason'] != null &&
                        (pass['reason'] as String).isNotEmpty)
                      _infoRow(Icons.notes, pass['reason']),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                "Present this QR code upon entry",
                style: TextStyle(fontSize: 12, color: Colors.black38),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.black45),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F1ED),
      appBar: AppBar(
        title: const Text('My Visitor Passes'),
        backgroundColor: primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const VisitorPassRequestScreen()),
              );
              _loadPasses();
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          isScrollable: true,                        // ← needed for 4 tabs
          tabAlignment: TabAlignment.start,
          tabs: [
            // ── Pending ──────────────────────────────
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Pending'),
                  if (_pending.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.orange,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${_pending.length}',
                        style: const TextStyle(
                            fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // ── Approved ─────────────────────────────
            const Tab(text: 'Approved'),
            // ── Rejected ─────────────────────────────
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Rejected'),
                  if (_rejected.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${_rejected.length}',
                        style: const TextStyle(
                            fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // ── History (used only) ───────────────────
            const Tab(text: 'History'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
        controller: _tabController,
        children: [
          _buildList(_pending,
              emptyIcon: Icons.hourglass_empty_outlined,
              emptyMsg: 'No pending requests'),
          _buildList(_approved,
              showQR: true,
              emptyIcon: Icons.check_circle_outline,
              emptyMsg: 'No approved passes'),
          _buildList(_rejected,
              emptyIcon: Icons.cancel_outlined,
              emptyMsg: 'No rejected passes'),
          _buildList(_used,
              emptyIcon: Icons.history,
              emptyMsg: 'No used passes'),
        ],
      ),
    );
  }

  Widget _buildList(
      List<Map<String, dynamic>> passes, {
        bool showQR = false,
        required IconData emptyIcon,
        required String emptyMsg,
      }) {
    if (passes.isEmpty) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(emptyIcon, size: 64, color: Colors.black12),
          const SizedBox(height: 12),
          Text(emptyMsg,
              style: const TextStyle(color: Colors.black38, fontSize: 15)),
        ]),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadPasses,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: passes.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, i) => _PassCard(
          pass: passes[i],
          primary: primary,
          onViewQR: showQR ? () => _showQR(passes[i]) : null,
        ),
      ),
    );
  }
}

// ─── Pass Card (unchanged) ────────────────────────────────────────────────────

class _PassCard extends StatelessWidget {
  final Map<String, dynamic> pass;
  final Color primary;
  final VoidCallback? onViewQR;

  const _PassCard({
    required this.pass,
    required this.primary,
    this.onViewQR,
  });

  @override
  Widget build(BuildContext context) {
    final statusColors = {
      'pending':  Colors.orange,
      'approved': Colors.green,
      'rejected': Colors.red,
      'used':     Colors.grey,
    };
    final status      = pass['status'] as String;
    final statusColor = statusColors[status] ?? Colors.grey;
    final validDate   =
    DateFormat('d MMM, yyyy').format(DateTime.parse(pass['valid_date']));
    final purposeLabel =
    pass['purpose'] == 'event' ? 'Event' : 'Normal Visit';
    final initials = (pass['visitor_name'] as String)
        .trim()
        .split(' ')
        .where((s) => s.isNotEmpty)
        .take(2)
        .map((s) => s[0].toUpperCase())
        .join();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: const Color(0xFFEADFD6),
                  child: Text(
                    initials,
                    style: const TextStyle(
                      color: Color(0xFF9A4B3C),
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Expanded(
                          child: Text(
                            pass['visitor_name'],
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 15),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 9, vertical: 3),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            status.toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              color: statusColor,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ]),
                      if (pass['visitor_ic'] != null &&
                          (pass['visitor_ic'] as String).isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(pass['visitor_ic'],
                            style: const TextStyle(
                                fontSize: 13, color: Colors.black54)),
                      ],
                      const SizedBox(height: 3),
                      Text(validDate,
                          style: const TextStyle(
                              fontSize: 12, color: Colors.black38)),
                      if (pass['events'] != null) ...[
                        const SizedBox(height: 2),
                        Row(children: [
                          const Icon(Icons.event_outlined,
                              size: 12, color: Colors.black38),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              pass['events']['title'],
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.black45),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ]),
                      ],
                      if (pass['reason'] != null &&
                          (pass['reason'] as String).isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Row(children: [
                          const Icon(Icons.notes_outlined,
                              size: 12, color: Colors.black38),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              pass['reason'],
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.black45),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ]),
                      ],
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: primary.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          purposeLabel,
                          style: TextStyle(
                              fontSize: 11,
                              color: primary,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (onViewQR != null) ...[
            const Divider(height: 1, thickness: 1, color: Color(0xFFF0EBE6)),
            InkWell(
              onTap: onViewQR,
              borderRadius:
              const BorderRadius.vertical(bottom: Radius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.qr_code_2, size: 18, color: primary),
                    const SizedBox(width: 6),
                    Text(
                      'View QR Code',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}