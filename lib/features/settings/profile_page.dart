import 'package:flutter/material.dart';
import '../../core/database/app_database.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final one = TextEditingController(),
      two = TextEditingController(),
      start = TextEditingController();
  bool ready = false;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final profile =
        (await AppDatabase.instance.getAll('couple_profiles')).first;
    one.text = profile['partner_one'] as String? ?? 'You';
    two.text = profile['partner_two'] as String? ?? 'Your sweetheart';
    start.text = profile['relationship_start'] as String? ?? '';
    if (mounted) setState(() => ready = true);
  }

  Future<void> save() async {
    final db = AppDatabase.instance;
    final profile = (await db.getAll('couple_profiles')).first;
    await db.update('couple_profiles', profile['id'] as int, {
      'partner_one': one.text.trim().isEmpty ? 'You' : one.text.trim(),
      'partner_two':
          two.text.trim().isEmpty ? 'Your sweetheart' : two.text.trim(),
      'relationship_start': start.text.trim(),
      'updated_at': DateTime.now().toIso8601String(),
    });
    if (mounted)
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Couple profile saved on this device.')));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
            title: const Text('Our little space',
                style: TextStyle(fontWeight: FontWeight.w800))),
        body: !ready
            ? const Center(child: CircularProgressIndicator())
            : ListView(padding: const EdgeInsets.all(18), children: [
                const Center(
                    child: CircleAvatar(
                        radius: 42,
                        backgroundColor: Color(0xFFFCE4EC),
                        child: Icon(Icons.favorite,
                            color: Color(0xFFE91E63), size: 38))),
                const SizedBox(height: 14),
                const Center(
                    child: Text('Your couple profile',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w800))),
                const SizedBox(height: 22),
                TextField(
                    controller: one,
                    decoration:
                        const InputDecoration(labelText: 'Partner 1 name')),
                const SizedBox(height: 12),
                TextField(
                    controller: two,
                    decoration:
                        const InputDecoration(labelText: 'Partner 2 name')),
                const SizedBox(height: 12),
                TextField(
                    controller: start,
                    decoration: const InputDecoration(
                        labelText: 'Relationship start date (YYYY-MM-DD)')),
                const SizedBox(height: 16),
                FilledButton.icon(
                    onPressed: save,
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('Save profile')),
                const SizedBox(height: 24),
                const Text('About PairBloom',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                const Text(
                    'A little space for two hearts. Your core records are stored locally in SQLite. This starter does not sync between devices.'),
                const SizedBox(height: 12),
                const Text(
                    'Keep a separate backup of your device data. Database export and restore will be added in a later implementation phase.',
                    style: TextStyle(color: Colors.black54)),
              ]),
      );
}
