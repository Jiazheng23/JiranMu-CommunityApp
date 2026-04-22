import 'package:assignment/facility/facility_model.dart';
import 'package:assignment/facility/facility_service.dart';
import 'package:flutter/material.dart';

class FacilityBookingSheet extends StatefulWidget {
  const FacilityBookingSheet({
    super.key,
    required this.facility,
  });

  final FacilityModel facility;

  @override
  State<FacilityBookingSheet> createState() => _FacilityBookingSheetState();
}

class _FacilityBookingSheetState extends State<FacilityBookingSheet> {
  final FacilityService _facilityService = FacilityService();

  late DateTime _visibleMonth;
  DateTime? _selectedDate;

  String? _selectedStartTime; // HH:mm:ss
  String? _selectedEndTime; // HH:mm:ss

  final TextEditingController _participantsController =
  TextEditingController(text: '1');
  final TextEditingController _purposeController = TextEditingController();

  bool _isLoadingSlots = false;
  bool _isSubmitting = false;

  List<_BookedRange> _existingRanges = [];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _visibleMonth = DateTime(now.year, now.month);
  }

  @override
  void dispose() {
    _participantsController.dispose();
    _purposeController.dispose();
    super.dispose();
  }

  DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  int get _nowMinutes {
    final now = TimeOfDay.now();
    return now.hour * 60 + now.minute;
  }

  bool _isSameDate(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  bool _isPastDate(DateTime date) {
    return date.isBefore(_today);
  }

  Future<void> _showErrorDialog(String message) async {
    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Booking Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  List<DateTime?> _buildCalendarDays() {
    final daysInMonth =
    DateUtils.getDaysInMonth(_visibleMonth.year, _visibleMonth.month);
    final firstDay = DateTime(_visibleMonth.year, _visibleMonth.month, 1);
    final leadingEmptyDays = firstDay.weekday % 7;
    final totalCells = leadingEmptyDays + daysInMonth;
    final trailingEmptyDays = (7 - (totalCells % 7)) % 7;

    return List<DateTime?>.generate(
      totalCells + trailingEmptyDays,
          (index) {
        if (index < leadingEmptyDays) return null;

        final day = index - leadingEmptyDays + 1;
        if (day > daysInMonth) return null;

        return DateTime(_visibleMonth.year, _visibleMonth.month, day);
      },
    );
  }

  void _changeMonth(int offset) {
    setState(() {
      _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month + offset);
    });
  }

  Future<void> _selectDate(DateTime date) async {
    setState(() {
      _selectedDate = date;
      _selectedStartTime = null;
      _selectedEndTime = null;
      _existingRanges = [];
      _isLoadingSlots = true;
    });

    try {
      final result = await _facilityService.fetchUnavailableRanges(
        facility: widget.facility,
        bookingDate: date,
      );

      if (!mounted) return;

      setState(() {
        _existingRanges = result
            .map(
              (item) => _BookedRange(
            startTime: item['start_time']?.toString() ?? '',
            endTime: item['end_time']?.toString() ?? '',
          ),
        )
            .where((e) => e.startTime.isNotEmpty && e.endTime.isNotEmpty)
            .toList();
      });
    } catch (e) {
      await _showErrorDialog('Failed to load booking time ranges: $e');
    } finally {
      if (!mounted) return;
      setState(() {
        _isLoadingSlots = false;
      });
    }
  }

  Future<void> _pickStartTime() async {
    if (_selectedDate == null) {
      await _showErrorDialog('Please select a booking date first.');
      return;
    }

    final initialTime =
        _timeOfDayFromDbString(_selectedStartTime) ??
            _timeOfDayFromDbString(widget.facility.openTime) ??
            TimeOfDay.now();

    final picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
      initialEntryMode: TimePickerEntryMode.dial,
      helpText: 'Select Start Time',
    );

    if (picked == null) return;

    final pickedMinutes = picked.hour * 60 + picked.minute;
    final openMinutes = _parseTimeToMinutes(widget.facility.openTime);
    final closeMinutes = _parseTimeToMinutes(widget.facility.closeTime);

    if (openMinutes == null || closeMinutes == null) {
      await _showErrorDialog('Invalid facility operating hours.');
      return;
    }

    if (_selectedDate != null &&
        _isSameDate(_selectedDate!, _today) &&
        pickedMinutes <= _nowMinutes) {
      await _showErrorDialog(
        'Start time must be later than current time for today.',
      );
      return;
    }

    if (pickedMinutes < openMinutes || pickedMinutes >= closeMinutes) {
      await _showErrorDialog(
        'Start time must be within facility operating hours.',
      );
      return;
    }

    final pickedDbTime = _formatMinutesToDbTime(pickedMinutes);

    setState(() {
      _selectedStartTime = pickedDbTime;

      final currentEndMinutes = _selectedEndTime == null
          ? null
          : _parseTimeToMinutes(_selectedEndTime!);

      if (currentEndMinutes != null && currentEndMinutes <= pickedMinutes) {
        _selectedEndTime = null;
      }
    });
  }

  Future<void> _pickEndTime() async {
    if (_selectedDate == null) {
      await _showErrorDialog('Please select a booking date first.');
      return;
    }

    if (_selectedStartTime == null) {
      await _showErrorDialog('Please select start time first.');
      return;
    }

    final startMinutes = _parseTimeToMinutes(_selectedStartTime!);
    final closeMinutes = _parseTimeToMinutes(widget.facility.closeTime);

    if (startMinutes == null || closeMinutes == null) {
      await _showErrorDialog('Invalid booking time.');
      return;
    }

    final suggestedMinutes = (startMinutes + 60) <= closeMinutes
        ? startMinutes + 60
        : closeMinutes;

    final initialTime =
        _timeOfDayFromDbString(_selectedEndTime) ??
            _timeOfDayFromMinutes(suggestedMinutes) ??
            TimeOfDay.now();

    final picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
      initialEntryMode: TimePickerEntryMode.dial,
      helpText: 'Select End Time',
    );

    if (picked == null) return;

    final pickedMinutes = picked.hour * 60 + picked.minute;

    if (pickedMinutes <= startMinutes) {
      await _showErrorDialog('End time must be later than start time.');
      return;
    }

    if (pickedMinutes > closeMinutes) {
      await _showErrorDialog(
        'End time must be within facility operating hours.',
      );
      return;
    }

    if (widget.facility.maxDurationMinutes != null &&
        (pickedMinutes - startMinutes) > widget.facility.maxDurationMinutes!) {
      await _showErrorDialog(
        'Maximum duration for ${widget.facility.name} is '
            '${widget.facility.maxDurationMinutes! ~/ 60} hour(s).',
      );
      return;
    }

    setState(() {
      _selectedEndTime = _formatMinutesToDbTime(pickedMinutes);
    });
  }

  Future<void> _submit() async {
    if (_selectedDate == null) {
      await _showErrorDialog('Please select a booking date.');
      return;
    }

    if (_selectedStartTime == null || _selectedEndTime == null) {
      await _showErrorDialog('Please select both start time and end time.');
      return;
    }

    final startMinutes = _parseTimeToMinutes(_selectedStartTime!);
    final endMinutes = _parseTimeToMinutes(_selectedEndTime!);
    final openMinutes = _parseTimeToMinutes(widget.facility.openTime);
    final closeMinutes = _parseTimeToMinutes(widget.facility.closeTime);

    if (startMinutes == null ||
        endMinutes == null ||
        openMinutes == null ||
        closeMinutes == null) {
      await _showErrorDialog('Invalid booking time.');
      return;
    }

    if (_isSameDate(_selectedDate!, _today) && startMinutes <= _nowMinutes) {
      await _showErrorDialog(
        'Start time must be later than current time for today.',
      );
      return;
    }

    if (startMinutes < openMinutes || startMinutes >= closeMinutes) {
      await _showErrorDialog(
        'Start time must be within facility operating hours.',
      );
      return;
    }

    if (endMinutes <= startMinutes) {
      await _showErrorDialog('End time must be later than start time.');
      return;
    }

    if (endMinutes > closeMinutes) {
      await _showErrorDialog(
        'End time must be within facility operating hours.',
      );
      return;
    }

    final durationMinutes = endMinutes - startMinutes;

    if (widget.facility.maxDurationMinutes != null &&
        durationMinutes > widget.facility.maxDurationMinutes!) {
      await _showErrorDialog(
        'Maximum duration for ${widget.facility.name} is '
            '${widget.facility.maxDurationMinutes! ~/ 60} hour(s).',
      );
      return;
    }

    if (!widget.facility.isShared) {
      final hasOverlap = _existingRanges.any((range) {
        final bookedStart = _parseTimeToMinutes(range.startTime);
        final bookedEnd = _parseTimeToMinutes(range.endTime);

        if (bookedStart == null || bookedEnd == null) return false;

        return !(endMinutes <= bookedStart || startMinutes >= bookedEnd);
      });

      if (hasOverlap) {
        await _showErrorDialog(
          'This selected time range overlaps with an existing booking/request.',
        );
        return;
      }
    }

    int participants = 1;
    if (widget.facility.requiresApproval && !widget.facility.isShared) {
      participants = int.tryParse(_participantsController.text.trim()) ?? 0;

      if (participants < 1) {
        await _showErrorDialog('Participants must be at least 1.');
        return;
      }

      if (participants > widget.facility.capacity) {
        await _showErrorDialog(
          'Participants cannot exceed facility capacity (${widget.facility.capacity}).',
        );
        return;
      }
    }

    if (widget.facility.purposeRequired &&
        _purposeController.text.trim().isEmpty) {
      await _showErrorDialog('Purpose is required.');
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await _facilityService.submitFacilityBooking(
        facility: widget.facility,
        bookingDate: _selectedDate!,
        startTime: _selectedStartTime!,
        endTime: _selectedEndTime!,
        participants: participants,
        purpose: _purposeController.text.trim(),
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      await _showErrorDialog('Submit failed: $e');
    } finally {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  int? _parseTimeToMinutes(String raw) {
    if (raw.trim().isEmpty) return null;

    final normalized = raw.trim();
    final parts = normalized.split(':');
    if (parts.length < 2) return null;

    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);

    if (hour == null || minute == null) return null;

    return hour * 60 + minute;
  }

  String _formatMinutesToDbTime(int totalMinutes) {
    final hour = totalMinutes ~/ 60;
    final minute = totalMinutes % 60;
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}:00';
  }

  String _formatDbTimeTo12Hour(String raw) {
    final totalMinutes = _parseTimeToMinutes(raw);
    if (totalMinutes == null) return raw;

    final hour24 = totalMinutes ~/ 60;
    final minute = totalMinutes % 60;

    final period = hour24 >= 12 ? 'PM' : 'AM';
    final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;

    return '$hour12:${minute.toString().padLeft(2, '0')} $period';
  }

  TimeOfDay? _timeOfDayFromDbString(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final totalMinutes = _parseTimeToMinutes(raw);
    if (totalMinutes == null) return null;

    return _timeOfDayFromMinutes(totalMinutes);
  }

  TimeOfDay? _timeOfDayFromMinutes(int totalMinutes) {
    if (totalMinutes < 0) return null;

    final hour = totalMinutes ~/ 60;
    final minute = totalMinutes % 60;

    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;

    return TimeOfDay(hour: hour, minute: minute);
  }

  String _monthLabel(DateTime date) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    return '${months[date.month - 1]} ${date.year}';
  }

  String _durationRuleLabel() {
    if (widget.facility.maxDurationMinutes == null) {
      return 'Flexible duration within operating hours';
    }

    final hours = widget.facility.maxDurationMinutes! ~/ 60;
    final remainingMinutes = widget.facility.maxDurationMinutes! % 60;

    if (remainingMinutes == 0) {
      return 'Maximum duration: $hours hour(s)';
    }

    return 'Maximum duration: $hours hour(s) $remainingMinutes minute(s)';
  }

  Widget _buildBookedRangesSection() {
    if (_selectedDate == null) return const SizedBox.shrink();

    if (_existingRanges.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE4DDD6)),
        ),
        child: const Text(
          'No existing approved bookings for this date.',
          style: TextStyle(
            fontSize: 13,
            color: Colors.black54,
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE4DDD6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Existing booked time ranges',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF2B2B2B),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _existingRanges.map((range) {
              final label =
                  '${_formatDbTimeTo12Hour(range.startTime)} - ${_formatDbTimeTo12Hour(range.endTime)}';

              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF4ECE6),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF7C4A3B),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final calendarDays = _buildCalendarDays();

    final buttonText = widget.facility.isInstantBooking
        ? 'Confirm Booking'
        : 'Submit Request';

    return SafeArea(
      child: FractionallySizedBox(
        heightFactor: 0.95,
        child: Container(
          decoration: const BoxDecoration(
            color: Color(0xFFF7F3EE),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Spacer(),
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                      Text(
                        widget.facility.isInstantBooking
                            ? 'Book ${widget.facility.name}'
                            : 'Request ${widget.facility.name}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF2B2B2B),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        widget.facility.isInstantBooking
                            ? 'Select a date and exact time range to confirm your booking.'
                            : 'Select a date and exact time range, then submit for admin approval.',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 14),
                      _InfoRow(
                        icon: Icons.location_on_outlined,
                        text: widget.facility.location,
                      ),
                      const SizedBox(height: 8),
                      _InfoRow(
                        icon: Icons.people_outline,
                        text: '${widget.facility.capacity} people',
                      ),
                      const SizedBox(height: 8),
                      _InfoRow(
                        icon: Icons.access_time_outlined,
                        text:
                        '${_formatDbTimeTo12Hour(widget.facility.openTime)} - ${_formatDbTimeTo12Hour(widget.facility.closeTime)}',
                      ),
                      const SizedBox(height: 8),
                      _InfoRow(
                        icon: Icons.timelapse_outlined,
                        text: _durationRuleLabel(),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Select Date',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF2B2B2B),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0xFFE4DDD6)),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                IconButton(
                                  onPressed: () => _changeMonth(-1),
                                  icon: const Icon(Icons.chevron_left_rounded),
                                ),
                                Expanded(
                                  child: Text(
                                    _monthLabel(_visibleMonth),
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  onPressed: () => _changeMonth(1),
                                  icon: const Icon(Icons.chevron_right_rounded),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            const Row(
                              children: [
                                _WeekdayLabel(label: 'Su'),
                                _WeekdayLabel(label: 'Mo'),
                                _WeekdayLabel(label: 'Tu'),
                                _WeekdayLabel(label: 'We'),
                                _WeekdayLabel(label: 'Th'),
                                _WeekdayLabel(label: 'Fr'),
                                _WeekdayLabel(label: 'Sa'),
                              ],
                            ),
                            const SizedBox(height: 6),
                            GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: calendarDays.length,
                              gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 7,
                                mainAxisSpacing: 6,
                                crossAxisSpacing: 6,
                                childAspectRatio: 1,
                              ),
                              itemBuilder: (context, index) {
                                final date = calendarDays[index];
                                if (date == null) {
                                  return const SizedBox.shrink();
                                }

                                final isSelected = _selectedDate != null &&
                                    _isSameDate(_selectedDate!, date);
                                final isPast = _isPastDate(date);

                                return InkWell(
                                  onTap: isPast ? null : () => _selectDate(date),
                                  borderRadius: BorderRadius.circular(10),
                                  child: Container(
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? const Color(0xFF9A4B3C)
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      '${date.day}',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: isPast
                                            ? Colors.black26
                                            : isSelected
                                            ? Colors.white
                                            : const Color(0xFF2B2B2B),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Select Time Range',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF2B2B2B),
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (_isLoadingSlots)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else ...[
                        Row(
                          children: [
                            Expanded(
                              child: _TimePickerField(
                                label: 'Start Time',
                                value: _selectedStartTime == null
                                    ? null
                                    : _formatDbTimeTo12Hour(_selectedStartTime!),
                                onTap: _selectedDate == null ? null : _pickStartTime,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _TimePickerField(
                                label: 'End Time',
                                value: _selectedEndTime == null
                                    ? null
                                    : _formatDbTimeTo12Hour(_selectedEndTime!),
                                onTap: (_selectedDate == null ||
                                    _selectedStartTime == null)
                                    ? null
                                    : _pickEndTime,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        _buildBookedRangesSection(),
                      ],
                      if (widget.facility.isShared) ...[
                        const SizedBox(height: 16),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF7EC),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFF2D7A6)),
                          ),
                          child: const Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.info_outline,
                                size: 18,
                                color: Color(0xFF9A4B3C),
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Shared facility booking will be counted as 1 resident automatically.',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF7C4A3B),
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (widget.facility.requiresApproval &&
                          !widget.facility.isShared) ...[
                        const SizedBox(height: 20),
                        const Text(
                          'Participants',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF2B2B2B),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _participantsController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            hintText: 'Enter number of participants',
                            helperText: 'Maximum: ${widget.facility.capacity}',
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                color: Color(0xFFE4DDD6),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                color: Color(0xFFE4DDD6),
                              ),
                            ),
                          ),
                        ),
                      ],
                      if (widget.facility.purposeRequired) ...[
                        const SizedBox(height: 16),
                        const Text(
                          'Purpose',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF2B2B2B),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _purposeController,
                          maxLines: 3,
                          decoration: InputDecoration(
                            hintText: 'Purpose is required',
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                color: Color(0xFFE4DDD6),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                color: Color(0xFFE4DDD6),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF9A4B3C),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey.shade400,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                        : Text(
                      buttonText,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BookedRange {
  const _BookedRange({
    required this.startTime,
    required this.endTime,
  });

  final String startTime;
  final String endTime;
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.black54),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              color: Colors.black54,
            ),
          ),
        ),
      ],
    );
  }
}

class _WeekdayLabel extends StatelessWidget {
  const _WeekdayLabel({
    required this.label,
  });

  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Color(0xFF6A6A6A),
        ),
      ),
    );
  }
}

class _TimePickerField extends StatelessWidget {
  const _TimePickerField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String? value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isDisabled = onTap == null;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
        decoration: BoxDecoration(
          color: isDisabled ? Colors.grey.shade100 : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE4DDD6)),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.access_time_rounded,
              size: 18,
              color: Colors.black54,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                value ?? label,
                style: TextStyle(
                  fontSize: 14,
                  color: value == null ? Colors.black45 : const Color(0xFF2B2B2B),
                  fontWeight: value == null ? FontWeight.w500 : FontWeight.w600,
                ),
              ),
            ),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: Colors.black45,
            ),
          ],
        ),
      ),
    );
  }
}