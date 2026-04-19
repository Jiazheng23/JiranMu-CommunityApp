import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class AdminQRScannerScreen extends StatefulWidget {
  const AdminQRScannerScreen({super.key});

  @override
  State<AdminQRScannerScreen> createState() => _AdminQRScannerScreenState();
}

class _AdminQRScannerScreenState extends State<AdminQRScannerScreen>
    with WidgetsBindingObserver {
  final _client = Supabase.instance.client;

  late final MobileScannerController _controller;
  StreamSubscription<Object?>? _subscription;

  bool _processing = false;
  bool _torchOn = false;
  Map<String, dynamic>? _result;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _controller = MobileScannerController(
      autoStart: false,
      detectionSpeed: DetectionSpeed.noDuplicates,
      facing: CameraFacing.back,
      formats: [BarcodeFormat.qrCode],
    );

    _subscription = _controller.barcodes.listen(_handleBarcode);
    unawaited(_controller.start());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_controller.value.hasCameraPermission) return;

    switch (state) {
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        return;
      case AppLifecycleState.resumed:
        _subscription = _controller.barcodes.listen(_handleBarcode);
        unawaited(_controller.start());
      case AppLifecycleState.inactive:
        unawaited(_subscription?.cancel());
        _subscription = null;
        unawaited(_controller.stop());
    }
  }

  @override
  Future<void> dispose() async {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_subscription?.cancel());
    _subscription = null;
    super.dispose();
    await _controller.dispose();
  }

  void _handleBarcode(Object? event) {
    if (_processing || _result != null || _error != null) return;
    if (event is! BarcodeCapture) return;

    final raw = event.barcodes.firstOrNull?.rawValue;
    if (raw == null || raw.isEmpty) return;

    unawaited(_controller.stop());
    unawaited(_subscription?.cancel());
    _subscription = null;

    _validatePass(raw);
  }

  Future<void> _validatePass(String qrToken) async {
    setState(() {
      _processing = true;
      _result = null;
      _error = null;
    });

    try {
      final res = await _client
          .from('visitor_passes')
          .select('*, events(title)')
          .eq('qr_token', qrToken)
          .single();

      final pass = Map<String, dynamic>.from(res);

      if (pass['status'] == 'used') {
        setState(() => _error = 'This pass has already been used.');
        return;
      }
      if (pass['status'] != 'approved') {
        setState(() =>
        _error = 'Pass not approved (status: ${pass['status']}).');
        return;
      }

      final validDate = DateTime.parse(pass['valid_date']);
      final today = DateTime.now();
      final isToday = validDate.year == today.year &&
          validDate.month == today.month &&
          validDate.day == today.day;

      if (!isToday) {
        setState(() => _error =
        'Pass not valid today.\nValid on: ${DateFormat('d MMM yyyy').format(validDate)}');
        return;
      }

      await _client
          .from('visitor_passes')
          .update({
        'status': 'used',
        'used_at': DateTime.now().toIso8601String(),
      })
          .eq('id', pass['id']);

      setState(() => _result = pass);
    } catch (_) {
      setState(() => _error = 'Invalid or unrecognised QR code.');
    } finally {
      setState(() => _processing = false);
    }
  }

  Future<void> _reset() async {
    setState(() {
      _result = null;
      _error = null;
      _processing = false;
    });
    _subscription = _controller.barcodes.listen(_handleBarcode);
    unawaited(_controller.start());
  }

  Future<void> _toggleTorch() async {
    await _controller.toggleTorch();
    setState(() => _torchOn = !_torchOn);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Scan Visitor Pass'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(_torchOn ? Icons.flash_on : Icons.flash_off),
            color: _torchOn ? Colors.yellow : Colors.white,
            onPressed: _toggleTorch,
          ),
        ],
      ),
      body: Stack(
        children: [
          // Camera feed
          MobileScanner(controller: _controller),

          // Dimmed overlay with cutout frame
          _buildOverlay(),

          // Processing spinner
          if (_processing)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),

          // Result / error sheet
          if (_result != null || _error != null)
            _buildResultSheet(),
        ],
      ),
    );
  }

  Widget _buildOverlay() {
    return LayoutBuilder(builder: (context, constraints) {
      const cutout = 240.0;
      final cx = constraints.maxWidth / 2;
      final cy = constraints.maxHeight / 2;
      final l = cx - cutout / 2;
      final t = cy - cutout / 2;

      return Stack(children: [
        // Four dark panels around the cutout
        Positioned(top: 0, left: 0, right: 0, height: t,
            child: Container(color: Colors.black54)),
        Positioned(top: t + cutout, left: 0, right: 0, bottom: 0,
            child: Container(color: Colors.black54)),
        Positioned(top: t, left: 0, width: l, height: cutout,
            child: Container(color: Colors.black54)),
        Positioned(top: t, left: l + cutout, right: 0, height: cutout,
            child: Container(color: Colors.black54)),

        // White bordered frame
        Positioned(
          top: t,
          left: l,
          child: Container(
            width: cutout,
            height: cutout,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white, width: 2.5),
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),

        // Hint label below the frame
        Positioned(
          top: t + cutout + 20,
          left: 0,
          right: 0,
          child: const Text(
            'Align the visitor pass QR code within the frame',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ),
      ]);
    });
  }

  Widget _buildResultSheet() {
    final success = _result != null;
    final pass = _result;

    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: success ? Colors.green.shade50 : Colors.red.shade50,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: success ? Colors.green.shade400 : Colors.red.shade400,
            width: 1.5,
          ),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(
            success ? Icons.check_circle_rounded : Icons.cancel_rounded,
            color: success ? Colors.green.shade700 : Colors.red.shade700,
            size: 52,
          ),
          const SizedBox(height: 10),
          Text(
            success ? 'Entry Approved' : 'Entry Denied',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: success ? Colors.green.shade800 : Colors.red.shade800,
            ),
          ),
          const SizedBox(height: 10),
          if (success && pass != null) ...[
            _infoRow(Icons.person_outline, pass['visitor_name']),
            if (pass['visitor_ic'] != null)
              _infoRow(Icons.badge_outlined, pass['visitor_ic']),
            if (pass['events'] != null)
              _infoRow(Icons.event_outlined, pass['events']['title']),
            _infoRow(
              Icons.calendar_today_outlined,
              DateFormat('d MMM yyyy')
                  .format(DateTime.parse(pass['valid_date'])),
            ),
          ],
          if (!success)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                _error ?? '',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.red.shade700, fontSize: 14),
              ),
            ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _reset,
              style: ElevatedButton.styleFrom(
                backgroundColor:
                success ? Colors.green.shade700 : Colors.red.shade700,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Scan Next Pass', style: TextStyle(fontSize: 15)),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(icon, size: 16, color: Colors.black54),
      const SizedBox(width: 6),
      Flexible(
        child: Text(text,
            style: const TextStyle(fontSize: 14, color: Colors.black87)),
      ),
    ]),
  );
}