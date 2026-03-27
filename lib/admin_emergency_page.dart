import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class AdminEmergencyPage extends StatelessWidget {
  final Map<String, dynamic> profiles;
  final supabase = Supabase.instance.client;

  AdminEmergencyPage({super.key, required this.profiles});

  // Test Function: Fetch the latest data for this specific resident
  Future<Map<String, dynamic>> fetchResidentData() async {
    try {
      final data = await supabase
          .from('profiles')
          .select('*, emergency(*)')
          .eq('id', profiles['id']) // Uses the ID passed from the previous page
          .single();
      return data;
    } catch (e) {
      // Fallback to the passed profile if the fetch fails
      debugPrint("Error fetching resident: $e");
      return profiles;
    }
  }

  Future<void> _makePhoneCall(String? phoneNumber) async {
    if (phoneNumber == null || phoneNumber.isEmpty) return;
    final Uri url = Uri.parse("tel:$phoneNumber");
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Emergency Response"),
        backgroundColor: Colors.red[700],
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: fetchResidentData(), // Testing the Supabase collection here
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.red),
            );
          }

          final resident = snapshot.data ?? profiles;
          final emergencyList = resident['emergency'];
          final emergency = emergencyList[0];

          return Stack(
            children: [
              // Background "Map" Area
              Container(
                color: Colors.grey[200],
                width: double.infinity,
                height: MediaQuery.of(context).size.height * 0.4,
                child: const Icon(
                  Icons.map_outlined,
                  size: 100,
                  color: Colors.grey,
                ),
              ),

              // Draggable Sheet for Information
              DraggableScrollableSheet(
                initialChildSize: 0.6,
                minChildSize: 0.05,
                maxChildSize: 0.75,
                builder: (context, scrollController) {
                  return Container(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(30),
                      ),
                      boxShadow: [
                        BoxShadow(color: Colors.black26, blurRadius: 10),
                      ],
                    ),
                    child: ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                      children: [
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

                        // Resident ID Card
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
                              "${resident['full_name'] ?? 'Unknown'} (${resident['Age'] ?? 'N/A'})",
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                            subtitle: Text(
                              "Unit: ${resident['block']}-${resident['unit_number']}",
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

                        // Stats Grid
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
                              "${resident['Blood'] ?? 'N/A'}",
                              Icons.bloodtype,
                              Colors.red,
                            ),
                            _infoTile(
                              "Weight",
                              "${resident['Weight'] ?? '-'} kg",
                              Icons.monitor_weight,
                              Colors.blue,
                            ),
                            _infoTile(
                              "Height",
                              "${resident['Height'] ?? '-'} cm",
                              Icons.height,
                              Colors.purple,
                            ),
                            _infoTile(
                              "Type",
                              "${emergency?['type'] ?? 'Emergency'} ",
                              Icons.warning,
                              Colors.orange,
                            ),
                          ],
                        ),

                        const SizedBox(height: 20),

                        // Action Buttons
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () {},
                                icon: const Icon(Icons.camera_alt),
                                label: const Text("Evidence"),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 15,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 20),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => Navigator.pop(context),
                                icon: const Icon(Icons.check),
                                label: const Text("Mark Solved"),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 15,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 50),
                      ],
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _infoTile(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[200]!),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(title, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ],
      ),
    );
  }
}
