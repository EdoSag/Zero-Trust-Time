# Zero-Trust Time

An end-to-end encrypted time tracker for freelancers and anyone who bills by
the hour. On the phone it is called **ZT Time**; in stores and on release
pages, **Zero-Trust Time**. Same account, settings and look as the other
Zero-Trust apps, built on
[Zero-Trust-Core](https://github.com/EdoSag/Zero-Trust-Core). Part of the
[Zero-Trust suite](https://zerotrust.bz).

It replaces the earlier TimeSpot app. One person can track their own time,
and a team can track time together.

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
- **Export:** a period or everything as Excel (.xlsx), LibreOffice (.ods) or
  CSV, with Toggl Track's column names. Spreadsheet files hold real dates,
  times, durations and numbers, so sorting and sums work. CSV is UTF-8 with a
  byte-order mark, so Excel shows Hebrew correctly.
- **Import:** .xlsx (Excel, Google Sheets), .ods (LibreOffice) or CSV,
  including exports from Toggl Track, Clockify or this app. Columns are found
  by name (a "Start date" column plus an end time or a duration). Missing
  projects are created; importing the same file again skips what's there.
  Everything is read and written on the phone.
- **Notification** (Android): a lasting notification with a live clock
  while a timer runs, and a "still running?" reminder after 8 hours
  (2 to 12, or never).
- **Start and stop by place** (Settings, off until you add a place): a timer
  starts when you arrive at the office or a client and stops when you
  leave. Each place can have its own project and a wait before starting and
  stopping (so driving past doesn't start a timer). The phone watches the
  place itself (Core's `zt_places`, no Google Play services). It works
  while Time is locked: the entry is saved the next time you open it.
- **Teams:** make a team and invite people by link or QR code. Members
  track time on the team's projects and see the team's reports; only
  owners change projects and rates. End-to-end encrypted (Core's shared
  spaces).
- **Home screen widget** (Android): the running timer with Stop, and your
  recent projects to start one.
- **From the other apps:** ZT Tasks can start a timer for a task ("Track
  time in ZT Time"), and ZT Clock can log a stopwatch or a timer as an
  entry.

## Privacy

Like every Zero-Trust app, it is zero-knowledge: your data is encrypted on
your device, with keys made from your password, before anything is sent.
The server stores only ciphertext and your password itself is never
sent, so neither we nor anyone who breaks into the server can read your
data. The recovery key shown at sign-up is the only way back in if you
forget the password. How the keys work:
[Zero-Trust-Core](https://github.com/EdoSag/Zero-Trust-Core#key-hierarchy) and
[zerotrust.bz/security](https://zerotrust.bz/security/).

- Entries and projects are items in the shared `vault_items` table,
  encrypted on the device with the Time app key (`app = 'time'`, kinds
  `entry` and `project`). No database change was needed.
- The running-timer notification says only "Timer running" unless you turn
  on **Description in that notification**; then that one line is handed to
  the phone so it can show while the app is locked.
- Exported spreadsheets are plain files; the app says so before sharing one.
- The widget shows only "Timer running" and the clock until "Show details
  on the home screen" is on; then what you are tracking and your recent
  projects are kept unencrypted on this phone for the launcher.
- Places are watched on the phone. Your location never leaves it.

## One account, one core

One Zero-Trust account opens every app in the suite. Sign-in, unlock
(fingerprint or face, auto-lock), the recovery key, settings, the look,
sync and languages come from
[Zero-Trust-Core](https://github.com/EdoSag/Zero-Trust-Core), so they work
the same in every app. Accounts made before the core still sign in and
see their data.

## Install

Android: get the latest signed APK from this repository's
[Releases](https://github.com/EdoSag/Zero-Trust-Time/releases/latest),
or from [zerotrust.bz/install](https://zerotrust.bz/install/#time),
which also shows each file's SHA-256, the signing fingerprint and an
Obtainium link. GitHub Releases are the main way the apps are published.

Builds from GitHub check for a newer release themselves (Settings > About,
one anonymous request a day, can be turned off). Every Zero-Trust app is signed
with the same key, and Android only installs an update signed with it.

## Languages

English and Hebrew, with right-to-left layout. Choose under
Settings > Appearance > Language.

## Build from source

Flutter 3.47.9, the version CI pins (3.50 deprecates `material.dart` and
fails analyze).

```bash
# .env (not committed; CI writes its own). Public client values only:
# never a service-role key, because .env is bundled into the APK.
SUPABASE_URL=https://<project>.supabase.co
SUPABASE_ANON_KEY=<publishable key>

flutter pub get
dart run zt_release_checks --app time   # shared release checks
flutter analyze && flutter test test/
flutter run
```

Never add `cryptography_flutter`: it breaks the core's key derivation and
sign-in fails.

Launcher icons are drawn from the suite's brand mark:
`flutter test tool/launcher_icon_test.dart`.

## Branches and releases

Work happens on `Dev`: pull requests target `Dev`, never `main`, and get a
test build. A release is one `Dev` → `main` pull request. Every push to
`main` runs the suite's release checks, builds a signed APK and a Google Play bundle
and publishes them as a GitHub Release named "Zero-Trust Time"
(`.github/workflows/android-apk.yml`). The workflow needs the repository
secrets `ANDROID_KEYSTORE_BASE64` and `ANDROID_KEYSTORE_PASSWORD`, the
keystore shared by all Zero-Trust apps.

## Support and security

- Help centre: [zerotrust.bz/help](https://zerotrust.bz/help/). Questions and
  account deletion: support@zerotrust.bz.
- Security problems: please report them privately to cyber@zerotrust.bz. What
  the encryption does and doesn't protect against is on
  [zerotrust.bz/security](https://zerotrust.bz/security/).
- [Privacy policy](https://zerotrust.bz/privacy/) and
  [terms](https://zerotrust.bz/terms/).

## License

Copyright (C) 2026 Edo Sagron (https://zerotrust.bz)

Zero-Trust is open source under the [GNU Affero General Public License v3.0](LICENSE)
(AGPL-3.0-only), the same licence Signal uses.

- You may use, study, change and share the code, including in your own projects.
- If you share a changed version, or run it for other people over a network, you must
  publish your full source code under the same licence.
- This program comes with no warranty; see the licence for details.

Third-party libraries keep their own licences; the app lists them under
Settings > Open-source licences.

### Name and logo

The AGPL covers the code, not the brand. "Zero-Trust", "ZT", the app names and icons are
reserved. If you publish a fork, give it a different name and icon so nobody mistakes it
for an official Zero-Trust app.

### Servers

The official apps use the Zero-Trust servers. A fork must use its own backend (for
example its own Supabase project) and must not connect to the official servers.

### Contributing

Pull requests are welcome. By sending one you agree that your contribution is licensed
under the AGPL-3.0 and that the copyright holder may also license it under other terms,
including commercially. This keeps the project able to offer paid plans and other licences.
