import 'package:assignment/facility/facility_model.dart';
import 'package:assignment/facility/facility_service.dart';
import 'package:flutter/material.dart';

class FacilityUnavailableSlotsPage extends StatefulWidget {
  const FacilityUnavailableSlotsPage({
    super.key,
    required this.facility,
  });

  final FacilityModel facility;

  @override
  State<FacilityUnavailableSlotsPage> createState() =>
      _FacilityUnavailableSlotsPageState();
}

class _FacilityUnavailableSlotsPageState
    extends State<FacilityUnavailableSlotsPage> {
  static const Color bgColor = Color(0xFFF5F1ED);
  static const Color primaryColor = Color(0xFF9A4B3C);
  static const Color textDark = Color(0xFF2B2B2B);

  final FacilityService _facilityService = FacilityService();
  final TextEditingController _reasonController = TextEditingController();

  bool _isSaving = false;
  bool _hasChanges = false;

  DateTime? _selectedDate;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;

  TimeOfDay _parseFacilityTime(String time) {
    final parts = time.split(':');
    return TimeOfDay(
      hour: int.parse(parts[0]),
      minute: int.parse(parts[1]),
    );
  }

  late Future<List<FacilityUnavailableSlot>> _slotsFuture;

  @override
  void initState() {
    super.initState();

    _startTime = _parseFacilityTime(widget.facility.openTime);
    _endTime = _parseFacilityTime(widget.facility.closeTime);

    _slotsFuture = _facilityService.fetchFacilityUnavailableSlots(
      widget.facility.id,
    );
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  void _reloadSlots() {
    setState(() {
      _slotsFuture = _facilityService.fetchFacilityUnavailableSlots(
        widget.facility.id,
      );
    });
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 2),
    );

    if (picked == null) return;

    setState(() {
      _selectedDate = picked;
    });
  }

  Future<void> _pickTime(bool isStart) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart
          ? (_startTime ?? const TimeOfDay(hour: 8, minute: 0))
          : (_endTime ?? const TimeOfDay(hour: 9, minute: 0)),
    );

    if (picked == null) return;

    setState(() {
      if (isStart) {
        _startTime = picked;
      } else {
        _endTime = picked;
      }
    });
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Select date';
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    return '$day/$month/$year';
  }

  String _formatDisplayTime(TimeOfDay? time) {
    if (time == null) return 'Select time';

    final period = time.hour >= 12 ? 'PM' : 'AM';
    final hour12 = time.hour % 12 == 0 ? 12 : time.hour % 12;
    final minute = time.minute.toString().padLeft(2, '0');

    return '$hour12:$minute $period';
  }

  String _formatDbTime(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute:00';
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
        borderSide: BorderSide(color: primaryColor, width: 1.5),
      ),
    );
  }

  Future<void> _saveBlockedSlot() async {
    if (_selectedDate == null) {
      _showSnackBar('Please select a date');
      return;
    }

    if (_startTime == null || _endTime == null) {
      _showSnackBar('Please select start time and end time');
      return;
    }

    try {
      setState(() {
        _isSaving = true;
      });

      await _facilityService.createFacilityUnavailableSlot(
        facility: widget.facility,
        blockDate: _selectedDate!,
        startTime: _formatDbTime(_startTime!),
        endTime: _formatDbTime(_endTime!),
        reason: _reasonController.text.trim(),
      );

      if (!mounted) return;

      setState(() {
        _hasChanges = true;
        _selectedDate = null;
        _startTime = _parseFacilityTime(widget.facility.openTime);
        _endTime = _parseFacilityTime(widget.facility.closeTime);
        _reasonController.clear();
      });

      _reloadSlots();
      _showSnackBar('Unavailable slot added successfully');
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Failed to add unavailable slot: $e');
    } finally {
      if (!mounted) return;

      setState(() {
        _isSaving = false;
      });
    }
  }

  Future<void> _deleteSlot(FacilityUnavailableSlot slot) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove unavailable slot?'),
        content: const Text(
          'This will make the blocked time range available again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _facilityService.deleteFacilityUnavailableSlot(slot.id);

      if (!mounted) return;

      setState(() {
        _hasChanges = true;
      });

      _reloadSlots();
      _showSnackBar('Unavailable slot removed');
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Failed to remove slot: $e');
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message)),
      );
  }

  Widget _buildPickerTile({
    required String label,
    required String value,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: InputDecorator(
        decoration: _inputDecoration(label).copyWith(
          suffixIcon: Icon(icon, color: primaryColor),
        ),
        child: Text(
          value,
          style: TextStyle(
            color: value.startsWith('Select') ? Colors.grey.shade600 : textDark,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildSlotCard(FacilityUnavailableSlot slot) {
    final reason = slot.reason?.trim();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 10,
        ),
        title: Text(
          slot.blockDate,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: textDark,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${_facilityService.formatDbTimeTo12Hour(slot.startTime)} - '
                    '${_facilityService.formatDbTimeTo12Hour(slot.endTime)}',
              ),
              if (reason != null && reason.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text('Reason: $reason'),
              ],
            ],
          ),
        ),
        trailing: IconButton(
          onPressed: () => _deleteSlot(slot),
          icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
        ),
      ),
    );
  }

  Future<bool> _handleBack() async {
    Navigator.pop(context, _hasChanges);
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (_) => _handleBack(),
      child: Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          backgroundColor: bgColor,
          surfaceTintColor: bgColor,
          elevation: 0,
          foregroundColor: textDark,
          title: Text(
            '${widget.facility.name} Slots',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: textDark,
            ),
          ),
          leading: IconButton(
            onPressed: _handleBack,
            icon: const Icon(Icons.arrow_back),
          ),
        ),
        body: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Add Unavailable Slot',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: textDark,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildPickerTile(
                          label: 'Date',
                          value: _formatDate(_selectedDate),
                          icon: Icons.calendar_today_outlined,
                          onTap: _pickDate,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _buildPickerTile(
                                label: 'Start Time',
                                value: _formatDisplayTime(_startTime),
                                icon: Icons.access_time_outlined,
                                onTap: () => _pickTime(true),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildPickerTile(
                                label: 'End Time',
                                value: _formatDisplayTime(_endTime),
                                icon: Icons.access_time_outlined,
                                onTap: () => _pickTime(false),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _reasonController,
                          maxLines: 2,
                          decoration: _inputDecoration('Reason (optional)'),
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isSaving ? null : _saveBlockedSlot,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: _isSaving
                                ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: Colors.white,
                              ),
                            )
                                : const Text(
                              'Save Unavailable Slot',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Existing Unavailable Slots',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: textDark,
                    ),
                  ),
                  const SizedBox(height: 12),
                  FutureBuilder<List<FacilityUnavailableSlot>>(
                    future: _slotsFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Padding(
                          padding: EdgeInsets.all(20),
                          child: Center(
                            child: CircularProgressIndicator(
                              color: primaryColor,
                            ),
                          ),
                        );
                      }

                      if (snapshot.hasError) {
                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            'Failed to load unavailable slots: ${snapshot.error}',
                          ),
                        );
                      }

                      final slots = snapshot.data ?? [];

                      if (slots.isEmpty) {
                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Text(
                            'No unavailable slots yet.',
                            style: TextStyle(color: Colors.black54),
                          ),
                        );
                      }

                      return Column(
                        children: List.generate(slots.length, (index) {
                          return Padding(
                            padding: EdgeInsets.only(
                              bottom: index == slots.length - 1 ? 0 : 12,
                            ),
                            child: _buildSlotCard(slots[index]),
                          );
                        }),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}