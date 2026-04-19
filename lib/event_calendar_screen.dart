import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'event_model.dart';
import 'event_service.dart';
import 'create_event_screen.dart';
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

  // Use your teammate's test role logic here
  String currentRole = 'resident';
  String currentUserId = Supabase.instance.client.auth.currentUser?.id ?? '';
  String currentName = 'Yu Xin';

  List<CommunityEvent> _allEvents = [];
  final EventService _eventService = EventService();
  late Future<List<CommunityEvent>> _eventsFuture;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _refreshEvents();
  }

  void _refreshEvents() {
    setState(() {
      // Logic: Admins see pending proposals, Residents see approved events
      _eventsFuture = currentRole == 'admin'
          ? _eventService.fetchPendingEvents()
          : _eventService.fetchAllEvents();
    });
  }

  List<CommunityEvent> _getEventsForDay(DateTime day) {
    // Use event.eventDate instead of event.date
    return _allEvents.where((event) => isSameDay(event.eventDate, day)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor: creamBg,
      appBar: AppBar(
        title: const Text('JiranMu Events',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: cork,
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(currentRole == 'admin' ? Icons.admin_panel_settings : Icons.person),
            onPressed: () {
              setState(() {
                currentRole = (currentRole == 'resident') ? 'admin' : 'resident';
              });
              _refreshEvents();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("Switched to $currentRole mode")),
              );
            },
          )
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CreateEventScreen(
                userRole: currentRole,
                userEmail: "wongkz2003@gmail.com", // Updated to your test email
                userName: currentName,
              ),
            ),
          ).then((value) {
            if (value == true) _refreshEvents();
          });
        },
        backgroundColor: apricot,
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text(currentRole == 'admin' ? "Create Event" : "Propose Event",
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: Column(
          children: [
            TableCalendar(
              firstDay: DateTime.utc(2026, 01, 01),
              lastDay: DateTime.utc(2026, 12, 31),
              focusedDay: _focusedDay,
              calendarFormat: _calendarFormat,
              eventLoader: _getEventsForDay,
              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
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
              ),
            ),
            Expanded(
              child: FutureBuilder<List<CommunityEvent>>(
                future: _eventsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator(color: apricot));
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text("Error loading events"));
                  }

                  _allEvents = snapshot.data ?? [];
                  // Use event.eventDate instead of event.date
                  final dayEvents = _allEvents.where((event) => isSameDay(event.eventDate, _selectedDay)).toList();

                  if (dayEvents.isEmpty) return _buildEmptyState();

                  return ListView.builder(
                    padding: const EdgeInsets.only(bottom: 80),
                    itemCount: dayEvents.length,
                    itemBuilder: (context, index) => _buildEventCard(dayEvents[index]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventCard(CommunityEvent event) {
    // Logic for Capacity Bar
    double occupancy = event.participants / event.maxCapacity;
    bool isFull = event.participants >= event.maxCapacity;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 4,
      child: Column(
        children: [
          // Event Image
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: event.imageUrl != null
                ? Image.network(event.imageUrl!, height: 150, width: double.infinity, fit: BoxFit.cover)
                : Container(height: 150, color: cork.withOpacity(0.1), child: Icon(Icons.image, color: cork)),
          ),
          ListTile(
            title: Text(event.title, style: TextStyle(color: cork, fontWeight: FontWeight.bold)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoRow(Icons.location_on, event.location),
                const SizedBox(height: 4),
                // NEW: Capacity Display
                _buildInfoRow(Icons.people, "Capacity: ${event.participants} / ${event.maxCapacity}"),
                const SizedBox(height: 8),
                // Visual Progress Bar for Capacity
                LinearProgressIndicator(
                  value: occupancy,
                  backgroundColor: Colors.grey[200],
                  color: isFull ? Colors.red : apricot,
                  minHeight: 6,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (currentRole == 'admin' && event.status == 'pending')
                  _buildAdminActionButtons(event)
                else if (currentRole == 'resident' && event.status == 'approved')
                  _buildJoinButton(event, isFull),
                if (currentRole == 'admin') _buildStatusBadge(event.status),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, size: 16, color: apricot),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(fontSize: 13)),
      ],
    );
  }

  Widget _buildJoinButton(CommunityEvent event, bool isFull) {
    return ElevatedButton(
      onPressed: isFull ? null : () async {
        try {
          await _eventService.joinEvent(event.id, currentUserId);
          _refreshEvents();
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
        }
      },
      style: ElevatedButton.styleFrom(backgroundColor: isFull ? Colors.grey : apricot),
      child: Text(isFull ? "Event Full" : "Join Event", style: const TextStyle(color: Colors.white)),
    );
  }

  Widget _buildStatusBadge(String status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: status == 'pending' ? Colors.orange[100] : Colors.green[100], borderRadius: BorderRadius.circular(10)),
      child: Text(status.toUpperCase(), style: TextStyle(color: status == 'pending' ? Colors.orange : Colors.green, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildAdminActionButtons(CommunityEvent event) {
    return Row(
      children: [
        TextButton(onPressed: () => _eventService.rejectRequest(event.id, "Rejected"), child: const Text("Reject", style: TextStyle(color: Colors.red))),
        ElevatedButton(onPressed: () => _eventService.approveAndPromoteRequest(event.id).then((_) => _refreshEvents()), style: ElevatedButton.styleFrom(backgroundColor: cork), child: const Text("Approve", style: TextStyle(color: Colors.white))),
      ],
    );
  }

  Widget _buildEmptyState() {
    return const Center(child: Text("No events scheduled for this day."));
  }
}