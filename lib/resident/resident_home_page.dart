import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../event/screen/event_calendar_screen.dart';
import '../event/service/event_service.dart'; // Ensure this path is correct
import '../event/model/event_model.dart';   // Ensure this path is correct

class ResidentHomePage extends StatefulWidget {
  const ResidentHomePage({super.key});

  @override
  State<ResidentHomePage> createState() => _ResidentHomePageState();
}

class _ResidentHomePageState extends State<ResidentHomePage> {
  int currentIndex = 0;
  final EventService _eventService = EventService();

  final Color bgColor = const Color(0xFFF5F1ED);
  final Color primaryColor = const Color(0xFF9A4B3C);
  final Color accentColor = const Color(0xFFF26A3D);
  final Color softYellow = const Color(0xFFF0E6B8);
  final Color textDark = const Color(0xFF2B2B2B);

  Future<void> logout() async {
    await Supabase.instance.client.auth.signOut();
    if (!mounted) return;
    Navigator.popUntil(context, (route) => route.isFirst);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Logged out successfully")),
    );
  }

  // --- UI Helper Components ---

  Widget buildServiceItem({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Column(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: color.withOpacity(0.18),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: textDark,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildSectionTitle(String title, {VoidCallback? onSeeAll}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: textDark,
            ),
          ),
          if (onSeeAll != null)
            GestureDetector(
              onTap: onSeeAll,
              child: Text(
                "See All",
                style: TextStyle(
                  color: primaryColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget buildAnnouncementCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Power outage announcement",
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: textDark,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "Please be informed that maintenance works are scheduled from 10 AM to 12 PM. Power supply will be temporarily interrupted in Block A.",
            style: TextStyle(fontSize: 13, color: Colors.black54, height: 1.5),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const CircleAvatar(
                radius: 14,
                backgroundColor: Color(0xFFEADFD6),
                child: Icon(Icons.business, size: 14, color: Color(0xFF9A4B3C)),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  "Office Management",
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ),
              Text(
                "5 Jan, 2026",
                style: TextStyle(
                  fontSize: 12,
                  color: primaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- Updated: Dynamic Event Card ---
  Widget buildDynamicEventCard(CommunityEvent event) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Event Image or Placeholder
          Container(
            height: 150,
            width: double.infinity,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
              child: event.imageUrl != null && event.imageUrl!.isNotEmpty
                  ? Image.network(event.imageUrl!, fit: BoxFit.cover)
                  : Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFF7D7C8), Color(0xFFF4B39B)],
                  ),
                ),
                child: Icon(Icons.event, size: 40, color: primaryColor),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.title,
                  style: TextStyle(
                    color: textDark,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.location_on, color: accentColor, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      event.location,
                      style: const TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                    const SizedBox(width: 12),
                    Icon(Icons.calendar_today, color: accentColor, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      event.formattedDate,
                      style: const TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const EventCalendarScreen(),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text("View Details"),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- Home Tab Content ---
  Widget buildHomeTab() {
    return RefreshIndicator(
      onRefresh: () async {
        setState(() {}); // Pull to refresh the data
      },
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Location Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.location_on_outlined, color: primaryColor, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    "BLOCK A",
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: primaryColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.keyboard_arrow_down_rounded),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              "Welcome back",
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: textDark,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              "Manage your community services and stay informed.",
              style: TextStyle(fontSize: 14, color: Colors.black54, height: 1.5),
            ),
            const SizedBox(height: 22),

            // Community Banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: softYellow,
                borderRadius: BorderRadius.circular(26),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      "JiranMu keeps your community connected, safe and informed.",
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: primaryColor,
                        height: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.85),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Icon(Icons.groups_rounded, color: primaryColor, size: 28),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
            buildSectionTitle("Services"),
            Row(
              children: [
                buildServiceItem(
                  icon: Icons.badge_outlined,
                  color: const Color(0xFFE96B9E),
                  label: "Visitors",
                  onTap: () {},
                ),
                buildServiceItem(
                  icon: Icons.fitness_center,
                  color: const Color(0xFF4BC0B8),
                  label: "Facility",
                  onTap: () {},
                ),
                buildServiceItem(
                  icon: Icons.event_note_outlined,
                  color: const Color(0xFF758BFD),
                  label: "Events",
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const EventCalendarScreen()),
                  ),
                ),
                buildServiceItem(
                  icon: Icons.sos_outlined,
                  color: const Color(0xFFFF5A5A),
                  label: "SOS",
                  onTap: () {},
                ),
              ],
            ),

            const SizedBox(height: 28),
            buildSectionTitle("Announcement"),
            buildAnnouncementCard(),

            const SizedBox(height: 28),
            buildSectionTitle(
              "Upcoming Events",
              onSeeAll: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const EventCalendarScreen()),
              ),
            ),

            // --- Updated: Dynamic Fetching logic ---
            FutureBuilder<List<CommunityEvent>>(
              // Fetches all unexpired events automatically
              future: _eventService.fetchAllEvents(upcomingOnly: true),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: CircularProgressIndicator(),
                    ),
                  );
                }

                if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 30),
                    child: const Center(
                      child: Text(
                        "No upcoming events found.",
                        style: TextStyle(color: Colors.black38),
                      ),
                    ),
                  );
                }

                return Column(
                  children: snapshot.data!
                      .map((event) => buildDynamicEventCard(event))
                      .toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // --- Other Tabs ---

  Widget buildCommunityTab() => const Center(child: Text("Community Page"));
  Widget buildChatsTab() => const Center(child: Text("Chats Page"));
  Widget buildAccountTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
      child: Column(
        children: [
          CircleAvatar(
            radius: 42,
            backgroundColor: const Color(0xFFEADFD6),
            child: Icon(Icons.person, size: 42, color: primaryColor),
          ),
          const SizedBox(height: 14),
          const Text("Resident Account", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          ListTile(
            leading: Icon(Icons.logout, color: primaryColor),
            title: const Text("Logout"),
            onTap: logout,
          ),
        ],
      ),
    );
  }

  Widget getCurrentPage() {
    switch (currentIndex) {
      case 0: return buildHomeTab();
      case 1: return buildCommunityTab();
      case 2: return buildChatsTab();
      case 3: return buildAccountTab();
      default: return buildHomeTab();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(child: getCurrentPage()),
      bottomNavigationBar: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BottomNavigationBar(
            currentIndex: currentIndex,
            onTap: (index) => setState(() => currentIndex = index),
            type: BottomNavigationBarType.fixed,
            selectedItemColor: primaryColor,
            unselectedItemColor: Colors.black38,
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: "Home"),
              BottomNavigationBarItem(icon: Icon(Icons.groups_rounded), label: "Community"),
              BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outline_rounded), label: "Chats"),
              BottomNavigationBarItem(icon: Icon(Icons.person_outline_rounded), label: "Account"),
            ],
          ),
        ),
      ),
    );
  }
}