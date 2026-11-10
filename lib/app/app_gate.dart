import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zero_trust_core/zero_trust_core.dart';

import '../data/time_store.dart';
import '../model/time_entry.dart';
import '../notify/timer_notifier.dart';
import '../ui/home_page.dart';
import '../widget/timer_widget.dart';
import 'auth_providers.dart';
import 'time_settings.dart';

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
    MaterialPageRoute<void>(builder: (_) => const ZtForgotPasswordScreen()),
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
      return ZtSignInScreen(onUnlocked: _onUnlocked, onForgotPassword: _forgotPassword);
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

  /// What the notification last showed, so an unrelated edit doesn't
  /// re-post it.
  String? _shown;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _schedule());
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
    if (state == AppLifecycleState.resumed) _schedule();
  }

  /// Starts and stops tapped on the widget, at the time they were tapped.
  Future<void> _applyWidgetTaps() async {
    final taps = await const TimerWidget().takePending();
    if (taps.isEmpty) return;
    final repo = ref.read(timeRepositoryProvider);
    final projects = {for (final p in await repo.allProjects()) p.id: p};
    for (final t in taps) {
      if (t.stop) {
        await repo.stopAll(at: t.at);
      } else {
        final project = projects[t.projectId];
        await repo.start(projectId: project?.id, billable: project?.billable ?? false, at: t.at);
      }
    }
  }

  Future<void> _publishWidget() async {
    final entries = ref.read(entriesProvider).value;
    final projects = ref.read(projectsProvider).value;
    if (entries == null || projects == null) return;
    final next = TimerWidgetState.from(
      entries: entries,
      projects: projects,
      details: ref.read(timeSettingsProvider).widgetDetails,
    );
    if (next == _widgetShown) return;
    _widgetShown = next;
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
          : 'Timer running';
      final hours = settings.nudgeAfterHours;
      final key = '${entry.id}|${entry.start.toIso8601String()}|$title|$hours';
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
    return const HomePage();
  }
}
