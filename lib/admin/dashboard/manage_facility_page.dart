import 'package:assignment/facility/facility_model.dart';
import 'package:assignment/facility/facility_service.dart';
import 'package:flutter/material.dart';
import 'create_facility_page.dart';

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
          facility.bookingMode.toLowerCase().contains(query);
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

  Future<void> _toggleActive(FacilityModel facility, bool newValue) async {
    try {
      await _facilityService.updateFacilityActiveStatus(
        id: facility.id,
        isActive: newValue,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            newValue
                ? '${facility.name} activated'
                : '${facility.name} deactivated',
          ),
        ),
      );

      _reloadFacilities();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update facility: $e')),
      );
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
        child: const Icon(
          Icons.apartment_rounded,
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
                _buildInfoChip(Icons.people_outline, '${facility.capacity} pax'),
                _buildInfoChip(
                  Icons.calendar_view_day_outlined,
                  facility.bookingMode == 'instant' ? 'Instant' : 'Approval',
                ),
                _buildInfoChip(
                  Icons.access_time_outlined,
                  '${facility.openTime} - ${facility.closeTime}',
                ),
                if (facility.isShared)
                  _buildInfoChip(Icons.groups_2_outlined, 'Shared'),
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
                    hintText: 'Search facility...',
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
