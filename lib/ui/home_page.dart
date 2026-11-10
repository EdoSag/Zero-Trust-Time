import 'package:flutter/material.dart';

import 'entry_editor_page.dart';
import 'project_editor_page.dart';
import 'projects_tab.dart';
import 'reports_tab.dart';
import 'settings_page.dart';
import 'timer_tab.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _tab = 0;

  static const _titles = ['Timer', 'Reports', 'Projects'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_tab]),
        actions: [
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const TimeSettingsPage()),
            ),
          ),
        ],
      ),
      body: IndexedStack(
        index: _tab,
        children: const [TimerTab(), ReportsTab(), ProjectsTab()],
      ),
      floatingActionButton: switch (_tab) {
        0 => FloatingActionButton(
          tooltip: 'Add time by hand',
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const EntryEditorPage()),
          ),
          child: const Icon(Icons.add),
        ),
        2 => FloatingActionButton(
          tooltip: 'New project',
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const ProjectEditorPage()),
          ),
          child: const Icon(Icons.add),
        ),
        _ => null,
      },
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.timer_outlined),
            selectedIcon: Icon(Icons.timer),
            label: 'Timer',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: 'Reports',
          ),
          NavigationDestination(
            icon: Icon(Icons.folder_outlined),
            selectedIcon: Icon(Icons.folder),
            label: 'Projects',
          ),
        ],
      ),
    );
  }
}
