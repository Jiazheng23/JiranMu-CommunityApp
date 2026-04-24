import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../emergency/emergency_list_page.dart';
import '../request/request_list_page.dart';

class AdminNotificationsPage extends StatefulWidget {
  const AdminNotificationsPage({super.key});

  @override
  State<AdminNotificationsPage> createState() => _AdminNotificationsPageState();
}

class _AdminNotificationsPageState extends State<AdminNotificationsPage> {
  final supabase = Supabase.instance.client;
  List<dynamic> notifications = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  Future<void> _fetchNotifications() async {
    setState(() => isLoading = true);
    try {
      final requestsResponse = await supabase
          .from('requests')
          .select('*')
          .eq('status', 'pending')
          .order('created_at', ascending: false)
          .limit(20);

      final emergencyResponse = await supabase
          .from('emergency')
          .select('*')
          .eq('status', 'active')
          .order('created_at', ascending: false)
          .limit(20);

      List<dynamic> combinedList = [];
      combinedList.addAll(requestsResponse);

      for (var emg in emergencyResponse) {
        combinedList.add({
          'id': emg['id'] ?? emg['emergency_id'],
          'type': 'emergency',
          'title': '🚨 EMERGENCY SOS!',
          'description': emg['description'] ?? emg['reason'] ?? 'Immediate attention required.',
          'created_at': emg['created_at'],
          'status': emg['status'] ?? 'pending',
          'original_data': emg,
        });
      }

      combinedList.sort((a, b) {
        final dateA = DateTime.tryParse(a['created_at']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
        final dateB = DateTime.tryParse(b['created_at']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
        return dateB.compareTo(dateA);
      });

      if (combinedList.length > 20) {
        combinedList = combinedList.sublist(0, 20);
      }

      setState(() {
        notifications = combinedList;
      });
    } catch (e) {
      debugPrint("Error fetching notifications: $e");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  IconData _getIconForType(String type) {
    switch (type.toLowerCase()) {
      case 'emergency':
        return Icons.emergency;
      case 'resident':
        return Icons.person_add_alt_1;
      case 'visitor':
        return Icons.directions_walk;
      case 'facility':
      case 'booking':
        return Icons.event_available;
      case 'complaint':
        return Icons.report_problem_outlined;
      default:
        return Icons.notifications_active;
    }
  }

  Color _getColorForType(String type) {
    switch (type.toLowerCase()) {
      case 'emergency':
        return Colors.red;
      case 'resident':
        return Colors.blue;
      case 'visitor':
        return Colors.orange;
      case 'facility':
      case 'booking':
        return Colors.green;
      case 'complaint':
        return Colors.redAccent;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F1ED),
      appBar: AppBar(
        title: const Text("Notifications", style: TextStyle(color: Colors.black87)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchNotifications,
          )
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : notifications.isEmpty
          ? _buildEmptyState()
          : RefreshIndicator(
        onRefresh: _fetchNotifications,
        child: ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: notifications.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final item = notifications[index];
            final type = item['type'] ?? 'system';
            final title = item['title'] ?? 'New Request';
            final desc = item['description'] ?? '';
            final rawDate = item['created_at'];

            String timeText = '';
            if (rawDate != null) {
              try {
                final date = DateTime.parse(rawDate);
                timeText = timeago.format(date);
              } catch (e) {
                timeText = rawDate.toString().substring(0, 10);
              }
            }

            return Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: type.toLowerCase() == 'emergency'
                    ? Border.all(color: Colors.red.shade200, width: 1.5)
                    : null,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _getColorForType(type).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _getIconForType(type),
                    color: _getColorForType(type),
                  ),
                ),
                title: Text(
                  title,
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: type.toLowerCase() == 'emergency' ? Colors.red.shade800 : Colors.black87
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text(
                      desc,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.black54, fontSize: 13),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      timeText,
                      style: const TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                trailing: Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: Colors.redAccent,
                    shape: BoxShape.circle,
                  ),
                ),
                onTap: () {
                  final dbType = type.toLowerCase();
                  String? targetPageType;
                  Widget? emergencyPage;

                  switch (dbType) {
                    case 'resident':
                    case 'user':
                      targetPageType = "Users";
                      break;
                    case 'event':
                    case 'booking':
                      targetPageType = "Event";
                      break;
                    case 'facility':
                      targetPageType = "Facilities";
                      break;
                    case 'visitor':
                      targetPageType = "Visitor";
                      break;
                    case 'emergency':
                      emergencyPage = const EmergencyListPage();
                      break;
                    default:
                      targetPageType = null;
                  }

                  if (targetPageType != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => RequestListPage(type: targetPageType!),
                      ),
                    ).then((_) => _fetchNotifications());
                  } else if (emergencyPage != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => emergencyPage!,
                      ),
                    ).then((_) => _fetchNotifications());
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Unknown request type.")),
                    );
                  }
                },
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_off_outlined, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text(
            "No new notifications",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black54),
          ),
          const SizedBox(height: 8),
          const Text(
            "You're all caught up!",
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}