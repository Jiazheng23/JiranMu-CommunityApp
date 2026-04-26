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
  static const Color bgColor = Color(0xFFF5F1ED);
  static const Color primaryColor = Color(0xFF9A4B3C);
  static const Color softYellow = Color(0xFFF0E6B8);
  static const Color textDark = Color(0xFF2B2B2B);
  static const Color cardColor = Colors.white;

  final _formKey = GlobalKey<FormState>();
  final FacilityService _facilityService = FacilityService();
  final ImagePicker _picker = ImagePicker();

  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _imageUrlController;
  late final TextEditingController _locationController;
  late final TextEditingController _capacityController;
  late final TextEditingController _maxDurationController;

  String _bookingType = 'exclusive';
  String _usageType = 'facility';

  bool _isActive = true;
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
    _imageUrlController = TextEditingController(text: facility?.imageUrl ?? '');
    _locationController = TextEditingController(text: facility?.location ?? '');
    _capacityController = TextEditingController(
      text: facility != null ? facility.capacity.toString() : '1',
    );
    _maxDurationController = TextEditingController(
      text: facility?.maxDurationMinutes?.toString() ?? '',
    );

    _bookingType = facility?.bookingType ?? 'exclusive';
    _usageType = facility?.usageType ?? 'facility';
    if (_usageType == 'event') {
      _bookingType = 'exclusive';
    } else {
      _bookingType = facility?.bookingType ?? 'exclusive';
    }
    _isActive = facility?.isActive ?? true;

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

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(
        color: Color(0xFF7A6258),
        fontWeight: FontWeight.w500,
      ),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
        borderSide: BorderSide(color: primaryColor, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
      ),
    );
  }

  Future<void> _pickTime(bool isOpen) async {
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: isOpen
          ? (_openTime ?? const TimeOfDay(hour: 8, minute: 0))
          : (_closeTime ?? const TimeOfDay(hour: 22, minute: 0)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: primaryColor,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: textDark,
            ),
          ),
          child: child!,
        );
      },
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
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(
                  Icons.photo_camera_outlined,
                  color: primaryColor,
                ),
                title: const Text(
                  'Take photo',
                  style: TextStyle(
                    color: textDark,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.photo_library_outlined,
                  color: primaryColor,
                ),
                title: const Text(
                  'Choose from gallery',
                  style: TextStyle(
                    color: textDark,
                    fontWeight: FontWeight.w600,
                  ),
                ),
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
    _maxDurationController.clear();

    setState(() {
      _bookingType = 'exclusive';
      _usageType = 'facility';
      _isActive = true;
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
    final maxDuration = _maxDurationController.text.trim().isEmpty
        ? null
        : int.parse(_maxDurationController.text.trim());

    if (_usageType == 'facility' && maxDuration == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maximum duration is required for facilities')),
      );
      return;
    }

    if (maxDuration != null && maxDuration <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maximum duration must be more than 0')),
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
          bookingType: _bookingType,
          usageType: _usageType,
          isActive: _isActive,
          maxDurationMinutes: maxDuration
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
          bookingType: _bookingType,
          usageType: _usageType,
          isActive: _isActive,
          maxDurationMinutes: maxDuration
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
      borderRadius: BorderRadius.circular(16),
      child: InputDecorator(
        decoration: _inputDecoration(label).copyWith(
          suffixIcon: const Icon(
            Icons.access_time_outlined,
            color: primaryColor,
          ),
        ),
        child: Text(
          _formatDisplayTime(value),
          style: TextStyle(
            color: value == null ? Colors.grey.shade600 : textDark,
            fontSize: 15,
            fontWeight: FontWeight.w500,
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
        borderRadius: BorderRadius.circular(18),
        child: Image.file(
          _selectedImageFile!,
          fit: BoxFit.cover,
          width: double.infinity,
        ),
      );
    } else if (existingImageUrl.isNotEmpty) {
      previewChild = ClipRRect(
        borderRadius: BorderRadius.circular(18),
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
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: textDark,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          height: 190,
          width: double.infinity,
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(18),
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
                style: OutlinedButton.styleFrom(
                  foregroundColor: primaryColor,
                  side: const BorderSide(color: primaryColor),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(width: 10),
            if (_selectedImageFile != null || existingImageUrl.isNotEmpty)
              OutlinedButton.icon(
                onPressed: _clearImage,
                icon: const Icon(Icons.delete_outline),
                label: const Text('Remove'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFC67B75),
                  side: const BorderSide(color: Color(0xFFC67B75)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
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
            size: 42,
            color: Color(0xFF9A4B3C),
          ),
          SizedBox(height: 8),
          Text(
            'No image selected',
            style: TextStyle(
              color: Color(0xFF7A6258),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownCard({
    required String label,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF7A6258),
              fontWeight: FontWeight.w600,
            ),
          ),
          child,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEventUsage = _usageType == 'event';

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        automaticallyImplyLeading: widget.isEditMode,
        backgroundColor: bgColor,
        surfaceTintColor: bgColor,
        elevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: primaryColor),
        title: Text(
          widget.isEditMode ? 'Edit Facility' : 'Create Facility',
          style: const TextStyle(
            color: textDark,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            const SizedBox(height: 16),
            _buildImageSection(),
            const SizedBox(height: 12),
            TextFormField(
              controller: _imageUrlController,
              onChanged: (_) => setState(() {}),
              decoration: _inputDecoration('Image URL (optional fallback)'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _nameController,
              decoration: _inputDecoration('Facility Name'),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter facility name';
                }
                if (value.trim().length < 2) {
                  return 'Facility name is too short';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descriptionController,
              maxLines: 3,
              decoration: _inputDecoration('Description'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _locationController,
              decoration: _inputDecoration('Location'),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter location';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _capacityController,
              keyboardType: TextInputType.number,
              decoration: _inputDecoration('Capacity'),
              validator: (value) {
                final parsed = int.tryParse(value?.trim() ?? '');
                if (parsed == null) {
                  return 'Please enter a valid number';
                }
                if (parsed < 1) {
                  return 'Capacity must be at least 1';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _maxDurationController,
              keyboardType: TextInputType.number,
              decoration: _inputDecoration(
                isEventUsage
                    ? 'Maximum Duration (minutes, optional)'
                    : 'Maximum Duration (minutes)',
              ),
              validator: (value) {
                if (isEventUsage) {
                  if (value == null || value.trim().isEmpty) return null;
                  final parsed = int.tryParse(value.trim());
                  if (parsed == null) return 'Please enter a valid number';
                  if (parsed <= 0) return 'Duration must be more than 0';
                  return null;
                } else {
                  if (value == null || value.trim().isEmpty) {
                    return 'Maximum duration is required';
                  }
                  final parsed = int.tryParse(value.trim());
                  if (parsed == null) return 'Please enter a valid number';
                  if (parsed <= 0) return 'Duration must be more than 0';
                  return null;
                }
              },
            ),
            const SizedBox(height: 12),
            _buildDropdownCard(
              label: 'Usage Type',
              child: DropdownButtonFormField<String>(
                value: _usageType,
                decoration: const InputDecoration(border: InputBorder.none),
                items: const [
                  DropdownMenuItem(
                    value: 'facility',
                    child: Text('Facility'),
                  ),
                  DropdownMenuItem(
                    value: 'event',
                    child: Text('Event Venue'),
                  ),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _usageType = value;
                    if (_usageType == 'event') {
                      _bookingType = 'exclusive';
                    }
                  });
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _formKey.currentState?.validate();
                  });
                },
              ),
            ),
            const SizedBox(height: 12),
            _buildDropdownCard(
              label: 'Booking Type',
              child: DropdownButtonFormField<String>(
                value: _bookingType,
                decoration: const InputDecoration(border: InputBorder.none),
                items: const [
                  DropdownMenuItem(value: 'exclusive', child: Text('Exclusive')),
                  DropdownMenuItem(value: 'shared', child: Text('Shared')),
                ],
                onChanged: isEventUsage
                    ? null
                    : (value) {
                  if (value == null) return;
                  setState(() {
                    _bookingType = value;
                  });
                },
              ),
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
            const SizedBox(height: 14),
            Container(
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                children: [
                  SwitchListTile(
                    value: _isActive,
                    activeColor: primaryColor,
                    title: const Text(
                      'Available',
                      style: TextStyle(
                        color: textDark,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _isActive = value;
                      });
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveFacility,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade300,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _isSaving
                    ? const SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: Colors.white,
                  ),
                )
                    : Text(
                  widget.isEditMode ? 'Save Changes' : 'Create Facility',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}