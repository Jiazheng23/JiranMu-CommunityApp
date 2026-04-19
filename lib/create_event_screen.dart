import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'event_service.dart';
// Import your history page here once created
// import 'resident_history_screen.dart';

class CreateEventScreen extends StatefulWidget {
  final String userRole;
  final String userEmail;
  final String userName;

  const CreateEventScreen({
    super.key,
    required this.userRole,
    required this.userEmail,
    required this.userName,
  });

  @override
  State<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends State<CreateEventScreen> {
  final _formKey = GlobalKey<FormState>();
  final EventService _eventService = EventService();

  // Controllers
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  // NEW: Controller for Max Capacity
  final TextEditingController _capacityController = TextEditingController(text: "20");

  // State Variables
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _startTime = TimeOfDay.now();
  TimeOfDay _endTime = TimeOfDay.now().replacing(hour: (TimeOfDay.now().hour + 1) % 24);

  String? _selectedLocation;
  bool _isPrivate = false;
  File? _selectedImage;
  final ImagePicker _picker = ImagePicker();

  // Theme Colors
  final Color cork = const Color(0xFFAD8762);
  final Color apricot = const Color(0xFFFFB38A);

  final List<String> _condoFacilities = [
    'Swimming Pool',
    'Multi-purpose Hall',
    'BBQ Area',
    'Gymnasium',
    'Badminton Court',
    'Lounge',
    'Playground',
  ];

  // --- HELPERS ---

  String _formatTimeForDb(TimeOfDay time) {
    final now = DateTime.now();
    final dt = DateTime(now.year, now.month, now.day, time.hour, time.minute);
    return DateFormat('HH:mm:ss').format(dt);
  }

  // --- LOGIC ---

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
    if (_formKey.currentState!.validate()) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      try {
        final formattedDate = DateFormat('yyyy-MM-dd').format(_selectedDate);
        final dbStartTime = _formatTimeForDb(_startTime);
        final dbEndTime = _formatTimeForDb(_endTime);

        // 1. Double-Booking Check
        bool isAvailable = await _eventService.isFacilityAvailable(
          _selectedLocation!,
          formattedDate,
          dbStartTime,
          dbEndTime,
        );

        if (!isAvailable) {
          if (mounted) Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Time Conflict! Facility already booked."), backgroundColor: Colors.orange),
          );
          return;
        }

        // 2. Image Upload
        String? imageUrl;
        if (_selectedImage != null) {
          imageUrl = await _eventService.uploadEventImage(_selectedImage!);
        }

        // 3. Data Preparation (Including Max Capacity)
        final eventData = {
          'title': _titleController.text.trim(),
          'description': _descController.text.trim(),
          'location': _selectedLocation,
          'event_date': formattedDate,
          'start_time': dbStartTime,
          'end_time': dbEndTime,
          'max_capacity': int.parse(_capacityController.text), // NEW
          'created_by_name': widget.userName,
          'is_private': _isPrivate,
          'image_url': imageUrl,
        };

        // 4. Send to Service
        await _eventService.createEvent(
          eventData: eventData,
          userRole: widget.userRole,
        );

        if (mounted) {
          Navigator.pop(context); // Close loading

          String msg = widget.userRole == 'admin' ? "Event Published! ✅" : "Proposal Sent! ⏳";
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: cork));

          // 5. Navigation Logic
          if (widget.userRole == 'admin') {
            Navigator.pop(context, true); // Return to calendar
          } else {
            // Redirect Resident to History Page
            // Replace with your actual History Screen push
            // Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => ResidentHistoryScreen()));
            Navigator.pop(context);
          }
        }
      } catch (e) {
        if (mounted) Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  // --- UI BUILDING ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.userRole == 'admin' ? 'Create Official Event' : 'Propose Community Event'),
        backgroundColor: cork,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
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
                  height: 180, width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey[200], borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Colors.grey.shade300),
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
                decoration: _inputStyle("e.g. Community Yoga"),
                validator: (v) => v!.isEmpty ? "Enter a title" : null,
              ),
              const SizedBox(height: 20),

              // NEW: Max Capacity Field
              _buildLabel("Max Capacity (People)"),
              TextFormField(
                controller: _capacityController,
                keyboardType: TextInputType.number,
                decoration: _inputStyle("e.g. 30"),
                validator: (v) {
                  if (v == null || v.isEmpty) return "Enter capacity";
                  if (int.tryParse(v) == null) return "Enter a valid number";
                  return null;
                },
              ),
              const SizedBox(height: 20),

              _buildLabel("Select Facility/Area"),
              DropdownButtonFormField<String>(
                value: _selectedLocation,
                items: _condoFacilities.map((loc) => DropdownMenuItem(value: loc, child: Text(loc))).toList(),
                onChanged: (val) => setState(() => _selectedLocation = val),
                decoration: _inputStyle("Choose a location"),
                validator: (v) => v == null ? "Please select a location" : null,
              ),
              const SizedBox(height: 20),

              _buildLabel("Date"),
              InkWell(onTap: _pickDate, child: _buildSelectionBox(DateFormat('dd MMM yyyy').format(_selectedDate))),
              const SizedBox(height: 20),

              Row(
                children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    _buildLabel("Start Time"),
                    InkWell(onTap: _pickStartTime, child: _buildSelectionBox(_startTime.format(context))),
                  ])),
                  const SizedBox(width: 15),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    _buildLabel("End Time"),
                    InkWell(onTap: _pickEndTime, child: _buildSelectionBox(_endTime.format(context))),
                  ])),
                ],
              ),
              const SizedBox(height: 20),

              Container(
                decoration: BoxDecoration(color: cork.withOpacity(0.05), borderRadius: BorderRadius.circular(10)),
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
                decoration: _inputStyle("Tell us more about the event..."),
              ),
              const SizedBox(height: 40),

              SizedBox(
                width: double.infinity, height: 55,
                child: ElevatedButton(
                  onPressed: _submitForm,
                  style: ElevatedButton.styleFrom(backgroundColor: apricot, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                  child: Text(widget.userRole == 'admin' ? "Publish Event" : "Submit Proposal",
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // --- UI COMPONENTS ---
  Widget _buildLabel(String label) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(label, style: TextStyle(color: cork, fontWeight: FontWeight.bold)));

  Widget _buildSelectionBox(String text) => Container(
    padding: const EdgeInsets.all(12), width: double.infinity,
    decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(10), color: Colors.white),
    child: Text(text, style: const TextStyle(fontSize: 16)),
  );

  InputDecoration _inputStyle(String hint) => InputDecoration(
    hintText: hint, filled: true, fillColor: Colors.white,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: cork, width: 2)),
  );
}