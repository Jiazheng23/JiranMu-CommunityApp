import 'package:assignment/facility/facility_service.dart';
import 'package:flutter/material.dart';

class ResidentBookingHistoryPage extends StatefulWidget {
  const ResidentBookingHistoryPage({super.key});

  @override
  State<ResidentBookingHistoryPage> createState() =>
      _ResidentBookingHistoryPageState();
}

class _ResidentBookingHistoryPageState
    extends State<ResidentBookingHistoryPage> {
  final FacilityService _facilityService = FacilityService();

  bool _isLoading = true;
  String _statusFilter = 'all';

  List<Map<String, dynamic>> _requests = [];
  List<Map<String, dynamic>> _confirmedBookings = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final requests = await _facilityService.fetchMyFacilityRequests();
      final bookings = await _facilityService.fetchMyConfirmedBookings();

      if (!mounted) return;

      setState(() {
        _requests = requests;
        _confirmedBookings = bookings;
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

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'pending':
        return Colors.orange;
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

  List<Map<String, dynamic>> _buildUnifiedHistory() {
    final List<Map<String, dynamic>> items = [];

    // A. facility requests (pending / approved / rejected)
    for (final request in _requests) {
      final detail = _extractSubData(request['facility_requests']);
      final facility = _extractSubData(detail?['facilities']);

      items.add({
        'source': 'request',
        'status': request['status']?.toString() ?? 'pending',
        'facility_name': facility?['name']?.toString() ?? 'Facility',
        'location': facility?['location']?.toString() ?? '-',
        'booking_date': detail?['booking_date']?.toString() ?? '-',
        'start_time': detail?['start_time']?.toString() ?? '-',
        'end_time': detail?['end_time']?.toString() ?? '-',
        'participants': detail?['participants']?.toString() ?? '-',
        'purpose': detail?['purpose']?.toString() ?? '-',
        'reject_reason': request['reject_reason']?.toString(),
        'source_label': 'Facility Request',
        'created_at': request['created_at']?.toString(),
      });
    }

    // B. only confirmed bookings without request_id
    // instant / shared instant only
    for (final booking in _confirmedBookings) {
      if (booking['request_id'] != null) continue;

      final facility = _extractSubData(booking['facilities']);
      final isShared = facility?['is_shared'] ?? false;

      items.add({
        'source': 'booking',
        'status': 'approved',
        'facility_name': facility?['name']?.toString() ?? 'Facility',
        'location': facility?['location']?.toString() ?? '-',
        'booking_date': booking['booking_date']?.toString() ?? '-',
        'start_time': booking['start_time']?.toString() ?? '-',
        'end_time': booking['end_time']?.toString() ?? '-',
        'participants': booking['participants']?.toString() ?? '1',
        'purpose': booking['purpose']?.toString() ?? '-',
        'reject_reason': null,
        'source_label': isShared
            ? 'Shared Instant Booking'
            : 'Instant Booking',
        'created_at': booking['created_at']?.toString(),
      });
    }

    // Optional: sort by created_at descending if available
    items.sort((a, b) {
      final aTime = a['created_at']?.toString() ?? '';
      final bTime = b['created_at']?.toString() ?? '';
      return bTime.compareTo(aTime);
    });

    return items;
  }

  List<Map<String, dynamic>> _filteredHistory() {
    final allItems = _buildUnifiedHistory();

    if (_statusFilter == 'all') return allItems;

    return allItems
        .where((item) =>
    item['status']?.toString().toLowerCase() == _statusFilter)
        .toList();
  }

  Widget _buildTopTab(String label, String value) {
    final isSelected = _statusFilter == value;

    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _statusFilter = value;
          });
        },
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isSelected ? Colors.white : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.white70,
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryCard(Map<String, dynamic> item) {
    final status = item['status']?.toString() ?? 'pending';
    final facilityName = item['facility_name']?.toString() ?? 'Facility';
    final location = item['location']?.toString() ?? '-';
    final bookingDate = item['booking_date']?.toString() ?? '-';
    final startTime = item['start_time']?.toString() ?? '-';
    final endTime = item['end_time']?.toString() ?? '-';
    final participants = item['participants']?.toString() ?? '-';
    final purpose = item['purpose']?.toString() ?? '-';
    final rejectReason = item['reject_reason']?.toString();

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: Colors.grey.shade200),
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
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                _buildStatusChip(status),
              ],
            ),
            const SizedBox(height: 10),
            Text('Date: $bookingDate'),
            Text('Time: $startTime - $endTime'),
            Text('Location: $location'),
            Text('Participants: $participants'),
            Text('Purpose: $purpose'),
            if (status.toLowerCase() == 'rejected' &&
                rejectReason != null &&
                rejectReason.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Reject Reason: $rejectReason',
                style: const TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Text(
        message,
        style: const TextStyle(
          fontSize: 14,
          color: Colors.black54,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final historyItems = _filteredHistory();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F1ED),
      appBar: AppBar(
        backgroundColor: const Color(0xFF9A4B3C),
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Booking History',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            color: const Color(0xFF9A4B3C),
            child: Row(
              children: [
                _buildTopTab('All', 'all'),
                _buildTopTab('Pending', 'pending'),
                _buildTopTab('Approved', 'approved'),
                _buildTopTab('Rejected', 'rejected'),
              ],
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: _loadHistory,
        child: historyItems.isEmpty
            ? ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 180),
            Center(
              child: Text(
                'No facility history found.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.black54,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        )
            : ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          itemCount: historyItems.length,
          itemBuilder: (context, index) {
            return _buildHistoryCard(historyItems[index]);
          },
        ),
      ),
    );
  }
}