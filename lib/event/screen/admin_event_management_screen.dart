import 'package:flutter/material.dart';
import '../model/event_model.dart';
import '../service/event_service.dart';

class AdminEventManagementScreen extends StatefulWidget {
  const AdminEventManagementScreen({super.key});

  @override
  _AdminEventManagementScreenState createState() => _AdminEventManagementScreenState();
}

class _AdminEventManagementScreenState extends State<AdminEventManagementScreen> {
  final EventService _eventService = EventService();

  // Theme colors
  final Color cork = const Color(0xFFAD8762);
  final Color apricot = const Color(0xFFFFB38A);
  final Color creamBg = const Color(0xFFFFF8F0);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: creamBg,
      appBar: AppBar(
        title: const Text("Event Approvals",
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: cork,
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: true,
      ),
      body: FutureBuilder<List<CommunityEvent>>(
        // Re-fetching pending events
        future: _eventService.fetchPendingEvents(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: apricot));
          }

          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }

          final pendingEvents = snapshot.data ?? [];

          if (pendingEvents.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.fact_check, size: 60, color: cork.withOpacity(0.5)),
                  const SizedBox(height: 10),
                  Text("All caught up! No pending requests.",
                      style: TextStyle(color: cork, fontWeight: FontWeight.w500)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: pendingEvents.length,
            itemBuilder: (context, index) => _buildRequestCard(pendingEvents[index]),
          );
        },
      ),
    );
  }

  Widget _buildRequestCard(CommunityEvent event) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(event.title,
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: cork)),
                ),
                _buildTypeBadge(),
              ],
            ),
            const Divider(),
            // Ensure this matches your model variable: event.createdByName or event.createdBy
            _buildDetailRow(Icons.person, "Requested by: ${event.createdByDisplayName}"),
            _buildDetailRow(Icons.location_on, "Location: ${event.location}"),
            _buildDetailRow(Icons.calendar_today, "Date: ${event.eventDate.toLocal().toString().split(' ')[0]}"),
            _buildDetailRow(Icons.access_time, "Time: ${event.startTime} - ${event.endTime}"),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _processAction(event, false),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text("Reject", style: TextStyle(color: Colors.red)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _processAction(event, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: cork,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text("Approve", style: TextStyle(color: Colors.white)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: apricot),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Colors.black87),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: apricot.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text("BOOKING",
          style: TextStyle(color: apricot, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  void _processAction(CommunityEvent event, bool isApproval) async {
    if (isApproval) {
      await _eventService.approveAndPromoteRequest(event.id);
      _showSnackBar("Event Approved!");
      setState(() {});
    } else {
      // Show Dialog to get the reason
      String? reason = await _showRejectDialog();
      if (reason != null && reason.isNotEmpty) {
        await _eventService.rejectRequest(event.id, reason);
        _showSnackBar("Event Rejected: $reason");
        setState(() {});
      }
    }
  }

  // Add this new helper method
  Future<String?> _showRejectDialog() async {
    TextEditingController reasonController = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Reject Reason"),
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(hintText: "Enter reason for rejection"),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, reasonController.text),
            child: const Text("Confirm"),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}