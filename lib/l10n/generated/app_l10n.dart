import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_l10n_en.dart';
import 'app_l10n_he.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppL10n
/// returned by `AppL10n.of(context)`.
///
/// Applications need to include `AppL10n.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_l10n.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppL10n.localizationsDelegates,
///   supportedLocales: AppL10n.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppL10n.supportedLocales
/// property.
abstract class AppL10n {
  AppL10n(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppL10n of(BuildContext context) {
    return Localizations.of<AppL10n>(context, AppL10n)!;
  }

  static const LocalizationsDelegate<AppL10n> delegate = _AppL10nDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('he'),
  ];

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// No description provided for @yesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get yesterday;

  /// No description provided for @tomorrow.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow'**
  String get tomorrow;

  /// No description provided for @durationDecimalHours.
  ///
  /// In en, this message translates to:
  /// **'{hours} h'**
  String durationDecimalHours(String hours);

  /// No description provided for @durationMinutes.
  ///
  /// In en, this message translates to:
  /// **'{m}m'**
  String durationMinutes(int m);

  /// No description provided for @durationHours.
  ///
  /// In en, this message translates to:
  /// **'{h}h'**
  String durationHours(int h);

  /// No description provided for @durationHoursMinutes.
  ///
  /// In en, this message translates to:
  /// **'{h}h {m}m'**
  String durationHoursMinutes(int h, int m);

  /// No description provided for @tabTimer.
  ///
  /// In en, this message translates to:
  /// **'Timer'**
  String get tabTimer;

  /// No description provided for @tabReports.
  ///
  /// In en, this message translates to:
  /// **'Reports'**
  String get tabReports;

  /// No description provided for @tabProjects.
  ///
  /// In en, this message translates to:
  /// **'Projects'**
  String get tabProjects;

  /// No description provided for @settingsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTooltip;

  /// No description provided for @addTimeByHand.
  ///
  /// In en, this message translates to:
  /// **'Add time by hand'**
  String get addTimeByHand;

  /// No description provided for @newProject.
  ///
  /// In en, this message translates to:
  /// **'New project'**
  String get newProject;

  /// No description provided for @couldNotLoadProjects.
  ///
  /// In en, this message translates to:
  /// **'Could not load your projects'**
  String get couldNotLoadProjects;

  /// No description provided for @perHour.
  ///
  /// In en, this message translates to:
  /// **'{amount}/h'**
  String perHour(String amount);

  /// No description provided for @archived.
  ///
  /// In en, this message translates to:
  /// **'Archived'**
  String get archived;

  /// No description provided for @noProjectsYet.
  ///
  /// In en, this message translates to:
  /// **'No projects yet'**
  String get noProjectsYet;

  /// No description provided for @noProjectsBody.
  ///
  /// In en, this message translates to:
  /// **'Group your time by project or client, and set an hourly rate to see what it is worth.'**
  String get noProjectsBody;

  /// No description provided for @noProject.
  ///
  /// In en, this message translates to:
  /// **'No project'**
  String get noProject;

  /// No description provided for @exportTimesheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Export a timesheet'**
  String get exportTimesheetTitle;

  /// No description provided for @exportNotEncrypted.
  ///
  /// In en, this message translates to:
  /// **'The file is not encrypted. Anyone who gets it can read your entries. Share it only with people and apps you trust.'**
  String get exportNotEncrypted;

  /// No description provided for @formatXlsx.
  ///
  /// In en, this message translates to:
  /// **'Excel (.xlsx)'**
  String get formatXlsx;

  /// No description provided for @formatXlsxApps.
  ///
  /// In en, this message translates to:
  /// **'Excel, Google Sheets, Numbers'**
  String get formatXlsxApps;

  /// No description provided for @formatOds.
  ///
  /// In en, this message translates to:
  /// **'LibreOffice (.ods)'**
  String get formatOds;

  /// No description provided for @formatOdsApps.
  ///
  /// In en, this message translates to:
  /// **'LibreOffice, OpenOffice, Collabora'**
  String get formatOdsApps;

  /// No description provided for @formatCsv.
  ///
  /// In en, this message translates to:
  /// **'CSV (.csv)'**
  String get formatCsv;

  /// No description provided for @formatCsvApps.
  ///
  /// In en, this message translates to:
  /// **'Plain text for any app, and Toggl or Clockify'**
  String get formatCsvApps;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @sheetTimeEntries.
  ///
  /// In en, this message translates to:
  /// **'Time entries'**
  String get sheetTimeEntries;

  /// No description provided for @couldNotLoadEntries.
  ///
  /// In en, this message translates to:
  /// **'Could not load your time entries'**
  String get couldNotLoadEntries;

  /// No description provided for @showOlderEntries.
  ///
  /// In en, this message translates to:
  /// **'Show older entries'**
  String get showOlderEntries;

  /// No description provided for @whatAreYouWorkingOn.
  ///
  /// In en, this message translates to:
  /// **'What are you working on?'**
  String get whatAreYouWorkingOn;

  /// No description provided for @billable.
  ///
  /// In en, this message translates to:
  /// **'Billable'**
  String get billable;

  /// No description provided for @start.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get start;

  /// No description provided for @stop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get stop;

  /// No description provided for @noDescription.
  ///
  /// In en, this message translates to:
  /// **'(No description)'**
  String get noDescription;

  /// No description provided for @runningSince.
  ///
  /// In en, this message translates to:
  /// **'{project} · since {time}'**
  String runningSince(String project, String time);

  /// No description provided for @entryDeleted.
  ///
  /// In en, this message translates to:
  /// **'Entry deleted'**
  String get entryDeleted;

  /// No description provided for @undo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get undo;

  /// No description provided for @startAgain.
  ///
  /// In en, this message translates to:
  /// **'Start again'**
  String get startAgain;

  /// No description provided for @nothingTrackedYet.
  ///
  /// In en, this message translates to:
  /// **'Nothing tracked yet'**
  String get nothingTrackedYet;

  /// No description provided for @nothingTrackedBody.
  ///
  /// In en, this message translates to:
  /// **'Start the timer above, or add time by hand with the + button. Everything is encrypted on this phone before it syncs.'**
  String get nothingTrackedBody;

  /// No description provided for @endBeforeStart.
  ///
  /// In en, this message translates to:
  /// **'The end is before the start'**
  String get endBeforeStart;

  /// No description provided for @runningInFuture.
  ///
  /// In en, this message translates to:
  /// **'A running timer can\'t start in the future'**
  String get runningInFuture;

  /// No description provided for @discardTimerQuestion.
  ///
  /// In en, this message translates to:
  /// **'Discard this timer?'**
  String get discardTimerQuestion;

  /// No description provided for @deleteEntryQuestion.
  ///
  /// In en, this message translates to:
  /// **'Delete this entry?'**
  String get deleteEntryQuestion;

  /// No description provided for @discard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get discard;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @runningTimer.
  ///
  /// In en, this message translates to:
  /// **'Running timer'**
  String get runningTimer;

  /// No description provided for @editEntry.
  ///
  /// In en, this message translates to:
  /// **'Edit entry'**
  String get editEntry;

  /// No description provided for @addTime.
  ///
  /// In en, this message translates to:
  /// **'Add time'**
  String get addTime;

  /// No description provided for @discardTimer.
  ///
  /// In en, this message translates to:
  /// **'Discard timer'**
  String get discardTimer;

  /// No description provided for @deleteEntry.
  ///
  /// In en, this message translates to:
  /// **'Delete entry'**
  String get deleteEntry;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @description.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get description;

  /// No description provided for @end.
  ///
  /// In en, this message translates to:
  /// **'End'**
  String get end;

  /// No description provided for @tags.
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get tags;

  /// No description provided for @tagsHelper.
  ///
  /// In en, this message translates to:
  /// **'Separate with commas: meeting, design'**
  String get tagsHelper;

  /// No description provided for @nothingToExportPeriod.
  ///
  /// In en, this message translates to:
  /// **'Nothing to export in this period'**
  String get nothingToExportPeriod;

  /// No description provided for @periodDay.
  ///
  /// In en, this message translates to:
  /// **'Day'**
  String get periodDay;

  /// No description provided for @periodWeek.
  ///
  /// In en, this message translates to:
  /// **'Week'**
  String get periodWeek;

  /// No description provided for @periodMonth.
  ///
  /// In en, this message translates to:
  /// **'Month'**
  String get periodMonth;

  /// No description provided for @periodYear.
  ///
  /// In en, this message translates to:
  /// **'Year'**
  String get periodYear;

  /// No description provided for @periodCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get periodCustom;

  /// No description provided for @earlier.
  ///
  /// In en, this message translates to:
  /// **'Earlier'**
  String get earlier;

  /// No description provided for @later.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get later;

  /// No description provided for @exportPeriod.
  ///
  /// In en, this message translates to:
  /// **'Export this period (Excel, LibreOffice or CSV)'**
  String get exportPeriod;

  /// No description provided for @total.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get total;

  /// No description provided for @amount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get amount;

  /// No description provided for @noTimeInPeriod.
  ///
  /// In en, this message translates to:
  /// **'No time tracked in this period'**
  String get noTimeInPeriod;

  /// No description provided for @barTooltip.
  ///
  /// In en, this message translates to:
  /// **'{label}: {duration}'**
  String barTooltip(String label, String duration);

  /// No description provided for @projectNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Give the project a name'**
  String get projectNameRequired;

  /// No description provided for @rateInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a number, like 60 or 42.50'**
  String get rateInvalid;

  /// No description provided for @deleteProjectQuestion.
  ///
  /// In en, this message translates to:
  /// **'Delete this project?'**
  String get deleteProjectQuestion;

  /// No description provided for @deleteProjectBody.
  ///
  /// In en, this message translates to:
  /// **'Its time entries are kept and show as \"No project\". To hide a project but keep its reports, archive it instead.'**
  String get deleteProjectBody;

  /// No description provided for @editProject.
  ///
  /// In en, this message translates to:
  /// **'Edit project'**
  String get editProject;

  /// No description provided for @deleteProject.
  ///
  /// In en, this message translates to:
  /// **'Delete project'**
  String get deleteProject;

  /// No description provided for @projectName.
  ///
  /// In en, this message translates to:
  /// **'Project name'**
  String get projectName;

  /// No description provided for @clientOptional.
  ///
  /// In en, this message translates to:
  /// **'Client (optional)'**
  String get clientOptional;

  /// No description provided for @colour.
  ///
  /// In en, this message translates to:
  /// **'Colour'**
  String get colour;

  /// No description provided for @colourNumber.
  ///
  /// In en, this message translates to:
  /// **'Colour {n}'**
  String colourNumber(int n);

  /// No description provided for @hourlyRateOptional.
  ///
  /// In en, this message translates to:
  /// **'Hourly rate (optional)'**
  String get hourlyRateOptional;

  /// No description provided for @hourlyRateHelper.
  ///
  /// In en, this message translates to:
  /// **'Reports turn billable hours into an amount'**
  String get hourlyRateHelper;

  /// No description provided for @billableByDefault.
  ///
  /// In en, this message translates to:
  /// **'Billable by default'**
  String get billableByDefault;

  /// No description provided for @billableByDefaultBody.
  ///
  /// In en, this message translates to:
  /// **'New entries on this project start as billable'**
  String get billableByDefaultBody;

  /// No description provided for @archivedBody.
  ///
  /// In en, this message translates to:
  /// **'Hidden when picking a project; reports keep it'**
  String get archivedBody;

  /// No description provided for @startOfWeek.
  ///
  /// In en, this message translates to:
  /// **'Start of the week'**
  String get startOfWeek;

  /// No description provided for @likeYourRegionDay.
  ///
  /// In en, this message translates to:
  /// **'Like your region ({day})'**
  String likeYourRegionDay(String day);

  /// No description provided for @likeYourRegion.
  ///
  /// In en, this message translates to:
  /// **'Like your region'**
  String get likeYourRegion;

  /// No description provided for @currency.
  ///
  /// In en, this message translates to:
  /// **'Currency'**
  String get currency;

  /// No description provided for @currencySubtitle.
  ///
  /// In en, this message translates to:
  /// **'{currency}  (for hourly rates and amounts)'**
  String currencySubtitle(String currency);

  /// No description provided for @decimalHours.
  ///
  /// In en, this message translates to:
  /// **'Decimal hours'**
  String get decimalHours;

  /// No description provided for @decimalHoursBody.
  ///
  /// In en, this message translates to:
  /// **'Show totals as 7.50 h instead of 7h 30m'**
  String get decimalHoursBody;

  /// No description provided for @runningNotification.
  ///
  /// In en, this message translates to:
  /// **'Notification while a timer runs'**
  String get runningNotification;

  /// No description provided for @runningNotificationBody.
  ///
  /// In en, this message translates to:
  /// **'A lasting notification with a live clock (Android)'**
  String get runningNotificationBody;

  /// No description provided for @notificationDescription.
  ///
  /// In en, this message translates to:
  /// **'Description in that notification'**
  String get notificationDescription;

  /// No description provided for @notificationDescriptionBody.
  ///
  /// In en, this message translates to:
  /// **'Off: it only says \"Timer running\". On, the description is handed to the phone so it can show while Time is locked.'**
  String get notificationDescriptionBody;

  /// No description provided for @widgetDetails.
  ///
  /// In en, this message translates to:
  /// **'Show details on the home screen'**
  String get widgetDetails;

  /// No description provided for @widgetDetailsBody.
  ///
  /// In en, this message translates to:
  /// **'Off: the timer widget shows only \"Timer running\" and the clock. On: what you are tracking and your recent projects are stored unencrypted on this phone for the home screen.'**
  String get widgetDetailsBody;

  /// No description provided for @remindLongTimer.
  ///
  /// In en, this message translates to:
  /// **'Remind me about a long timer'**
  String get remindLongTimer;

  /// No description provided for @never.
  ///
  /// In en, this message translates to:
  /// **'Never'**
  String get never;

  /// No description provided for @afterHours.
  ///
  /// In en, this message translates to:
  /// **'After {hours} hours'**
  String afterHours(int hours);

  /// No description provided for @importTimesheet.
  ///
  /// In en, this message translates to:
  /// **'Import a timesheet'**
  String get importTimesheet;

  /// No description provided for @importTimesheetBody.
  ///
  /// In en, this message translates to:
  /// **'Excel, LibreOffice, Google Sheets or CSV; Toggl Track, Clockify or ZT Time'**
  String get importTimesheetBody;

  /// No description provided for @exportAllEntries.
  ///
  /// In en, this message translates to:
  /// **'Export all entries'**
  String get exportAllEntries;

  /// No description provided for @exportAllEntriesBody.
  ///
  /// In en, this message translates to:
  /// **'Excel, LibreOffice or CSV. Unencrypted, for spreadsheets and invoicing'**
  String get exportAllEntriesBody;

  /// No description provided for @other.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get other;

  /// No description provided for @useThis.
  ///
  /// In en, this message translates to:
  /// **'Use this'**
  String get useThis;

  /// No description provided for @nothingToExportYet.
  ///
  /// In en, this message translates to:
  /// **'There is nothing to export yet'**
  String get nothingToExportYet;

  /// No description provided for @importHelp.
  ///
  /// In en, this message translates to:
  /// **'Choose an Excel (.xlsx), LibreOffice (.ods) or CSV file. From Google Sheets: File, Download, Microsoft Excel.\n\nThe sheet needs a \"Start date\" column, and an end time or a duration. Toggl Track and Clockify detailed reports work as they are.\n\nProjects in the file are created if you don\'t have them. Importing the same file again skips entries you already have.'**
  String get importHelp;

  /// No description provided for @chooseFile.
  ///
  /// In en, this message translates to:
  /// **'Choose file'**
  String get chooseFile;

  /// No description provided for @chooseSpreadsheet.
  ///
  /// In en, this message translates to:
  /// **'Choose a spreadsheet or .csv file'**
  String get chooseSpreadsheet;

  /// No description provided for @importedEntries.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Imported 1 entry} other{Imported {count} entries}}'**
  String importedEntries(int count);

  /// No description provided for @importedProjects.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{and 1 new project} other{and {count} new projects}}'**
  String importedProjects(int count);

  /// No description provided for @importedSkipped.
  ///
  /// In en, this message translates to:
  /// **'skipped {count} already here'**
  String importedSkipped(int count);

  /// No description provided for @importedUnreadable.
  ///
  /// In en, this message translates to:
  /// **'{count} rows had no readable times'**
  String importedUnreadable(int count);

  /// No description provided for @couldNotImportReason.
  ///
  /// In en, this message translates to:
  /// **'Could not import that file: {reason}'**
  String couldNotImportReason(String reason);

  /// No description provided for @couldNotImport.
  ///
  /// In en, this message translates to:
  /// **'Could not import that file'**
  String get couldNotImport;

  /// No description provided for @errFileEmpty.
  ///
  /// In en, this message translates to:
  /// **'The file is empty'**
  String get errFileEmpty;

  /// No description provided for @errNoStartDate.
  ///
  /// In en, this message translates to:
  /// **'No \"Start date\" column in this file'**
  String get errNoStartDate;

  /// No description provided for @errFileDamaged.
  ///
  /// In en, this message translates to:
  /// **'The file is damaged'**
  String get errFileDamaged;

  /// No description provided for @errNotSpreadsheet.
  ///
  /// In en, this message translates to:
  /// **'Not a spreadsheet. Use .xlsx, .ods or .csv'**
  String get errNotSpreadsheet;

  /// No description provided for @errOldXls.
  ///
  /// In en, this message translates to:
  /// **'Old .xls files can\'t be read. Save it as .xlsx or .csv first'**
  String get errOldXls;

  /// No description provided for @timerRunning.
  ///
  /// In en, this message translates to:
  /// **'Timer running'**
  String get timerRunning;

  /// No description provided for @tapToOpen.
  ///
  /// In en, this message translates to:
  /// **'Tap to open ZT Time'**
  String get tapToOpen;

  /// No description provided for @channelRunning.
  ///
  /// In en, this message translates to:
  /// **'Running timer'**
  String get channelRunning;

  /// No description provided for @channelRunningBody.
  ///
  /// In en, this message translates to:
  /// **'Shows while a timer is running'**
  String get channelRunningBody;

  /// No description provided for @timerStillRunning.
  ///
  /// In en, this message translates to:
  /// **'Timer still running'**
  String get timerStillRunning;

  /// No description provided for @timerStillRunningBody.
  ///
  /// In en, this message translates to:
  /// **'Your timer has been running for a while. Still working?'**
  String get timerStillRunningBody;

  /// No description provided for @channelLong.
  ///
  /// In en, this message translates to:
  /// **'Long-running timer'**
  String get channelLong;

  /// No description provided for @channelLongBody.
  ///
  /// In en, this message translates to:
  /// **'A reminder when a timer runs for hours'**
  String get channelLongBody;

  /// No description provided for @widgetStopTimer.
  ///
  /// In en, this message translates to:
  /// **'Stop the timer'**
  String get widgetStopTimer;

  /// No description provided for @widgetSignedOut.
  ///
  /// In en, this message translates to:
  /// **'Signed out'**
  String get widgetSignedOut;

  /// No description provided for @widgetNotTracking.
  ///
  /// In en, this message translates to:
  /// **'Not tracking'**
  String get widgetNotTracking;

  /// No description provided for @widgetOpenToStart.
  ///
  /// In en, this message translates to:
  /// **'Open ZT Time to start tracking'**
  String get widgetOpenToStart;

  /// No description provided for @widgetTapPlay.
  ///
  /// In en, this message translates to:
  /// **'Tap play to start a timer'**
  String get widgetTapPlay;

  /// No description provided for @widgetOpenApp.
  ///
  /// In en, this message translates to:
  /// **'Open ZT Time'**
  String get widgetOpenApp;

  /// No description provided for @widgetStartTimer.
  ///
  /// In en, this message translates to:
  /// **'Start a timer'**
  String get widgetStartTimer;

  /// No description provided for @widgetStartTimerFor.
  ///
  /// In en, this message translates to:
  /// **'Start a timer for {project}'**
  String widgetStartTimerFor(String project);
}

class _AppL10nDelegate extends LocalizationsDelegate<AppL10n> {
  const _AppL10nDelegate();

  @override
  Future<AppL10n> load(Locale locale) {
    return SynchronousFuture<AppL10n>(lookupAppL10n(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'he'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppL10nDelegate old) => false;
}

AppL10n lookupAppL10n(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppL10nEn();
    case 'he':
      return AppL10nHe();
  }

  throw FlutterError(
    'AppL10n.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
