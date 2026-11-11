import 'package:flutter/material.dart';

import 'entry_editor_page.dart';
import 'project_editor_page.dart';
import 'projects_tab.dart';
import 'reports_tab.dart';
import 'settings_page.dart';
import 'timer_tab.dart';
import '../l10n/l10n.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final titles = [l.tabTimer, l.tabReports, l.tabProjects];
    return Scaffold(
      appBar: AppBar(
        title: Text(titles[_tab]),
        actions: [
          IconButton(
            tooltip: l.settingsTooltip,
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
          tooltip: l.addTimeByHand,
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const EntryEditorPage()),
          ),
          child: const Icon(Icons.add),
        ),
        2 => FloatingActionButton(
          tooltip: l.newProject,
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
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.timer_outlined),
            selectedIcon: const Icon(Icons.timer),
            label: l.tabTimer,
          ),
          NavigationDestination(
            icon: const Icon(Icons.bar_chart_outlined),
            selectedIcon: const Icon(Icons.bar_chart),
            label: l.tabReports,
          ),
          NavigationDestination(
            icon: const Icon(Icons.folder_outlined),
            selectedIcon: const Icon(Icons.folder),
            label: l.tabProjects,
          ),
        ],
      ),
    );
  }
}
