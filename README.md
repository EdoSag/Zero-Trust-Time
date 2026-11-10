# Zero-Trust Time

An end-to-end encrypted time tracker (on the phone: **ZT Time**). Same
account, settings and look as the other Zero-Trust apps, built on
[Zero-Trust-Core](https://github.com/EdoSag/Zero-Trust-Core).

This is the personal mode: one person tracking their own time. It replaces
the earlier TimeSpot app; a business mode (teams, shared timesheets) comes
later, once the suite has sharing between accounts.

## What it does

- **Timer:** type what you're working on, pick a project, press Start. One
  timer runs at a time; starting another stops the first. A running timer
  is synced, so your other devices show it running too.
- **Entries:** add time by hand, edit start and end, tags, billable flag.
  Swipe to delete (with undo), or "start again" to continue an old entry.
- **Projects:** colour, client, hourly rate, billable by default, archive.
- **Reports:** day, week, month, year or any range: total, billable time,
  amount (billable hours at each project's rate), a bar per day and a
  breakdown by project.
- **Export:** a period or everything as CSV (Toggl Track's column names).
- **Import:** CSV exports from Toggl Track, Clockify or this app. Missing
  projects are created; importing the same file again skips what's there.
- **Notification** (Android): a lasting notification with a live clock
  while a timer runs, and a "still running?" reminder after 8 hours
  (2 to 12, or never).

## Privacy

- Entries and projects are items in the shared `vault_items` table,
  encrypted on the device with the Time app key (`app = 'time'`, kinds
  `entry` and `project`). No database change was needed.
- The running-timer notification says only "Timer running" unless you turn
  on **Description in that notification**; then that one line is handed to
  the phone so it can show while the app is locked.
- CSV exports are plain files; the app says so before sharing one.

## Build

```bash
# .env (not committed; CI writes its own)
SUPABASE_URL=https://<project>.supabase.co
SUPABASE_ANON_KEY=<publishable key>

flutter pub get
flutter analyze && flutter test test/
flutter run
```

Pushing to `main` builds a signed APK and publishes it as a GitHub Release
(`.github/workflows/android-apk.yml`). It needs the repository secrets
`ANDROID_KEYSTORE_BASE64` and `ANDROID_KEYSTORE_PASSWORD`, the same
keystore as the other Zero-Trust apps.

Launcher icons are drawn from the suite's brand mark:
`flutter test tool/launcher_icon_test.dart`.
