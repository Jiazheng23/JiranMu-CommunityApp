import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../AdminVisitorPassScreen.dart';
import 'request_detail_page.dart';
import 'request_list_page.dart';


class AdminRequestsPage extends StatefulWidget {
  const AdminRequestsPage({super.key});

  @override
  State<AdminRequestsPage> createState() => _AdminRequestsPageState();
}

class _AdminRequestsPageState extends State<AdminRequestsPage> {
  final supabase = Supabase.instance.client;

  Map<String, List> grouped = {
    'user': [],
    'event': [],
    'facility': [],
    'visitor': [],
  };

  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchRequests();
  }

  Future<void> fetchRequests() async {
    try {
      setState(() => isLoading = true);

      final data = await supabase
          .from('requests')
          .select('''
            *,
            resident_requests(*),
            admin_requests(*),
            visitor_requests(*),
            facility_requests(*),
            event_requests(*)
          ''')
          .order('created_at', ascending: false)
          .limit(20);

      Map<String, List> temp = {
        'user': [],
        'event': [],
        'facility': [],
        'visitor': [],
      };

      for (var r in data) {
        final type = r['type'];
        if (type == 'visitor') {
          temp['visitor']!.add(r);
        } else if (type == 'facility') {
          temp['facility']!.add(r);
        } else if (type == 'complaint') {
          temp['event']!.add(r);
        } else if (type == 'admin' || type == 'resident') {
          temp['user']!.add(r);
        }
      }

      setState(() {
        grouped = temp;
        isLoading = false;
      });
    } catch (e) {
      debugPrint("Fetch error: $e");
      setState(() => isLoading = false);
    }
  }

  void navigateTo(String type) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => RequestListPage(type: type)),
    );
  }

  Widget buildRequestCard(Map data) {
    String status = (data['status'] ?? "pending").toString().toLowerCase();

    Color statusColor;
    if (status == 'approved') {
      statusColor = const Color(0xFF6B8E6B);
    } else if (status == 'rejected') {
      statusColor = const Color(0xFFC67B75);
    } else {
      statusColor = const Color(0xFFD49A6A);
    }

    IconData placeholderIcon;
    String reqType = (data['type'] ?? "").toString().toLowerCase();
    if (reqType == 'visitor') {
      placeholderIcon = Icons.badge_outlined;
    } else if (reqType == 'booking') {
      placeholderIcon = Icons.meeting_room_outlined;
    } else if (reqType == 'complaint') {
      placeholderIcon = Icons.event_note_outlined;
    } else {
      placeholderIcon = Icons.person_outline;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9F5F3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => RequestDetailPage(data: data),
              ),
            ).then((_) => fetchRequests());
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(2),
                  margin: const EdgeInsets.only(right: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B5E4A).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: CircleAvatar(
                    radius: 22,
                    backgroundColor: const Color(0xFFEADFD6),
                    child: Icon(placeholderIcon, color: const Color(0xFF8B5E4A), size: 22),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data['title'] ?? "No Title",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Color(0xFF2B2B2B),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        data['description'] ?? "",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        data['created_at'].toString().substring(0, 16).replaceAll('T', ' '),
                        style: TextStyle(color: Colors.grey.shade400, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        status.toUpperCase(),
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Icon(Icons.chevron_right, color: Color(0xFF8B5E4A), size: 20),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget buildTopButton(String title, IconData icon, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          margin: const EdgeInsets.symmetric(horizontal: 5),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF8B5E4A).withOpacity(0.08),
                blurRadius: 10,
                offset: const Offset(0, 5),
              )
            ],
          ),
          child: Column(
            children: [
              Icon(icon, size: 28, color: const Color(0xFF8B5E4A)),
              const SizedBox(height: 6),
              FittedBox(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2B2B2B),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── UPDATED: accepts optional onViewAll override ──────────────────────────
  Widget buildSection(String title, String key, {VoidCallback? onViewAll}) {
    final list = grouped[key]!;
    if (list.isEmpty) return const SizedBox();

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8B5E4A).withOpacity(0.06),
            blurRadius: 15,
            spreadRadius: 0,
            offset: const Offset(0, 5),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "$title Requests",
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2B2B2B),
                ),
              ),
              TextButton(
                // ← Use override if provided, else default navigateTo
                onPressed: onViewAll ?? () => navigateTo(title),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(50, 30),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  "View All",
                  style: TextStyle(
                    color: Color(0xFF8B5E4A),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          ...list.take(2).map((r) => buildRequestCard(r)).toList(),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5EBE6),
      appBar: AppBar(
        title: const Text(
          "Request",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        backgroundColor: const Color(0xFFF5EBE6),
        foregroundColor: const Color(0xFF2B2B2B),
        elevation: 0,
        centerTitle: true,
      ),
      body: RefreshIndicator(
        color: const Color(0xFF8B5E4A),
        onRefresh: fetchRequests,
        child: isLoading
            ? const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8B5E4A)),
          ),
        )
            : ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          children: [
            Row(
              children: [
                buildTopButton("Users", Icons.person, () => navigateTo("Users")),
                buildTopButton("Event", Icons.event, () => navigateTo("Event")),
                buildTopButton("Facilities", Icons.home, () => navigateTo("Facilities")),
                // ← Visitor top button also opens AdminVisitorPassScreen
                buildTopButton("Visitor", Icons.badge, () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AdminVisitorPassScreen(),
                    ),
                  );
                }),
              ],
            ),
            const SizedBox(height: 25),
            const Text(
              "Recent Requests",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2B2B2B),
              ),
            ),
            const SizedBox(height: 5),
            buildSection("Users", "user"),
            buildSection("Event", "event"),
            buildSection("Facilities", "facility"),
            // ← Visitor "View All" opens AdminVisitorPassScreen
            buildSection(
              "Visitor",
              "visitor",
              onViewAll: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AdminVisitorPassScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}