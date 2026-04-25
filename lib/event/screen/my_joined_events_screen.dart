import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart'; // 1. Added Import
import 'package:assignment/event/model/event_model.dart';
import 'package:assignment/event/service/event_service.dart';
import 'event_details_screen.dart';

class MyJoinedEventsScreen extends StatefulWidget {
  final String currentUserId;
  final String currentRole;

  const MyJoinedEventsScreen({
    super.key,
    required this.currentUserId,
    required this.currentRole,
  });

  @override
  State<MyJoinedEventsScreen> createState() => _MyJoinedEventsScreenState();
}

class _MyJoinedEventsScreenState extends State<MyJoinedEventsScreen> {
  // ── THEME COLORS ──────────────────────────────
  final Color primaryRed = const Color(0xFF9A4B3C); // Deep Red/Brown
  final Color accentPeach = const Color(0xFFFC9D7E); // Apricot/Peach
  final Color bgColor = const Color(0xFFF5F1ED);    // Beige Background

  final EventService _eventService = EventService();
  List<String> _seenJoinedIds = []; // 2. Track seen IDs locally

  // Filter: 'all', 'upcoming', 'past'
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    _loadSeenIds();
  }

  // 3. Load the list of IDs the user has already acknowledged
  Future<void> _loadSeenIds() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _seenJoinedIds = prefs.getStringList('seen_joined_event_ids') ?? [];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text(
          "My Joined Events",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: primaryRed,
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: true,
        elevation: 0,
      ),
      body: FutureBuilder<List<CommunityEvent>>(
        future: _eventService.fetchJoinedEvents(widget.currentUserId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
                child: CircularProgressIndicator(color: accentPeach));
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  "Error loading joined events: ${snapshot.error}",
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.black54),
                ),
              ),
            );
          }

          final allEvents = snapshot.data ?? [];

          if (allEvents.isEmpty) {
            return _buildEmptyState();
          }

          final now = DateTime.now();
          final filtered = allEvents.where((e) {
            if (_filter == 'upcoming') return e.eventDate.isAfter(now);
            if (_filter == 'past') return e.eventDate.isBefore(now);
            return true;
          }).toList();

          filtered.sort((a, b) => a.eventDate.compareTo(b.eventDate));

          return Column(
            children: [
              _buildFilterBar(allEvents, now),
              Expanded(
                child: filtered.isEmpty
                    ? _buildEmptyFilterState()
                    : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final event = filtered[index];
                    // 4. Check if this specific joined event is "NEW"
                    final bool isNew = !_seenJoinedIds.contains(event.id);

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildEventCard(event, isNew),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // --- UI COMPONENTS (UNCHANGED) ---

  Widget _buildFilterBar(List<CommunityEvent> allEvents, DateTime now) {
    final upcomingCount =
        allEvents.where((e) => e.eventDate.isAfter(now)).length;
    final pastCount =
        allEvents.where((e) => e.eventDate.isBefore(now)).length;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Row(
        children: [
          _filterChip('All', 'all', allEvents.length),
          const SizedBox(width: 8),
          _filterChip('Upcoming', 'upcoming', upcomingCount),
          const SizedBox(width: 8),
          _filterChip('Past', 'past', pastCount),
        ],
      ),
    );
  }

  Widget _filterChip(String label, String value, int count) {
    final isSelected = _filter == value;
    return GestureDetector(
      onTap: () => setState(() => _filter = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? primaryRed : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? primaryRed : Colors.grey.shade200,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.black54,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withOpacity(0.3)
                      : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color:
                    isSelected ? Colors.white : Colors.black54,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // 5. Updated buildEventCard to accept the isNew boolean
  // 5. Improved buildEventCard UI with a Sleek Black Outline
  Widget _buildEventCard(CommunityEvent event, bool isNew) {
    final now = DateTime.now();
    final isPast = event.eventDate.isBefore(now);
    final isToday = event.eventDate.year == now.year &&
        event.eventDate.month == now.month &&
        event.eventDate.day == now.day;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => EventDetailsScreen(
            event: event,
            currentRole: widget.currentRole,
            currentUserId: widget.currentUserId,
            onRefresh: () => setState(() {}),
            currentUserName: '',
          ),
        ),
      ),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          // --- THE BLACK LINE COVER (BORDER) ---
          border: Border.all(
            color: Colors.black.withOpacity(0.15), // Subtle black outline
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // --- LEFT: DATE STRIP ---
              Container(
                width: 75,
                color: isPast
                    ? Colors.grey.withOpacity(0.1)
                    : primaryRed.withOpacity(0.08),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      DateFormat('dd').format(event.eventDate),
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: isPast ? Colors.grey : primaryRed,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat('MMM').format(event.eventDate).toUpperCase(),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isPast
                            ? Colors.grey.withOpacity(0.7)
                            : primaryRed.withOpacity(0.7),
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
              ),

              // Vertical Separator Line
              VerticalDivider(
                width: 1,
                thickness: 1,
                color: Colors.black.withOpacity(0.1),
              ),

              // --- RIGHT: CONTENT ---
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              event.title,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isPast ? Colors.black45 : Colors.black87,
                                fontSize: 16,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isNew && !isPast)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.redAccent,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                "NEW",
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Location & Time
                      _buildInfoRow(Icons.location_on_rounded, event.location, isPast),
                      const SizedBox(height: 6),
                      _buildInfoRow(Icons.access_time_filled_rounded, '${event.startTime} – ${event.endTime}', isPast),

                      const SizedBox(height: 14),

                      // Footer
                      Row(
                        children: [
                          if (isToday || isPast)
                            _buildStatusBadge(isToday),
                          if (isToday || isPast) const SizedBox(width: 8),

                          // Privacy Badge
                          _buildPrivacyBadge(event),

                          const Spacer(),

                          if (!isPast)
                            GestureDetector(
                              onTap: () => _confirmLeave(event),
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.08),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.logout_rounded, size: 16, color: Colors.red),
                              ),
                            ),
                          const SizedBox(width: 8),
                          Icon(Icons.chevron_right_rounded, color: isPast ? Colors.black12 : primaryRed.withOpacity(0.4)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper UI methods to keep the card clean while preserving all logic:

  Widget _buildInfoRow(IconData icon, String text, bool isPast) {
    return Row(
      children: [
        Icon(icon, size: 14, color: isPast ? Colors.grey : accentPeach),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              color: isPast ? Colors.black38 : Colors.black54,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBadge(bool isToday) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isToday ? Colors.green.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        isToday ? '📅 Today' : '✓ Past',
        style: TextStyle(
          fontSize: 11,
          color: isToday ? Colors.green : Colors.grey,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildPrivacyBadge(CommunityEvent event) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: event.isPrivate ? Colors.purple.withOpacity(0.05) : Colors.blue.withOpacity(0.05),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Icon(
            event.isPrivate ? Icons.lock : Icons.public,
            size: 11,
            color: event.isPrivate ? Colors.purple : Colors.blue,
          ),
          const SizedBox(width: 4),
          Text(
            event.isPrivate ? "Private" : "Public",
            style: TextStyle(
              fontSize: 10,
              color: event.isPrivate ? Colors.purple : Colors.blue,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // --- REMAINING FUNCTIONS (UNCHANGED) ---

  void _confirmLeave(CommunityEvent event) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Leave Event'),
        content: Text('Are you sure you want to leave "${event.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.black54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              Navigator.pop(context);
              try {
                await _eventService.leaveEvent(event.id, widget.currentUserId);
                setState(() {});
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('You have left the event.'), backgroundColor: Colors.red),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
                  );
                }
              }
            },
            child: const Text('Leave'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.confirmation_number_outlined,
              size: 80, color: primaryRed.withOpacity(0.2)),
          const SizedBox(height: 16),
          Text(
            "You haven't joined any events yet!",
            style: TextStyle(
                color: primaryRed, fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            "Browse community events and join one.",
            style: TextStyle(color: primaryRed.withOpacity(0.6), fontSize: 14),
          ),
          const SizedBox(height: 20),
          TextButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: Icon(Icons.explore_outlined, color: accentPeach),
            label:
            Text("Explore Calendar", style: TextStyle(color: accentPeach)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyFilterState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.filter_list_off,
              size: 56, color: primaryRed.withOpacity(0.2)),
          const SizedBox(height: 12),
          Text(
            _filter == 'upcoming'
                ? 'No upcoming events'
                : 'No past events',
            style: TextStyle(
                color: primaryRed, fontWeight: FontWeight.w500, fontSize: 15),
          ),
        ],
      ),
    );
  }
}