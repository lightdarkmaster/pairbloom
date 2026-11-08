import 'package:flutter/material.dart';

import '../../widgets/common_widgets.dart';
import '../../widgets/module_placeholder_page.dart';

/// Hub for every module that lives under the Activities tab.
class ActivitiesPage extends StatelessWidget {
  const ActivitiesPage({super.key});

  static const _modules = <(IconData, String)>[
    (Icons.mail_rounded, 'Love Notes'),
    (Icons.event_available_rounded, 'Date Planner'),
    (Icons.checklist_rounded, 'Bucket List'),
    (Icons.mood_rounded, 'Mood Check-in'),
    (Icons.question_answer_rounded, 'Challenges'),
    (Icons.payments_rounded, 'Expenses'),
    (Icons.card_giftcard_rounded, 'Gift Wishlist'),
    (Icons.flag_rounded, 'Goals'),
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Activities')),
      body: GridView.count(
        padding: const EdgeInsets.all(16),
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.25,
        children: [
          for (final (icon, title) in _modules)
            AppCard(
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => ModulePlaceholderPage(title: title, icon: icon))),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                CircleAvatar(
                    radius: 26,
                    backgroundColor: cs.primaryContainer,
                    child: Icon(icon, color: cs.primary, size: 28)),
                const SizedBox(height: 10),
                Text(title, style: const TextStyle(fontWeight: FontWeight.w800), textAlign: TextAlign.center),
              ]),
            ),
        ],
      ),
    );
  }
}
