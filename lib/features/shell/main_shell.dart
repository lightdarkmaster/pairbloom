import 'package:flutter/material.dart';
import '../../core/models/module_config.dart';
import '../dashboard/dashboard_page.dart';
import '../records/record_list_page.dart';
import '../settings/profile_page.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int index = 0;
  final pages = [
    DashboardPage(
      onNavigate: (int value) {},
    ),
    const MemoriesShortcut(),
    const ActivitiesShortcut(),
    const ProfilePage()
  ];
  @override
  Widget build(BuildContext context) => Scaffold(
        body: IndexedStack(index: index, children: pages),
        bottomNavigationBar: NavigationBar(
          selectedIndex: index,
          onDestinationSelected: (value) => setState(() => index = value),
          destinations: const [
            NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home),
                label: 'Home'),
            NavigationDestination(
                icon: Icon(Icons.photo_album_outlined),
                selectedIcon: Icon(Icons.photo_album),
                label: 'Memories'),
            NavigationDestination(
                icon: Icon(Icons.favorite_border),
                selectedIcon: Icon(Icons.favorite),
                label: 'Activities'),
            NavigationDestination(
                icon: Icon(Icons.people_outline),
                selectedIcon: Icon(Icons.people),
                label: 'Us'),
          ],
        ),
      );
}

class MemoriesShortcut extends StatelessWidget {
  const MemoriesShortcut({super.key});
  @override
  Widget build(BuildContext context) => const RecordListPage(configIndex: 0);
}

class ActivitiesShortcut extends StatelessWidget {
  const ActivitiesShortcut({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Our activities')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            for (var i = 1; i < modules.length; i++)
              Card(
                  child: ListTile(
                leading: Icon(modules[i].icon, color: const Color(0xFFD85B83)),
                title: Text(modules[i].title),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => RecordListPage(configIndex: i))),
              )),
          ],
        ),
      );
}
