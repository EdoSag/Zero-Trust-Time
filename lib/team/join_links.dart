import 'package:flutter/foundation.dart';

/// A team invite link (https://zerotrust.bz/join/time#zt1.time.…) opened
/// on this phone, waiting for the unlocked app to show the join screen.
/// The invite is after the #, so it never reached the website.
abstract final class JoinLinks {
  static final pending = ValueNotifier<String?>(null);

  static bool isInvite(Uri uri) =>
      uri.host == 'zerotrust.bz' && uri.path.startsWith('/join/time');
}
