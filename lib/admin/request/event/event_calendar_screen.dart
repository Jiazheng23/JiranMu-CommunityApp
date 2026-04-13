import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'event_model.dart';
import 'event_service.dart';
import 'create_event_screen.dart';

class EventCalendarScreen extends StatefulWidget {
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

  // --- MOCK DATA FOR TESTING ---
  // Flip this to 'admin' to see how the form behaves differently
  String currentRole = 'resident';
  String currentEmail = 'yuxin@gmail.com';
  String currentName = 'Yu Xin';

  List<CommunityEvent> _allEvents = [];
  final EventService _eventService = EventService();

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
  }

  List<CommunityEvent> _getEventsForDay(DateTime day) {
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
        elevation: 0,
        centerTitle: true,
        // --- ADDED: TEST SWITCHER ---
        actions: [
          IconButton(
            icon: Icon(currentRole == 'admin' ? Icons.admin_panel_settings : Icons.person),
            onPressed: () {
              setState(() {
                currentRole = (currentRole == 'resident') ? 'admin' : 'resident';
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("Switched to $currentRole mode")),
              );
            },
          )
        ],
      ),
      // --- ADDED: FLOATING ACTION BUTTON ---
      floatingActionButton: FloatingActionButton.extended(
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
          ).then((_) => setState(() {})); // Refresh calendar when coming back
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
                markersAlignment: Alignment.bottomCenter,
                outsideDaysVisible: false,
              ),
              headerStyle: HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
                titleTextStyle: TextStyle(color: cork, fontWeight: FontWeight.bold, fontSize: 20),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Divider(color: cork.withOpacity(0.2), thickness: 1),
            ),
            Expanded(
              child: FutureBuilder<List<CommunityEvent>>(
                // Logic: Admin sees all (or pending), Resident sees approved
                future: currentRole == 'admin'
                    ? _eventService.fetchPendingEvents() // Or show everything
                    : _eventService.fetchAllEvents(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator(color: apricot));
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text("Error: ${snapshot.error}", style: TextStyle(color: cork)));
                  }
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return Center(child: Text("No events found.", style: TextStyle(color: cork)));
                  }

                  _allEvents = snapshot.data!;
                  final dayEvents = _allEvents.where((event) => isSameDay(event.eventDate, _selectedDay)).toList();

                  if (dayEvents.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.calendar_today_outlined, color: cork.withOpacity(0.3), size: 50),
                          const SizedBox(height: 10),
                          Text("No events for this day.", style: TextStyle(color: cork.withOpacity(0.5), fontSize: 16)),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.only(bottom: 80), // Space for FAB
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
    // Determine if the "Join" button should show (e.g. only for approved events)
    bool isApproved = event.status == 'approved';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 4,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // SHOW IMAGE IF EXISTS, ELSE SHOW PLACEHOLDER
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: event.imageUrl != null && event.imageUrl!.isNotEmpty
                ? Image.network(
              event.imageUrl!,
              height: 150,
              width: double.infinity,
              fit: BoxFit.cover,
            )
                : Container(
              height: 150,
              width: double.infinity,
              color: cork.withOpacity(0.1),
              child: Icon(Icons.image, color: cork, size: 50),
            ),
          ),
          ListTile(
            title: Text(event.title, style: TextStyle(color: cork, fontWeight: FontWeight.bold)),
            subtitle: Text("${event.startTime} @ ${event.location}"),
            trailing: currentRole == 'admin'
                ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: event.status == 'pending' ? apricot.withOpacity(0.2) : Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                event.status.toUpperCase(),
                style: TextStyle(color: event.status == 'pending' ? cork : Colors.green, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            )
                : null,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("SDG 11: Sustainable Community", style: TextStyle(fontSize: 10, color: Colors.grey)),

                // Only show "Join" if it's an approved event and I'm a resident
                if (isApproved && currentRole == 'resident')
                  ElevatedButton(
                    onPressed: () => _eventService.joinEvent(event.id, currentEmail),
                    style: ElevatedButton.styleFrom(backgroundColor: apricot),
                    child: const Text("Join Now", style: TextStyle(color: Colors.white)),
                  ),

                // If Admin is looking at a pending event, show Approve button
                if (currentRole == 'admin' && event.status == 'pending')
                  ElevatedButton(
                    onPressed: () async {
                      await _eventService.updateEventStatus(event.id, 'approved');
                      setState(() {}); // Refresh UI
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: cork),
                    child: const Text("Approve", style: TextStyle(color: Colors.white)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}