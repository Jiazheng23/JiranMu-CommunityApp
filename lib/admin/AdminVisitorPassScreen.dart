import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';

class AdminVisitorPassScreen extends StatefulWidget {
  const AdminVisitorPassScreen({super.key});

  @override
  State<AdminVisitorPassScreen> createState() => _AdminVisitorPassScreenState();
}

class _AdminVisitorPassScreenState extends State<AdminVisitorPassScreen>
    with SingleTickerProviderStateMixin {
  final _client = Supabase.instance.client;
  late TabController _tabController;

  List<Map<String, dynamic>> _pending  = [];
  List<Map<String, dynamic>> _approved = [];
  List<Map<String, dynamic>> _rejected = [];
  bool _loading = true;

  static const Color primary = Color(0xFF9A4B3C);
  static const Color _bg     = Color(0xFFF5EBE6);
  static const Color _brown  = Color(0xFF8B5E4A);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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
      // Try joining events first; if it fails fall back to plain select
      List<Map<String, dynamic>> all = [];
      try {
        final res = await _client
            .from('visitor_passes')
            .select('*, events(title)')
            .order('created_at', ascending: false);
        all = List<Map<String, dynamic>>.from(res);
      } catch (_) {
        // Foreign key to events doesn't exist — fetch without join
        final res = await _client
            .from('visitor_passes')
            .select('*')
            .order('created_at', ascending: false);
        all = List<Map<String, dynamic>>.from(res);
      }

      if (mounted) {
        setState(() {
          _pending  = all.where((p) => p['status'] == 'pending').toList();
          _approved = all.where((p) => p['status'] == 'approved').toList();
          _rejected = all.where((p) => p['status'] == 'rejected').toList();
          _loading  = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        _showSnack('Error loading passes: $e');
      }
    }
  }

  Future<void> _approvePass(Map<String, dynamic> pass) async {
    try {
      // Generate a unique QR token when approving
      final qrToken = pass['id'].toString();

      await _client
          .from('visitor_passes')
          .update({
        'status': 'approved',
        'qr_token': qrToken,
      })
          .eq('id', pass['id']);

      _showSnack('Pass approved — QR code generated.');
      await _loadPasses();

      if (mounted) {
        _showQRDialog({...pass, 'status': 'approved', 'qr_token': qrToken});
      }
    } catch (e) {
      _showSnack('Error approving pass: $e');
    }
  }

  Future<void> _rejectPass(Map<String, dynamic> pass) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Reject Pass?'),
        content: Text('Reject visitor pass for ${pass['visitor_name']}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reject', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _client
          .from('visitor_passes')
          .update({'status': 'rejected'})
          .eq('id', pass['id']);
      _showSnack('Pass rejected.');
      await _loadPasses();
    } catch (e) {
      _showSnack('Error rejecting pass: $e');
    }
  }

  void _showQRDialog(Map<String, dynamic> pass) {
    final qrToken = pass['qr_token']?.toString() ?? '';
    final eventTitle = pass['events']?['title'] as String?;

    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Visitor Pass QR',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: primary)),
            const SizedBox(height: 4),
            Text(pass['visitor_name'] ?? '',
                style: const TextStyle(color: Colors.black54, fontSize: 14)),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 4))
                ],
              ),
              child: qrToken.isEmpty
                  ? const SizedBox(
                  height: 200,
                  width: 200,
                  child: Center(child: Text('No QR token')))
                  : QrImageView(
                data: qrToken,
                version: QrVersions.auto,
                size: 200,
              ),
            ),
            const SizedBox(height: 16),
            _dialogInfoRow(Icons.person_outline, pass['visitor_name'] ?? '-'),
            if (pass['visitor_ic'] != null && pass['visitor_ic'] != '')
              _dialogInfoRow(Icons.badge_outlined, pass['visitor_ic']),
            if (eventTitle != null && eventTitle.isNotEmpty)
              _dialogInfoRow(Icons.event_outlined, eventTitle),
            if (pass['purpose'] != null)
              _dialogInfoRow(
                  Icons.category_outlined, 'Purpose: ${pass['purpose']}'),
            if (pass['reason'] != null && pass['reason'] != '')
              _dialogInfoRow(
                  Icons.note_outlined, 'Reason: ${pass['reason']}'),
            _dialogInfoRow(
              Icons.calendar_today_outlined,
              pass['valid_date'] != null
                  ? DateFormat('d MMM yyyy')
                  .format(DateTime.parse(pass['valid_date']))
                  : '-',
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text('Close'),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _dialogInfoRow(IconData icon, String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(children: [
      Icon(icon, size: 16, color: Colors.black45),
      const SizedBox(width: 8),
      Expanded(
          child: Text(text,
              style: const TextStyle(
                  fontSize: 13, color: Colors.black87))),
    ]),
  );

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  String _initials(String name) => name
      .trim()
      .split(' ')
      .where((s) => s.isNotEmpty)
      .take(2)
      .map((s) => s[0].toUpperCase())
      .join();

  Color _statusColor(String status) {
    switch (status) {
      case 'approved': return const Color(0xFF6B8E6B);
      case 'rejected': return const Color(0xFFC67B75);
      case 'used':     return Colors.grey;
      default:         return const Color(0xFFD4A847);
    }
  }

  Widget _statusBadge(String status) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(20)),
      child: Text(status.toUpperCase(),
          style: TextStyle(
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5)),
    );
  }

  Widget _tabBadge(String label, int count, Color badgeColor) {
    return Tab(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label),
          // if (count > 0) ...[
          //   const SizedBox(width: 4),
          //   Container(
          //     padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          //     decoration: BoxDecoration(
          //         color: badgeColor,
          //         borderRadius: BorderRadius.circular(10)),
          //     child: Text('$count',
          //         style: const TextStyle(
          //             fontSize: 11, fontWeight: FontWeight.bold)),
          //   ),
          // ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: const Text('Visitor Pass Requests',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 0,
        // actions: [
        //   IconButton(
        //       icon: const Icon(Icons.refresh), onPressed: _loadPasses),
        // ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: [
            _tabBadge('Pending',  _pending.length,  Colors.orange),
            _tabBadge('Approved', _approved.length, const Color(0xFF6B8E6B)),
            _tabBadge('Rejected', _rejected.length, Colors.red),
          ],
        ),
      ),
      body: _loading
          ? const Center(
          child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(_brown)))
          : TabBarView(
        controller: _tabController,
        children: [
          _buildPendingList(),
          _buildApprovedList(),
          _buildRejectedList(),
        ],
      ),
    );
  }

  // ── PENDING list ──────────────────────────────────────────────────────────
  Widget _buildPendingList() {
    if (_pending.isEmpty) {
      return _buildEmpty(Icons.inbox_outlined, 'No pending requests');
    }
    return RefreshIndicator(
      onRefresh: _loadPasses,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _pending.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, i) => _buildPendingCard(_pending[i]),
      ),
    );
  }

  // ── APPROVED list ─────────────────────────────────────────────────────────
  Widget _buildApprovedList() {
    if (_approved.isEmpty) {
      return _buildEmpty(Icons.check_circle_outline, 'No approved passes yet');
    }
    return RefreshIndicator(
      onRefresh: _loadPasses,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _approved.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, i) => _buildApprovedCard(_approved[i]),
      ),
    );
  }

  // ── REJECTED list ─────────────────────────────────────────────────────────
  Widget _buildRejectedList() {
    if (_rejected.isEmpty) {
      return _buildEmpty(Icons.cancel_outlined, 'No rejected passes');
    }
    return RefreshIndicator(
      onRefresh: _loadPasses,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _rejected.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, i) => _buildRejectedCard(_rejected[i]),
      ),
    );
  }

  // ── PENDING card ──────────────────────────────────────────────────────────
  Widget _buildPendingCard(Map<String, dynamic> pass) {
    final validDate = pass['valid_date'] != null
        ? DateTime.parse(pass['valid_date'])
        : DateTime.now();
    final eventTitle = pass['events']?['title'] as String?;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: _brown.withOpacity(0.06),
              blurRadius: 15,
              offset: const Offset(0, 5))
        ],
      ),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _avatar(pass['visitor_name'] ?? '?',
                const Color(0xFFE96B9E), const Color(0xFFEADFD6), primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                        child: Text(pass['visitor_name'] ?? '-',
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 15)),
                      ),
                      _statusBadge('pending'),
                    ]),
                    if (pass['visitor_ic'] != null &&
                        pass['visitor_ic'] != '') ...[
                      const SizedBox(height: 3),
                      Text(pass['visitor_ic'],
                          style: const TextStyle(
                              fontSize: 13, color: Colors.black54)),
                    ],
                    const SizedBox(height: 3),
                    Text(DateFormat('d MMM, yyyy').format(validDate),
                        style: const TextStyle(
                            fontSize: 12, color: Colors.black38)),
                    if (eventTitle != null && eventTitle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Row(children: [
                        const Icon(Icons.event_outlined,
                            size: 12, color: Colors.black38),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(eventTitle,
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.black45)),
                        ),
                      ]),
                    ],
                    if (pass['purpose'] != null) ...[
                      const SizedBox(height: 2),
                      Text('Purpose: ${pass['purpose']}',
                          style: const TextStyle(
                              fontSize: 12, color: Colors.black45)),
                    ],
                    if (pass['reason'] != null && pass['reason'] != '') ...[
                      const SizedBox(height: 2),
                      Text('Reason: ${pass['reason']}',
                          style: const TextStyle(
                              fontSize: 12, color: Colors.black45)),
                    ],
                  ]),
            ),
          ]),
        ),
        const Divider(height: 1, thickness: 1, color: Color(0xFFF0EBE6)),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
          child: Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _rejectPass(pass),
                icon: const Icon(Icons.close, size: 15),
                label: const Text('Reject'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  textStyle: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: () => _approvePass(pass),
                icon: const Icon(Icons.qr_code_2, size: 15),
                label: const Text('Generate QR'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  textStyle: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600),
                  elevation: 0,
                ),
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  // ── APPROVED card ─────────────────────────────────────────────────────────
  Widget _buildApprovedCard(Map<String, dynamic> pass) {
    final validDate = pass['valid_date'] != null
        ? DateTime.parse(pass['valid_date'])
        : DateTime.now();
    final eventTitle = pass['events']?['title'] as String?;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: _brown.withOpacity(0.06),
              blurRadius: 15,
              offset: const Offset(0, 5))
        ],
      ),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _avatar(
                pass['visitor_name'] ?? '?',
                const Color(0xFF6B8E6B),
                const Color(0xFFDFEADF),
                const Color(0xFF6B8E6B)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                        child: Text(pass['visitor_name'] ?? '-',
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 15)),
                      ),
                      _statusBadge('approved'),
                    ]),
                    if (pass['visitor_ic'] != null &&
                        pass['visitor_ic'] != '') ...[
                      const SizedBox(height: 3),
                      Text(pass['visitor_ic'],
                          style: const TextStyle(
                              fontSize: 13, color: Colors.black54)),
                    ],
                    const SizedBox(height: 3),
                    Text(DateFormat('d MMM, yyyy').format(validDate),
                        style: const TextStyle(
                            fontSize: 12, color: Colors.black38)),
                    if (pass['purpose'] != null) ...[
                      const SizedBox(height: 2),
                      Text('Purpose: ${pass['purpose']}',
                          style: const TextStyle(
                              fontSize: 12, color: Colors.black45)),
                    ],
                    if (pass['reason'] != null && pass['reason'] != '') ...[
                      const SizedBox(height: 2),
                      Text('Reason: ${pass['reason']}',
                          style: const TextStyle(
                              fontSize: 12, color: Colors.black45)),
                    ],
                    if (eventTitle != null && eventTitle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Row(children: [
                        const Icon(Icons.event_outlined,
                            size: 12, color: Colors.black38),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(eventTitle,
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.black45)),
                        ),
                      ]),
                    ],
                  ]),
            ),
          ]),
        ),
        const Divider(height: 1, thickness: 1, color: Color(0xFFF0EBE6)),
        InkWell(
          onTap: () => _showQRDialog(pass),
          borderRadius:
          const BorderRadius.vertical(bottom: Radius.circular(16)),
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.qr_code_2, size: 18, color: primary),
                SizedBox(width: 6),
                Text('View QR Code',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: primary)),
              ],
            ),
          ),
        ),
      ]),
    );
  }

  // ── REJECTED card ─────────────────────────────────────────────────────────
  Widget _buildRejectedCard(Map<String, dynamic> pass) {
    final validDate = pass['valid_date'] != null
        ? DateTime.parse(pass['valid_date'])
        : DateTime.now();
    final eventTitle = pass['events']?['title'] as String?;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: _brown.withOpacity(0.06),
              blurRadius: 15,
              offset: const Offset(0, 5))
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _avatar(
              pass['visitor_name'] ?? '?',
              const Color(0xFFC67B75),
              const Color(0xFFF5E0DE),
              const Color(0xFFC67B75)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                      child: Text(pass['visitor_name'] ?? '-',
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 15)),
                    ),
                    _statusBadge('rejected'),
                  ]),
                  if (pass['visitor_ic'] != null &&
                      pass['visitor_ic'] != '') ...[
                    const SizedBox(height: 3),
                    Text(pass['visitor_ic'],
                        style: const TextStyle(
                            fontSize: 13, color: Colors.black54)),
                  ],
                  const SizedBox(height: 3),
                  Text(DateFormat('d MMM, yyyy').format(validDate),
                      style: const TextStyle(
                          fontSize: 12, color: Colors.black38)),
                  if (pass['purpose'] != null) ...[
                    const SizedBox(height: 2),
                    Text('Purpose: ${pass['purpose']}',
                        style: const TextStyle(
                            fontSize: 12, color: Colors.black45)),
                  ],
                  if (pass['reason'] != null && pass['reason'] != '') ...[
                    const SizedBox(height: 2),
                    Text('Reason: ${pass['reason']}',
                        style: const TextStyle(
                            fontSize: 12, color: Colors.black45)),
                  ],
                  if (eventTitle != null && eventTitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Row(children: [
                      const Icon(Icons.event_outlined,
                          size: 12, color: Colors.black38),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(eventTitle,
                            style: const TextStyle(
                                fontSize: 12, color: Colors.black45)),
                      ),
                    ]),
                  ],
                ]),
          ),
        ]),
      ),
    );
  }

  // ── Shared avatar widget ──────────────────────────────────────────────────
  Widget _avatar(String name, Color ringColor, Color bgColor,
      Color textColor) =>
      Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
            color: ringColor.withOpacity(0.15), shape: BoxShape.circle),
        child: CircleAvatar(
          radius: 24,
          backgroundColor: bgColor,
          child: Text(_initials(name),
              style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 15)),
        ),
      );

  // ── Empty state ───────────────────────────────────────────────────────────
  Widget _buildEmpty(IconData icon, String msg) => Center(
    child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.black12),
          const SizedBox(height: 12),
          Text(msg,
              style: const TextStyle(
                  color: Colors.black38, fontSize: 15)),
        ]),
  );
}