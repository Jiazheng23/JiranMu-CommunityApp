import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:assignment/event/model/event_model.dart';
import 'package:assignment/event/service/event_service.dart';

// ─────────────────────────────────────────────
// Resident Calendar Screen
// Updated with New Theme Colors
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

  // ── NEW THEME COLORS ──────────────────────────────
  final Color primaryColor = const Color(0xFF9A4B3C); // Deep Red/Brown
  final Color accentColor = const Color(0xFFFC9D7E);  // Apricot/Peach
  final Color bgColor = const Color(0xFFF5F1ED);      // Off-white/Beige
  final Color softYellow = const Color(0xFFF0E6B8);   // Today highlight
  final Color textDark = const Color(0xFF2B2B2B);

  DateTime _focusedMonth = DateTime.now();
  DateTime? _selectedDay;

  List<CommunityEvent> _myApprovedEvents = [];
  List<CommunityEvent> _selectedDayEvents = [];
  Set<String> _joinedEventIds = {};

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
      final response = await supabase
          .from('events')
          .select('*')
          .eq('status', 'approved')
          .or('is_private.eq.false,user_id.eq.${widget.currentUserId}')
          .order('event_date', ascending: true);

      final joinedData = await supabase
          .from('event_participants')
          .select('event_id')
          .eq('user_id', widget.currentUserId);

      final Set<String> joinedIds = (joinedData as List)
          .map((item) => item['event_id'].toString())
          .toSet();

      final events = (response as List)
          .map((e) => CommunityEvent.fromMap(e as Map<String, dynamic>))
          .toList();

      setState(() {
        _myApprovedEvents = events;
        _joinedEventIds = joinedIds;
        _loading = false;
        if (_selectedDay != null) {
          _updateSelectedDayEvents(_selectedDay!);
        }
      });
    } catch (e) {
      debugPrint('Error: $e');
      setState(() => _loading = false);
    }
  }

  void _updateSelectedDayEvents(DateTime day) {
    final eventsOnDay = _myApprovedEvents.where((event) {
      return event.eventDate.year == day.year &&
          event.eventDate.month == day.month &&
          event.eventDate.day == day.day;
    }).toList();

    eventsOnDay.sort((a, b) {
      bool aMine = a.userId == widget.currentUserId;
      bool bMine = b.userId == widget.currentUserId;
      if (aMine && !bMine) return -1;
      if (!aMine && bMine) return 1;
      return a.startTime.compareTo(b.startTime);
    });

    setState(() {
      _selectedDay = day;
      _selectedDayEvents = eventsOnDay;
    });
  }

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
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text(
          'My Event Calendar',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: primaryColor,
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
          ? Center(child: CircularProgressIndicator(color: accentColor))
          : RefreshIndicator(
        onRefresh: _loadMyApprovedEvents,
        color: accentColor,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: _buildCalendarCard(),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: _buildLegend(),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: _buildSelectedDayHeader(),
              ),
            ),
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
                      child: _buildEventCard(_selectedDayEvents[index]),
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
            color: primaryColor,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          Expanded(
            child: Text(
              DateFormat('MMMM yyyy').format(_focusedMonth),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: primaryColor,
                letterSpacing: -0.3,
              ),
            ),
          ),
          IconButton(
            onPressed: _nextMonth,
            icon: const Icon(Icons.chevron_right_rounded),
            color: primaryColor,
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
                  color: primaryColor.withOpacity(0.6),
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
    final firstDay = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
    final firstWeekday = firstDay.weekday % 7;
    final daysInMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 0).day;

    final cells = <DateTime?>[];
    for (int i = 0; i < firstWeekday; i++) {
      cells.add(null);
    }
    for (int d = 1; d <= daysInMonth; d++) {
      cells.add(DateTime(_focusedMonth.year, _focusedMonth.month, d));
    }
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
    if (day == null) return const SizedBox(height: 52);

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
              ? primaryColor
              : isToday
              ? softYellow
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
                fontWeight: isSelected || isToday ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? Colors.white
                    : inMonth ? textDark : textDark.withOpacity(0.3),
              ),
            ),
            const SizedBox(height: 3),
            if (hasEvents)
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : accentColor,
                  shape: BoxShape.circle,
                  boxShadow: isSelected
                      ? null
                      : [
                    BoxShadow(
                      color: accentColor.withOpacity(0.5),
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

  Widget _buildLegend() {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: accentColor,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: accentColor.withOpacity(0.5),
                blurRadius: 4,
                spreadRadius: 1,
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        Text(
          'Approved events',
          style: TextStyle(
            fontSize: 12,
            color: textDark.withOpacity(0.6),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 16),
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: softYellow,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          'Today',
          style: TextStyle(
            fontSize: 12,
            color: textDark.withOpacity(0.6),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildSelectedDayHeader() {
    final day = _selectedDay ?? DateTime.now();
    final hasEvents = _selectedDayEvents.isNotEmpty;

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: primaryColor,
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
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: accentColor.withOpacity(0.4)),
            ),
            child: Text(
              '${_selectedDayEvents.length} event${_selectedDayEvents.length == 1 ? '' : 's'}',
              style: TextStyle(
                fontSize: 12,
                color: primaryColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildNoEventsForDay() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: primaryColor.withOpacity(0.12)),
        ),
        child: Column(
          children: [
            Icon(Icons.event_available_outlined, size: 48, color: primaryColor.withOpacity(0.25)),
            const SizedBox(height: 10),
            Text(
              'No events on this day',
              style: TextStyle(
                color: textDark.withOpacity(0.6),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventCard(CommunityEvent event) {
    final bool isOwner = event.userId == widget.currentUserId;
    final bool isJoined = _joinedEventIds.contains(event.id.toString());

    String badgeText = "AVAILABLE";
    Color badgeColor = Colors.blue;

    if (isOwner) {
      badgeText = "MY EVENT";
      badgeColor = primaryColor;
    } else if (isJoined) {
      badgeText = "JOINED";
      badgeColor = Colors.green;
    }

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
          Container(
            width: 68,
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.08),
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
                  event.startTime.length >= 5 ? event.startTime.substring(0, 5) : event.startTime,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: primaryColor),
                ),
                const SizedBox(height: 2),
                Container(width: 1, height: 16, color: primaryColor.withOpacity(0.3)),
                const SizedBox(height: 2),
                Text(
                  event.endTime.length >= 5 ? event.endTime.substring(0, 5) : event.endTime,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: primaryColor.withOpacity(0.6)),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          event.title,
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: textDark),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: badgeColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: badgeColor.withOpacity(0.3)),
                        ),
                        child: Text(
                          badgeText,
                          style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: badgeColor),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        event.isPrivate ? Icons.lock_outline : Icons.public,
                        size: 13,
                        color: event.isPrivate ? Colors.purple : Colors.blue,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          event.location,
                          style: TextStyle(fontSize: 12, color: textDark.withOpacity(0.7)),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.people_outline, size: 13, color: accentColor),
                      const SizedBox(width: 4),
                      Text(
                        'Max ${event.maxCapacity} · ${event.participants ?? 0} joined',
                        style: TextStyle(fontSize: 12, color: textDark.withOpacity(0.7)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}