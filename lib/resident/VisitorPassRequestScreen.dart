import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class VisitorPassRequestScreen extends StatefulWidget {
  const VisitorPassRequestScreen({super.key});

  @override
  State<VisitorPassRequestScreen> createState() =>
      _VisitorPassRequestScreenState();
}

class _VisitorPassRequestScreenState
    extends State<VisitorPassRequestScreen> {
  // ── Supabase ──────────────────────────────────────────────────────────────
  final _client = Supabase.instance.client;

  // ── Form controllers ──────────────────────────────────────────────────────
  final _nameCtrl  = TextEditingController();
  final _icCtrl    = TextEditingController();
  final _notesCtrl = TextEditingController();

  // ── Validation error strings (null = no error) ────────────────────────────
  String? _nameError;
  String? _icError;
  String? _notesError;

  // ── Touched flags ─────────────────────────────────────────────────────────
  bool _nameTouched  = false;
  bool _icTouched    = false;
  bool _notesTouched = false;
  bool _dateTouched  = false;

  // ── Form state ────────────────────────────────────────────────────────────
  String?   _purpose;
  DateTime? _validDate;
  bool      _loading = false;

  // ── Theme ─────────────────────────────────────────────────────────────────
  static const Color _primary      = Color(0xFF9A4B3C);
  static const Color _bgPage       = Color(0xFFF5F1ED);
  static const Color _errorColor   = Color(0xFFD32F2F);
  static const Color _successColor = Color(0xFF388E3C);

  static const _purposes = [
    (value: 'visiting',    label: 'Visiting',    icon: Icons.person_outline_rounded),
    (value: 'delivery',    label: 'Delivery',    icon: Icons.local_shipping_outlined),
    (value: 'contractor',  label: 'Contractor',  icon: Icons.build_outlined),
    (value: 'event_guest', label: 'Event Guest', icon: Icons.celebration_outlined),
  ];

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _nameCtrl.addListener(_validateName);
    _icCtrl.addListener(_validateIC);
    _notesCtrl.addListener(_validateNotes);
  }

  @override
  void dispose() {
    _nameCtrl.removeListener(_validateName);
    _icCtrl.removeListener(_validateIC);
    _notesCtrl.removeListener(_validateNotes);
    _nameCtrl.dispose();
    _icCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  // ── Validators ────────────────────────────────────────────────────────────

  // Doc 1's name validation (correct — allows spaces/punctuation)
  void _validateName() {
    if (!_nameTouched) return;
    final val = _nameCtrl.text.trim();
    setState(() {
      if (val.isEmpty) {
        _nameError = 'Visitor name is required.';
      } else if (val.length < 3) {
        _nameError = 'Name must be at least 3 characters.';
      } else if (!RegExp(r"^[a-zA-Z\s'./-]+$").hasMatch(val)) {
        _nameError = 'Name can only contain letters and basic punctuation.';
      } else if (val.length > 80) {
        _nameError = 'Name must not exceed 80 characters.';
      } else {
        _nameError = null;
      }
    });
  }

  // Doc 2's IC validation (stricter, specific error messages per format)
  void _validateIC() {
    if (!_icTouched) return;
    final val = _icCtrl.text.trim().toUpperCase();
    setState(() {
      if (val.isEmpty) {
        _icError = 'IC/Passport number is required.';
      } else if (RegExp(r'^\d{12}$').hasMatch(val)) {
        _icError = null; // MyKad: exactly 12 digits
      } else if (RegExp(r'^[A-Z]\d{8}$').hasMatch(val)) {
        _icError = null; // Passport: 1 letter + 8 digits
      } else if (RegExp(r'^\d+$').hasMatch(val) && val.length != 12) {
        _icError = 'MyKad must be exactly 12 digits (e.g. 901231071234).';
      } else if (RegExp(r'^[A-Z]').hasMatch(val) &&
          !RegExp(r'^[A-Z]\d{8}$').hasMatch(val)) {
        _icError = 'Passport must be 1 letter + 8 digits (e.g. A12345678).';
      } else {
        _icError =
        'Enter a valid MyKad (12 digits) or Passport (e.g. A12345678).';
      }
    });
  }

  void _validateNotes() {
    if (!_notesTouched) return;
    final val = _notesCtrl.text.trim();
    setState(() {
      _notesError = val.length > 200 ? '${val.length}/200 — too long.' : null;
    });
  }

  // Doc 2's stricter _isFormValid (only MyKad or valid Passport accepted)
  bool get _isFormValid {
    final name  = _nameCtrl.text.trim();
    final ic    = _icCtrl.text.trim();
    final notes = _notesCtrl.text.trim();

    final nameOk = name.length >= 3 &&
        name.length <= 80 &&
        RegExp(r"^[a-zA-Z\s'./-]+$").hasMatch(name);

    final icOk = ic.isNotEmpty &&
        (RegExp(r'^\d{12}$').hasMatch(ic) ||
            RegExp(r'^[A-Z]\d{8}$').hasMatch(ic.toUpperCase()));

    final purposeOk = _purpose != null;
    final dateOk    = _validDate != null;
    final notesOk   = notes.length <= 200;

    return nameOk && icOk && purposeOk && dateOk && notesOk;
  }

  // ── Submit ────────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    if (!_isFormValid) return;

    setState(() => _loading = true);
    try {
      final userId = _client.auth.currentUser!.id;
      await _client.from('visitor_passes').insert({
        'resident_id':  userId,
        'visitor_name': _nameCtrl.text.trim(),
        'visitor_ic':   _icCtrl.text.trim().toUpperCase(), // normalise to uppercase
        'purpose':      _purpose,
        'notes':        _notesCtrl.text.trim().isEmpty
            ? null
            : _notesCtrl.text.trim(),
        'valid_date': DateFormat('yyyy-MM-dd').format(_validDate!),
        'status':     'pending',
      });

      if (!mounted) return;
      Navigator.pop(context, true);
      _snack('Visitor pass requested! Awaiting admin approval.');
    } catch (e) {
      _snack('Error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onDisabledTap() {
    setState(() {
      _nameTouched  = true;
      _icTouched    = true;
      _notesTouched = true;
      _dateTouched  = true;
    });
    _validateName();
    _validateIC();
    _validateNotes();
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  // ── Date picker ───────────────────────────────────────────────────────────

  Future<void> _pickDate() async {
    setState(() => _dateTouched = true);
    final picked = await showDatePicker(
      context:     context,
      initialDate: _validDate ?? DateTime.now().add(const Duration(days: 1)),
      firstDate:   DateTime.now().add(const Duration(days: 1)),
      lastDate:    DateTime.now().add(const Duration(days: 30)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary:   _primary,
            onPrimary: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _validDate = picked);
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgPage,
      appBar: AppBar(
        title: const Text(
          'Request Visitor Pass',
          style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.w700, fontSize: 17),
        ),
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        elevation:       0,
        centerTitle:     true,
        leading: IconButton(
          icon:      const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Visitor details ──────────────────────────────────────
            _sectionLabel('Visitor Details'),
            const SizedBox(height: 10),
            _card(children: [
              // Name field — Doc 1 formatters (letters + punctuation, limit 80)
              _validatedField(
                controller: _nameCtrl,
                label:      'Visitor Full Name',
                icon:       Icons.person_outline_rounded,
                required:   true,
                error:      _nameError,
                isValid:    _nameTouched &&
                    _nameError == null &&
                    _nameCtrl.text.trim().isNotEmpty,
                onChanged: (_) {
                  _nameTouched = true;
                  _validateName();
                },
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r"[a-zA-Z\s'./-]")),
                  LengthLimitingTextInputFormatter(80),
                ],
                hint: 'e.g. Ahmad bin Ali',
              ),
              const SizedBox(height: 14),
              // IC field — Doc 1 formatters (alphanumeric, limit 12) +
              //            Doc 2 capitalisation & stricter validation
              _validatedField(
                controller: _icCtrl,
                label:      'IC / Passport Number',
                icon:       Icons.badge_outlined,
                required:   true,
                error:      _icError,
                isValid:    _icTouched &&
                    _icError == null &&
                    _icCtrl.text.trim().isNotEmpty,
                onChanged: (_) {
                  _icTouched = true;
                  _validateIC();
                },
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
                  LengthLimitingTextInputFormatter(12), // MyKad=12, Passport=9
                ],
                hint:               'e.g. 901231071234 or A12345678',
                keyboardType:       TextInputType.text,
                textCapitalization: TextCapitalization.characters,
              ),
            ]),
            const SizedBox(height: 20),

            // ── Purpose ──────────────────────────────────────────────
            _sectionLabel('Purpose of Visit *'),
            const SizedBox(height: 10),
            _card(children: [
              _purposeGrid(),
              if (_purpose == null && _dateTouched) ...[
                const SizedBox(height: 8),
                Row(children: const [
                  SizedBox(width: 4),
                  Icon(Icons.info_outline, size: 12, color: _errorColor),
                  SizedBox(width: 4),
                  Text('Please select a purpose.',
                      style: TextStyle(fontSize: 11, color: _errorColor)),
                ]),
              ],
              const SizedBox(height: 14),
              _validatedField(
                controller: _notesCtrl,
                label:      'Additional Notes',
                icon:       Icons.notes_rounded,
                required:   false,
                error:      _notesError,
                isValid:    false,
                onChanged:  (_) {
                  _notesTouched = true;
                  _validateNotes();
                },
                maxLines:   2,
                hint:       'Optional details…',
                suffixText: '${_notesCtrl.text.length}/200',
                inputFormatters: [
                  LengthLimitingTextInputFormatter(200),
                ],
              ),
            ]),
            const SizedBox(height: 20),

            // ── Visit date ───────────────────────────────────────────
            _sectionLabel('Visit Date *'),
            const SizedBox(height: 10),
            _card(children: [
              _datePicker(),
              if (_validDate == null && _dateTouched) ...[
                const SizedBox(height: 6),
                Row(children: const [
                  SizedBox(width: 4),
                  Icon(Icons.info_outline, size: 12, color: _errorColor),
                  SizedBox(width: 4),
                  Text('Please select a visit date.',
                      style: TextStyle(fontSize: 11, color: _errorColor)),
                ]),
              ] else ...[
                const SizedBox(height: 6),
                const Padding(
                  padding: EdgeInsets.only(left: 4),
                  child: Text(
                    'Pass is valid only on the selected date.',
                    style: TextStyle(fontSize: 11, color: Colors.black38),
                  ),
                ),
              ],
              const SizedBox(height: 4),
            ]),
            const SizedBox(height: 28),

            // ── Submit ───────────────────────────────────────────────
            _submitButton(),

            if (_dateTouched && !_isFormValid) ...[
              const SizedBox(height: 14),
              _missingFieldsHint(),
            ],
          ],
        ),
      ),
    );
  }

  // ── Missing fields hint ───────────────────────────────────────────────────

  Widget _missingFieldsHint() {
    final missing = <String>[];
    final name = _nameCtrl.text.trim();
    final ic   = _icCtrl.text.trim();

    if (name.length < 3 || !RegExp(r"^[a-zA-Z\s'./-]+$").hasMatch(name))
      missing.add('Visitor Name');
    if (ic.isEmpty ||
        (!RegExp(r'^\d{12}$').hasMatch(ic) &&
            !RegExp(r'^[A-Z]\d{8}$').hasMatch(ic.toUpperCase())))
      missing.add('IC / Passport');
    if (_purpose == null)   missing.add('Purpose');
    if (_validDate == null) missing.add('Visit Date');

    if (missing.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color:        _errorColor.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border:       Border.all(color: _errorColor.withOpacity(0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.checklist_rounded, size: 16, color: _errorColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Still required: ${missing.join(', ')}',
              style: const TextStyle(fontSize: 12, color: _errorColor),
            ),
          ),
        ],
      ),
    );
  }

  // ── Sub-widgets ───────────────────────────────────────────────────────────

  Widget _sectionLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
          fontSize:      13,
          fontWeight:    FontWeight.w700,
          color:         Colors.black54,
          letterSpacing: 0.3),
    );
  }

  Widget _card({required List<Widget> children}) {
    return Container(
      width:   double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
              color:      Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset:     const Offset(0, 4)),
        ],
      ),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children),
    );
  }

  Widget _validatedField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool required,
    required String? error,
    required bool isValid,
    required Function(String) onChanged,
    int maxLines = 1,
    String? hint,
    String? suffixText,
    TextInputType keyboardType = TextInputType.text,
    TextCapitalization textCapitalization = TextCapitalization.words,
    List<TextInputFormatter> inputFormatters = const [],
  }) {
    final borderColor = error != null
        ? _errorColor
        : isValid
        ? _successColor
        : Colors.black12;
    final borderWidth = (error != null || isValid) ? 1.5 : 1.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller:         controller,
          maxLines:           maxLines,
          onChanged:          onChanged,
          keyboardType:       keyboardType,
          textCapitalization: textCapitalization,
          inputFormatters:    inputFormatters,
          style: const TextStyle(fontSize: 14, color: Colors.black87),
          decoration: InputDecoration(
            labelText: required ? '$label *' : label,
            hintText:  hint,
            hintStyle: const TextStyle(fontSize: 13, color: Colors.black26),
            prefixIcon: Icon(icon,
                size:  18,
                color: error != null
                    ? _errorColor
                    : isValid
                    ? _successColor
                    : _primary.withOpacity(0.7)),
            suffixIcon: error != null
                ? const Icon(Icons.error_outline,
                color: _errorColor, size: 18)
                : isValid
                ? const Icon(Icons.check_circle_outline,
                color: _successColor, size: 18)
                : suffixText != null
                ? Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Text(suffixText,
                  style: const TextStyle(
                      fontSize: 11, color: Colors.black38)),
            )
                : null,
            suffixIconConstraints:
            suffixText != null && error == null && !isValid
                ? const BoxConstraints()
                : null,
            alignLabelWithHint: maxLines > 1,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:   BorderSide(color: borderColor, width: borderWidth),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:   BorderSide(color: borderColor, width: borderWidth),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:   BorderSide(
                  color: error != null ? _errorColor : _primary, width: 1.5),
            ),
            filled:    true,
            fillColor: error != null
                ? _errorColor.withOpacity(0.03)
                : isValid
                ? _successColor.withOpacity(0.03)
                : Colors.grey.shade50,
            contentPadding: EdgeInsets.symmetric(
                horizontal: 14, vertical: maxLines > 1 ? 14 : 12),
            isDense: true,
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: 5),
          Row(children: [
            const SizedBox(width: 4),
            const Icon(Icons.info_outline, size: 12, color: _errorColor),
            const SizedBox(width: 4),
            Expanded(
              child: Text(error,
                  style: const TextStyle(fontSize: 11, color: _errorColor)),
            ),
          ]),
        ],
      ],
    );
  }

  Widget _purposeGrid() {
    return GridView.count(
      crossAxisCount:   2,
      shrinkWrap:       true,
      physics:          const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing:  10,
      childAspectRatio: 2.8,
      children: _purposes.map((p) {
        final isSelected = _purpose == p.value;
        return GestureDetector(
          onTap: () => setState(() => _purpose = p.value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? _primary : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? _primary : Colors.black12,
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Row(children: [
              Icon(p.icon,
                  size:  16,
                  color: isSelected ? Colors.white : Colors.black45),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  p.label,
                  style: TextStyle(
                      fontSize:   12,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white : Colors.black54),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ]),
          ),
        );
      }).toList(),
    );
  }

  Widget _datePicker() {
    final hasDate = _validDate != null;
    return GestureDetector(
      onTap: _pickDate,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          border: Border.all(
            color: !hasDate && _dateTouched ? _errorColor : Colors.black12,
            width: !hasDate && _dateTouched ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(children: [
          Icon(Icons.calendar_today_rounded,
              color: !hasDate && _dateTouched ? _errorColor : _primary,
              size:  18),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Visit Date *',
                  style: TextStyle(
                      fontSize: 11,
                      color: !hasDate && _dateTouched
                          ? _errorColor
                          : Colors.black45),
                ),
                const SizedBox(height: 2),
                Text(
                  hasDate
                      ? DateFormat('EEEE, d MMMM yyyy').format(_validDate!)
                      : 'Tap to select a date',
                  style: TextStyle(
                      fontSize:   14,
                      fontWeight: FontWeight.w600,
                      color: hasDate ? Colors.black87 : Colors.black38),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
                color:        _primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8)),
            child: Text(
              hasDate ? 'Change' : 'Pick',
              style: const TextStyle(
                  fontSize:   12,
                  color:      _primary,
                  fontWeight: FontWeight.w600),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _submitButton() {
    final enabled = _isFormValid && !_loading;
    return SizedBox(
      width:  double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: _loading ? null : (enabled ? _submit : _onDisabledTap),
        style: ElevatedButton.styleFrom(
          backgroundColor: enabled ? _primary : Colors.grey.shade400,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
        ),
        child: _loading
            ? const SizedBox(
            width:  22,
            height: 22,
            child:  CircularProgressIndicator(
                color: Colors.white, strokeWidth: 2.5))
            : Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              enabled
                  ? Icons.send_rounded
                  : Icons.lock_outline_rounded,
              size: 18,
            ),
            const SizedBox(width: 8),
            const Text('Submit Request',
                style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}