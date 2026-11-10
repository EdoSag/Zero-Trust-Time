import 'package:flutter/material.dart';
import 'package:zero_trust_core/zero_trust_core.dart';

/// Time in the suite. Not in the core's `ZtSuite` list yet, so the other
/// apps don't link to it before it's released.
const ZtSuiteApp timeSuiteApp = ZtSuiteApp(
  appId: 'time',
  name: 'Time',
  tagline: 'Time tracking, projects and reports',
  icon: Icons.timer_outlined,
  accent: Color(0xFF3B82F6), // blue
  androidPackage: 'dev.sagron.zerotrusttime',
);

const ZtAppConfig timeAppConfig = ZtAppConfig(
  appId: 'time',
  displayName: 'Zero-Trust Time',
  accent: Color(0xFF3B82F6),
);
