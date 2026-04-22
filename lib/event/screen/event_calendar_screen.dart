import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:assignment/event/model/event_model.dart';
import 'package:assignment/event/service/event_service.dart';
import 'create_event_screen.dart';
import 'resident_event_history_screen.dart';
import 'my_joined_events_screen.dart';
import 'event_details_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EventCalendarScreen extends StatefulWidget {
  final String? highlightEventId;
  const EventCalendarScreen({super.key, this.highlightEventId});

  @override
  _EventCalendarScreenState createState() => _EventCalendarScreenState();
}

class _EventCalendarScreenState extends State<EventCalendarScreen> {
  final Color cork = const Color(0xFFAD8762);
  final Color apricot = const Color(0xFFFFB38A);
  final Color creamBg = const Color(0xFFFFF8F0);

  // Three separate dot colors
  static const Color _createdEventDot = Color(0xFF6C63FF); // indigo — events YOU created
  static const Color _joinedEventDot  = Color(0xFF22C55E); // green  — events you JOINED
  // apricot (above) is reused for community events (public, not yours)

  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  String currentRole = 'resident';
  String currentUserId = '';
  String currentName = 'User';
  String currentEmail = '';
  bool _isInitializing = true;
  bool _isLoadingEvents = false;

  List<CommunityEvent> _allEvents = [];

  /// Events the resident CREATED (approved)
  List<CommunityEvent> _myCreatedEvents = [];

  /// Events the resident JOINED (approved, not created by them)
  List<CommunityEvent> _myJoinedEvents = [];

  final EventService _eventService = EventService();

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _initializeUserSession();
  }

  // ── Session ──────────────────────────────────

  Future<void> _initializeUserSession() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    if (user != null) {
      currentUserId = user.id;
      currentEmail = user.email ?? '';

      try {
        final adminData = await supabase
            .from('admin_new')
            .select('full_name')
            .eq('id', currentUserId)
            .maybeSingle();

        if (adminData != null) {
          setState(() {
            currentRole = 'admin';
            currentName = adminData['full_name'] ?? 'Admin';
            _isInitializing = false;
          });
        } else {
          final residentData = await supabase
              .from('resident')
              .select('full_name')
              .eq('id', currentUserId)
              .maybeSingle();
          setState(() {
            currentRole = 'resident';
            currentName = residentData?['full_name'] ?? 'Resident';
            _isInitializing = false;
          });
        }
      } catch (e) {
        debugPrint("Error fetching user role: $e");
        setState(() => _isInitializing = false);
      }
    }
    _refreshEvents();
  }

  // ── Data ─────────────────────────────────────

  /// Refreshes all events and updates state so the calendar dots render correctly.
  void _refreshEvents() {
    if (!mounted) return;
    setState(() => _isLoadingEvents = true);

    _eventService.fetchAllEvents().then((events) {
      if (!mounted) return;
      setState(() {
        _allEvents = events;
        _isLoadingEvents = false;
      });
      _applyHighlight();
    }).catchError((e) {
      debugPrint('Error fetching events: $e');
      if (mounted) setState(() => _isLoadingEvents = false);
    });

    if (currentUserId.isNotEmpty) {
      _loadMyEvents();
    }
  }

  /// Separately loads created vs joined so they get distinct dots on the calendar.
  Future<void> _loadMyEvents() async {
    try {
      // Events the resident created (approved)
      final created = await _eventService.fetchMyApprovedEvents(currentUserId);

      // Events the resident joined (approved), excluding ones they also created
      final joined = await _eventService.fetchJoinedEvents(currentUserId);
      final createdIds = created.map((e) => e.id).toSet();
      final joinedApproved = joined
          .where((e) => e.status == 'approved' && !createdIds.contains(e.id))
          .toList();

      if (mounted) {
        setState(() {
          _myCreatedEvents = created;
          _myJoinedEvents  = joinedApproved;
        });
      }
    } catch (e) {
      debugPrint('Error loading my events: $e');
    }
  }

  void _applyHighlight() {
    final id = widget.highlightEventId;
    if (id == null || _allEvents.isEmpty) return;
    try {
      final target = _allEvents.firstWhere((e) => e.id == id);
      setState(() {
        _selectedDay = target.eventDate;
        _focusedDay  = target.eventDate;
      });
    } catch (_) {}
  }

  // ── Helpers ───────────────────────────────────

  List<CommunityEvent> _getEventsForDay(DateTime day) =>
      _allEvents.where((event) => isSameDay(event.eventDate, day)).toList();

  bool _hasCreatedEventOnDay(DateTime day) =>
      _myCreatedEvents.any((e) => isSameDay(e.eventDate, day));

  bool _hasJoinedEventOnDay(DateTime day) =>
      _myJoinedEvents.any((e) => isSameDay(e.eventDate, day));

  // ── Build ────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_isInitializing) {
      return Scaffold(
        backgroundColor: creamBg,
        body: Center(child: CircularProgressIndicator(color: apricot)),
      );
    }

    return Scaffold(
      backgroundColor: creamBg,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Community Calendar',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: cork,
        centerTitle: true,
        elevation: 0,
      ),

      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CreateEventScreen(
                userRole: currentRole,
                userEmail: currentEmail,
                userName: currentName,
                currentUserId: currentUserId,
              ),
            ),
          ).then((_) => _refreshEvents());
        },
        backgroundColor: apricot,
        shape: const CircleBorder(),
        elevation: 4,
        child: const Icon(Icons.add, color: Colors.white, size: 30),
      ),

      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8.0,
        color: cork,
        child: SizedBox(
          height: 60,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              IconButton(
                icon: const Icon(Icons.history, color: Colors.white),
                tooltip: 'Event History',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ResidentEventHistoryScreen(
                      currentUserId: currentUserId,
                      currentUserName: currentName,
                    ),
                  ),
                ).then((_) => _refreshEvents()),
              ),
              const SizedBox(width: 40),
              IconButton(
                icon: const Icon(
                    Icons.assignment_turned_in_rounded, color: Colors.white),
                tooltip: 'My Joined Events',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MyJoinedEventsScreen(
                      currentUserId: currentUserId,
                      currentRole: currentRole,
                    ),
                  ),
                ).then((_) => _refreshEvents()),
              ),
            ],
          ),
        ),
      ),

      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // ── Calendar ──────────────────────
              TableCalendar(
                firstDay: DateTime.utc(2026, 01, 01),
                lastDay: DateTime.utc(2026, 12, 31),
                focusedDay: _focusedDay,
                calendarFormat: _calendarFormat,
                eventLoader: _getEventsForDay,
                selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                availableCalendarFormats: const {
                  CalendarFormat.month: 'Month'
                },
                headerStyle: HeaderStyle(
                  formatButtonVisible: false,
                  titleCentered: true,
                  titleTextStyle: TextStyle(
                      color: cork,
                      fontWeight: FontWeight.bold,
                      fontSize: 17),
                  leftChevronIcon:
                  Icon(Icons.chevron_left, color: cork),
                  rightChevronIcon:
                  Icon(Icons.chevron_right, color: cork),
                ),
                onDaySelected: (selectedDay, focusedDay) {
                  setState(() {
                    _selectedDay = selectedDay;
                    _focusedDay  = focusedDay;
                  });
                },
                onPageChanged: (focusedDay) =>
                    setState(() => _focusedDay = focusedDay),
                rowHeight: 52,
                daysOfWeekHeight: 24,
                daysOfWeekStyle: DaysOfWeekStyle(
                  weekdayStyle: TextStyle(
                      color: cork, fontSize: 12, fontWeight: FontWeight.w600),
                  weekendStyle: TextStyle(
                      color: cork.withOpacity(0.7),
                      fontSize: 12,
                      fontWeight: FontWeight.w600),
                ),
                calendarStyle: CalendarStyle(
                  cellMargin: const EdgeInsets.all(4),
                  todayDecoration: BoxDecoration(
                      color: apricot.withOpacity(0.5),
                      shape: BoxShape.circle),
                  selectedDecoration:
                  BoxDecoration(color: cork, shape: BoxShape.circle),
                  // Suppress default markers — we paint custom ones in markerBuilder
                  markersMaxCount: 0,
                  outsideDaysVisible: false,
                ),
                calendarBuilders: CalendarBuilders(
                  markerBuilder: (context, day, events) {
                    final hasCommunityEvents = events.isNotEmpty;
                    final hasCreated = currentRole == 'resident' &&
                        _hasCreatedEventOnDay(day);
                    final hasJoined = currentRole == 'resident' &&
                        _hasJoinedEventOnDay(day);

                    if (!hasCommunityEvents && !hasCreated && !hasJoined) {
                      return const SizedBox.shrink();
                    }

                    // Wrap in Align so dots anchor to the bottom of the cell
                    // without overlapping the day number.
                    return Align(
                      alignment: Alignment.bottomCenter,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Apricot dots — community events
                            if (hasCommunityEvents)
                              ...List.generate(
                                events.length.clamp(0, 3),
                                    (_) => Container(
                                  width: 5,
                                  height: 5,
                                  margin: const EdgeInsets.symmetric(horizontal: 1),
                                  decoration: BoxDecoration(
                                      color: apricot, shape: BoxShape.circle),
                                ),
                              ),
                            // Indigo dot — events this resident CREATED
                            if (hasCreated) ...[
                              if (hasCommunityEvents) const SizedBox(width: 2),
                              Container(
                                width: 7,
                                height: 7,
                                decoration: BoxDecoration(
                                  color: _createdEventDot,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: _createdEventDot.withOpacity(0.5),
                                      blurRadius: 4,
                                      spreadRadius: 1,
                                    )
                                  ],
                                ),
                              ),
                            ],
                            // Green dot — events this resident JOINED
                            if (hasJoined) ...[
                              if (hasCommunityEvents || hasCreated)
                                const SizedBox(width: 2),
                              Container(
                                width: 7,
                                height: 7,
                                decoration: BoxDecoration(
                                  color: _joinedEventDot,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: _joinedEventDot.withOpacity(0.5),
                                      blurRadius: 4,
                                      spreadRadius: 1,
                                    )
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              // ── Legend (residents only) — uses Wrap to prevent overflow ───
              if (currentRole == 'resident')
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 4,
                    children: [
                      _legendItem(apricot, 'Community events'),
                      _legendItem(_createdEventDot, 'Your events', glow: true),
                      _legendItem(_joinedEventDot, 'Joined events', glow: true),
                    ],
                  ),
                ),

              const Divider(height: 16),
              _buildEventList(),
            ],
          ),
        ),
      ),
    );
  }

  // ── Legend helpers ────────────────────────────

  Widget _legendItem(Color color, String label, {bool glow = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _legendDot(color, glow: glow),
        const SizedBox(width: 4),
        Text(label,
            style:
            const TextStyle(fontSize: 11, color: Colors.black45)),
      ],
    );
  }

  Widget _legendDot(Color color, {bool glow = false}) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: glow
            ? [
          BoxShadow(
              color: color.withOpacity(0.5),
              blurRadius: 4,
              spreadRadius: 1)
        ]
            : null,
      ),
    );
  }

  // ── Event list below calendar ─────────────────

  Widget _buildEventList() {
    if (_isLoadingEvents) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Center(child: CircularProgressIndicator(color: apricot)),
      );
    }

    final selectedDay = _selectedDay;

    final publicDayEvents = _allEvents
        .where((e) => isSameDay(e.eventDate, selectedDay))
        .toList();

    // Private events the resident is involved in (created or joined)
    // that aren't already in the public list
    final myPrivateDayEvents = currentRole == 'resident'
        ? [
      ..._myCreatedEvents,
      ..._myJoinedEvents,
    ]
        .where((e) =>
    e.isPrivate &&
        isSameDay(e.eventDate, selectedDay) &&
        !publicDayEvents.any((p) => p.id == e.id))
        .toList()
        : <CommunityEvent>[];

    final dayEvents = [...publicDayEvents, ...myPrivateDayEvents];

    if (dayEvents.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: _buildEmptyState(),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 100, top: 10),
      itemCount: dayEvents.length,
      itemBuilder: (context, index) => _buildEventCard(dayEvents[index]),
    );
  }

  // ── Event card ────────────────────────────────

  Widget _buildEventCard(CommunityEvent event) {
    final int participantCount = event.participants ?? 0;
    final double occupancy =
    event.maxCapacity > 0 ? participantCount / event.maxCapacity : 0;
    final bool isFull    = participantCount >= event.maxCapacity;
    final bool isMyEvent = event.userId == currentUserId;
    final bool hasJoined = _myJoinedEvents.any((e) => e.id == event.id);

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => EventDetailsScreen(
            event: event,
            currentRole: currentRole,
            currentUserId: currentUserId,
            currentUserName: currentName,
            onRefresh: _refreshEvents,
          ),
        ),
      ),
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 4,
        child: Column(
          children: [
            // Image / placeholder
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(20)),
                  child: event.imageUrl != null &&
                      event.imageUrl!.isNotEmpty
                      ? Image.network(event.imageUrl!,
                      height: 150,
                      width: double.infinity,
                      fit: BoxFit.cover)
                      : Container(
                    height: 150,
                    width: double.infinity,
                    color: cork.withOpacity(0.1),
                    child:
                    Icon(Icons.image, color: cork, size: 50),
                  ),
                ),
                // "Your Event" badge (created)
                if (isMyEvent)
                  Positioned(
                    top: 10,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _createdEventDot,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                              color: _createdEventDot.withOpacity(0.4),
                              blurRadius: 6)
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.star_rounded,
                              color: Colors.white, size: 12),
                          SizedBox(width: 4),
                          Text('Your Event',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  ),
                // "Joined" badge
                if (!isMyEvent && hasJoined)
                  Positioned(
                    top: 10,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _joinedEventDot,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                              color: _joinedEventDot.withOpacity(0.4),
                              blurRadius: 6)
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle_rounded,
                              color: Colors.white, size: 12),
                          SizedBox(width: 4),
                          Text('Joined',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  ),
                // "Private" badge
                if (event.isPrivate)
                  Positioned(
                    top: 10,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.purple.withOpacity(0.85),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.lock_outline,
                              color: Colors.white, size: 11),
                          SizedBox(width: 4),
                          Text('Private',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),

            // Details
            ListTile(
              title: Text(event.title,
                  style: TextStyle(
                      color: cork,
                      fontWeight: FontWeight.bold,
                      fontSize: 18)),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 5),
                  _buildInfoRow(Icons.location_on, event.location),
                  _buildInfoRow(Icons.access_time,
                      "${event.startTime} - ${event.endTime}"),
                  _buildInfoRow(Icons.people,
                      "Capacity: $participantCount / ${event.maxCapacity}"),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: occupancy,
                    backgroundColor: Colors.grey[200],
                    color: isFull ? Colors.red : apricot,
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(5),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (event.status == 'approved')
                    _buildJoinButton(event, isFull),
                  _buildStatusBadge(event.status),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label) {
    return Row(children: [
      Icon(icon, size: 16, color: apricot),
      const SizedBox(width: 5),
      Expanded(
          child: Text(label,
              style: const TextStyle(fontSize: 13, color: Colors.black87))),
    ]);
  }

  Widget _buildJoinButton(CommunityEvent event, bool isFull) {
    final bool isHost    = event.userId == currentUserId;
    final bool hasJoined = _myJoinedEvents.any((e) => e.id == event.id);

    if (isHost) {
      return Text(
        "You are the Host",
        style: TextStyle(
            color: cork,
            fontWeight: FontWeight.bold,
            fontStyle: FontStyle.italic,
            fontSize: 13),
      );
    }
    if (hasJoined) {
      return Text(
        "Already Joined",
        style: TextStyle(
            color: _joinedEventDot,
            fontWeight: FontWeight.bold,
            fontStyle: FontStyle.italic,
            fontSize: 13),
      );
    }
    return ElevatedButton(
      onPressed: isFull
          ? null
          : () async {
        try {
          await _eventService.joinEvent(event.id, currentUserId);
          _refreshEvents();
        } catch (e) {
          _showErrorDialog(
              "Note", e.toString().replaceAll("Exception: ", ""));
        }
      },
      style: ElevatedButton.styleFrom(
          backgroundColor: apricot,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10))),
      child: Text(isFull ? "Full" : "Join",
          style: const TextStyle(color: Colors.white)),
    );
  }

  Widget _buildStatusBadge(String status) {
    final Color badgeColor = status == 'pending'
        ? Colors.orange
        : (status == 'approved' ? Colors.green : Colors.red);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: badgeColor.withOpacity(0.5)),
      ),
      child: Text(status.toUpperCase(),
          style: TextStyle(
              color: badgeColor,
              fontSize: 10,
              fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.event_busy, size: 50, color: cork.withOpacity(0.3)),
          const SizedBox(height: 10),
          Text("No events for this day.",
              style: TextStyle(color: cork.withOpacity(0.6))),
        ],
      ),
    );
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("OK"))
        ],
      ),
    );
  }
}