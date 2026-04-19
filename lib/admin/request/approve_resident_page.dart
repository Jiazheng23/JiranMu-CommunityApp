import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ApproveResidentPage extends StatefulWidget {
  const ApproveResidentPage({super.key});

  @override
  State<ApproveResidentPage> createState() => _ApproveResidentPageState();
}

class _ApproveResidentPageState extends State<ApproveResidentPage> {
  final supabase = Supabase.instance.client;

  List residents = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchResidents();
  }

  Future<void> fetchResidents() async {
    try {
      final data = await supabase
          .from('profiles')
          .select()
          .eq('role', 'resident')
          .eq('status', 'pending');

      setState(() {
        residents = data;
        isLoading = false;
      });
    } catch (e) {
      print("Error fetching residents: $e");
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> updateStatus(String id, String newStatus) async {
    try {
      await supabase
          .from('profiles')
          .update({'status': newStatus}).eq('id', id);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Resident $newStatus")),
      );

      fetchResidents(); // refresh list
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }

  Widget buildResidentCard(Map data) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            data['full_name'] ?? '',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text("Email: ${data['email']}"),
          Text("Phone: ${data['phone_number']}"),
          Text("Block: ${data['block']}"),
          Text("Unit: ${data['unit_number']}"),

          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () =>
                      updateStatus(data['id'], 'approved'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                  ),
                  child: const Text("Approve"),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: () =>
                      updateStatus(data['id'], 'rejected'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                  ),
                  child: const Text("Reject"),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Approve Residents"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : residents.isEmpty
            ? const Center(child: Text("No pending residents"))
            : ListView.builder(
          itemCount: residents.length,
          itemBuilder: (context, index) {
            return buildResidentCard(residents[index]);
          },
        ),
      ),
    );
  }
}