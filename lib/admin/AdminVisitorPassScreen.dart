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

  List<Map<String, dynamic>> _pending = [];
  List<Map<String, dynamic>> _approved = [];
  bool _loading = true;

  final Color primary = const Color(0xFF9A4B3C);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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
          .order('created_at', ascending: false);

      final all = List<Map<String, dynamic>>.from(res);
      setState(() {
        _pending = all.where((p) => p['status'] == 'pending').toList();
        _approved = all
            .where((p) =>
        p['status'] == 'approved' || p['status'] == 'used')
            .toList();
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      _showSnack('Error loading passes: $e');
    }
  }

  Future<void> _approvePass(Map<String, dynamic> pass) async {
    try {
      await _client
          .from('visitor_passes')
          .update({'status': 'approved'})
          .eq('id', pass['id']);

      _showSnack('Pass approved — QR code generated.');
      await _loadPasses();

      if (mounted) {
        final updated = {...pass, 'status': 'approved'};
        _showQRDialog(updated);
      }
    } catch (e) {
      _showSnack('Error approving pass: $e');
    }
  }

  Future<void> _rejectPass(Map<String, dynamic> pass) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
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
    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child:
          Column(mainAxisSize: MainAxisSize.min, children: [
            Text(
              'Visitor Pass QR',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: primary),
            ),
            const SizedBox(height: 4),
            Text(
              pass['visitor_name'],
              style:
              const TextStyle(color: Colors.black54, fontSize: 14),
            ),
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
                    offset: const Offset(0, 4),
                  )
                ],
              ),
              child: QrImageView(
                data: pass['qr_token'],
                version: QrVersions.auto,
                size: 200,
              ),
            ),
            const SizedBox(height: 16),
            _dialogInfoRow(Icons.person_outline, pass['visitor_name']),
            if (pass['visitor_ic'] != null)
              _dialogInfoRow(Icons.badge_outlined, pass['visitor_ic']),
            if (pass['events'] != null)
              _dialogInfoRow(
                  Icons.event_outlined, pass['events']['title']),
            _dialogInfoRow(
              Icons.calendar_today_outlined,
              DateFormat('d MMM yyyy')
                  .format(DateTime.parse(pass['valid_date'])),
            ),
            _dialogInfoRow(
              Icons.category_outlined,
              'Purpose: ${pass['purpose'] ?? 'General'}',
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
                fontSize: 13, color: Colors.black87)),
      ),
    ]),
  );

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F1ED),
      appBar: AppBar(
        title: const Text('Visitor Pass Requests'),
        backgroundColor: primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadPasses,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
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
                            fontSize: 11,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Tab(text: 'Approved'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
        controller: _tabController,
        children: [
          _buildPendingList(),
          _buildApprovedList(),
        ],
      ),
    );
  }

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

  Widget _buildApprovedList() {
    if (_approved.isEmpty) {
      return _buildEmpty(
          Icons.check_circle_outline, 'No approved passes yet');
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

  Widget _buildPendingCard(Map<String, dynamic> pass) {
    final validDate = DateTime.parse(pass['valid_date']);
    final eventTitle = pass['events']?['title'];
    final initials = (pass['visitor_name'] as String)
        .trim()
        .split(' ')
        .where((s) => s.isNotEmpty)
        .take(2)
        .map((s) => s[0].toUpperCase())
        .join();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
          // ── Top section ──
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar
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
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              pass['visitor_name'],
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          // Status chip
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 9, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              'PENDING',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.orange,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (pass['visitor_ic'] != null) ...[
                        const SizedBox(height: 3),
                        Text(
                          pass['visitor_ic'],
                          style: const TextStyle(
                              fontSize: 13, color: Colors.black54),
                        ),
                      ],
                      const SizedBox(height: 3),
                      Text(
                        DateFormat('d MMM, yyyy').format(validDate),
                        style: const TextStyle(
                            fontSize: 12, color: Colors.black38),
                      ),
                      if (eventTitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          eventTitle,
                          style: const TextStyle(
                              fontSize: 12, color: Colors.black45),
                        ),
                      ],
                      const SizedBox(height: 2),
                      Text(
                        'Purpose: ${pass['purpose'] ?? 'General'}',
                        style: const TextStyle(
                            fontSize: 12, color: Colors.black45),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Divider ──
          const Divider(height: 1, thickness: 1, color: Color(0xFFF0EBE6)),

          // ── Action buttons ──
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
            child: Row(
              children: [
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
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildApprovedCard(Map<String, dynamic> pass) {
    final validDate = DateTime.parse(pass['valid_date']);
    final isUsed = pass['status'] == 'used';
    final statusColor = isUsed ? Colors.grey : Colors.green;
    final statusLabel = isUsed ? 'USED' : 'APPROVED';
    final initials = (pass['visitor_name'] as String)
        .trim()
        .split(' ')
        .where((s) => s.isNotEmpty)
        .take(2)
        .map((s) => s[0].toUpperCase())
        .join();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
          // ── Top section ──
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar
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
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              pass['visitor_name'],
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          // Status chip
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 9, vertical: 3),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              statusLabel,
                              style: TextStyle(
                                fontSize: 10,
                                color: statusColor,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        DateFormat('d MMM, yyyy').format(validDate),
                        style: const TextStyle(
                            fontSize: 12, color: Colors.black38),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Purpose: ${pass['purpose'] ?? 'General'}',
                        style: const TextStyle(
                            fontSize: 12, color: Colors.black45),
                      ),
                      if (pass['events'] != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          pass['events']['title'],
                          style: const TextStyle(
                              fontSize: 12, color: Colors.black45),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── View QR button (approved only) ──
          if (!isUsed) ...[
            const Divider(height: 1, thickness: 1, color: Color(0xFFF0EBE6)),
            InkWell(
              onTap: () => _showQRDialog(pass),
              borderRadius:
              const BorderRadius.vertical(bottom: Radius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.qr_code_2, size: 18, color: Color(0xFF9A4B3C)),
                    SizedBox(width: 6),
                    Text(
                      'View QR Code',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF9A4B3C),
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

  Widget _cardInfoRow(IconData icon, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 5),
    child: Row(children: [
      Icon(icon, size: 14, color: Colors.black45),
      const SizedBox(width: 6),
      Expanded(
        child: Text(text,
            style: const TextStyle(
                fontSize: 13, color: Colors.black54)),
      ),
    ]),
  );

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