import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/utilities/geo_helper.dart';

class LocationInput {
  LocationInput(this.lat, this.lng, this.label, this.at, this.source);
  final double lat, lng;
  final String label;
  final DateTime? at;
  final String source; // 'code' | 'manual'
}

/// Accepts a PairBloom share message, a map link or "lat, lng".
class LocationInputDialog extends StatefulWidget {
  const LocationInputDialog({super.key, required this.title, this.askLabel = false, this.labelRequired = false});
  final String title;
  final bool askLabel, labelRequired;

  @override
  State<LocationInputDialog> createState() => _LocationInputDialogState();
}

class _LocationInputDialogState extends State<LocationInputDialog> {
  final _text = TextEditingController();
  final _label = TextEditingController();
  String? _error;
  ({double lat, double lng, DateTime? at, bool isCode})? _parsed;

  @override
  void dispose() {
    _text.dispose();
    _label.dispose();
    super.dispose();
  }

  void _reparse() => setState(() {
        _parsed = GeoHelper.parse(_text.text);
        _error = null;
      });

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text == null) return;
    _text.text = data!.text!;
    _reparse();
  }

  void _save() {
    final p = GeoHelper.parse(_text.text);
    if (p == null) {
      setState(() => _error = 'Could not find coordinates. Paste a PairBloom message, a map link, or type "14.5995, 120.9842".');
      return;
    }
    if (widget.labelRequired && _label.text.trim().isEmpty) {
      setState(() => _error = 'Please give this place a name.');
      return;
    }
    Navigator.pop(context, LocationInput(p.lat, p.lng, _label.text.trim(), p.at, p.isCode ? 'code' : 'manual'));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final p = _parsed;
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          TextField(
            controller: _text,
            minLines: 2,
            maxLines: 4,
            onChanged: (_) => _reparse(),
            decoration: const InputDecoration(hintText: 'Paste message, map link or 14.5995, 120.9842'),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(onPressed: _paste, icon: const Icon(Icons.content_paste_rounded, size: 18), label: const Text('Paste')),
          ),
          if (p != null)
            Text('Found: ${p.lat.toStringAsFixed(5)}, ${p.lng.toStringAsFixed(5)}', style: TextStyle(color: cs.primary, fontWeight: FontWeight.w700)),
          if (widget.askLabel) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _label,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(labelText: widget.labelRequired ? 'Place name *' : 'Label (optional)'),
            ),
          ],
          if (_error != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(_error!, style: TextStyle(color: cs.error))),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}
