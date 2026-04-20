import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import '../model/event_model.dart';
import '../service/event_service.dart';
import 'create_event_screen.dart';
import 'resident_event_history_screen.dart';
import 'my_joined_events_screen.dart';
import 'event_details_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EventCalendarScreen extends StatefulWidget {
  const EventCalendarScreen({super.key});

  @override
  _EventCalendarScreenState createState() => _EventCalendarScreenState();
}

class _EventCalendarScreenState extends State<EventCalendarScreen> {
  final Color cork = const Color(0xFFAD8762);
  final Color apricot = const Color(0xFFFFB38A);
  final Color creamBg = const Color(0xFFFFF8F0);

  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  String currentRole = 'resident';
  String currentUserId = '';
  String currentName = 'User';
  String currentEmail = '';
  bool _isInitializing = true;

  List<CommunityEvent> _allEvents = [];
  final EventService _eventService = EventService();
  late Future<List<CommunityEvent>> _eventsFuture;

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
    setState(() {
      _eventsFuture = _eventService.fetchAllEvents();
    });
  }

  List<CommunityEvent> _getEventsForDay(DateTime day) {
    return _allEvents.where((event) => isSameDay(event.eventDate, day)).toList();
  }

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
        // --- MOVED EXIT ICON TO TOP LEFT ---
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Community Calendar',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
              ),
            ),
          ).then((value) => _refreshEvents());
        },
        backgroundColor: apricot,
        shape: const CircleBorder(),
        elevation: 4,
        child: const Icon(Icons.add, color: Colors.white, size: 30),
      ),

      // --- CLEANED BOTTOM BAR ---
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8.0,
        color: cork,
        child: SizedBox(
          height: 60,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              // LEFT SIDE: HISTORY
              IconButton(
                icon: const Icon(Icons.history, color: Colors.white),
                tooltip: 'Event History',
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(
                      builder: (context) => const ResidentEventHistoryScreen()
                  ));
                },
              ),

              const SizedBox(width: 40), // Gap for FAB

              // RIGHT SIDE: JOINED EVENTS
              IconButton(
                icon: const Icon(Icons.assignment_turned_in_rounded, color: Colors.white),
                tooltip: 'My Joined Events',
                onPressed: () => Navigator.push(context, MaterialPageRoute(
                  builder: (context) => MyJoinedEventsScreen(currentUserId: currentUserId, currentRole: currentRole),
                )).then((_) => _refreshEvents()),
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
                  titleTextStyle: TextStyle(color: cork, fontWeight: FontWeight.bold, fontSize: 17),
                  leftChevronIcon: Icon(Icons.chevron_left, color: cork),
                  rightChevronIcon: Icon(Icons.chevron_right, color: cork),
                ),
                onDaySelected: (selectedDay, focusedDay) {
                  setState(() {
                    _selectedDay = selectedDay;
                    _focusedDay = focusedDay;
                  });
                },
                calendarStyle: CalendarStyle(
                  todayDecoration: BoxDecoration(color: apricot.withOpacity(0.5), shape: BoxShape.circle),
                  selectedDecoration: BoxDecoration(color: cork, shape: BoxShape.circle),
                  markerDecoration: BoxDecoration(color: apricot, shape: BoxShape.circle),
                  outsideDaysVisible: false,
                ),
              ),
              const Divider(),
              _buildEventList(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEventList() {
    return FutureBuilder<List<CommunityEvent>>(
      future: _eventsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: Padding(padding: const EdgeInsets.symmetric(vertical: 40), child: CircularProgressIndicator(color: apricot)));
        }
        if (snapshot.hasError) return Center(child: Text("Error loading events: ${snapshot.error}"));

        _allEvents = snapshot.data ?? [];
        final dayEvents = _allEvents.where((event) => isSameDay(event.eventDate, _selectedDay)).toList();

        if (dayEvents.isEmpty) {
          return Padding(padding: const EdgeInsets.symmetric(vertical: 40), child: _buildEmptyState());
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 100, top: 10),
          itemCount: dayEvents.length,
          itemBuilder: (context, index) => _buildEventCard(dayEvents[index]),
        );
      },
    );
  }

  Widget _buildEventCard(CommunityEvent event) {
    double occupancy = event.maxCapacity > 0 ? event.participants / event.maxCapacity : 0;
    bool isFull = event.participants >= event.maxCapacity;

    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(
        builder: (context) => EventDetailsScreen(
            event: event,
            currentRole: currentRole,
            currentUserId: currentUserId,
            onRefresh: _refreshEvents
        ),
      )),
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 4,
        child: Column(
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              child: event.imageUrl != null && event.imageUrl!.isNotEmpty
                  ? Image.network(event.imageUrl!, height: 150, width: double.infinity, fit: BoxFit.cover)
                  : Container(height: 150, width: double.infinity, color: cork.withOpacity(0.1), child: Icon(Icons.image, color: cork, size: 50)),
            ),
            ListTile(
              title: Text(event.title, style: TextStyle(color: cork, fontWeight: FontWeight.bold, fontSize: 18)),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 5),
                  _buildInfoRow(Icons.location_on, event.location),
                  _buildInfoRow(Icons.access_time, "${event.startTime} - ${event.endTime}"),
                  _buildInfoRow(Icons.people, "Capacity: ${event.participants} / ${event.maxCapacity}"),
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
            )
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label) {
    return Row(children: [Icon(icon, size: 16, color: apricot), const SizedBox(width: 5), Expanded(child: Text(label, style: const TextStyle(fontSize: 13, color: Colors.black87)))]);
  }

  Widget _buildJoinButton(CommunityEvent event, bool isFull) {
    if (event.createdBy == currentUserId) return Text("You are the Host", style: TextStyle(color: cork, fontWeight: FontWeight.bold, fontStyle: FontStyle.italic, fontSize: 13));
    return ElevatedButton(
      onPressed: isFull ? null : () async {
        try {
          await _eventService.joinEvent(event.id, currentUserId);
          _refreshEvents();
        } catch (e) {
          _showErrorDialog("Note", e.toString().replaceAll("Exception: ", ""));
        }
      },
      style: ElevatedButton.styleFrom(backgroundColor: apricot, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
      child: Text(isFull ? "Full" : "Join", style: const TextStyle(color: Colors.white)),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color badgeColor = status == 'pending' ? Colors.orange : (status == 'approved' ? Colors.green : Colors.red);
    return Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: badgeColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: badgeColor.withOpacity(0.5))), child: Text(status.toUpperCase(), style: TextStyle(color: badgeColor, fontSize: 10, fontWeight: FontWeight.bold)));
  }

  Widget _buildEmptyState() {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.event_busy, size: 50, color: cork.withOpacity(0.3)), const SizedBox(height: 10), Text("No events for this day.", style: TextStyle(color: cork.withOpacity(0.6)))]));
  }

  void _showErrorDialog(String title, String message) {
    showDialog(context: context, builder: (context) => AlertDialog(title: Text(title), content: Text(message), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK"))]));
  }
}