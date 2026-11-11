import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/services/location_service.dart';
import '../../core/utilities/geo_helper.dart';
import '../../models/location_entry.dart';
import '../../repositories/repos.dart';
import '../../widgets/common_widgets.dart';
import '../activities/crud_framework.dart' show partnerNames;
import '../dashboard/dashboard_controller.dart';
import '../profiles/profile_controller.dart';
import 'location_input_dialog.dart';

const _meKey = 'me_partner';
const _unitKey = 'distance_unit';

class DistancePage extends StatefulWidget {
  const DistancePage({super.key});
  @override
  State<DistancePage> createState() => _DistancePageState();
}

class _DistancePageState extends State<DistancePage> {
  final _service = LocationService();
  int _me = 1;
  bool _miles = false, _loading = true, _busy = false;
  String? _error;
  LocationEntry? _mine, _partner;
  List<LocationEntry> _places = [], _history = [];

  int get _other => _me == 1 ? 2 : 1;
  int? get _cid => context.read<ProfileController>().profile?.id;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final cid = _cid;
    if (cid == null) {
      setState(() => _loading = false);
      return;
    }
    try {
      _me = (await Repos.settings.get(_meKey)) == '2' ? 2 : 1;
      _miles = (await Repos.settings.get(_unitKey)) == 'mi';
      final mine = await Repos.locations.latest(cid, _me);
      final partner = await Repos.locations.latest(cid, _other);
      final places = await Repos.locations.places(cid);
      final history = await Repos.locations.history(cid);
      if (!mounted) return;
      setState(() {
        _mine = mine;
        _partner = partner;
        _places = places;
        _history = history;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _afterChange() async {
    await _load();
    if (mounted) context.read<DashboardController>().load();
  }

  // ------------------------------------------------------------ actions ----
  Future<void> _setMe(int n) async {
    await Repos.settings.set(_meKey, '$n');
    await _afterChange();
  }

  Future<void> _setUnit(bool miles) async {
    setState(() => _miles = miles);
    await Repos.settings.set(_unitKey, miles ? 'mi' : 'km');
    if (mounted) context.read<DashboardController>().load();
  }

  Future<void> _save(LocationEntry e, String message) async {
    try {
      await Repos.locations.insert(e);
      await _afterChange();
      if (mounted) showAppSnack(context, message);
    } catch (err) {
      if (mounted) showAppSnack(context, err.toString(), error: true);
    }
  }

  Future<void> _useGps() async {
    final cid = _cid;
    if (cid == null || _busy) return;
    setState(() => _busy = true);
    try {
      final fix = await _service.current();
      await _save(
        LocationEntry(
            coupleId: cid, owner: _me, latitude: fix.latitude, longitude: fix.longitude, accuracyM: fix.accuracyM, source: 'gps', recordedAt: DateTime.now()),
        'Your location was updated',
      );
    } on LocationException catch (e) {
      if (!mounted) return;
      final fixable = e.reason == LocationFailure.serviceOff || e.reason == LocationFailure.deniedForever;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(e.message),
          action: fixable
              ? SnackBarAction(
                  label: 'Settings',
                  onPressed: () => e.reason == LocationFailure.serviceOff ? _service.openLocationSettings() : _service.openAppSettings())
              : null,
        ));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _enter({required int owner, bool place = false}) async {
    final cid = _cid;
    if (cid == null) return;
    final r = await showDialog<LocationInput>(
      context: context,
      builder: (_) => LocationInputDialog(
        title: place ? 'Add a saved place' : (owner == _me ? 'Set my location' : "Set partner's location"),
        askLabel: true,
        labelRequired: place,
      ),
    );
    if (r == null) return;
    await _save(
      LocationEntry(
        coupleId: cid,
        owner: place ? 0 : owner,
        label: r.label,
        latitude: r.lat,
        longitude: r.lng,
        source: r.source,
        isPlace: place,
        recordedAt: r.at ?? DateTime.now(),
      ),
      place ? 'Place saved' : 'Location saved',
    );
  }

  Future<void> _usePlace(int owner) async {
    final cid = _cid;
    if (cid == null) return;
    if (_places.isEmpty) {
      showAppSnack(context, 'Save a place first (see "Saved places" below).');
      return;
    }
    final p = await showModalBottomSheet<LocationEntry>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ListView(shrinkWrap: true, children: [
          for (final pl in _places)
            ListTile(
              leading: const Icon(Icons.place_rounded),
              title: Text(pl.label ?? 'Place'),
              subtitle: Text('${pl.latitude.toStringAsFixed(4)}, ${pl.longitude.toStringAsFixed(4)}'),
              onTap: () => Navigator.pop(ctx, pl),
            ),
        ]),
      ),
    );
    if (p == null) return;
    await _save(
      LocationEntry(coupleId: cid, owner: owner, label: p.label, latitude: p.latitude, longitude: p.longitude, source: 'manual', recordedAt: DateTime.now()),
      'Location set to ${p.label}',
    );
  }

  Future<void> _delete(LocationEntry e) async {
    final yes = await confirmDialog(context, title: e.isPlace ? 'Delete place?' : 'Delete this entry?', message: 'This cannot be undone.');
    if (!yes) return;
    try {
      await Repos.locations.delete(e.id!);
      await _afterChange();
    } catch (err) {
      if (mounted) showAppSnack(context, err.toString(), error: true);
    }
  }

  Future<void> _openMaps(double lat, double lng) async {
    final ok = await launchUrl(Uri.parse(GeoHelper.mapsUrl(lat, lng)), mode: LaunchMode.externalApplication).catchError((_) => false);
    if (!ok && mounted) showAppSnack(context, 'No app found to open the map.', error: true);
  }

  void _share() {
    final m = _mine;
    if (m == null) return;
    final names = partnerNames(context);
    final msg = GeoHelper.shareMessage(names[_me - 1], m.latitude, m.longitude, m.recordedAt);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Share my location', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text('Send this to your partner. They paste it in PairBloom → Distance → "Paste shared location".',
                style: TextStyle(color: Theme.of(ctx).colorScheme.onSurfaceVariant)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Theme.of(ctx).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(14)),
              child: Text(msg, style: const TextStyle(fontSize: 13)),
            ),
            const SizedBox(height: 14),
            Wrap(spacing: 8, runSpacing: 8, children: [
              FilledButton.icon(
                icon: const Icon(Icons.copy_rounded),
                label: const Text('Copy'),
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: msg));
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (mounted) showAppSnack(context, 'Copied. Paste it in any chat app.');
                },
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.sms_rounded),
                label: const Text('Send SMS'),
                onPressed: () async {
                  final ok = await launchUrl(Uri(scheme: 'sms', queryParameters: {'body': msg})).catchError((_) => false);
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (!ok && mounted) showAppSnack(context, 'Could not open messages. Use Copy instead.', error: true);
                },
              ),
            ]),
          ]),
        ),
      ),
    );
  }

  // -------------------------------------------------------------- helpers --
  String _ago(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes} min ago';
    if (d.inHours < 24) return '${d.inHours} h ago';
    return '${d.inDays} ${d.inDays == 1 ? 'day' : 'days'} ago';
  }

  String _coords(LocationEntry e) => '${e.latitude.toStringAsFixed(5)}, ${e.longitude.toStringAsFixed(5)}';

  IconData _sourceIcon(String s) => s == 'gps' ? Icons.my_location_rounded : (s == 'code' ? Icons.mark_email_read_rounded : Icons.edit_location_alt_rounded);

  // ---------------------------------------------------------------- build --
  @override
  Widget build(BuildContext context) {
    final profile = context.watch<ProfileController>().profile;
    return Scaffold(
      appBar: AppBar(title: const Text('Distance Between Us')),
      body: profile == null
          ? const EmptyState(
              icon: Icons.favorite_border_rounded,
              title: 'Set up your couple profile first',
              message: 'Go to the Profile tab and add your names to use this section.')
          : _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? ErrorState(message: _error!, onRetry: _load)
                  : RefreshIndicator(onRefresh: _load, child: _content(context)),
    );
  }

  Widget _content(BuildContext context) {
    final names = partnerNames(context);
    final both = _mine != null && _partner != null;
    final km = both ? GeoHelper.haversineKm(_mine!.latitude, _mine!.longitude, _partner!.latitude, _partner!.longitude) : null;

    return ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 32), children: [
      AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('This phone belongs to', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          SegmentedButton<int>(
            showSelectedIcon: false,
            segments: [ButtonSegment(value: 1, label: Text(names[0])), ButtonSegment(value: 2, label: Text(names[1]))],
            selected: {_me},
            onSelectionChanged: (s) => _setMe(s.first),
          ),
        ]),
      ),
      const SizedBox(height: 12),
      _hero(context, km),
      const SizedBox(height: 12),
      _locationCard(
        context,
        title: 'Me • ${names[_me - 1]}',
        entry: _mine,
        empty: 'Not set yet',
        actions: [
          FilledButton.tonalIcon(
            onPressed: _busy ? null : _useGps,
            icon: _busy ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.my_location_rounded),
            label: Text(_busy ? 'Locating…' : 'Use GPS'),
          ),
          OutlinedButton(onPressed: () => _enter(owner: _me), child: const Text('Enter')),
          OutlinedButton(onPressed: () => _usePlace(_me), child: const Text('Saved place')),
          if (_mine != null) OutlinedButton.icon(onPressed: _share, icon: const Icon(Icons.ios_share_rounded), label: const Text('Share')),
        ],
      ),
      const SizedBox(height: 12),
      _locationCard(
        context,
        title: 'Partner • ${names[_other - 1]}',
        entry: _partner,
        empty: 'Ask them to share their location with you',
        actions: [
          FilledButton.tonalIcon(onPressed: () => _enter(owner: _other), icon: const Icon(Icons.content_paste_rounded), label: const Text('Paste shared location')),
          OutlinedButton(onPressed: () => _usePlace(_other), child: const Text('Saved place')),
        ],
      ),
      if (km != null) ...[
        const SectionHeader('Travel time estimates'),
        _estimates(context, km),
        const SectionHeader('Meet in the middle'),
        _midpoint(context),
      ],
      SectionHeader('Saved places', actionLabel: 'Add', onAction: () => _enter(owner: 0, place: true)),
      _places.isEmpty
          ? const AppCard(child: Text('Save spots like Home, Office or your favourite cafe to set a location quickly.'))
          : Column(children: [
              for (final p in _places)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: AppCard(
                    padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
                    child: Row(children: [
                      Icon(Icons.place_rounded, color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(p.label ?? 'Place', style: const TextStyle(fontWeight: FontWeight.w700)),
                          Text(_coords(p), style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                        ]),
                      ),
                      IconButton(icon: const Icon(Icons.map_outlined), onPressed: () => _openMaps(p.latitude, p.longitude)),
                      IconButton(icon: const Icon(Icons.delete_outline_rounded), onPressed: () => _delete(p)),
                    ]),
                  ),
                ),
            ]),
      const SectionHeader('Recent updates'),
      if (_history.isEmpty)
        const AppCard(child: Text('Location updates will appear here.'))
      else
        for (final h in _history)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: AppCard(
              padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
              child: Row(children: [
                Icon(_sourceIcon(h.source), color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${names[h.owner == 2 ? 1 : 0]}${h.label == null ? '' : ' • ${h.label}'}', style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text('${_coords(h)} • ${_ago(h.recordedAt)}', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  ]),
                ),
                IconButton(icon: const Icon(Icons.delete_outline_rounded), onPressed: () => _delete(h)),
              ]),
            ),
          ),
      const SizedBox(height: 12),
      Text(
        'Everything stays on this phone. PairBloom reads your GPS only when you tap "Use GPS", never in the background, and shares nothing unless you send the message yourself.',
        style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
    ]);
  }

  Widget _hero(BuildContext context, double? km) {
    final cs = Theme.of(context).colorScheme;
    String? note;
    if (_mine != null && _partner != null) {
      final gap = _mine!.recordedAt.difference(_partner!.recordedAt).abs();
      if (gap.inHours >= 6) note = 'These locations were saved ${GeoHelper.formatHours(gap.inMinutes / 60)} apart, so the distance may be out of date.';
    }
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(colors: [cs.primaryContainer, cs.secondaryContainer], begin: Alignment.topLeft, end: Alignment.bottomRight),
      ),
      child: Column(children: [
        Row(children: [
          const Expanded(child: Text('How far apart are we?', style: TextStyle(fontWeight: FontWeight.w800))),
          SegmentedButton<bool>(
            showSelectedIcon: false,
            style: const ButtonStyle(visualDensity: VisualDensity.compact),
            segments: const [ButtonSegment(value: false, label: Text('km')), ButtonSegment(value: true, label: Text('mi'))],
            selected: {_miles},
            onSelectionChanged: (s) => _setUnit(s.first),
          ),
        ]),
        const SizedBox(height: 14),
        if (km == null)
          Text('Set both locations below to see the distance.', textAlign: TextAlign.center, style: TextStyle(color: cs.onSurfaceVariant))
        else ...[
          Text(GeoHelper.formatDistance(km, _miles), style: TextStyle(fontSize: 44, fontWeight: FontWeight.w900, color: cs.primary, height: 1.1)),
          const Text('in a straight line', style: TextStyle(fontWeight: FontWeight.w600)),
          if (km < 0.05) const Padding(padding: EdgeInsets.only(top: 6), child: Text("You're together! 💕")),
          if (note != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(note, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant))),
        ],
      ]),
    );
  }

  Widget _locationCard(BuildContext context,
      {required String title, required LocationEntry? entry, required String empty, required List<Widget> actions}) {
    final cs = Theme.of(context).colorScheme;
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        const SizedBox(height: 6),
        if (entry == null)
          Text(empty, style: TextStyle(color: cs.onSurfaceVariant))
        else
          Row(children: [
            Icon(_sourceIcon(entry.source), size: 18, color: cs.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${entry.label == null ? '' : '${entry.label} • '}${_coords(entry)}\nUpdated ${_ago(entry.recordedAt)}'
                '${entry.accuracyM == null ? '' : ' • ±${entry.accuracyM!.round()} m'}',
                style: const TextStyle(fontSize: 13),
              ),
            ),
            IconButton(icon: const Icon(Icons.map_outlined), onPressed: () => _openMaps(entry.latitude, entry.longitude)),
          ]),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: actions),
      ]),
    );
  }

  Widget _estimates(BuildContext context, double km) {
    final cs = Theme.of(context).colorScheme;
    return AppCard(
      child: Column(children: [
        for (final e in GeoHelper.estimates(km))
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(children: [
              Icon(e.icon, color: cs.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(e.label, style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text(e.note, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                ]),
              ),
              Text(GeoHelper.formatHours(e.hours), style: TextStyle(fontWeight: FontWeight.w800, color: cs.primary)),
            ]),
          ),
        const SizedBox(height: 4),
        Text('Rough estimates from the straight-line distance. Real routes and traffic will differ.', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
      ]),
    );
  }

  Widget _midpoint(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final mid = GeoHelper.midpoint(_mine!.latitude, _mine!.longitude, _partner!.latitude, _partner!.longitude);
    final half = GeoHelper.haversineKm(_mine!.latitude, _mine!.longitude, mid.lat, mid.lng);
    return AppCard(
      onTap: () => _openMaps(mid.lat, mid.lng),
      child: Row(children: [
        Icon(Icons.favorite_rounded, color: cs.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${mid.lat.toStringAsFixed(4)}, ${mid.lng.toStringAsFixed(4)}', style: const TextStyle(fontWeight: FontWeight.w700)),
            Text('About ${GeoHelper.formatDistance(half, _miles)} from each of you. Tap to open in maps.', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
          ]),
        ),
        const Icon(Icons.map_outlined),
      ]),
    );
  }
}
