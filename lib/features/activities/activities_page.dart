import 'package:flutter/material.dart';

import '../../widgets/common_widgets.dart';
import 'bucket_list_page.dart';
import 'challenges_page.dart';
import 'date_planner_page.dart';
import 'expenses_page.dart';
import '../location/distance_page.dart';
import 'goals_page.dart';
import 'love_notes_page.dart';
import 'mood_page.dart';
import 'wishlist_page.dart';

/// Hub for every module that lives under the Activities tab.
class ActivitiesPage extends StatelessWidget {
  const ActivitiesPage({super.key});

  static final _modules = <(IconData, String, String, Widget Function())>[
    (
      Icons.mail_rounded,
      'Love Notes',
      'Letters & appreciation',
      () => const LoveNotesPage()
    ),
    (
      Icons.event_available_rounded,
      'Date Planner',
      'Plan your next date',
      () => const DatePlannerPage()
    ),
    (
      Icons.checklist_rounded,
      'Bucket List',
      'Dreams to tick off',
      () => const BucketListPage()
    ),
    (
      Icons.mood_rounded,
      'Mood Check-in',
      'Daily feelings',
      () => const MoodPage()
    ),
    (
      Icons.question_answer_rounded,
      'Challenges',
      'Questions & activities',
      () => const ChallengesPage()
    ),
    (
      Icons.payments_rounded,
      'Expenses',
      'Shared spending',
      () => const ExpensesPage()
    ),
    (
      Icons.card_giftcard_rounded,
      'Gift Wishlist',
      'Ideas they will love',
      () => const WishlistPage()
    ),
    (Icons.flag_rounded, 'Goals', 'Grow together', () => const GoalsPage()),
    (
      Icons.social_distance_rounded,
      'Distance',
      'Locations & travel time',
      () => const DistancePage()
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Activities')),
      body: GridView(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          mainAxisExtent: 140,
        ),
        children: [
          for (final (icon, title, subtitle, builder) in _modules)
            AppCard(
              onTap: () => Navigator.push(
                  context, MaterialPageRoute(builder: (_) => builder())),
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircleAvatar(
                        radius: 24,
                        backgroundColor: cs.primaryContainer,
                        child: Icon(icon, color: cs.primary, size: 26)),
                    const SizedBox(height: 8),
                    Text(title,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    Text(subtitle,
                        style:
                            TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ]),
            ),
        ],
      ),
    );
  }
}
