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

class _VisitorPassListScreenState extends State<VisitorPassListScreen> {
  final _client = Supabase.instance.client;
  late Future<List<Map<String, dynamic>>> _passesFuture;

  @override
  void initState() {
    super.initState();
    _passesFuture = _loadPasses();
  }

  Future<List<Map<String, dynamic>>> _loadPasses() async {
    final res = await _client
        .from('visitor_passes')
        .select('*, events(title)')
        .eq('resident_id', _client.auth.currentUser!.id)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(res);
  }

  void _showQR(Map<String, dynamic> pass) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.85,
        expand: false,
        builder: (_, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(30),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Text(
              'Visitor Pass',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              pass['visitor_name'],
              style: const TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 16),
            QrImageView(
              data: pass['qr_token'],
              version: QrVersions.auto,
              size: 310,
            ),
            const SizedBox(height: 10),
            Text(
              'Valid: ${DateFormat('d MMM yyyy').format(DateTime.parse(pass['valid_date']))}',
              style: const TextStyle(color: Colors.black54, fontSize: 13),
            ),
            if (pass['events'] != null)
              Text(
                'Event: ${pass['events']['title']}',
                style: const TextStyle(color: Colors.black54, fontSize: 13),
              ),
            const SizedBox(height: 8),
            _statusChip(pass['status']),
          ]),
        ),
      ),
    );
  }

  /// Groups passes by how many days until their valid_date
  Map<String, List<Map<String, dynamic>>> _groupByDaysToGo(
      List<Map<String, dynamic>> passes) {
    final Map<String, List<Map<String, dynamic>>> groups = {};
    final today = DateTime.now();
    for (final p in passes) {
      final validDate = DateTime.parse(p['valid_date']);
      final diff = validDate.difference(DateTime(today.year, today.month, today.day)).inDays;
      String label;
      if (diff < 0) {
        label = 'Past';
      } else if (diff == 0) {
        label = 'Today';
      } else if (diff == 1) {
        label = '1 day to go';
      } else {
        label = '$diff days to go';
      }
      groups.putIfAbsent(label, () => []).add(p);
    }
    return groups;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F1ED),
      appBar: AppBar(
        title: const Text('My Visitor Passes'),
        backgroundColor: const Color(0xFF9A4B3C),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const VisitorPassRequestScreen()),
            ),
          )
        ],
      ),
      body: FutureBuilder(
        future: _passesFuture,
        builder: (_, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final passes = snap.data ?? [];
          if (passes.isEmpty) {
            return const Center(child: Text('No visitor passes yet.'));
          }

          final groups = _groupByDaysToGo(passes);

          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            children: groups.entries.map((entry) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12, top: 4),
                    child: Text(
                      entry.key,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.black45,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                  ...entry.value.map((p) => _PassCard(
                    pass: p,
                    onViewQR: p['status'] == 'approved' ? () => _showQR(p) : null,
                  )),
                  const SizedBox(height: 8),
                ],
              );
            }).toList(),
          );
        },
      ),
    );
  }

  Widget _statusChip(String status) {
    final colors = {
      'pending': Colors.orange,
      'approved': Colors.green,
      'rejected': Colors.red,
      'used': Colors.grey,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: (colors[status] ?? Colors.grey).withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          color: colors[status] ?? Colors.grey,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

// ─── Pass Card Widget ────────────────────────────────────────────────────────

class _PassCard extends StatelessWidget {
  final Map<String, dynamic> pass;
  final VoidCallback? onViewQR;

  const _PassCard({required this.pass, this.onViewQR});

  @override
  Widget build(BuildContext context) {
    final statusColors = {
      'pending': Colors.orange,
      'approved': Colors.green,
      'rejected': Colors.red,
      'used': Colors.grey,
    };
    final status = pass['status'] as String;
    final statusColor = statusColors[status] ?? Colors.grey;
    final validDate = DateFormat('d MMM, yyyy').format(DateTime.parse(pass['valid_date']));
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
          // ── Top row: avatar + info + menu ──
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 8, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar with initials
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
                // Name, event/note, date
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
                          // Status chip (top-right)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
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
                        ],
                      ),
                      const SizedBox(height: 3),
                      if (pass['events'] != null)
                        Text(
                          pass['events']['title'],
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.black54,
                          ),
                        ),
                      const SizedBox(height: 3),
                      Text(
                        validDate,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black38,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Divider ──
          if (onViewQR != null) ...[
            const Divider(height: 1, thickness: 1, color: Color(0xFFF0EBE6)),

            // ── View QR Code button ──
            InkWell(
              onTap: onViewQR,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
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
}