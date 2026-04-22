import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:assignment/event/service/event_service.dart';
import 'resident_event_history_screen.dart';

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

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _capacityController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 10, minute: 0);

  Map<String, dynamic>? _selectedFacility;
  List<Map<String, dynamic>> _availableFacilities = [];
  bool _isLoadingFacilities = true;

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
    final facilities = await _eventService.fetchActiveFacilities();
    if (mounted) {
      setState(() {
        _availableFacilities = facilities;
        _isLoadingFacilities = false;
      });
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
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickStartTime() async {
    TimeOfDay? picked = await showTimePicker(context: context, initialTime: _startTime);
    if (picked != null) setState(() => _startTime = picked);
  }

  Future<void> _pickEndTime() async {
    TimeOfDay? picked = await showTimePicker(context: context, initialTime: _endTime);
    if (picked != null) setState(() => _endTime = picked);
  }

  void _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

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

      bool isAvailable = await _eventService.isFacilityAvailable(
        _selectedFacility!['name'],
        formattedDate,
        dbStartTime,
        dbEndTime,
      );

      if (!isAvailable) {
        if (mounted) Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Time Conflict! This facility is already booked."),
            backgroundColor: Colors.deepOrange,
          ),
        );
        return;
      }

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
        'max_capacity': int.tryParse(_capacityController.text) ?? 20,
        'created_by_name': widget.userName,
        'is_private': _isPrivate,
        'image_url': imageUrl,
      };

      await _eventService.createEvent(
        eventData: eventData,
        userRole: widget.userRole,
      );

      if (mounted) {
        Navigator.pop(context); // Close loading dialog

        String msg = widget.userRole == 'admin' ? "Event Published! ✅" : "Proposal Sent! ⏳";
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: cork));

        // Logic fix: Navigate back correctly depending on role
        if (widget.userRole == 'admin') {
          // Admins go back to the Calendar (which will refresh automatically)
          Navigator.pop(context, true);
        } else {
          // Residents go to their History to see the "Pending" status
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
              _buildLabel("Max Capacity (5 - 100 people)"),
              TextFormField(
                controller: _capacityController,
                keyboardType: TextInputType.number,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                decoration: _inputStyle("e.g. 20"),
                validator: (v) {
                  if (v == null || v.isEmpty) return "Enter capacity";
                  final n = int.tryParse(v);
                  if (n == null) return "Enter a valid number";
                  if (n < 5) return "Minimum 5 people required";
                  if (n > 100) return "Maximum 100 people allowed";
                  return null;
                },
              ),
              const SizedBox(height: 20),
              _buildLabel("Select Facility/Area"),
              _buildFacilityDropdown(),
              _buildOperatingHoursWarning(),
              const SizedBox(height: 20),
              _buildLabel("Date"),
              InkWell(onTap: _pickDate, child: _buildSelectionBox(DateFormat('dd MMM yyyy').format(_selectedDate))),
              const SizedBox(height: 20),
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
                  onPressed: _submitForm,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: apricot,
                      elevation: 5,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                  child: Text(widget.userRole == 'admin' ? "Publish Event" : "Submit Proposal",
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
                hintText: "Choose a location",
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
                    label: facility['name'],
                  );
                }).toList(),
                onSelected: (val) {
                  setState(() {
                    _selectedFacility = val;
                    state.didChange(val);
                  });
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
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.orange.shade800, size: 18),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    "Special Request: Selected time is outside standard hours. Approval is subject to Admin discretion.",
                    style: TextStyle(fontSize: 11, color: Color(0xFF855D00), fontWeight: FontWeight.bold),
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
    decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(10), color: Colors.white),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(text, style: const TextStyle(fontSize: 16)),
        Icon(Icons.arrow_drop_down, color: cork),
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