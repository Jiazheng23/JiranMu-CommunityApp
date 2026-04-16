import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class AdminEmergencyPage extends StatefulWidget {
  final Map<String, dynamic> emergency;

  const AdminEmergencyPage({super.key, required this.emergency});

  @override
  State<AdminEmergencyPage> createState() => _AdminEmergencyPageState();
}

class _AdminEmergencyPageState extends State<AdminEmergencyPage> {
  final supabase = Supabase.instance.client;

  late double lat;
  late double lng;

  GoogleMapController? mapController;

  @override
  void initState() {
    super.initState();

    lat = (widget.emergency['latitude'] ?? 0).toDouble();
    lng = (widget.emergency['longitude'] ?? 0).toDouble();

    subscribeRealtime();
  }

  // 🔥 REALTIME SUPABASE SUBSCRIPTION
  void subscribeRealtime() {
    supabase
        .channel('emergency-updates')
        .onPostgresChanges(
      event: PostgresChangeEvent.update,
      schema: 'public',
      table: 'emergency',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'emergency_id',
        value: widget.emergency['emergency_id'].toString(),
      ),
      callback: (payload) {
        final newData = payload.newRecord;

        setState(() {
          lat = (newData['latitude'] ?? lat).toDouble();
          lng = (newData['longitude'] ?? lng).toDouble();
        });

        mapController?.animateCamera(
          CameraUpdate.newLatLng(LatLng(lat, lng)),
        );
      },
    )
        .subscribe();
  }

  @override
  void dispose() {
    supabase.removeAllChannels();
    super.dispose();
  }

  // 📞 PHONE CALL FUNCTION
  Future<void> _makePhoneCall(String? phoneNumber) async {
    if (phoneNumber == null || phoneNumber.isEmpty) return;
    final Uri url = Uri.parse("tel:$phoneNumber");
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  // ✅ MARK AS SOLVED FUNCTION
  Future<void> markSolved() async {
    await supabase
        .from('emergency')
        .update({'status': 'solved'}).eq('emergency_id', widget.emergency['emergency_id']);

    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Extract resident data safely, falling back to an empty map if null
    final resident = widget.emergency['admin'] ?? {};

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          "Emergency Response",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.red[700],
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Stack(
        children: [
          // 🔥 GOOGLE MAP BACKGROUND
          Positioned.fill(
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: LatLng(lat, lng),
                zoom: 16,
              ),
              onMapCreated: (controller) {
                mapController = controller;
              },
              markers: {
                Marker(
                  markerId: const MarkerId("emergency_location"),
                  position: LatLng(lat, lng),
                  icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
                ),
              },
            ),
          ),

          // 🔥 DRAGGABLE BOTTOM SHEET (BEAUTIFUL UI)
          DraggableScrollableSheet(
            initialChildSize: 0.6,
            minChildSize: 0.15,
            maxChildSize: 0.85,
            builder: (context, scrollController) {
              return Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(30),
                  ),
                  boxShadow: [
                    BoxShadow(color: Colors.black26, blurRadius: 10, spreadRadius: 2),
                  ],
                ),
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                  children: [
                    // DRAG HANDLE
                    Center(
                      child: Container(
                        width: 50,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      "Resident Information",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // 👤 RESIDENT ID CARD
                    Container(
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          radius: 30,
                          backgroundColor: Colors.red[100],
                          child: const Icon(
                            Icons.person,
                            size: 35,
                            color: Colors.red,
                          ),
                        ),
                        title: Text(
                          "${resident['full_name'] ?? 'Unknown'} ${resident['Age'] != null || resident['age'] != null ? '(${resident['Age'] ?? resident['age']})' : ''}",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        subtitle: Text(
                          "Unit: ${resident['block'] ?? '-'}-${resident['unit_number'] ?? '-'}",
                        ),
                        trailing: IconButton.filled(
                          onPressed: () => _makePhoneCall(
                            resident['phone_number']?.toString(),
                          ),
                          icon: const Icon(Icons.phone),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.green,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // 🔥 STATS GRID
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 15,
                      mainAxisSpacing: 15,
                      childAspectRatio: 1.5,
                      children: [
                        _infoTile(
                          "Blood Type",
                          "${resident['Blood'] ?? resident['blood'] ?? 'N/A'}",
                          Icons.bloodtype,
                          Colors.red,
                        ),
                        _infoTile(
                          "Weight",
                          "${resident['Weight'] ?? resident['weight'] ?? '-'} kg",
                          Icons.monitor_weight,
                          Colors.blue,
                        ),
                        _infoTile(
                          "Height",
                          "${resident['Height'] ?? resident['height'] ?? '-'} cm",
                          Icons.height,
                          Colors.purple,
                        ),
                        _infoTile(
                          "Type",
                          "${widget.emergency['type'] ?? 'Emergency'}",
                          Icons.warning,
                          Colors.orange,
                        ),
                      ],
                    ),

                    const SizedBox(height: 30),

                    // 🛠 ACTION BUTTONS
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              // Add Evidence Logic Here
                            },
                            icon: const Icon(Icons.camera_alt),
                            label: const Text("Evidence"),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 15),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: markSolved,
                            icon: const Icon(Icons.check),
                            label: const Text("Mark Solved"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 15),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // 🎨 CUSTOM INFO TILE WIDGET
  Widget _infoTile(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey[200]!),
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.05),
            blurRadius: 5,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}