import 'package:assignment/facility/facility_model.dart';
import 'package:assignment/facility/facility_service.dart';
import 'package:assignment/facility/facility_booking_sheet.dart';
import 'package:assignment/facility/facility_card.dart';
import 'package:flutter/material.dart';

class FacilityBookingPage extends StatefulWidget {
  final bool showBackButton;

  const FacilityBookingPage({
    super.key,
    this.showBackButton = true,
  });

  @override
  State<FacilityBookingPage> createState() => _FacilityBookingPageState();
}

class _FacilityBookingPageState extends State<FacilityBookingPage> {
  final FacilityService _facilityService = FacilityService();
  final TextEditingController _searchController = TextEditingController();

  String _searchText = '';
  late Future<List<FacilityModel>> _facilitiesFuture;

  @override
  void initState() {
    super.initState();
    _facilitiesFuture = _facilityService.fetchFacilities();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _reloadFacilities() {
    setState(() {
      _facilitiesFuture = _facilityService.fetchFacilities();
    });
  }

  List<FacilityModel> _filterFacilities(List<FacilityModel> facilities) {
    if (_searchText.trim().isEmpty) {
      return facilities;
    }

    final query = _searchText.trim().toLowerCase();

    return facilities.where((facility) {
      return facility.name.toLowerCase().contains(query) ||
          facility.description.toLowerCase().contains(query) ||
          facility.location.toLowerCase().contains(query) ||
          facility.bookingMode.toLowerCase().contains(query);
    }).toList();
  }

  Future<void> _openBookingSheet(FacilityModel facility) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FacilityBookingSheet(facility: facility),
    );

    if (result == true && mounted) {
      final message = facility.isInstantBooking
          ? 'Booking submitted successfully.'
          : 'Request submitted successfully. Waiting for admin approval.';

      Future.delayed(const Duration(milliseconds: 250), () {
        if (!mounted) return;

        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(message),
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 90),
            ),
          );
      });

      _reloadFacilities();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F1ED),
      appBar: AppBar(
        automaticallyImplyLeading: widget.showBackButton,
        backgroundColor: const Color(0xFFF5F1ED),
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: const Color(0xFF2B2B2B),
        title: const Text(
          'Facility Booking',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: Color(0xFF2B2B2B),
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() {
                  _searchText = value;
                });
              },
              decoration: InputDecoration(
                hintText: 'Search facility...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<FacilityModel>>(
              future: _facilitiesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            size: 44,
                            color: Colors.redAccent,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Failed to load facilities\n${snapshot.error}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.black54,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _reloadFacilities,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF9A4B3C),
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final facilities = snapshot.data ?? [];
                final filteredFacilities = _filterFacilities(facilities);

                if (filteredFacilities.isEmpty) {
                  return const Center(
                    child: Text(
                      'No facilities found.',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.black54,
                      ),
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    _reloadFacilities();
                    await _facilitiesFuture;
                  },
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    itemCount: filteredFacilities.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      final facility = filteredFacilities[index];

                      return FacilityCard(
                        facility: facility,
                        onTap: () => _openBookingSheet(facility),
                      );
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