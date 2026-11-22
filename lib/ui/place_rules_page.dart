import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zt_places/zt_places.dart';

import '../data/time_store.dart';
import '../l10n/l10n.dart';
import '../model/place_rule.dart';
import '../places/place_timer.dart';
import 'project_widgets.dart';

/// Start and stop by place (roadmap TM-3): "start the timer when I arrive
/// at the office, stop it when I leave".
class PlaceRulesPage extends ConsumerStatefulWidget {
  const PlaceRulesPage({super.key});

  @override
  ConsumerState<PlaceRulesPage> createState() => _PlaceRulesPageState();
}

class _PlaceRulesPageState extends ConsumerState<PlaceRulesPage>
    with WidgetsBindingObserver {
  ZtPlacePermissions? _permissions;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Back from the phone's settings: the permissions may have changed.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    final p = await ref.read(placeRemindersProvider).permissions();
    if (!mounted) return;
    setState(() => _permissions = p);
    _watch(p);
  }

  /// Places saved before location was allowed aren't watched yet: watch
  /// them now (places already watched are left alone).
  void _watch(ZtPlacePermissions p) {
    final rules = ref.read(placeRulesProvider).value;
    if (p.precise && rules != null) ref.read(placeTimerProvider).sync(rules).ignore();
  }

  /// Precise location, then "Allow all the time", then notifications.
  Future<void> _allow() async {
    final places = ref.read(placeRemindersProvider);
    var p = await places.requestLocation();
    if (p.precise && !p.background) p = await places.requestBackground();
    if (!p.notifications) p = await places.requestNotifications();
    if (!mounted) return;
    setState(() => _permissions = p);
    _watch(p);
  }

  Future<void> _add(List<PlaceRule> rules) async {
    final choice = await ZtPlacePickerPage.show(
      context,
      reminders: ref.read(placeRemindersProvider),
      savedPlaces: [for (final r in rules) r.place],
      newId: TimeRepository.newId,
    );
    if (choice == null || !mounted) return;
    final rule = PlaceRule(
      id: TimeRepository.newId(),
      place: choice.place,
      startOnArrive: true,
      stopOnLeave: true,
    );
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => PlaceRuleEditorPage(rule: rule, isNew: true)),
    );
    if (_permissions?.ready != true) await _allow();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final rules = ref.watch(placeRulesProvider).value ?? const <PlaceRule>[];
    final projects = {for (final p in ref.watch(projectsProvider).value ?? const []) p.id: p};
    final permissions = _permissions;
    return Scaffold(
      appBar: AppBar(title: Text(l.placeTimerTitle)),
      floatingActionButton: FloatingActionButton(
        tooltip: l.placeTimerAdd,
        onPressed: () => _add(rules),
        child: const Icon(Icons.add_location_alt_outlined),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 88),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text(l.placeTimerIntro),
          ),
          if (rules.isNotEmpty && permissions != null && !permissions.ready)
            Card(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: ListTile(
                leading: const Icon(Icons.location_off_outlined),
                title: Text(l.placeTimerNeedsLocation),
                subtitle: Text(l.placeTimerNeedsLocationBody),
                onTap: permissions.precise && !permissions.background
                    ? ref.read(placeRemindersProvider).openSettings
                    : _allow,
              ),
            ),
          if (rules.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                l.placeTimerEmpty,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
          for (final r in rules)
            ListTile(
              key: ValueKey(r.id),
              leading: const Icon(Icons.place_outlined),
              title: Text(r.place.name.isEmpty ? l.placeTimerUnnamed : r.place.name),
              subtitle: Text([
                projects[r.projectId]?.name ?? l.noProject,
                if (r.startOnArrive) l.placeTimerStarts,
                if (r.stopOnLeave) l.placeTimerStops,
              ].join(' · ')),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => PlaceRuleEditorPage(rule: r)),
              ),
              trailing: Switch(
                value: r.enabled,
                onChanged: (v) =>
                    ref.read(timeRepositoryProvider).savePlaceRule(r.copyWith(enabled: v)),
              ),
            ),
        ],
      ),
    );
  }
}

/// One place: which project, start on arrival, stop on leaving.
class PlaceRuleEditorPage extends ConsumerStatefulWidget {
  const PlaceRuleEditorPage({super.key, required this.rule, this.isNew = false});

  final PlaceRule rule;
  final bool isNew;

  @override
  ConsumerState<PlaceRuleEditorPage> createState() => _PlaceRuleEditorPageState();
}

class _PlaceRuleEditorPageState extends ConsumerState<PlaceRuleEditorPage> {
  late PlaceRule _rule = widget.rule;

  Future<void> _save() async {
    await ref.read(timeRepositoryProvider).savePlaceRule(_rule);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    await ref.read(timeRepositoryProvider).deletePlaceRule(_rule.id);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _changePlace() async {
    final choice = await ZtPlacePickerPage.show(
      context,
      reminders: ref.read(placeRemindersProvider),
      initialPlace: _rule.place,
      newId: TimeRepository.newId,
    );
    if (choice != null && mounted) setState(() => _rule = _rule.copyWith(place: choice.place));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final place = _rule.place;
    return Scaffold(
      appBar: AppBar(
        title: Text(place.name.isEmpty ? l.placeTimerUnnamed : place.name),
        actions: [
          if (!widget.isNew)
            IconButton(
              tooltip: l.delete,
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete,
            ),
          TextButton(onPressed: _save, child: Text(l.save)),
        ],
      ),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.place_outlined),
            title: Text(place.name.isEmpty ? l.placeTimerUnnamed : place.name),
            subtitle: Text('${place.position.format()} · ${place.radiusMeters.round()} m'),
            onTap: _changePlace,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: ProjectChip(
                projectId: _rule.projectId,
                onChanged: (p) => setState(() => _rule = _rule.copyWith(projectId: p?.id)),
              ),
            ),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.play_circle_outline),
            title: Text(l.placeTimerStartOnArrive),
            subtitle: Text(l.placeTimerStartOnArriveBody),
            value: _rule.startOnArrive,
            onChanged: (v) => setState(() => _rule = _rule.copyWith(startOnArrive: v)),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.stop_circle_outlined),
            title: Text(l.placeTimerStopOnLeave),
            subtitle: Text(l.placeTimerStopOnLeaveBody),
            value: _rule.stopOnLeave,
            onChanged: (v) => setState(() => _rule = _rule.copyWith(stopOnLeave: v)),
          ),
        ],
      ),
    );
  }
}
