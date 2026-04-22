import 'dart:io';
import 'package:assignment/facility/facility_model.dart';
import 'package:assignment/facility/facility_service.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class CreateFacilityPage extends StatefulWidget {
  const CreateFacilityPage({
    super.key,
    this.facility,
  });

  final FacilityModel? facility;

  bool get isEditMode => facility != null;

  @override
  State<CreateFacilityPage> createState() => _CreateFacilityPageState();
}

class _CreateFacilityPageState extends State<CreateFacilityPage> {
  final _formKey = GlobalKey<FormState>();
  final FacilityService _facilityService = FacilityService();
  final ImagePicker _picker = ImagePicker();

  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _imageUrlController;
  late final TextEditingController _locationController;
  late final TextEditingController _capacityController;
  late final TextEditingController _slotDurationController;
  late final TextEditingController _maxDurationController;

  String _bookingMode = 'instant';
  bool _isActive = true;
  bool _purposeRequired = false;
  bool _isShared = false;
  bool _isSaving = false;

  TimeOfDay? _openTime;
  TimeOfDay? _closeTime;
  File? _selectedImageFile;

  @override
  void initState() {
    super.initState();

    final facility = widget.facility;

    _nameController = TextEditingController(text: facility?.name ?? '');
    _descriptionController =
        TextEditingController(text: facility?.description ?? '');
    _imageUrlController =
        TextEditingController(text: facility?.imageUrl ?? '');
    _locationController =
        TextEditingController(text: facility?.location ?? '');
    _capacityController = TextEditingController(
      text: facility != null ? facility.capacity.toString() : '1',
    );
    _slotDurationController = TextEditingController(
      text: facility != null
          ? facility.slotDurationMinutes.toString()
          : '60',
    );
    _maxDurationController = TextEditingController(
      text: facility?.maxDurationMinutes?.toString() ?? '',
    );

    _bookingMode = facility?.bookingMode ?? 'instant';
    _isActive = facility?.isActive ?? true;
    _purposeRequired = facility?.purposeRequired ?? false;
    _isShared = facility?.isShared ?? false;

    _openTime = _parseTime(facility?.openTime);
    _closeTime = _parseTime(facility?.closeTime);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _imageUrlController.dispose();
    _locationController.dispose();
    _capacityController.dispose();
    _slotDurationController.dispose();
    _maxDurationController.dispose();
    super.dispose();
  }

  TimeOfDay? _parseTime(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;

    final parts = raw.split(':');
    if (parts.length < 2) return null;

    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);

    if (hour == null || minute == null) return null;

    return TimeOfDay(hour: hour, minute: minute);
  }

  String _formatToDbTime(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute:00';
  }

  String _formatDisplayTime(TimeOfDay? time) {
    if (time == null) return 'Select time';

    final period = time.hour >= 12 ? 'PM' : 'AM';
    final hour12 = time.hour % 12 == 0 ? 12 : time.hour % 12;
    final minute = time.minute.toString().padLeft(2, '0');

    return '$hour12:$minute $period';
  }

  int _timeToMinutes(TimeOfDay time) {
    return (time.hour * 60) + time.minute;
  }

  Future<void> _pickTime(bool isOpen) async {
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: isOpen
          ? (_openTime ?? const TimeOfDay(hour: 8, minute: 0))
          : (_closeTime ?? const TimeOfDay(hour: 22, minute: 0)),
    );

    if (pickedTime == null) return;

    setState(() {
      if (isOpen) {
        _openTime = pickedTime;
      } else {
        _closeTime = pickedTime;
      }
    });
  }

  Future<void> _pickImage(ImageSource source) async {
    final pickedFile = await _picker.pickImage(
      source: source,
      imageQuality: 75,
    );

    if (pickedFile == null) return;

    setState(() {
      _selectedImageFile = File(pickedFile.path);
    });
  }

  Future<void> _showImageSourceSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Take photo'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Choose from gallery'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _clearImage() {
    setState(() {
      _selectedImageFile = null;
      _imageUrlController.clear();
    });
  }

  void _resetCreateForm() {
    _nameController.clear();
    _descriptionController.clear();
    _imageUrlController.clear();
    _locationController.clear();
    _capacityController.text = '1';
    _slotDurationController.text = '60';
    _maxDurationController.clear();

    setState(() {
      _bookingMode = 'instant';
      _isActive = true;
      _purposeRequired = false;
      _isShared = false;
      _openTime = null;
      _closeTime = null;
      _selectedImageFile = null;
    });
  }

  Future<void> _saveFacility() async {
    if (!_formKey.currentState!.validate()) return;

    if (_openTime == null || _closeTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select open time and close time')),
      );
      return;
    }

    if (_timeToMinutes(_closeTime!) <= _timeToMinutes(_openTime!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Close time must be later than open time')),
      );
      return;
    }

    final capacity = int.parse(_capacityController.text.trim());
    final slotDuration = int.parse(_slotDurationController.text.trim());
    final maxDuration = _maxDurationController.text.trim().isEmpty
        ? null
        : int.parse(_maxDurationController.text.trim());

    if (maxDuration != null && maxDuration < slotDuration) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Max duration must be greater than or equal to slot duration',
          ),
        ),
      );
      return;
    }

    try {
      setState(() {
        _isSaving = true;
      });

      var finalImageUrl = _imageUrlController.text.trim();

      if (_selectedImageFile != null) {
        final uploadedUrl =
        await _facilityService.uploadFacilityImage(_selectedImageFile!);

        if (uploadedUrl == null || uploadedUrl.isEmpty) {
          throw Exception('Failed to upload facility image');
        }

        finalImageUrl = uploadedUrl;
      }

      if (widget.isEditMode) {
        await _facilityService.updateFacility(
          id: widget.facility!.id,
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim(),
          imageUrl: finalImageUrl,
          location: _locationController.text.trim(),
          capacity: capacity,
          openTime: _formatToDbTime(_openTime!),
          closeTime: _formatToDbTime(_closeTime!),
          bookingMode: _bookingMode,
          isActive: _isActive,
          slotDurationMinutes: slotDuration,
          maxDurationMinutes: maxDuration,
          purposeRequired: _purposeRequired,
          isShared: _isShared,
        );

        if (!mounted) return;
        Navigator.pop(context, true);
      } else {
        await _facilityService.createFacility(
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim(),
          imageUrl: finalImageUrl,
          location: _locationController.text.trim(),
          capacity: capacity,
          openTime: _formatToDbTime(_openTime!),
          closeTime: _formatToDbTime(_closeTime!),
          bookingMode: _bookingMode,
          isActive: _isActive,
          slotDurationMinutes: slotDuration,
          maxDurationMinutes: maxDuration,
          purposeRequired: _purposeRequired,
          isShared: _isShared,
        );

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Facility created successfully')),
        );
        _resetCreateForm();
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save facility: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Widget _buildTimeField({
    required String label,
    required TimeOfDay? value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          suffixIcon: const Icon(Icons.access_time_outlined),
        ),
        child: Text(
          _formatDisplayTime(value),
          style: TextStyle(
            color: value == null ? Colors.grey.shade600 : Colors.black87,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildImageSection() {
    final existingImageUrl = _imageUrlController.text.trim();

    Widget previewChild;

    if (_selectedImageFile != null) {
      previewChild = ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.file(
          _selectedImageFile!,
          fit: BoxFit.cover,
          width: double.infinity,
        ),
      );
    } else if (existingImageUrl.isNotEmpty) {
      previewChild = ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.network(
          existingImageUrl,
          fit: BoxFit.cover,
          width: double.infinity,
          errorBuilder: (context, error, stackTrace) {
            return _buildImagePlaceholder();
          },
        ),
      );
    } else {
      previewChild = _buildImagePlaceholder();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Facility Image',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        Container(
          height: 180,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: previewChild,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _showImageSourceSheet,
                icon: const Icon(Icons.add_a_photo_outlined),
                label: const Text('Camera / Gallery'),
              ),
            ),
            const SizedBox(width: 10),
            if (_selectedImageFile != null || existingImageUrl.isNotEmpty)
              OutlinedButton.icon(
                onPressed: _clearImage,
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                label: const Text(
                  'Remove',
                  style: TextStyle(color: Colors.red),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.redAccent),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildImagePlaceholder() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.image_outlined,
            size: 40,
            color: Colors.grey,
          ),
          SizedBox(height: 8),
          Text(
            'No image selected',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: Text(widget.isEditMode ? 'Edit Facility' : 'Create Facility'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildImageSection(),
            const SizedBox(height: 12),
            TextFormField(
              controller: _imageUrlController,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Image URL (optional fallback)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Facility Name',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter facility name';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descriptionController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _locationController,
              decoration: const InputDecoration(
                labelText: 'Location',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter location';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _capacityController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Capacity',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      final number = int.tryParse(value ?? '');
                      if (number == null || number <= 0) {
                        return 'Invalid';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _bookingMode,
                    decoration: const InputDecoration(
                      labelText: 'Booking Mode',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'instant',
                        child: Text('Instant'),
                      ),
                      DropdownMenuItem(
                        value: 'approval',
                        child: Text('Approval'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        _bookingMode = value;
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildTimeField(
                    label: 'Open Time',
                    value: _openTime,
                    onTap: () => _pickTime(true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTimeField(
                    label: 'Close Time',
                    value: _closeTime,
                    onTap: () => _pickTime(false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _slotDurationController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Slot Duration (minutes)',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      final number = int.tryParse(value ?? '');
                      if (number == null || number <= 0) {
                        return 'Invalid';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _maxDurationController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Max Duration (optional)',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) return null;
                      final number = int.tryParse(value);
                      if (number == null || number <= 0) {
                        return 'Invalid';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Facility is active'),
              value: _isActive,
              onChanged: (value) {
                setState(() {
                  _isActive = value;
                });
              },
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Purpose required'),
              value: _purposeRequired,
              onChanged: (value) {
                setState(() {
                  _purposeRequired = value;
                });
              },
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Shared facility'),
              subtitle: const Text('Example: gym / swimming pool'),
              value: _isShared,
              onChanged: (value) {
                setState(() {
                  _isShared = value;
                });
              },
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveFacility,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E88E5),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _isSaving
                    ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                )
                    : Text(
                  widget.isEditMode
                      ? 'Update Facility'
                      : 'Create Facility',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}