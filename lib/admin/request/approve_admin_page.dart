import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminApprovePage extends StatefulWidget {
  const AdminApprovePage({super.key});

  @override
  State<AdminApprovePage> createState() => _AdminApprovePageState();
}

class _AdminApprovePageState extends State<AdminApprovePage> {
  final supabase = Supabase.instance.client;

  List requests = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchRequests();
  }

  Future<void> fetchRequests() async {
    final data = await supabase
        .from('requests')
        .select()
        .eq('status', 'pending');

    setState(() {
      requests = data;
      isLoading = false;
    });
  }

  // 🔥 APPROVE FUNCTION
  Future<void> approveRequest(Map request) async {
    try {
      final userId = request['user_id'];

      // 1️⃣ insert into admin_new
      await supabase.from('admin_new').insert({
        'id': userId,
        'full_name': request['title'], // 🔥 暂时用 title
        'email': 'pending@email.com', // 🔥 你可以之后优化
        'role': 'admin',
        'invite_code': 'APPROVED',
      });

      // 2️⃣ update request status
      await supabase
          .from('requests')
          .update({'status': 'approved'})
          .eq('id', request['id']);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Approved successfully")),
      );

      fetchRequests(); // refresh
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }

  Future<void> rejectRequest(Map request) async {
    await supabase
        .from('requests')
        .update({'status': 'rejected'})
        .eq('id', request['id']);

    fetchRequests();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Admin Approvals")),

      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
        itemCount: requests.length,
        itemBuilder: (context, index) {
          final r = requests[index];

          return Card(
            margin: const EdgeInsets.all(10),
            child: ListTile(
              title: Text(r['title'] ?? 'No Title'),
              subtitle: Text(r['description'] ?? ''),

              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.check, color: Colors.green),
                    onPressed: () => approveRequest(r),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.red),
                    onPressed: () => rejectRequest(r),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
