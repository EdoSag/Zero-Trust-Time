import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zero_trust_core/zero_trust_core.dart';

import '../data/time_store.dart';
import '../model/time_entry.dart';
import '../notify/timer_notifier.dart';
import '../places/place_timer.dart';
import '../links/zt_links.dart';
import '../ui/entry_editor_page.dart';
import '../ui/home_page.dart';
import '../widget/timer_widget.dart';
import 'auth_providers.dart';
import 'time_settings.dart';
import '../l10n/l10n.dart';
import 'email_links.dart';

/// Routes between the shared account screens and the time tracker.
///
/// Signed out: sign in or create an account. Signed in but locked (cold
/// start, auto-lock): unlock with the account password or biometrics. A new
/// recovery key is always shown, and confirmed, before the vault opens.
class AppGate extends ConsumerStatefulWidget {
  const AppGate({super.key});

  @override
  ConsumerState<AppGate> createState() => _AppGateState();
}

class _AppGateState extends ConsumerState<AppGate> with WidgetsBindingObserver {
  /// Stays on the sign-in screen until it hands back a result, even though
  /// Supabase reports the session a moment earlier.
  late bool _signingIn = ref.read(currentUserProvider) == null;
  UnlockResult? _awaitingRecoveryKey;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// A key still waiting behind the recovery-key screen is zeroed when the
  /// app leaves the foreground, so coming back asks for the password.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      final UnlockResult? pending = _awaitingRecoveryKey;
      if (pending != null) {
        pending.dek.fillRange(0, pending.dek.length, 0);
        setState(() => _awaitingRecoveryKey = null);
      }
    }
  }

  void _onUnlocked(UnlockResult result) {
    if (result.newRecoveryKey != null) {
      setState(() {
        _signingIn = false;
        _awaitingRecoveryKey = result;
      });
      return;
    }
    setState(() => _signingIn = false);
    ref.read(vaultControllerProvider.notifier).unlock(result.dek, legacyDek: result.legacyDek);
  }

  void _forgotPassword() => Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => ZtForgotPasswordScreen(redirectTo: EmailLinks.passwordReset)),
  );

  @override
  Widget build(BuildContext context) {
    ref.listen(vaultControllerProvider, (_, VaultState next) {
      // Don't leave a page open over a locked vault.
      if (next is VaultLocked) {
        Navigator.of(context).popUntil((Route<dynamic> r) => r.isFirst);
      }
    });
    ref.listen(currentUserProvider, (_, user) {
      if (user == null) {
        ref.read(vaultControllerProvider.notifier).lock();
        ref.read(timerNotifierProvider).clear().ignore();
        // Places watched for this account stop starting timers.
        ref.read(placeTimerProvider).clear().ignore();
        // Taps queued while locked belong to this account, not the next.
        const TimerWidget().discardPending().ignore();
        const TimerWidget().publish(const TimerWidgetState.signedOut()).ignore();
        setState(() => _signingIn = true);
      }
    });

    final UnlockResult? pending = _awaitingRecoveryKey;
    if (pending != null) {
      return ZtRecoveryKeyScreen(
        recoveryKey: pending.newRecoveryKey!,
        onDone: () {
          setState(() => _awaitingRecoveryKey = null);
          ref
              .read(vaultControllerProvider.notifier)
              .unlock(pending.dek, legacyDek: pending.legacyDek);
        },
      );
    }

    if (ref.watch(passwordRecoveryProvider)) {
      return ZtResetPasswordScreen(
        onUnlocked: (UnlockResult result) {
          ref.read(passwordRecoveryProvider.notifier).done();
          _onUnlocked(result);
        },
      );
    }

    final user = ref.watch(currentUserProvider);
    if (user == null || _signingIn) {
      return ZtSignInScreen(emailRedirectTo: EmailLinks.confirmed, onUnlocked: _onUnlocked, onForgotPassword: _forgotPassword);
    }

    if (ref.watch(vaultControllerProvider) is VaultLocked) {
      return ZtUnlockScreen(
        email: user.email,
        onUnlocked: _onUnlocked,
        onSignOut: () => ref.read(accountServiceProvider).signOut(),
        onForgotPassword: _forgotPassword,
      );
    }

    return const TimeHome();
  }
}

/// The tracker once unlocked: runs sync, applies Start/Stop taps made on the
/// home screen widget, and keeps the "timer running" notification and the
/// widget in step with the running entry.
class TimeHome extends ConsumerStatefulWidget {
  const TimeHome({super.key});

  @override
  ConsumerState<TimeHome> createState() => _TimeHomeState();
}

class _TimeHomeState extends ConsumerState<TimeHome> with WidgetsBindingObserver {
  Timer? _debounce;

  /// What the widget last showed.
  TimerWidgetState? _widgetShown;
  String? _widgetLanguage;

  /// What the notification last showed, so an unrelated edit doesn't
  /// re-post it.
  String? _shown;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _schedule();
      _takeTrackRequest();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _debounce?.cancel();
    super.dispose();
  }

  /// Back on screen: the widget may have been tapped meanwhile.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _schedule();
      _takeTrackRequest();
      // Location may have been allowed in the phone's settings meanwhile;
      // places already watched are left alone.
      final rules = ref.read(placeRulesProvider).value;
      if (rules != null && rules.isNotEmpty) ref.read(placeTimerProvider).sync(rules).ignore();
    }
  }

  bool _tracking = false;

  /// ZT Tasks or ZT Calendar opened Time to track time on a task or an
  /// event (see lib/links/zt_links.dart). An event's times become an entry
  /// to check and save; otherwise a timer starts once the user agrees.
  /// Either way Time then goes back to the app that asked.
  Future<void> _takeTrackRequest() async {
    if (_tracking) return;
    _tracking = true;
    try {
      final links = ref.read(ztLinksProvider);
      final request = await links.takeTrackRequest();
      if (request == null || !mounted) return;
      final repo = ref.read(timeRepositoryProvider);
      final link = request.link;
      // Time spent on the same task before: same project, tags, billable.
      final before = link == null ? null : await repo.lastLinkedTo(link);
      if (!mounted) return;
      if (request.isLog) {
        final saved = await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (_) => EntryEditorPage(
              draft: TimeEntry(
                id: TimeRepository.newId(),
                description: request.title,
                projectId: before?.projectId,
                tags: before?.tags ?? const [],
                billable: before?.billable ?? false,
                link: link,
                start: request.start!,
                end: request.end,
              ),
            ),
          ),
        );
        await _publishNow();
        await links.finishTrack(saved: saved == true);
        return;
      }
      final app = linkedAppName(request.app);
      final start = await showDialog<bool>(
        context: context,
        builder: (d) => AlertDialog(
          title: Text(d.l10n.trackStartQuestion),
          content: Text(
            request.title.isEmpty
                ? d.l10n.trackStartUntitled(app)
                : d.l10n.trackStartBody(request.title, app),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(d).pop(false), child: Text(d.l10n.cancel)),
            TextButton(onPressed: () => Navigator.of(d).pop(true), child: Text(d.l10n.start)),
          ],
        ),
      );
      if (start == true) {
        final started = await repo.start(
          description: request.title,
          projectId: before?.projectId,
          tags: before?.tags ?? const [],
          billable: before?.billable ?? false,
          link: link,
        );
        await _publishNow(running: started.id);
      }
      await links.finishTrack(saved: start == true);
    } on Object catch (e) {
      debugPrint('Track request not handled: $e');
    } finally {
      _tracking = false;
    }
  }

  /// Shows the notification and the widget right away instead of after the
  /// usual short wait: going back to the other app may close Time first.
  /// Waits up to a second for the timer [running] to show up.
  Future<void> _publishNow({String? running}) async {
    for (var i = 0; running != null && i < 20; i++) {
      if (ref.read(runningProvider).any((e) => e.id == running)) break;
      await Future<void>.delayed(const Duration(milliseconds: 50));
      if (!mounted) return;
    }
    _debounce?.cancel();
    await _apply();
  }

  /// Starts and stops tapped on the widget, at the time they were tapped.
  /// Each is taken off the queue only once saved; if saving fails the rest
  /// wait for the next try.
  Future<void> _applyWidgetTaps() async {
    const widget = TimerWidget();
    final lines = await widget.pendingLines();
    if (lines.isEmpty) return;
    final repo = ref.read(timeRepositoryProvider);
    final projects = {for (final p in await repo.allProjects()) p.id: p};
    for (final line in lines) {
      for (final t in WidgetTimerAction.parse(line)) {
        if (t.stop) {
          await repo.stopAll(at: t.at);
        } else if (!_alreadyStarted(t.at)) {
          final project = projects[t.projectId];
          await repo.start(projectId: project?.id, billable: project?.billable ?? false, at: t.at);
        }
      }
      await widget.acknowledge(line);
    }
  }

  /// A start saved just before the app was closed, and not yet taken off the
  /// queue, is not started a second time.
  bool _alreadyStarted(DateTime at) =>
      ref.read(entriesProvider).value?.any((e) => e.running && e.start == at) ?? false;

  Future<void> _publishWidget() async {
    final entries = ref.read(entriesProvider).value;
    final projects = ref.read(projectsProvider).value;
    if (entries == null || projects == null) return;
    final next = TimerWidgetState.from(
      entries: entries,
      projects: projects,
      details: ref.read(timeSettingsProvider).widgetDetails,
    );
    // The widget's texts are in the app's language: republish when it changes.
    final language = currentL10n.localeName;
    if (next == _widgetShown && language == _widgetLanguage) return;
    _widgetShown = next;
    _widgetLanguage = language;
    await const TimerWidget().publish(next);
  }

  void _schedule() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _apply);
  }

  Future<void> _apply() async {
    if (!mounted) return;
    // Until the entries have loaded, leave a notification from the last
    // run alone: the timer it belongs to is probably still running.
    if (ref.read(entriesProvider).value == null) return;
    try {
      await _applyWidgetTaps();
      await _publishWidget();
    } on Object {
      // The widget is extra; the tracker itself still works.
    }
    if (!mounted) return;
    final settings = ref.read(timeSettingsProvider);
    final running = ref.read(runningProvider);
    final notifier = ref.read(timerNotifierProvider);
    final TimeEntry? entry = running.isEmpty ? null : running.first;
    try {
      if (entry == null || !settings.runningNotification) {
        if (_shown != '') {
          _shown = '';
          await notifier.clear();
        }
        return;
      }
      final title = settings.notificationText && entry.description.trim().isNotEmpty
          ? entry.description.trim()
          : currentL10n.timerRunning;
      final hours = settings.nudgeAfterHours;
      final key = '${entry.id}|${entry.start.toIso8601String()}|$title|$hours'
          '|${currentL10n.localeName}';
      if (key == _shown) return;
      _shown = key;
      await notifier.showRunning(
        start: entry.start,
        title: title,
        nudgeAt: hours == null ? null : entry.start.add(Duration(hours: hours)),
      );
    } on Object {
      // Notifications unavailable; the tracker itself still works.
    }
  }

  @override
  Widget build(BuildContext context) {
    // Runs sync for the unlocked vault (push, pull, live changes).
    ref.watch(ztSyncControllerProvider);
    ref.listen(runningProvider, (_, _) => _schedule());
    ref.listen(timeSettingsProvider, (_, _) => _schedule());
    // Recent projects on the widget.
    ref.listen(projectsProvider, (_, _) => _schedule());
    ref.listen(entriesProvider, (_, _) => _schedule());
    // Places to watch for start and stop by place (TM-3).
    ref.listen(placeRulesProvider, (_, next) {
      final rules = next.value;
      if (rules != null) ref.read(placeTimerProvider).sync(rules).ignore();
    });
    // The notification and widget texts follow a language change; the
    // debounce lets the new language load first.
    ref.listen(ztLanguageProvider, (_, _) => _schedule());
    return const HomePage();
  }
}
