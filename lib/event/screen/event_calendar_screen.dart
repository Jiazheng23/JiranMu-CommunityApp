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
  // ── NEW THEME COLORS ──────────────────────────────
  final Color bgColor = const Color(0xFFF5F1ED);
  final Color primaryColor = const Color(0xFF9A4B3C);
  final Color accentColor = const Color(0xFFFC9D7E);
  final Color softYellow = const Color(0xFFF0E6B8);
  final Color textDark = const Color(0xFF2B2B2B);

  static const Color _createdEventDot = Color(0xFF6C63FF);
  static const Color _joinedEventDot  = Color(0xFF22C55E);

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
  List<CommunityEvent> _myCreatedEvents = [];
  List<CommunityEvent> _myJoinedEvents = [];

  final EventService _eventService = EventService();

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _initializeUserSession();
  }

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

  Future<void> _loadMyEvents() async {
    try {
      final created = await _eventService.fetchMyApprovedEvents(currentUserId);
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

  List<CommunityEvent> _getEventsForDay(DateTime day) =>
      _allEvents.where((event) => isSameDay(event.eventDate, day)).toList();

  bool _hasCreatedEventOnDay(DateTime day) =>
      _myCreatedEvents.any((e) => isSameDay(e.eventDate, day));

  bool _hasJoinedEventOnDay(DateTime day) =>
      _myJoinedEvents.any((e) => isSameDay(e.eventDate, day));

  @override
  Widget build(BuildContext context) {
    if (_isInitializing) {
      return Scaffold(
        backgroundColor: bgColor,
        body: Center(child: CircularProgressIndicator(color: accentColor)),
      );
    }

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Community Calendar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: primaryColor,
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
        backgroundColor: accentColor,
        shape: const CircleBorder(),
        elevation: 4,
        child: const Icon(Icons.add, color: Colors.white, size: 30),
      ),
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8.0,
        color: primaryColor,
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
                  MaterialPageRoute(builder: (_) => ResidentEventHistoryScreen(currentUserId: currentUserId, currentUserName: currentName)),
                ).then((_) => _refreshEvents()),
              ),
              const SizedBox(width: 40),
              IconButton(
                icon: const Icon(Icons.assignment_turned_in_rounded, color: Colors.white),
                tooltip: 'My Joined Events',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => MyJoinedEventsScreen(currentUserId: currentUserId, currentRole: currentRole)),
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
              TableCalendar(
                firstDay: DateTime.utc(2026, 01, 01),
                lastDay: DateTime.utc(2026, 12, 31),
                focusedDay: _focusedDay,
                calendarFormat: _calendarFormat,
                eventLoader: _getEventsForDay,
                selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                availableCalendarFormats: const {CalendarFormat.month: 'Month'},
                headerStyle: HeaderStyle(
                  formatButtonVisible: false,
                  titleCentered: true,
                  titleTextStyle: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 17),
                  leftChevronIcon: Icon(Icons.chevron_left, color: primaryColor),
                  rightChevronIcon: Icon(Icons.chevron_right, color: primaryColor),
                ),
                onDaySelected: (selectedDay, focusedDay) {
                  setState(() {
                    _selectedDay = selectedDay;
                    _focusedDay  = focusedDay;
                  });
                },
                onPageChanged: (focusedDay) => setState(() => _focusedDay = focusedDay),
                rowHeight: 52,
                daysOfWeekHeight: 24,
                daysOfWeekStyle: DaysOfWeekStyle(
                  weekdayStyle: TextStyle(color: primaryColor, fontSize: 12, fontWeight: FontWeight.w600),
                  weekendStyle: TextStyle(color: primaryColor.withOpacity(0.7), fontSize: 12, fontWeight: FontWeight.w600),
                ),
                calendarStyle: CalendarStyle(
                  cellMargin: const EdgeInsets.all(4),
                  todayDecoration: BoxDecoration(color: softYellow, shape: BoxShape.circle),
                  todayTextStyle: TextStyle(color: textDark, fontWeight: FontWeight.bold),
                  selectedDecoration: BoxDecoration(color: primaryColor, shape: BoxShape.circle),
                  markersMaxCount: 0,
                  outsideDaysVisible: false,
                ),
                calendarBuilders: CalendarBuilders(
                  markerBuilder: (context, day, events) {
                    final hasCommunityEvents = events.isNotEmpty;
                    final hasCreated = currentRole == 'resident' && _hasCreatedEventOnDay(day);
                    final hasJoined = currentRole == 'resident' && _hasJoinedEventOnDay(day);

                    if (!hasCommunityEvents && !hasCreated && !hasJoined) return const SizedBox.shrink();

                    return Align(
                      alignment: Alignment.bottomCenter,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (hasCommunityEvents)
                              ...List.generate(
                                events.length.clamp(0, 3),
                                    (_) => Container(
                                  width: 5, height: 5,
                                  margin: const EdgeInsets.symmetric(horizontal: 1),
                                  decoration: BoxDecoration(color: accentColor, shape: BoxShape.circle),
                                ),
                              ),
                            if (hasCreated) ...[
                              if (hasCommunityEvents) const SizedBox(width: 2),
                              _legendDot(_createdEventDot, glow: true, size: 7),
                            ],
                            if (hasJoined) ...[
                              if (hasCommunityEvents || hasCreated) const SizedBox(width: 2),
                              _legendDot(_joinedEventDot, glow: true, size: 7),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              if (currentRole == 'resident')
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                  child: Wrap(
                    spacing: 10, runSpacing: 4,
                    children: [
                      _legendItem(accentColor, 'Community events'),
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

  Widget _legendItem(Color color, String label, {bool glow = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _legendDot(color, glow: glow, size: 8),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 11, color: textDark.withOpacity(0.6))),
      ],
    );
  }

  Widget _legendDot(Color color, {bool glow = false, double size = 8}) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        color: color, shape: BoxShape.circle,
        boxShadow: glow ? [BoxShadow(color: color.withOpacity(0.5), blurRadius: 4, spreadRadius: 1)] : null,
      ),
    );
  }

  Widget _buildEventList() {
    if (_isLoadingEvents) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Center(child: CircularProgressIndicator(color: accentColor)),
      );
    }
    final selectedDay = _selectedDay;
    final publicDayEvents = _allEvents.where((e) => isSameDay(e.eventDate, selectedDay)).toList();
    final myPrivateDayEvents = currentRole == 'resident'
        ? [..._myCreatedEvents, ..._myJoinedEvents].where((e) => e.isPrivate && isSameDay(e.eventDate, selectedDay) && !publicDayEvents.any((p) => p.id == e.id)).toList()
        : <CommunityEvent>[];

    final dayEvents = [...publicDayEvents, ...myPrivateDayEvents];
    if (dayEvents.isEmpty) return Padding(padding: const EdgeInsets.symmetric(vertical: 40), child: _buildEmptyState());

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 100, top: 10),
      itemCount: dayEvents.length,
      itemBuilder: (context, index) => _buildEventCard(dayEvents[index]),
    );
  }

  // ── REFACTORED EVENT CARD WITH DUAL BADGES ──────────────────

  Widget _buildEventCard(CommunityEvent event) {
    final int participantCount = event.participants ?? 0;
    final double occupancy = event.maxCapacity > 0 ? participantCount / event.maxCapacity : 0;
    final bool isFull    = participantCount >= event.maxCapacity;
    final bool isMyEvent = event.userId == currentUserId;
    final bool hasJoined = _myJoinedEvents.any((e) => e.id == event.id);

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => EventDetailsScreen(event: event, currentRole: currentRole, currentUserId: currentUserId, currentUserName: currentName, onRefresh: _refreshEvents)),
      ),
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 4,
        child: Column(
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  child: event.imageUrl != null && event.imageUrl!.isNotEmpty
                      ? Image.network(event.imageUrl!, height: 150, width: double.infinity, fit: BoxFit.cover)
                      : Container(height: 150, width: double.infinity, color: primaryColor.withOpacity(0.1), child: Icon(Icons.image, color: primaryColor, size: 50)),
                ),

                // LEFT SIDE BADGES (Side-by-side using Wrap)
                Positioned(
                  top: 10,
                  left: 12,
                  child: Wrap(
                    spacing: 8,
                    children: [
                      if (isMyEvent)
                        _buildStickyBadge('Your Event', _createdEventDot, Icons.star_rounded),
                      if (!isMyEvent && hasJoined)
                        _buildStickyBadge('Joined', _joinedEventDot, Icons.check_circle_rounded),
                      // Explains why the "Community" dot exists for "Your Event"
                      if (!event.isPrivate && event.status == 'approved')
                        _buildStickyBadge('Community Event', accentColor, Icons.groups_rounded),
                    ],
                  ),
                ),

                // RIGHT SIDE PRIVATE BADGE
                if (event.isPrivate)
                  Positioned(
                    top: 10,
                    right: 12,
                    child: _buildStickyBadge('Private', Colors.purple.withOpacity(0.85), Icons.lock_outline),
                  ),
              ],
            ),
            ListTile(
              title: Text(event.title, style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 18)),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 5),
                  _buildInfoRow(Icons.location_on, event.location),
                  _buildInfoRow(Icons.access_time, "${event.startTime} - ${event.endTime}"),
                  _buildInfoRow(Icons.people, "Capacity: $participantCount / ${event.maxCapacity}"),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(value: occupancy, backgroundColor: Colors.grey[200], color: isFull ? Colors.red : accentColor, minHeight: 8, borderRadius: BorderRadius.circular(5)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (event.status == 'approved') _buildJoinButton(event, isFull),
                  _buildStatusBadge(event.status),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── HELPER FOR STICKY BADGES ──────────────────────────────

  Widget _buildStickyBadge(String text, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: color.withOpacity(0.4), blurRadius: 6)],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 12),
          const SizedBox(width: 4),
          Text(text, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label) {
    return Row(children: [
      Icon(icon, size: 16, color: accentColor),
      const SizedBox(width: 5),
      Expanded(child: Text(label, style: TextStyle(fontSize: 13, color: textDark))),
    ]);
  }

  Widget _buildJoinButton(CommunityEvent event, bool isFull) {
    final bool isHost    = event.userId == currentUserId;
    final bool hasJoined = _myJoinedEvents.any((e) => e.id == event.id);

    if (isHost) return Text("You are the Host", style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontStyle: FontStyle.italic, fontSize: 13));
    if (hasJoined) return Text("Already Joined", style: TextStyle(color: _joinedEventDot, fontWeight: FontWeight.bold, fontStyle: FontStyle.italic, fontSize: 13));

    return ElevatedButton(
      onPressed: isFull ? null : () async {
        try {
          await _eventService.joinEvent(event.id, currentUserId);
          _refreshEvents();
        } catch (e) {
          _showErrorDialog("Note", e.toString().replaceAll("Exception: ", ""));
        }
      },
      style: ElevatedButton.styleFrom(backgroundColor: accentColor, elevation: 2, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
      child: Text(isFull ? "Full" : "Join", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildStatusBadge(String status) {
    final Color badgeColor = status == 'pending' ? Colors.orange : (status == 'approved' ? Colors.green : Colors.red);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: badgeColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: badgeColor.withOpacity(0.5))),
      child: Text(status.toUpperCase(), style: TextStyle(color: badgeColor, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.event_busy, size: 50, color: primaryColor.withOpacity(0.3)),
          const SizedBox(height: 10),
          Text("No events for this day.", style: TextStyle(color: primaryColor.withOpacity(0.6))),
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
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK"))],
      ),
    );
  }
}