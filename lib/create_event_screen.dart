import 'dart:io'; // Required for File
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart'; // Ensure flutter pub add image_picker
import 'event_service.dart';

class CreateEventScreen extends StatefulWidget {
  final String userRole; // 'admin' or 'resident'
  final String userEmail;
  final String userName;

  const CreateEventScreen({
    super.key,
    required this.userRole,
    required this.userEmail,
    required this.userName
  });

  @override
  State<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends State<CreateEventScreen> {
  final _formKey = GlobalKey<FormState>();
  final EventService _eventService = EventService();

  // Text Controllers
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _locController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();

  // Image Picking Variables
  File? _selectedImage;
  final ImagePicker _picker = ImagePicker();

  // Color Palette
  final Color cork = const Color(0xFFAD8762);
  final Color apricot = const Color(0xFFFFB38A);

  // --- IMAGE PICKING LOGIC ---
  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70, // Compresses image to save Supabase storage space
    );

    if (image != null) {
      setState(() {
        _selectedImage = File(image.path);
      });
    }
  }

  // --- DATE & TIME PICKERS ---
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

  Future<void> _pickTime() async {
    TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null) setState(() => _selectedTime = picked);
  }

  // --- FORM SUBMISSION ---
  void _submitForm() async {
    if (_formKey.currentState!.validate()) {
      try {
        final eventData = {
          'title': _titleController.text,
          'description': _descController.text,
          'location': _locController.text,
          'event_date': DateFormat('yyyy-MM-dd').format(_selectedDate),
          'start_time': _selectedTime.format(context),
          'created_by': widget.userEmail,
          'created_by_name': widget.userName,
          'is_private': false,
          // imageUrl will be added here once we implement Supabase Storage upload
        };

        await _eventService.createEvent(
            eventData: eventData,
            userRole: widget.userRole
        );

        String message = widget.userRole == 'admin'
            ? "Event Published! ✅"
            : "Proposal Sent! Waiting for Approval. ⏳";

        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message), backgroundColor: cork)
        );

        Navigator.pop(context);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error: $e"), backgroundColor: Colors.redAccent)
        );
      }
    }
  }

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
              // --- IMAGE PICKER UI ---
              _buildLabel("Event Cover Image"),
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  height: 180,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: _selectedImage != null
                      ? ClipRRect(
                    borderRadius: BorderRadius.circular(15),
                    child: Image.file(_selectedImage!, fit: BoxFit.cover),
                  )
                      : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_a_photo, color: cork, size: 40),
                      const SizedBox(height: 10),
                      Text("Tap to upload photo", style: TextStyle(color: cork)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 25),

              // --- TITLE ---
              _buildLabel("Event Title"),
              TextFormField(
                controller: _titleController,
                decoration: _inputStyle("e.g. Garden Cleanup"),
                validator: (v) => v!.isEmpty ? "Enter a title" : null,
              ),
              const SizedBox(height: 20),

              // --- LOCATION ---
              _buildLabel("Location"),
              TextFormField(
                controller: _locController,
                decoration: _inputStyle("e.g. Block A Lobby"),
                validator: (v) => v!.isEmpty ? "Enter a location" : null,
              ),
              const SizedBox(height: 20),

              // --- DATE & TIME ROW ---
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel("Date"),
                        InkWell(
                          onTap: _pickDate,
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            width: double.infinity,
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(10),
                              color: Colors.white,
                            ),
                            child: Text(DateFormat('dd MMM yyyy').format(_selectedDate)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel("Time"),
                        InkWell(
                          onTap: _pickTime,
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            width: double.infinity,
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(10),
                              color: Colors.white,
                            ),
                            child: Text(_selectedTime.format(context)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // --- DESCRIPTION ---
              _buildLabel("Description"),
              TextFormField(
                controller: _descController,
                maxLines: 3,
                decoration: _inputStyle("Tell us more about the event..."),
              ),
              const SizedBox(height: 40),

              // --- SUBMIT BUTTON ---
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _submitForm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: apricot,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                  child: Text(
                      widget.userRole == 'admin' ? "Publish Event" : "Submit Proposal",
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- HELPER WIDGETS ---
  Widget _buildLabel(String label) => Padding(
    padding: const EdgeInsets.only(bottom: 8.0),
    child: Text(label, style: TextStyle(color: cork, fontWeight: FontWeight.bold)),
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