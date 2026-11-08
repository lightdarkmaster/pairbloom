import 'package:flutter/material.dart';

import 'common_widgets.dart';

/// TEMPORARY screen for modules that are built in later steps.
/// Each one is replaced by its real feature screen as we implement it.
class ModulePlaceholderPage extends StatelessWidget {
  const ModulePlaceholderPage({super.key, required this.title, required this.icon, this.showAppBar = true});
  final String title;
  final IconData icon;
  final bool showAppBar;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: showAppBar ? AppBar(title: Text(title)) : AppBar(title: Text(title)),
        body: EmptyState(
          icon: icon,
          title: '$title is coming next',
          message: 'This module is implemented in the next build step.',
        ),
      );
}
