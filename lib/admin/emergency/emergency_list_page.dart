import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../emergency//admin_emergency_page.dart';

class EmergencyListPage extends StatefulWidget {
  const EmergencyListPage({super.key});

  @override
  State<EmergencyListPage> createState() => _EmergencyListPageState();
}

class _EmergencyListPageState extends State<EmergencyListPage> {
  final supabase = Supabase.instance.client;

  List<Map<String, dynamic>> emergencies = [];
  String filter = "all";
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchEmergency();
  }

  Future<void> fetchEmergency() async {
    setState(() {
      isLoading = true;
    });

    try {
      final supabase = Supabase.instance.client;

      final data = await supabase
          .from('emergency')
          .select('*, admin(*)')
          .match(filter == "all" ? {} : {'status': filter}) // 🔥 用 match 代替 eq
          .order('created_at', ascending: false);

      setState(() {
        emergencies = List<Map<String, dynamic>>.from(data);
      });

    } catch (e) {
      print("Fetch error: $e");
    }

    setState(() {
      isLoading = false;
    });
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Emergency List")),

      body: Column(
        children: [
          const SizedBox(height: 10),

          // 🔥 FILTER BUTTONS
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              filterButton("all"),
              filterButton("active"),
              filterButton("solved"),
            ],
          ),

          const SizedBox(height: 10),

          // 🔥 LIST
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : emergencies.isEmpty
                ? const Center(child: Text("No emergency found"))
                : ListView.builder(
              itemCount: emergencies.length,
              itemBuilder: (context, index) {
                final e = emergencies[index];
                final resident = e['admin'];

                // 🔥 防止 join 不到 crash
                if (resident == null) {
                  return const ListTile(
                    title: Text("Missing resident data"),
                  );
                }

                return Card(
                  margin: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),

                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.red[100],
                      child: const Icon(Icons.warning,
                          color: Colors.red),
                    ),

                    title: Text(
                      resident['full_name'] ?? "Unknown",
                      style: const TextStyle(
                          fontWeight: FontWeight.bold),
                    ),

                    subtitle: Text(
                      "Block ${resident['block']} - ${resident['unit_number']}",
                    ),

                    trailing: Column(
                      mainAxisAlignment:
                      MainAxisAlignment.center,
                      children: [
                        Text(
                          e['status'],
                          style: TextStyle(
                            color: e['status'] == 'active'
                                ? Colors.red
                                : Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          e['type'],
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),

                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              AdminEmergencyPage(
                                  emergency: e),
                        ),
                      ).then((_) {
                        // 🔥 回来自动 refresh
                        fetchEmergency();
                      });
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

  // 🔥 FILTER BUTTON
  Widget filterButton(String value) {
    final isSelected = filter == value;

    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor:
        isSelected ? Colors.red : Colors.grey[300],
        foregroundColor:
        isSelected ? Colors.white : Colors.black,
      ),
      onPressed: () {
        setState(() {
          filter = value;
        });
        fetchEmergency();
      },
      child: Text(value.toUpperCase()),
    );
  }
}
