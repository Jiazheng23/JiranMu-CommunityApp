import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:assignment/event/service/event_service.dart';
import 'resident_event_history_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CreateEventScreen extends StatefulWidget {
  final String userRole;
  final String userEmail;
  final String userName;
  final String currentUserId;

  const CreateEventScreen({
    super.key,
    required this.userRole,
    required this.userEmail,
    required this.userName,
    required this.currentUserId,
  });

  @override
  State<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends State<CreateEventScreen> {
  final _formKey = GlobalKey<FormState>();
  final EventService _eventService = EventService();
  final SupabaseClient supabase = Supabase.instance.client;

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _capacityController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 10, minute: 0);

  Map<String, dynamic>? _selectedFacility;
  List<Map<String, dynamic>> _availableFacilities = [];
  bool _isLoadingFacilities = true;

  // Real-time validation states
  bool _isCheckingAvailability = false;
  bool? _isAvailable;
  List<String> _availableSuggestions = [];

  int _currentMaxAllowed = 0;

  bool _isPrivate = false;
  File? _selectedImage;
  final ImagePicker _picker = ImagePicker();

  final Color cork = const Color(0xFFAD8762);
  final Color apricot = const Color(0xFFFFB38A);

  @override
  void initState() {
    super.initState();
    _loadFacilities();
  }

  Future<void> _loadFacilities() async {
    try {
      final data = await supabase
          .from('facilities')
          .select()
          .eq('usage_type', 'event')
          .eq('is_active', true);

      if (mounted) {
        setState(() {
          _availableFacilities = List<Map<String, dynamic>>.from(data);
          _isLoadingFacilities = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading facilities: $e");
      setState(() => _isLoadingFacilities = false);
    }
  }

  // ─────────────────────────────────────────────
  // VALIDATION LOGIC
  // ─────────────────────────────────────────────
  Future<void> _validateAvailability() async {
    if (_selectedFacility == null) return;

    setState(() {
      _isCheckingAvailability = true;
      _isAvailable = null;
      _availableSuggestions = [];
    });

    // 1. Check Operating Hours FIRST
    if (_isOutsideOperatingHours()) {
      setState(() {
        _isAvailable = false;
        _isCheckingAvailability = false;
        // You can manually add a suggestion or message here
        _availableSuggestions = ["Note: Venue is closed during this time."];
      });
      return; // Stop here, don't check database for overlaps
    }

    // 2. If hours are okay, check Database for overlaps
    try {
      final formattedDate = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final dbStartTime = _formatTimeForDb(_startTime);
      final dbEndTime = _formatTimeForDb(_endTime);

      bool result = await _eventService.isFacilityAvailable(
        _selectedFacility!['name'],
        formattedDate,
        dbStartTime,
        dbEndTime,
      );

      List<String> suggestions = [];
      if (!result) {
        suggestions = await _eventService.getAvailableSlots(
          location: _selectedFacility!['name'],
          date: formattedDate,
          openTime: _selectedFacility!['open_time'],
          closeTime: _selectedFacility!['close_time'],
        );
      }

      if (mounted) {
        setState(() {
          _isAvailable = result;
          _availableSuggestions = suggestions;
          _isCheckingAvailability = false;
        });
      }
    } catch (e) {
      debugPrint("Validation Error: $e");
      if (mounted) setState(() => _isCheckingAvailability = false);
    }
  }

  bool _isOutsideOperatingHours() {
    if (_selectedFacility == null) return false;
    try {
      TimeOfDay parseDbTime(String timeStr) {
        final parts = timeStr.split(':');
        return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
      }
      final openTime = parseDbTime(_selectedFacility!['open_time']);
      final closeTime = parseDbTime(_selectedFacility!['close_time']);
      double toDouble(TimeOfDay myTime) => myTime.hour + (myTime.minute / 60.0);
      final start = toDouble(_startTime);
      final end = toDouble(_endTime);
      final open = toDouble(openTime);
      final close = toDouble(closeTime);
      return (start < open || end > close);
    } catch (e) {
      return false;
    }
  }

  String _formatTimeForDb(TimeOfDay time) {
    final String hour = time.hour.toString().padLeft(2, '0');
    final String minute = time.minute.toString().padLeft(2, '0');
    return "$hour:$minute:00";
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (image != null) setState(() => _selectedImage = File(image.path));
  }

  Future<void> _pickDate() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime(2027),
      builder: (context, child) => Theme(
        data: ThemeData.light().copyWith(colorScheme: ColorScheme.light(primary: cork)),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
      _validateAvailability();
    }
  }

  Future<void> _pickStartTime() async {
    TimeOfDay? picked = await showTimePicker(context: context, initialTime: _startTime);
    if (picked != null) {
      setState(() => _startTime = picked);
      _validateAvailability();
    }
  }

  Future<void> _pickEndTime() async {
    TimeOfDay? picked = await showTimePicker(context: context, initialTime: _endTime);
    if (picked != null) {
      setState(() => _endTime = picked);
      _validateAvailability();
    }
  }

  void _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isAvailable == false) return;

    final double startDouble = _startTime.hour + _startTime.minute / 60.0;
    final double endDouble = _endTime.hour + _endTime.minute / 60.0;

    if (endDouble <= startDouble) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("End Time must be later than Start Time!")),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final formattedDate = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final dbStartTime = _formatTimeForDb(_startTime);
      final dbEndTime = _formatTimeForDb(_endTime);

      String? imageUrl;
      if (_selectedImage != null) {
        imageUrl = await _eventService.uploadEventImage(_selectedImage!);
      }

      final eventData = {
        'title': _titleController.text.trim(),
        'description': _descController.text.trim(),
        'location': _selectedFacility!['name'],
        'event_date': formattedDate,
        'start_time': dbStartTime,
        'end_time': dbEndTime,
        'max_capacity': int.tryParse(_capacityController.text) ?? _currentMaxAllowed,
        'created_by_name': widget.userName,
        'is_private': _isPrivate,
        'image_url': imageUrl,
      };

      await _eventService.createEvent(
        eventData: eventData,
        userRole: widget.userRole,
      );

      if (mounted) {
        Navigator.pop(context);
        String msg = widget.userRole == 'admin' ? "Event Published! ✅" : "Proposal Sent! ⏳";
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: cork));

        if (widget.userRole == 'admin') {
          Navigator.pop(context, true);
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => ResidentEventHistoryScreen(
                currentUserId: widget.currentUserId,
                currentUserName: widget.userName,
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.redAccent),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F0),
      appBar: AppBar(
        title: Text(widget.userRole == 'admin' ? 'Create Official Event' : 'Propose Community Event',
            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: cork,
        centerTitle: true,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoadingFacilities
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildLabel("Event Cover Image"),
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  height: 180,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Colors.grey.shade300),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
                  ),
                  child: _selectedImage != null
                      ? ClipRRect(borderRadius: BorderRadius.circular(15), child: Image.file(_selectedImage!, fit: BoxFit.cover))
                      : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.add_a_photo, color: cork, size: 40),
                    const SizedBox(height: 10),
                    Text("Tap to upload photo", style: TextStyle(color: cork)),
                  ]),
                ),
              ),
              const SizedBox(height: 25),
              _buildLabel("Event Title"),
              TextFormField(
                controller: _titleController,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                decoration: _inputStyle("e.g. Community Yoga"),
                validator: (v) => (v == null || v.trim().isEmpty) ? "Please enter an event title" : null,
              ),
              const SizedBox(height: 20),

              _buildLabel("Select Event Venue"),
              _buildFacilityDropdown(),
              _buildOperatingHoursWarning(),
              const SizedBox(height: 20),

              _buildLabel("Date & Time Availability"),
              _buildAvailabilityStatus(),
              const SizedBox(height: 10),

              InkWell(onTap: _pickDate, child: _buildSelectionBox(DateFormat('dd MMM yyyy').format(_selectedDate))),
              const SizedBox(height: 15),
              Row(
                children: [
                  Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        _buildLabel("Start Time"),
                        InkWell(onTap: _pickStartTime, child: _buildSelectionBox(_startTime.format(context))),
                      ])),
                  const SizedBox(width: 15),
                  Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        _buildLabel("End Time"),
                        InkWell(onTap: _pickEndTime, child: _buildSelectionBox(_endTime.format(context))),
                      ])),
                ],
              ),
              const SizedBox(height: 20),

              _buildLabel("Expected Participants"),
              TextFormField(
                controller: _capacityController,
                keyboardType: TextInputType.number,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                decoration: InputDecoration(
                  hintText: _selectedFacility == null ? "Select venue first" : "Enter amount",
                  filled: true,
                  fillColor: Colors.white,
                  helperText: _selectedFacility != null
                      ? "The ${_selectedFacility!['name']} can hold up to $_currentMaxAllowed people."
                      : "Choose a venue to see capacity limits.",
                  helperStyle: TextStyle(color: cork, fontStyle: FontStyle.italic, fontSize: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: cork, width: 2)),
                ),
                validator: (v) {
                  if (_selectedFacility == null) return "Please select a venue first";
                  if (v == null || v.isEmpty) return "Enter capacity";
                  final n = int.tryParse(v);
                  if (n == null) return "Enter a valid number";
                  if (n < 1) return "Minimum 1 person required";
                  if (n > _currentMaxAllowed) return "Exceeds capacity! Enter $_currentMaxAllowed or less.";
                  return null;
                },
              ),
              const SizedBox(height: 20),

              Container(
                decoration: BoxDecoration(color: cork.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                child: SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  title: Text("Private Event", style: TextStyle(color: cork, fontWeight: FontWeight.bold)),
                  subtitle: const Text("Only visible to you and admins"),
                  value: _isPrivate,
                  activeColor: apricot,
                  onChanged: (val) => setState(() => _isPrivate = val),
                ),
              ),
              const SizedBox(height: 20),
              _buildLabel("Description"),
              TextFormField(
                controller: _descController,
                maxLines: 3,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                decoration: _inputStyle("Tell us more about the event..."),
                validator: (v) => (v == null || v.trim().isEmpty) ? "Please provide a description" : null,
              ),
              const SizedBox(height: 40),

              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: (_isAvailable == true && !_isCheckingAvailability) ? _submitForm : null,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: apricot,
                      disabledBackgroundColor: Colors.grey.shade300,
                      elevation: 5,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                  child: Text(
                      _isCheckingAvailability
                          ? "Checking Availability..."
                          : (widget.userRole == 'admin' ? "Publish Event" : "Submit Proposal"),
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // UPDATED UI WIDGETS (Schedules UI)
  // ─────────────────────────────────────────────

  Widget _buildAvailabilityStatus() {
    if (_selectedFacility == null) return const SizedBox.shrink();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      width: double.infinity,
      decoration: BoxDecoration(
        color: _isCheckingAvailability
            ? Colors.grey.shade50
            : (_isAvailable == true ? Colors.green.shade50 : Colors.red.shade50),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: _isCheckingAvailability
              ? Colors.grey.shade300
              : (_isAvailable == true ? Colors.green.shade400 : Colors.red.shade400),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _isCheckingAvailability
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : Icon(
                _isAvailable == true ? Icons.check_circle : Icons.error_outline,
                color: _isAvailable == true ? Colors.green : Colors.red,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _isCheckingAvailability
                      ? "Verifying venue schedule..."
                      : (_isAvailable == true
                      ? "Venue is available for this time!"
                      : "Schedule Conflict: Please pick a different time."),
                  style: TextStyle(
                    fontSize: 13,
                    color: _isAvailable == true ? Colors.green.shade900 : Colors.red.shade900,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          // SHOW SLOTS IF AVAILABLE
          if (_isAvailable == false) ...[
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Text(
              _availableSuggestions.isEmpty
                  ? "No other free slots found for this day."
                  : "Available Slots (including 2h buffers):",
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _availableSuggestions.map((slot) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.red.shade200),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    slot,
                    style: TextStyle(fontSize: 11, color: Colors.red.shade900, fontWeight: FontWeight.w600),
                  ),
                );
              }).toList(),
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildFacilityDropdown() {
    return FormField<Map<String, dynamic>>(
      validator: (v) => _selectedFacility == null ? "Please select a facility" : null,
      builder: (state) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LayoutBuilder(
              builder: (context, constraints) => DropdownMenu<Map<String, dynamic>>(
                width: constraints.maxWidth,
                initialSelection: _selectedFacility,
                hintText: "Choose an event venue",
                inputDecorationTheme: InputDecorationTheme(
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: state.hasError ? Colors.red : Colors.grey.shade300),
                  ),
                ),
                dropdownMenuEntries: _availableFacilities.map((facility) {
                  return DropdownMenuEntry<Map<String, dynamic>>(
                    value: facility,
                    label: "${facility['name']} (Cap: ${facility['capacity']})",
                  );
                }).toList(),
                onSelected: (val) {
                  setState(() {
                    _selectedFacility = val;
                    _currentMaxAllowed = val?['capacity'] ?? 0;
                    state.didChange(val);
                    _formKey.currentState?.validate();
                  });
                  _validateAvailability();
                },
              ),
            ),
            if (state.hasError)
              Padding(
                padding: const EdgeInsets.only(top: 8.0, left: 12),
                child: Text(state.errorText!, style: const TextStyle(color: Colors.red, fontSize: 12)),
              ),
          ],
        );
      },
    );
  }

  Widget _buildOperatingHoursWarning() {
    if (_selectedFacility == null) return const SizedBox.shrink();
    return Column(
      children: [
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(Icons.info_outline, size: 14, color: Colors.grey.shade600),
            const SizedBox(width: 4),
            Text(
              "Operating hours: ${_selectedFacility!['open_time']} - ${_selectedFacility!['close_time']}",
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
            ),
          ],
        ),
        if (_isOutsideOperatingHours())
          Container(
            margin: const EdgeInsets.only(top: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              // Using your theme's Red but very light
              color: const Color(0xFF9A4B3C).withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF9A4B3C).withOpacity(0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.history_toggle_off_rounded, color: Color(0xFF9A4B3C), size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "Venue is CLOSED at this time. Please select a time between ${_selectedFacility!['open_time']} and ${_selectedFacility!['close_time']}.",
                    style: const TextStyle(
                        color: Color(0xFF9A4B3C),
                        fontSize: 12,
                        fontWeight: FontWeight.bold
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildLabel(String label) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(label, style: TextStyle(color: cork, fontWeight: FontWeight.bold)));

  Widget _buildSelectionBox(String text) => Container(
    padding: const EdgeInsets.all(12),
    width: double.infinity,
    decoration: BoxDecoration(
      border: Border.all(color: Colors.grey.shade300),
      borderRadius: BorderRadius.circular(10),
      color: Colors.white,
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(text, style: const TextStyle(fontSize: 16)),
        Icon(Icons.access_time_rounded, color: cork, size: 20),
      ],
    ),
  );

  InputDecoration _inputStyle(String hint) => InputDecoration(
    hintText: hint,
    filled: true,
    fillColor: Colors.white,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: cork, width: 2)),
  );
}