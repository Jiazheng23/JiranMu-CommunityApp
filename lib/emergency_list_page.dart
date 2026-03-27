import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'admin_emergency_page.dart';

class EmergencyListPage extends StatefulWidget {
  const EmergencyListPage({super.key});

  @override
  State<EmergencyListPage> createState() => _EmergencyListPageState();
}

class _EmergencyListPageState extends State<EmergencyListPage> {
  final supabase = Supabase.instance.client;

  List emergencies = [];
  String filter = "all";

  @override
  void initState() {
    super.initState();
    fetchEmergency();
  }

  Future<void> fetchEmergency() async {
    var query = supabase.from('emergency').select('*, profiles(*)');

    if (filter != "all") {
      query = query.eq('status', filter);
    }

    final data = await query;

    setState(() {
      emergencies = data;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Emergency List")),

      body: Column(
        children: [
          // 🔥 filter buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              filterButton("all"),
              filterButton("active"),
              filterButton("solved"),
            ],
          ),

          Expanded(
            child: ListView.builder(
              itemCount: emergencies.length,
              itemBuilder: (context, index) {
                final e = emergencies[index];
                final profiles = e['profiles'];

                if (profiles == null) {
                  return const ListTile(title: Text("Error: Profile data missing"));
                }

                return Card(
                  child: ListTile(
                    title: Text(profiles['full_name']),
                    subtitle: Text(
                        "Block ${profiles['block']} - ${profiles['unit_number']}"),
                    trailing: Text(e['status']),

                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              AdminEmergencyPage(profiles: profiles),
                        ),
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

  Widget filterButton(String value) {
    return ElevatedButton(
      onPressed: () {
        setState(() {
          filter = value;
        });
        fetchEmergency();
      },
      child: Text(value),
    );
  }
}
