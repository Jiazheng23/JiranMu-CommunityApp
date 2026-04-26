import 'package:assignment/facility/facility_service.dart';
import 'package:flutter/material.dart';

class ResidentBookingHistoryPage extends StatefulWidget {
  const ResidentBookingHistoryPage({super.key});

  @override
  State<ResidentBookingHistoryPage> createState() =>
      _ResidentBookingHistoryPageState();
}

class _ResidentBookingHistoryPageState
    extends State<ResidentBookingHistoryPage>
    with SingleTickerProviderStateMixin {
  final FacilityService _facilityService = FacilityService();

  static const Color bgColor = Color(0xFFF5F1ED);
  static const Color primaryColor = Color(0xFF9A4B3C);
  static const Color textDark = Color(0xFF2B2B2B);

  late TabController _tabController;

  bool _isLoading = true;
  List<Map<String, dynamic>> _history = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadHistory();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final history = await _facilityService.fetchMyBookingHistory();

      if (!mounted) return;

      setState(() {
        _history = history;
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load booking history: $e')),
      );
    } finally {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });
    }
  }

  Map<String, dynamic>? _extractSubData(dynamic raw) {
    if (raw == null) return null;
    if (raw is Map<String, dynamic>) return raw;
    if (raw is List && raw.isNotEmpty) {
      final first = raw.first;
      if (first is Map<String, dynamic>) return first;
    }
    return null;
  }

  String _formatDate(String raw) {
    if (raw.trim().isEmpty) return '-';

    try {
      final date = DateTime.parse(raw);
      final day = date.day.toString().padLeft(2, '0');
      final month = date.month.toString().padLeft(2, '0');
      final year = date.year.toString();
      return '$day/$month/$year';
    } catch (_) {
      return raw;
    }
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed':
        return Colors.green;
      case 'cancelled':
        return Colors.redAccent;
      default:
        return Colors.grey;
    }
  }

  Widget _buildStatusChip(String status) {
    final color = _statusColor(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _historyByStatus(String status) {
    if (status == 'all') return _history;

    return _history
        .where(
          (item) => item['status']?.toString().toLowerCase() == status,
    )
        .toList();
  }

  Widget _buildHistoryCard(Map<String, dynamic> item) {
    final facility = _extractSubData(item['facilities']);

    final status = item['status']?.toString() ?? 'confirmed';
    final facilityName = facility?['name']?.toString() ?? 'Facility';
    final location = facility?['location']?.toString() ?? '-';
    final bookingDate = item['booking_date']?.toString() ?? '-';
    final startTime = item['start_time']?.toString() ?? '-';
    final endTime = item['end_time']?.toString() ?? '-';
    final participants = item['participants']?.toString() ?? '1';
    final cancelReason = item['cancel_reason']?.toString();
    final cancelledAt = item['cancelled_at']?.toString();

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
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    facilityName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: textDark,
                    ),
                  ),
                ),
                _buildStatusChip(status),
              ],
            ),
            const SizedBox(height: 10),
            Text('Date: ${_formatDate(bookingDate)}'),
            Text(
              'Time: ${_facilityService.formatDbTimeTo12Hour(startTime)} - '
                  '${_facilityService.formatDbTimeTo12Hour(endTime)}',
            ),
            Text('Location: $location'),
            Text('Participants: $participants'),
            if (status.toLowerCase() == 'cancelled') ...[
              const SizedBox(height: 8),
              Text(
                'Cancelled by admin',
                style: const TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (cancelReason != null && cancelReason.trim().isNotEmpty)
                Text(
                  'Reason: $cancelReason',
                  style: const TextStyle(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              if (cancelledAt != null && cancelledAt.trim().isNotEmpty)
                Text(
                  'Cancelled on: ${_formatDate(cancelledAt)}',
                  style: const TextStyle(
                    color: Colors.black54,
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryList(
      List<Map<String, dynamic>> items, {
        required IconData emptyIcon,
        required String emptyMsg,
      }) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: primaryColor),
      );
    }

    if (items.isEmpty) {
      return RefreshIndicator(
        color: primaryColor,
        onRefresh: _loadHistory,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 180),
            Column(
              children: [
                Icon(emptyIcon, size: 64, color: Colors.black12),
                const SizedBox(height: 12),
                Text(
                  emptyMsg,
                  style: const TextStyle(
                    color: Colors.black38,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: primaryColor,
      onRefresh: _loadHistory,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) => _buildHistoryCard(items[index]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final allItems = _historyByStatus('all');
    final approvedItems = _historyByStatus('confirmed');
    final cancelledItems = _historyByStatus('cancelled');

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text('Booking History'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Approved'),
            Tab(text: 'Cancelled'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildHistoryList(
            allItems,
            emptyIcon: Icons.history,
            emptyMsg: 'No booking history found',
          ),
          _buildHistoryList(
            approvedItems,
            emptyIcon: Icons.check_circle_outline,
            emptyMsg: 'No confirmed booking history',
          ),
          _buildHistoryList(
            cancelledItems,
            emptyIcon: Icons.cancel_outlined,
            emptyMsg: 'No cancelled booking history',
          ),
        ],
      ),
    );
  }
}