import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:assignment/event/model/event_model.dart';
import 'package:assignment/event/service/event_service.dart';

// ─────────────────────────────────────────────
// Resident Calendar Screen
// Shows calendar with dot indicators for days that
// have approved events created by the current resident.
// Tapping a date shows events for that day below the calendar.
// ─────────────────────────────────────────────

class ResidentCalendarScreen extends StatefulWidget {
  final String currentUserId;
  final String currentUserName;

  const ResidentCalendarScreen({
    super.key,
    required this.currentUserId,
    required this.currentUserName,
  });

  @override
  State<ResidentCalendarScreen> createState() =>
      _ResidentCalendarScreenState();
}

class _ResidentCalendarScreenState extends State<ResidentCalendarScreen> {
  final EventService _eventService = EventService();
  final supabase = Supabase.instance.client;

  // Theme
  static const Color cork = Color(0xFFAD8762);
  static const Color apricot = Color(0xFFFFB38A);
  static const Color creamBg = Color(0xFFFFF8F0);

  DateTime _focusedMonth = DateTime.now();
  DateTime? _selectedDay;

  // All approved events created by this resident
  List<CommunityEvent> _myApprovedEvents = [];

  // All approved public events (for joined ones too) — optional, extend later
  // Events on the selected day
  List<CommunityEvent> _selectedDayEvents = [];

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime.now();
    _loadMyApprovedEvents();
  }

  Future<void> _loadMyApprovedEvents() async {
    setState(() => _loading = true);
    try {
      // Fetch events created by this resident that are approved
      final data = await supabase
          .from('events')
          .select(
          'id, title, description, location, event_date, start_time, end_time, image_url, user_id, created_by_name, is_private, created_at, max_capacity, participants, processed_by')
          .eq('user_id', widget.currentUserId)
          .eq('status', 'approved')
          .order('event_date', ascending: true);

      final events = (data as List)
          .map((e) => CommunityEvent.fromMap(e as Map<String, dynamic>))
          .toList();

      setState(() {
        _myApprovedEvents = events;
        _loading = false;
        if (_selectedDay != null) {
          _updateSelectedDayEvents(_selectedDay!);
        }
      });
    } catch (e) {
      debugPrint('Error loading approved events: $e');
      setState(() => _loading = false);
    }
  }

  void _updateSelectedDayEvents(DateTime day) {
    final events = _myApprovedEvents.where((event) {
      return event.eventDate.year == day.year &&
          event.eventDate.month == day.month &&
          event.eventDate.day == day.day;
    }).toList();
    setState(() {
      _selectedDay = day;
      _selectedDayEvents = events;
    });
  }

  // Check if a given day has events
  bool _hasEvents(DateTime day) {
    return _myApprovedEvents.any((event) =>
    event.eventDate.year == day.year &&
        event.eventDate.month == day.month &&
        event.eventDate.day == day.day);
  }

  bool _isToday(DateTime day) {
    final now = DateTime.now();
    return day.year == now.year &&
        day.month == now.month &&
        day.day == now.day;
  }

  bool _isSelected(DateTime day) {
    if (_selectedDay == null) return false;
    return day.year == _selectedDay!.year &&
        day.month == _selectedDay!.month &&
        day.day == _selectedDay!.day;
  }

  bool _isInCurrentMonth(DateTime day) {
    return day.month == _focusedMonth.month &&
        day.year == _focusedMonth.year;
  }

  void _previousMonth() {
    setState(() {
      _focusedMonth =
          DateTime(_focusedMonth.year, _focusedMonth.month - 1, 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _focusedMonth =
          DateTime(_focusedMonth.year, _focusedMonth.month + 1, 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: creamBg,
      appBar: AppBar(
        title: const Text(
          'My Event Calendar',
          style:
          TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: cork,
        centerTitle: true,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadMyApprovedEvents,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: apricot))
          : RefreshIndicator(
        onRefresh: _loadMyApprovedEvents,
        color: apricot,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // Calendar card
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: _buildCalendarCard(),
              ),
            ),

            // Legend
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: _buildLegend(),
              ),
            ),

            // Selected day header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: _buildSelectedDayHeader(),
              ),
            ),

            // Events for selected day
            if (_selectedDayEvents.isEmpty)
              SliverToBoxAdapter(
                child: _buildNoEventsForDay(),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                        (context, index) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildEventCard(
                          _selectedDayEvents[index]),
                    ),
                    childCount: _selectedDayEvents.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── Calendar card ─────────────────────────────

  Widget _buildCalendarCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildCalendarHeader(),
          _buildWeekdayLabels(),
          const Divider(height: 1, thickness: 1),
          _buildCalendarGrid(),
        ],
      ),
    );
  }

  Widget _buildCalendarHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: _previousMonth,
            icon: const Icon(Icons.chevron_left_rounded),
            color: cork,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          Expanded(
            child: Text(
              DateFormat('MMMM yyyy').format(_focusedMonth),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: cork,
                letterSpacing: -0.3,
              ),
            ),
          ),
          IconButton(
            onPressed: _nextMonth,
            icon: const Icon(Icons.chevron_right_rounded),
            color: cork,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildWeekdayLabels() {
    const days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: days
            .map(
              (d) => Expanded(
            child: Center(
              child: Text(
                d,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: cork.withOpacity(0.6),
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ),
        )
            .toList(),
      ),
    );
  }

  Widget _buildCalendarGrid() {
    // First day of the month
    final firstDay =
    DateTime(_focusedMonth.year, _focusedMonth.month, 1);
    // Day of week for the first day (0=Sun, 6=Sat)
    final firstWeekday = firstDay.weekday % 7;
    // Total days in month
    final daysInMonth =
        DateTime(_focusedMonth.year, _focusedMonth.month + 1, 0).day;

    // Build grid cells
    final cells = <DateTime?>[];
    // Leading empty cells
    for (int i = 0; i < firstWeekday; i++) {
      cells.add(null);
    }
    // Day cells
    for (int d = 1; d <= daysInMonth; d++) {
      cells.add(DateTime(_focusedMonth.year, _focusedMonth.month, d));
    }
    // Pad to complete last row
    while (cells.length % 7 != 0) {
      cells.add(null);
    }

    final rows = cells.length ~/ 7;

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
      child: Column(
        children: List.generate(rows, (rowIndex) {
          return Row(
            children: List.generate(7, (colIndex) {
              final day = cells[rowIndex * 7 + colIndex];
              return Expanded(child: _buildDayCell(day));
            }),
          );
        }),
      ),
    );
  }

  Widget _buildDayCell(DateTime? day) {
    if (day == null) {
      return const SizedBox(height: 52);
    }

    final isSelected = _isSelected(day);
    final isToday = _isToday(day);
    final hasEvents = _hasEvents(day);
    final inMonth = _isInCurrentMonth(day);

    return GestureDetector(
      onTap: () => _updateSelectedDayEvents(day),
      child: Container(
        height: 52,
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: isSelected
              ? cork
              : isToday
              ? cork.withOpacity(0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${day.day}',
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected || isToday
                    ? FontWeight.w700
                    : FontWeight.w500,
                color: isSelected
                    ? Colors.white
                    : inMonth
                    ? Colors.black87
                    : Colors.black26,
              ),
            ),
            const SizedBox(height: 3),
            // Event indicator dot — always visible if there are events
            if (hasEvents)
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : apricot,
                  shape: BoxShape.circle,
                  boxShadow: isSelected
                      ? null
                      : [
                    BoxShadow(
                      color: apricot.withOpacity(0.5),
                      blurRadius: 3,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              )
            else
              const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }

  // ── Legend ────────────────────────────────────

  Widget _buildLegend() {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: apricot,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: apricot.withOpacity(0.5),
                blurRadius: 4,
                spreadRadius: 1,
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        const Text(
          'Your approved events',
          style: TextStyle(
            fontSize: 12,
            color: Colors.black54,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 16),
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: cork.withOpacity(0.12),
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Center(
            child: Text('1',
                style: TextStyle(fontSize: 11, color: cork, fontWeight: FontWeight.w700)),
          ),
        ),
        const SizedBox(width: 6),
        const Text(
          'Today',
          style: TextStyle(
            fontSize: 12,
            color: Colors.black54,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // ── Selected day header ───────────────────────

  Widget _buildSelectedDayHeader() {
    final day = _selectedDay ?? DateTime.now();
    final hasEvents = _selectedDayEvents.isNotEmpty;

    return Row(
      children: [
        Container(
          padding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: cork,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            DateFormat('EEE, dd MMM').format(day),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ),
        const SizedBox(width: 10),
        if (hasEvents)
          Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: apricot.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: apricot.withOpacity(0.4)),
            ),
            child: Text(
              '${_selectedDayEvents.length} event${_selectedDayEvents.length == 1 ? '' : 's'}',
              style: TextStyle(
                fontSize: 12,
                color: cork,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }

  // ── No events placeholder ─────────────────────

  Widget _buildNoEventsForDay() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cork.withOpacity(0.12)),
        ),
        child: Column(
          children: [
            Icon(Icons.event_available_outlined,
                size: 48, color: cork.withOpacity(0.25)),
            const SizedBox(height: 10),
            Text(
              'No events on this day',
              style: TextStyle(
                color: cork.withOpacity(0.6),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Approved events you create will appear here',
              style: TextStyle(
                color: cork.withOpacity(0.4),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Event card for selected day ───────────────

  Widget _buildEventCard(CommunityEvent event) {
    return Container(
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
          // Color accent strip + time
          Container(
            width: 68,
            decoration: BoxDecoration(
              color: cork.withOpacity(0.08),
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
                  event.startTime.length >= 5
                      ? event.startTime.substring(0, 5)
                      : event.startTime,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: cork,
                  ),
                ),
                const SizedBox(height: 2),
                Container(
                    width: 1,
                    height: 16,
                    color: cork.withOpacity(0.3)),
                const SizedBox(height: 2),
                Text(
                  event.endTime.length >= 5
                      ? event.endTime.substring(0, 5)
                      : event.endTime,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: cork.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),

          // Event info
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          event.title,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      // Privacy indicator
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: event.isPrivate
                              ? Colors.purple.withOpacity(0.1)
                              : Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          event.isPrivate
                              ? Icons.lock_outline
                              : Icons.public,
                          size: 12,
                          color:
                          event.isPrivate ? Colors.purple : Colors.blue,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.location_on_outlined,
                          size: 13,
                          color: apricot),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          event.location,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black54,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.people_outline,
                          size: 13,
                          color: apricot),
                      const SizedBox(width: 4),
                      Text(
                        'Max ${event.maxCapacity} · ${event.participants ?? 0} joined',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Approved badge
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
    );
  }
}