import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/services/image_service.dart';
import '../../core/utilities/date_helper.dart';
import '../../models/couple_profile.dart';
import '../../widgets/common_widgets.dart';
import '../dashboard/dashboard_controller.dart';
import 'profile_controller.dart';

class ProfileFormPage extends StatefulWidget {
  const ProfileFormPage({super.key, this.existing});
  final CoupleProfile? existing;

  @override
  State<ProfileFormPage> createState() => _ProfileFormPageState();
}

class _ProfileFormPageState extends State<ProfileFormPage> {
  final _form = GlobalKey<FormState>();
  final _images = ImageService();

  late final _n1 = TextEditingController(text: widget.existing?.partner1Name);
  late final _nick1 = TextEditingController(text: widget.existing?.partner1Nickname);
  late final _bio1 = TextEditingController(text: widget.existing?.partner1Bio);
  late final _n2 = TextEditingController(text: widget.existing?.partner2Name);
  late final _nick2 = TextEditingController(text: widget.existing?.partner2Nickname);
  late final _bio2 = TextEditingController(text: widget.existing?.partner2Bio);

  String? _photo1, _photo2;
  late final String? _origPhoto1 = widget.existing?.partner1PhotoPath;
  late final String? _origPhoto2 = widget.existing?.partner2PhotoPath;
  DateTime? _start, _anniversary;
  String _status = 'In a Relationship';
  bool _saving = false, _saved = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _photo1 = e?.partner1PhotoPath;
    _photo2 = e?.partner2PhotoPath;
    _start = e?.relationshipStartDate;
    _anniversary = e?.anniversaryDate;
    _status = e?.relationshipStatus ?? _status;
  }

  @override
  void dispose() {
    // Remove photos that were picked but never saved.
    if (!_saved) {
      if (_photo1 != _origPhoto1) _images.delete(_photo1);
      if (_photo2 != _origPhoto2) _images.delete(_photo2);
    }
    for (final c in [_n1, _nick1, _bio1, _n2, _nick2, _bio2]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickPhoto(int partner) async {
    try {
      final path = await _images.pickFromGallery();
      if (path == null) return;
      setState(() {
        if (partner == 1) {
          if (_photo1 != _origPhoto1) _images.delete(_photo1);
          _photo1 = path;
        } else {
          if (_photo2 != _origPhoto2) _images.delete(_photo2);
          _photo2 = path;
        }
      });
    } catch (_) {
      if (mounted) showAppSnack(context, 'Could not load that photo.', error: true);
    }
  }

  Future<void> _pickDate({required bool anniversary}) async {
    final now = DateTime.now();
    final initial = (anniversary ? _anniversary : _start) ?? now;
    final d = await showDatePicker(
      context: context,
      initialDate: initial.isAfter(now) ? now : initial,
      firstDate: DateTime(1950),
      lastDate: anniversary ? DateTime(now.year + 1, 12, 31) : now,
    );
    if (d != null) setState(() => anniversary ? _anniversary = d : _start = d);
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    if (_start == null) {
      showAppSnack(context, 'Please choose your relationship start date.', error: true);
      return;
    }
    setState(() => _saving = true);
    final profileCtl = context.read<ProfileController>();
    final dashCtl = context.read<DashboardController>();
    final nav = Navigator.of(context);
    try {
      await profileCtl.save(CoupleProfile(
        id: widget.existing?.id,
        partner1Name: _n1.text,
        partner1Nickname: _nick1.text,
        partner1PhotoPath: _photo1,
        partner1Bio: _bio1.text,
        partner2Name: _n2.text,
        partner2Nickname: _nick2.text,
        partner2PhotoPath: _photo2,
        partner2Bio: _bio2.text,
        relationshipStartDate: _start!,
        anniversaryDate: _anniversary,
        relationshipStatus: _status,
      ));
      _saved = true;
      // Delete replaced photos only after the new record is safely stored.
      if (_origPhoto1 != null && _origPhoto1 != _photo1) await _images.delete(_origPhoto1);
      if (_origPhoto2 != null && _origPhoto2 != _photo2) await _images.delete(_origPhoto2);
      await dashCtl.load();
      if (!mounted) return;
      showAppSnack(context, widget.existing == null ? 'Your couple profile is ready 💕' : 'Profile updated');
      nav.pop();
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        showAppSnack(context, e.toString(), error: true);
      }
    }
  }

  String? _required(String? v, String label) =>
      (v == null || v.trim().isEmpty) ? '$label is required' : null;

  Widget _partnerSection(int n, TextEditingController name, TextEditingController nick,
      TextEditingController bio, String? photo) {
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Partner $n', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        Center(
          child: GestureDetector(
            onTap: () => _pickPhoto(n),
            child: Stack(children: [
              PartnerAvatar(name: name.text, photoPath: photo, radius: 48),
              Positioned(
                right: 0,
                bottom: 0,
                child: CircleAvatar(
                    radius: 15,
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    child: const Icon(Icons.camera_alt_rounded, size: 16, color: Colors.white)),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: name,
          textCapitalization: TextCapitalization.words,
          maxLength: 40,
          decoration: const InputDecoration(labelText: 'Name *', counterText: ''),
          validator: (v) => _required(v, 'Name'),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        TextFormField(
            controller: nick,
            maxLength: 30,
            decoration: const InputDecoration(labelText: 'Nickname', counterText: '')),
        const SizedBox(height: 12),
        TextFormField(
            controller: bio,
            maxLines: 3,
            maxLength: 200,
            decoration: const InputDecoration(labelText: 'About them')),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.existing != null;
    return Scaffold(
      appBar: AppBar(title: Text(editing ? 'Edit couple profile' : 'Set up your couple profile')),
      body: Form(
        key: _form,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          _partnerSection(1, _n1, _nick1, _bio1, _photo1),
          const SizedBox(height: 16),
          _partnerSection(2, _n2, _nick2, _bio2, _photo2),
          const SizedBox(height: 16),
          AppCard(
            child: Column(children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.favorite_rounded),
                title: const Text('Relationship start date *'),
                subtitle: Text(_start == null ? 'Tap to choose' : DateHelper.pretty(_start!)),
                onTap: () => _pickDate(anniversary: false),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.cake_rounded),
                title: const Text('Anniversary date'),
                subtitle: Text(_anniversary == null
                    ? 'Optional (defaults to start date)'
                    : DateHelper.pretty(_anniversary!)),
                trailing: _anniversary == null
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close), onPressed: () => setState(() => _anniversary = null)),
                onTap: () => _pickDate(anniversary: true),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _status,
                decoration: const InputDecoration(labelText: 'Relationship status'),
                items: [
                  for (final s in AppConstants.relationshipStatuses) DropdownMenuItem(value: s, child: Text(s)),
                ],
                onChanged: (v) => setState(() => _status = v ?? _status),
              ),
            ]),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.check_rounded),
            label: Text(editing ? 'Save changes' : 'Create profile'),
          ),
          const SizedBox(height: 24),
        ]),
      ),
    );
  }
}
