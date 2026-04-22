import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:assignment/event/model/event_model.dart';
import 'package:assignment/event/service/event_service.dart';
import 'event_details_screen.dart';

// ─────────────────────────────────────────────
// MyJoinedEventsScreen
// Shows events the resident has JOINED (not created).
// Includes private/public indicator on each card.
// ─────────────────────────────────────────────

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
  static const Color cork = Color(0xFFAD8762);
  static const Color apricot = Color(0xFFFFB38A);
  static const Color creamBg = Color(0xFFFFF8F0);

  final EventService _eventService = EventService();

  // Filter: 'all', 'upcoming', 'past'
  String _filter = 'all';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: creamBg,
      appBar: AppBar(
        title: const Text(
          "My Joined Events",
          style:
          TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: cork,
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: true,
        elevation: 0,
      ),
      body: FutureBuilder<List<CommunityEvent>>(
        future: _eventService.fetchJoinedEvents(widget.currentUserId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: apricot));
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

          // Filter events
          final now = DateTime.now();
          final filtered = allEvents.where((e) {
            if (_filter == 'upcoming') return e.eventDate.isAfter(now);
            if (_filter == 'past') return e.eventDate.isBefore(now);
            return true;
          }).toList();

          // Sort: upcoming first
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
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildEventCard(filtered[index]),
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
          color: isSelected ? cork : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? cork : Colors.grey.shade200,
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

  Widget _buildEventCard(CommunityEvent event) {
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
            onRefresh: () => setState(() {}), currentUserName: '',
          ),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            // Date strip (left accent)
            Container(
              width: 64,
              decoration: BoxDecoration(
                color: isPast
                    ? Colors.grey.withOpacity(0.08)
                    : cork.withOpacity(0.09),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                ),
              ),
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    DateFormat('dd').format(event.eventDate),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: isPast ? Colors.grey : cork,
                    ),
                  ),
                  Text(
                    DateFormat('MMM').format(event.eventDate)
                        .toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isPast
                          ? Colors.grey.withOpacity(0.7)
                          : cork.withOpacity(0.7),
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),

            // Event info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title row + privacy + status badges
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            event.title,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isPast
                                  ? Colors.black45
                                  : Colors.black87,
                              fontSize: 15,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        // Private / Public badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: event.isPrivate
                                ? Colors.purple.withOpacity(0.1)
                                : Colors.blue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Icon(
                            event.isPrivate
                                ? Icons.lock_outline
                                : Icons.public,
                            size: 11,
                            color: event.isPrivate
                                ? Colors.purple
                                : Colors.blue,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    // Location
                    Row(
                      children: [
                        Icon(Icons.location_on_outlined,
                            size: 13,
                            color: isPast ? Colors.grey : apricot),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            event.location,
                            style: TextStyle(
                              fontSize: 12,
                              color: isPast
                                  ? Colors.black38
                                  : Colors.black54,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),

                    // Time
                    Row(
                      children: [
                        Icon(Icons.access_time_outlined,
                            size: 13,
                            color: isPast ? Colors.grey : apricot),
                        const SizedBox(width: 4),
                        Text(
                          '${event.startTime} – ${event.endTime}',
                          style: TextStyle(
                            fontSize: 12,
                            color: isPast
                                ? Colors.black38
                                : Colors.black54,
                          ),
                        ),
                      ],
                    ),

                    // "Today" or "Past" tag
                    if (isToday || isPast) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isToday
                              ? Colors.green.withOpacity(0.1)
                              : Colors.grey.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          isToday ? '📅 Today' : '✓ Past event',
                          style: TextStyle(
                            fontSize: 11,
                            color:
                            isToday ? Colors.green : Colors.grey,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Leave + Arrow
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!isPast)
                  GestureDetector(
                    onTap: () => _confirmLeave(event),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      margin: const EdgeInsets.only(right: 4),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.08),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.logout_rounded, size: 15, color: Colors.red),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Icon(Icons.arrow_forward_ios_rounded,
                      size: 14,
                      color: isPast ? Colors.black26 : cork.withOpacity(0.5)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }


  // ── Leave event ───────────────────────────────

  void _confirmLeave(CommunityEvent event) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Leave Event'),
        content: Text('Are you sure you want to leave "\${event.title}"?'),
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
              size: 80, color: cork.withOpacity(0.2)),
          const SizedBox(height: 16),
          Text(
            "You haven't joined any events yet!",
            style: TextStyle(
                color: cork, fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            "Browse community events and join one.",
            style: TextStyle(color: cork.withOpacity(0.6), fontSize: 14),
          ),
          const SizedBox(height: 20),
          TextButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: Icon(Icons.explore_outlined, color: apricot),
            label:
            Text("Explore Calendar", style: TextStyle(color: apricot)),
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
              size: 56, color: cork.withOpacity(0.2)),
          const SizedBox(height: 12),
          Text(
            _filter == 'upcoming'
                ? 'No upcoming events'
                : 'No past events',
            style: TextStyle(
                color: cork, fontWeight: FontWeight.w500, fontSize: 15),
          ),
        ],
      ),
    );
  }
}