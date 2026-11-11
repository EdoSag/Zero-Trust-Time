// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_l10n.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppL10nEn extends AppL10n {
  AppL10nEn([String locale = 'en']) : super(locale);

  @override
  String get today => 'Today';

  @override
  String get yesterday => 'Yesterday';

  @override
  String get tomorrow => 'Tomorrow';

  @override
  String durationDecimalHours(String hours) {
    return '$hours h';
  }

  @override
  String durationMinutes(int m) {
    return '${m}m';
  }

  @override
  String durationHours(int h) {
    return '${h}h';
  }

  @override
  String durationHoursMinutes(int h, int m) {
    return '${h}h ${m}m';
  }

  @override
  String get tabTimer => 'Timer';

  @override
  String get tabReports => 'Reports';

  @override
  String get tabProjects => 'Projects';

  @override
  String get settingsTooltip => 'Settings';

  @override
  String get addTimeByHand => 'Add time by hand';

  @override
  String get newProject => 'New project';

  @override
  String get couldNotLoadProjects => 'Could not load your projects';

  @override
  String perHour(String amount) {
    return '$amount/h';
  }

  @override
  String get archived => 'Archived';

  @override
  String get noProjectsYet => 'No projects yet';

  @override
  String get noProjectsBody =>
      'Group your time by project or client, and set an hourly rate to see what it is worth.';

  @override
  String get noProject => 'No project';

  @override
  String get exportTimesheetTitle => 'Export a timesheet';

  @override
  String get exportNotEncrypted =>
      'The file is not encrypted. Anyone who gets it can read your entries. Share it only with people and apps you trust.';

  @override
  String get formatXlsx => 'Excel (.xlsx)';

  @override
  String get formatXlsxApps => 'Excel, Google Sheets, Numbers';

  @override
  String get formatOds => 'LibreOffice (.ods)';

  @override
  String get formatOdsApps => 'LibreOffice, OpenOffice, Collabora';

  @override
  String get formatCsv => 'CSV (.csv)';

  @override
  String get formatCsvApps => 'Plain text for any app, and Toggl or Clockify';

  @override
  String get cancel => 'Cancel';

  @override
  String get sheetTimeEntries => 'Time entries';

  @override
  String get couldNotLoadEntries => 'Could not load your time entries';

  @override
  String get showOlderEntries => 'Show older entries';

  @override
  String get whatAreYouWorkingOn => 'What are you working on?';

  @override
  String get billable => 'Billable';

  @override
  String get start => 'Start';

  @override
  String get stop => 'Stop';

  @override
  String get noDescription => '(No description)';

  @override
  String runningSince(String project, String time) {
    return '$project · since $time';
  }

  @override
  String get entryDeleted => 'Entry deleted';

  @override
  String get undo => 'Undo';

  @override
  String get startAgain => 'Start again';

  @override
  String get nothingTrackedYet => 'Nothing tracked yet';

  @override
  String get nothingTrackedBody =>
      'Start the timer above, or add time by hand with the + button. Everything is encrypted on this phone before it syncs.';

  @override
  String get endBeforeStart => 'The end is before the start';

  @override
  String get runningInFuture => 'A running timer can\'t start in the future';

  @override
  String get discardTimerQuestion => 'Discard this timer?';

  @override
  String get deleteEntryQuestion => 'Delete this entry?';

  @override
  String get discard => 'Discard';

  @override
  String get delete => 'Delete';

  @override
  String get runningTimer => 'Running timer';

  @override
  String get editEntry => 'Edit entry';

  @override
  String get addTime => 'Add time';

  @override
  String get discardTimer => 'Discard timer';

  @override
  String get deleteEntry => 'Delete entry';

  @override
  String get save => 'Save';

  @override
  String get description => 'Description';

  @override
  String get end => 'End';

  @override
  String get tags => 'Tags';

  @override
  String get tagsHelper => 'Separate with commas: meeting, design';

  @override
  String get nothingToExportPeriod => 'Nothing to export in this period';

  @override
  String get periodDay => 'Day';

  @override
  String get periodWeek => 'Week';

  @override
  String get periodMonth => 'Month';

  @override
  String get periodYear => 'Year';

  @override
  String get periodCustom => 'Custom';

  @override
  String get earlier => 'Earlier';

  @override
  String get later => 'Later';

  @override
  String get exportPeriod => 'Export this period (Excel, LibreOffice or CSV)';

  @override
  String get total => 'Total';

  @override
  String get amount => 'Amount';

  @override
  String get noTimeInPeriod => 'No time tracked in this period';

  @override
  String barTooltip(String label, String duration) {
    return '$label: $duration';
  }

  @override
  String get projectNameRequired => 'Give the project a name';

  @override
  String get rateInvalid => 'Enter a number, like 60 or 42.50';

  @override
  String get deleteProjectQuestion => 'Delete this project?';

  @override
  String get deleteProjectBody =>
      'Its time entries are kept and show as \"No project\". To hide a project but keep its reports, archive it instead.';

  @override
  String get editProject => 'Edit project';

  @override
  String get deleteProject => 'Delete project';

  @override
  String get projectName => 'Project name';

  @override
  String get clientOptional => 'Client (optional)';

  @override
  String get colour => 'Colour';

  @override
  String colourNumber(int n) {
    return 'Colour $n';
  }

  @override
  String get hourlyRateOptional => 'Hourly rate (optional)';

  @override
  String get hourlyRateHelper => 'Reports turn billable hours into an amount';

  @override
  String get billableByDefault => 'Billable by default';

  @override
  String get billableByDefaultBody =>
      'New entries on this project start as billable';

  @override
  String get archivedBody => 'Hidden when picking a project; reports keep it';

  @override
  String get startOfWeek => 'Start of the week';

  @override
  String likeYourRegionDay(String day) {
    return 'Like your region ($day)';
  }

  @override
  String get likeYourRegion => 'Like your region';

  @override
  String get currency => 'Currency';

  @override
  String currencySubtitle(String currency) {
    return '$currency  (for hourly rates and amounts)';
  }

  @override
  String get decimalHours => 'Decimal hours';

  @override
  String get decimalHoursBody => 'Show totals as 7.50 h instead of 7h 30m';

  @override
  String get runningNotification => 'Notification while a timer runs';

  @override
  String get runningNotificationBody =>
      'A lasting notification with a live clock (Android)';

  @override
  String get notificationDescription => 'Description in that notification';

  @override
  String get notificationDescriptionBody =>
      'Off: it only says \"Timer running\". On, the description is handed to the phone so it can show while Time is locked.';

  @override
  String get widgetDetails => 'Show details on the home screen';

  @override
  String get widgetDetailsBody =>
      'Off: the timer widget shows only \"Timer running\" and the clock. On: what you are tracking and your recent projects are stored unencrypted on this phone for the home screen.';

  @override
  String get remindLongTimer => 'Remind me about a long timer';

  @override
  String get never => 'Never';

  @override
  String afterHours(int hours) {
    return 'After $hours hours';
  }

  @override
  String get importTimesheet => 'Import a timesheet';

  @override
  String get importTimesheetBody =>
      'Excel, LibreOffice, Google Sheets or CSV; Toggl Track, Clockify or ZT Time';

  @override
  String get exportAllEntries => 'Export all entries';

  @override
  String get exportAllEntriesBody =>
      'Excel, LibreOffice or CSV. Unencrypted, for spreadsheets and invoicing';

  @override
  String get other => 'Other';

  @override
  String get useThis => 'Use this';

  @override
  String get nothingToExportYet => 'There is nothing to export yet';

  @override
  String get importHelp =>
      'Choose an Excel (.xlsx), LibreOffice (.ods) or CSV file. From Google Sheets: File, Download, Microsoft Excel.\n\nThe sheet needs a \"Start date\" column, and an end time or a duration. Toggl Track and Clockify detailed reports work as they are.\n\nProjects in the file are created if you don\'t have them. Importing the same file again skips entries you already have.';

  @override
  String get chooseFile => 'Choose file';

  @override
  String get chooseSpreadsheet => 'Choose a spreadsheet or .csv file';

  @override
  String importedEntries(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Imported $count entries',
      one: 'Imported 1 entry',
    );
    return '$_temp0';
  }

  @override
  String importedProjects(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'and $count new projects',
      one: 'and 1 new project',
    );
    return '$_temp0';
  }

  @override
  String importedSkipped(int count) {
    return 'skipped $count already here';
  }

  @override
  String importedUnreadable(int count) {
    return '$count rows had no readable times';
  }

  @override
  String couldNotImportReason(String reason) {
    return 'Could not import that file: $reason';
  }

  @override
  String get couldNotImport => 'Could not import that file';

  @override
  String get errFileEmpty => 'The file is empty';

  @override
  String get errNoStartDate => 'No \"Start date\" column in this file';

  @override
  String get errFileDamaged => 'The file is damaged';

  @override
  String get errNotSpreadsheet => 'Not a spreadsheet. Use .xlsx, .ods or .csv';

  @override
  String get errOldXls =>
      'Old .xls files can\'t be read. Save it as .xlsx or .csv first';

  @override
  String get timerRunning => 'Timer running';

  @override
  String get tapToOpen => 'Tap to open ZT Time';

  @override
  String get channelRunning => 'Running timer';

  @override
  String get channelRunningBody => 'Shows while a timer is running';

  @override
  String get timerStillRunning => 'Timer still running';

  @override
  String get timerStillRunningBody =>
      'Your timer has been running for a while. Still working?';

  @override
  String get channelLong => 'Long-running timer';

  @override
  String get channelLongBody => 'A reminder when a timer runs for hours';

  @override
  String get widgetStopTimer => 'Stop the timer';

  @override
  String get widgetSignedOut => 'Signed out';

  @override
  String get widgetNotTracking => 'Not tracking';

  @override
  String get widgetOpenToStart => 'Open ZT Time to start tracking';

  @override
  String get widgetTapPlay => 'Tap play to start a timer';

  @override
  String get widgetOpenApp => 'Open ZT Time';

  @override
  String get widgetStartTimer => 'Start a timer';

  @override
  String widgetStartTimerFor(String project) {
    return 'Start a timer for $project';
  }
}
