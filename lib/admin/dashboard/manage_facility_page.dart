import 'package:assignment/facility/facility_model.dart';
import 'package:assignment/facility/facility_service.dart';
import 'package:flutter/material.dart';
import 'create_facility_page.dart';
import 'facility_unavailable_slots_page.dart';

class ManageFacilityPage extends StatefulWidget {
  const ManageFacilityPage({super.key});

  @override
  State<ManageFacilityPage> createState() => _ManageFacilityPageState();
}

class _ManageFacilityPageState extends State<ManageFacilityPage> {
  static const Color bgColor = Color(0xFFF5F1ED);
  static const Color primaryColor = Color(0xFF9A4B3C);
  static const Color softYellow = Color(0xFFF0E6B8);
  static const Color textDark = Color(0xFF2B2B2B);
  static const Color cardColor = Colors.white;

  final FacilityService _facilityService = FacilityService();
  final TextEditingController _searchController = TextEditingController();

  late Future<List<FacilityModel>> _facilitiesFuture;
  String _searchText = '';

  @override
  void initState() {
    super.initState();
    _reloadFacilities();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _reloadFacilities() {
    setState(() {
      _facilitiesFuture = _facilityService.fetchAllFacilities();
    });
  }

  List<FacilityModel> _filterFacilities(List<FacilityModel> facilities) {
    if (_searchText.trim().isEmpty) return facilities;

    final query = _searchText.toLowerCase().trim();

    return facilities.where((facility) {
      return facility.name.toLowerCase().contains(query) ||
          facility.location.toLowerCase().contains(query) ||
          facility.bookingType.toLowerCase().contains(query) ||
          facility.usageType.toLowerCase().contains(query);
    }).toList();
  }

  Future<void> _openEditPage(FacilityModel facility) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreateFacilityPage(facility: facility),
      ),
    );

    if (result == true && mounted) {
      _reloadFacilities();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Facility updated successfully')),
      );
    }
  }

  Future<void> _openUnavailableSlotsPage(FacilityModel facility) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => FacilityUnavailableSlotsPage(facility: facility),
      ),
    );

    if (result == true && mounted) {
      _reloadFacilities();
    }
  }

  Future<void> _toggleActive(FacilityModel facility, bool newValue) async {
    try {
      if (newValue == facility.isActive) return;

      if (newValue) {
        await _facilityService.updateFacilityActiveStatus(
          id: facility.id,
          isActive: true,
        );

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${facility.name} is now available')),
        );
        _reloadFacilities();
        return;
      }

      final upcomingCount =
      await _facilityService.fetchUpcomingApprovedBookingCount(facility.id);

      if (!mounted) return;

      if (upcomingCount == 0) {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Mark as unavailable?'),
            content: Text(
              'This will stop new resident bookings for ${facility.name}.',
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
                child: const Text('Confirm'),
              ),
            ],
          ),
        );

        if (confirm == true) {
          await _facilityService.updateFacilityActiveStatus(
            id: facility.id,
            isActive: false,
          );

          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${facility.name} is now unavailable')),
          );
        }

        _reloadFacilities();
        return;
      }

      final reasonController = TextEditingController();
      String? errorText;

      final confirmed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                title: const Text('Cancel bookings and mark unavailable?'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${facility.name} has $upcomingCount upcoming approved booking(s).',
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'To continue, enter a reason. The upcoming bookings will be cancelled and residents can see the reason in booking history.',
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: reasonController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: 'Cancellation reason',
                        errorText: errorText,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext, false),
                    child: const Text('Back'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      if (reasonController.text.trim().isEmpty) {
                        setDialogState(() {
                          errorText = 'Please enter a reason';
                        });
                        return;
                      }
                      Navigator.pop(dialogContext, true);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Cancel & Confirm'),
                  ),
                ],
              );
            },
          );
        },
      );

      if (confirmed == true) {
        await _facilityService.deactivateFacilityAndCancelUpcomingBookings(
          facilityId: facility.id,
          reason: reasonController.text.trim(),
        );

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${facility.name} is now unavailable and upcoming bookings were cancelled.',
            ),
          ),
        );
      }

      reasonController.dispose();
      _reloadFacilities();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update facility: $e')),
      );
      _reloadFacilities();
    }
  }

  Widget _buildInfoChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: softYellow.withOpacity(0.45),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: primaryColor),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              fontSize: 12,
              color: textDark,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFacilityImage(FacilityModel facility) {
    if (facility.imageUrl.isEmpty) {
      return Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: softYellow.withOpacity(0.45),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(
          facility.usageType == 'event'
              ? Icons.location_city_rounded
              : Icons.apartment_rounded,
          color: primaryColor,
          size: 30,
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Image.network(
        facility.imageUrl,
        width: 72,
        height: 72,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: softYellow.withOpacity(0.45),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.broken_image_outlined,
              color: primaryColor,
            ),
          );
        },
      ),
    );
  }

  Widget _buildFacilityCard(FacilityModel facility) {
    final isVenue = facility.usageType == 'event';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildFacilityImage(facility),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        facility.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: textDark,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        facility.location,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: facility.isActive
                        ? const Color(0xFFE9F5EC)
                        : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    facility.isActive ? 'Active' : 'Inactive',
                    style: TextStyle(
                      color: facility.isActive
                          ? const Color(0xFF4E8A62)
                          : Colors.grey.shade700,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildInfoChip(
                  isVenue
                      ? Icons.location_city_outlined
                      : Icons.home_work_outlined,
                  isVenue ? 'Event' : 'Facility',
                ),
                _buildInfoChip(Icons.people_outline, '${facility.capacity} pax'),
                _buildInfoChip(
                  Icons.calendar_view_day_outlined,
                  facility.bookingType == 'exclusive' ? 'Exclusive' : 'Shared',
                ),
                _buildInfoChip(
                  Icons.access_time_outlined,
                  '${facility.openTime} - ${facility.closeTime}',
                ),
              ],
            ),
            if (facility.description.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                facility.description,
                style: TextStyle(
                  color: Colors.grey.shade700,
                  height: 1.4,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _openEditPage(facility),
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Edit'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: primaryColor,
                      side: const BorderSide(color: primaryColor),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _openUnavailableSlotsPage(facility),
                    icon: const Icon(Icons.block_flipped),
                    label: const Text('Slots'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: textDark,
                      side: BorderSide(color: Colors.grey.shade400),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: softYellow.withOpacity(0.28),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Available',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: textDark,
                      ),
                    ),
                  ),
                  Switch(
                    activeColor: primaryColor,
                    value: facility.isActive,
                    onChanged: (value) => _toggleActive(facility, value),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: textDark),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        automaticallyImplyLeading: false,
        backgroundColor: bgColor,
        surfaceTintColor: bgColor,
        elevation: 0,
        centerTitle: false,
        title: const Text(
          'Manage Facility',
          style: TextStyle(
            color: textDark,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
            child: Column(
              children: [
                const SizedBox(height: 12),
                TextField(
                  controller: _searchController,
                  onChanged: (value) {
                    setState(() {
                      _searchText = value;
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'Search facility / event...',
                    hintStyle: TextStyle(color: Colors.grey.shade600),
                    prefixIcon: const Icon(Icons.search, color: primaryColor),
                    suffixIcon: _searchText.isEmpty
                        ? null
                        : IconButton(
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _searchText = '';
                        });
                      },
                      icon: const Icon(Icons.close, color: primaryColor),
                    ),
                    filled: true,
                    fillColor: Colors.white,
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
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<FacilityModel>>(
              future: _facilitiesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: primaryColor),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Failed to load facilities: ${snapshot.error}',
                      style: const TextStyle(color: textDark),
                    ),
                  );
                }

                final facilities = _filterFacilities(snapshot.data ?? []);

                if (facilities.isEmpty) {
                  return const Center(
                    child: Text(
                      'No facilities found.',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: textDark,
                      ),
                    ),
                  );
                }

                return RefreshIndicator(
                  color: primaryColor,
                  onRefresh: () async {
                    _reloadFacilities();
                    await _facilitiesFuture;
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                    itemCount: facilities.length,
                    itemBuilder: (context, index) {
                      return _buildFacilityCard(facilities[index]);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}