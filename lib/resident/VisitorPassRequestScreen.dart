import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class VisitorPassRequestScreen extends StatefulWidget {
  const VisitorPassRequestScreen({super.key});
  @override
  State<VisitorPassRequestScreen> createState() => _VisitorPassRequestScreenState();
}

class _VisitorPassRequestScreenState extends State<VisitorPassRequestScreen> {
  final _client = Supabase.instance.client;
  final _nameCtrl = TextEditingController();
  final _icCtrl = TextEditingController();
  String _purpose = 'event';
  DateTime _validDate = DateTime.now().add(const Duration(days: 1));
  List<Map<String, dynamic>> _events = [];
  String? _selectedEventId;
  bool _loading = false;

  final Color primary = const Color(0xFF9A4B3C);

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    final res = await _client
        .from('events')
        .select('id, title, event_date')
        .gte('event_date', DateTime.now().toIso8601String())
        .order('event_date');
    setState(() => _events = List<Map<String, dynamic>>.from(res));
  }

  Future<void> _submit() async {
    if (_nameCtrl.text.isEmpty) return;
    setState(() => _loading = true);
    try {
      final userId = _client.auth.currentUser!.id;
      await _client.from('visitor_passes').insert({
        'resident_id': userId,
        'visitor_name': _nameCtrl.text.trim(),
        'visitor_ic': _icCtrl.text.trim(),
        'purpose': _purpose,
        'event_id': _purpose == 'event' ? _selectedEventId : null,
        'valid_date': DateFormat('yyyy-MM-dd').format(_validDate),
        'status': 'pending',
      });
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Visitor pass requested! Await admin approval.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F1ED),
      appBar: AppBar(
        title: const Text('Request Visitor Pass'),
        backgroundColor: const Color(0xFF9A4B3C),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _card(children: [
            const Text('Visitor Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 16),
            _field('Visitor Full Name', _nameCtrl),
            const SizedBox(height: 12),
            _field('IC / Passport Number', _icCtrl),
          ]),
          const SizedBox(height: 16),
          _card(children: [
            const Text('Purpose', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            Row(children: [
              _chip('Event', 'event'),
              const SizedBox(width: 10),
              _chip('Facility', 'facility'),
            ]),
            if (_purpose == 'event') ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _selectedEventId,
                hint: const Text('Select Event'),
                decoration: _inputDeco('Event'),
                items: _events.map((e) => DropdownMenuItem(
                  value: e['id'] as String,
                  child: Text(e['title'] as String),
                )).toList(),
                onChanged: (v) => setState(() => _selectedEventId = v),
              ),
            ],
          ]),
          const SizedBox(height: 16),
          _card(children: [
            const Text('Visit Date', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _validDate,
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 90)),
                );
                if (picked != null) setState(() => _validDate = picked);
              },
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.black26),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(children: [
                  Icon(Icons.calendar_today, color: primary, size: 20),
                  const SizedBox(width: 10),
                  Text(DateFormat('d MMM yyyy').format(_validDate),
                      style: const TextStyle(fontSize: 15)),
                ]),
              ),
            ),
          ]),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _loading ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: _loading
                  ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                  : const Text('Submit Request', style: TextStyle(fontSize: 16)),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _card({required List<Widget> children}) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
  );

  Widget _field(String label, TextEditingController ctrl) => TextFormField(
    controller: ctrl,
    decoration: _inputDeco(label),
  );

  InputDecoration _inputDeco(String label) => InputDecoration(
    labelText: label,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
  );

  Widget _chip(String label, String value) => ChoiceChip(
    label: Text(label),
    selected: _purpose == value,
    onSelected: (_) => setState(() => _purpose = value),
    selectedColor: const Color(0xFF9A4B3C),
    labelStyle: TextStyle(color: _purpose == value ? Colors.white : Colors.black87),
  );
}