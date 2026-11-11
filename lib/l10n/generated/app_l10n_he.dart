// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_l10n.dart';

// ignore_for_file: type=lint

/// The translations for Hebrew (`he`).
class AppL10nHe extends AppL10n {
  AppL10nHe([String locale = 'he']) : super(locale);

  @override
  String get today => 'היום';

  @override
  String get yesterday => 'אתמול';

  @override
  String get tomorrow => 'מחר';

  @override
  String durationDecimalHours(String hours) {
    return '$hours ש׳';
  }

  @override
  String durationMinutes(int m) {
    return '$m ד׳';
  }

  @override
  String durationHours(int h) {
    return '$h ש׳';
  }

  @override
  String durationHoursMinutes(int h, int m) {
    return '$h ש׳ $m ד׳';
  }

  @override
  String get tabTimer => 'טיימר';

  @override
  String get tabReports => 'דוחות';

  @override
  String get tabProjects => 'פרויקטים';

  @override
  String get settingsTooltip => 'הגדרות';

  @override
  String get addTimeByHand => 'הוספת זמן ידנית';

  @override
  String get newProject => 'פרויקט חדש';

  @override
  String get couldNotLoadProjects => 'לא ניתן היה לטעון את הפרויקטים';

  @override
  String perHour(String amount) {
    return '$amount לשעה';
  }

  @override
  String get archived => 'בארכיון';

  @override
  String get noProjectsYet => 'עדיין אין פרויקטים';

  @override
  String get noProjectsBody =>
      'אפשר לקבץ את הזמן לפי פרויקט או לקוח, ולהגדיר תעריף לשעה כדי לראות כמה הוא שווה.';

  @override
  String get noProject => 'ללא פרויקט';

  @override
  String get exportTimesheetTitle => 'ייצוא גיליון שעות';

  @override
  String get exportNotEncrypted =>
      'הקובץ לא מוצפן. כל מי שמשיג אותו יכול לקרוא את הרישומים שלך. כדאי לשתף אותו רק עם אנשים ואפליקציות שסומכים עליהם.';

  @override
  String get formatXlsx => 'Excel ‏(.xlsx)';

  @override
  String get formatXlsxApps => 'Excel‏, Google Sheets‏, Numbers';

  @override
  String get formatOds => 'LibreOffice ‏(.ods)';

  @override
  String get formatOdsApps => 'LibreOffice‏, OpenOffice‏, Collabora';

  @override
  String get formatCsv => 'CSV ‏(.csv)';

  @override
  String get formatCsvApps => 'טקסט פשוט לכל אפליקציה, וגם ל-Toggl או Clockify';

  @override
  String get cancel => 'ביטול';

  @override
  String get sheetTimeEntries => 'רישומי זמן';

  @override
  String get couldNotLoadEntries => 'לא ניתן היה לטעון את רישומי הזמן';

  @override
  String get showOlderEntries => 'הצגת רישומים ישנים יותר';

  @override
  String get whatAreYouWorkingOn => 'על מה עובדים עכשיו?';

  @override
  String get billable => 'לחיוב';

  @override
  String get start => 'התחלה';

  @override
  String get stop => 'עצירה';

  @override
  String get noDescription => '(ללא תיאור)';

  @override
  String runningSince(String project, String time) {
    return '$project · מאז $time';
  }

  @override
  String get entryDeleted => 'הרישום נמחק';

  @override
  String get undo => 'ביטול פעולה';

  @override
  String get startAgain => 'התחלה מחדש';

  @override
  String get nothingTrackedYet => 'עדיין לא נרשם זמן';

  @override
  String get nothingTrackedBody =>
      'אפשר להפעיל את הטיימר למעלה, או להוסיף זמן ידנית עם כפתור ה-+. הכול מוצפן בטלפון הזה לפני הסנכרון.';

  @override
  String get endBeforeStart => 'הסיום לפני ההתחלה';

  @override
  String get runningInFuture => 'טיימר פעיל לא יכול להתחיל בעתיד';

  @override
  String get discardTimerQuestion => 'לבטל את הטיימר הזה?';

  @override
  String get deleteEntryQuestion => 'למחוק את הרישום הזה?';

  @override
  String get discard => 'ביטול טיימר';

  @override
  String get delete => 'מחיקה';

  @override
  String get runningTimer => 'טיימר פעיל';

  @override
  String get editEntry => 'עריכת רישום';

  @override
  String get addTime => 'הוספת זמן';

  @override
  String get discardTimer => 'ביטול הטיימר';

  @override
  String get deleteEntry => 'מחיקת הרישום';

  @override
  String get save => 'שמירה';

  @override
  String get description => 'תיאור';

  @override
  String get end => 'סיום';

  @override
  String get tags => 'תגיות';

  @override
  String get tagsHelper => 'מפרידים בפסיקים: פגישה, עיצוב';

  @override
  String get nothingToExportPeriod => 'אין מה לייצא בתקופה הזו';

  @override
  String get periodDay => 'יום';

  @override
  String get periodWeek => 'שבוע';

  @override
  String get periodMonth => 'חודש';

  @override
  String get periodYear => 'שנה';

  @override
  String get periodCustom => 'מותאם';

  @override
  String get earlier => 'קודם';

  @override
  String get later => 'הבא';

  @override
  String get exportPeriod => 'ייצוא התקופה הזו (Excel‏, LibreOffice או CSV)';

  @override
  String get total => 'סה״כ';

  @override
  String get amount => 'סכום';

  @override
  String get noTimeInPeriod => 'לא נרשם זמן בתקופה הזו';

  @override
  String barTooltip(String label, String duration) {
    return '$label: $duration';
  }

  @override
  String get projectNameRequired => 'צריך לתת שם לפרויקט';

  @override
  String get rateInvalid => 'צריך להזין מספר, כמו 60 או 42.50';

  @override
  String get deleteProjectQuestion => 'למחוק את הפרויקט הזה?';

  @override
  String get deleteProjectBody =>
      'רישומי הזמן שלו נשמרים ומופיעים כ\"ללא פרויקט\". כדי להסתיר פרויקט ולשמור את הדוחות שלו, אפשר להעביר אותו לארכיון במקום.';

  @override
  String get editProject => 'עריכת פרויקט';

  @override
  String get deleteProject => 'מחיקת הפרויקט';

  @override
  String get projectName => 'שם הפרויקט';

  @override
  String get clientOptional => 'לקוח (לא חובה)';

  @override
  String get colour => 'צבע';

  @override
  String colourNumber(int n) {
    return 'צבע $n';
  }

  @override
  String get hourlyRateOptional => 'תעריף לשעה (לא חובה)';

  @override
  String get hourlyRateHelper => 'הדוחות הופכים שעות לחיוב לסכום';

  @override
  String get billableByDefault => 'לחיוב כברירת מחדל';

  @override
  String get billableByDefaultBody =>
      'רישומים חדשים בפרויקט הזה מתחילים כלחיוב';

  @override
  String get archivedBody => 'מוסתר בבחירת פרויקט; הדוחות שומרים אותו';

  @override
  String get startOfWeek => 'תחילת השבוע';

  @override
  String likeYourRegionDay(String day) {
    return 'לפי האזור שלך ($day)';
  }

  @override
  String get likeYourRegion => 'לפי האזור שלך';

  @override
  String get currency => 'מטבע';

  @override
  String currencySubtitle(String currency) {
    return '$currency  (לתעריפים ולסכומים)';
  }

  @override
  String get decimalHours => 'שעות עשרוניות';

  @override
  String get decimalHoursBody => 'הצגת סיכומים כ-7.50 ש׳ במקום 7 ש׳ 30 ד׳';

  @override
  String get runningNotification => 'התראה בזמן שטיימר פועל';

  @override
  String get runningNotificationBody => 'התראה קבועה עם שעון חי (Android)';

  @override
  String get notificationDescription => 'התיאור בהתראה הזו';

  @override
  String get notificationDescriptionBody =>
      'כבוי: מופיע רק \"טיימר פועל\". כשמופעל, התיאור נמסר לטלפון כדי שיוצג גם כש-Time נעולה.';

  @override
  String get widgetDetails => 'הצגת פרטים במסך הבית';

  @override
  String get widgetDetailsBody =>
      'כבוי: הווידג׳ט מציג רק \"טיימר פועל\" ואת השעון. מופעל: מה שנמדד והפרויקטים האחרונים שלך נשמרים בטלפון הזה ללא הצפנה עבור מסך הבית.';

  @override
  String get remindLongTimer => 'תזכורת על טיימר ארוך';

  @override
  String get never => 'אף פעם';

  @override
  String afterHours(int hours) {
    return 'אחרי $hours שעות';
  }

  @override
  String get importTimesheet => 'ייבוא גיליון שעות';

  @override
  String get importTimesheetBody =>
      'Excel‏, LibreOffice‏, Google Sheets או CSV; ‏Toggl Track‏, Clockify או ZT Time';

  @override
  String get exportAllEntries => 'ייצוא כל הרישומים';

  @override
  String get exportAllEntriesBody =>
      'Excel‏, LibreOffice או CSV. לא מוצפן, לגיליונות ולחשבוניות';

  @override
  String get other => 'אחר';

  @override
  String get useThis => 'שימוש בזה';

  @override
  String get nothingToExportYet => 'עדיין אין מה לייצא';

  @override
  String get importHelp =>
      'אפשר לבחור קובץ Excel ‏(.xlsx), LibreOffice ‏(.ods) או CSV. מ-Google Sheets: קובץ, הורדה, Microsoft Excel.\n\nהגיליון צריך עמודת \"Start date\", ושעת סיום או משך. דוחות מפורטים של Toggl Track ו-Clockify עובדים כמו שהם.\n\nפרויקטים מהקובץ נוצרים אם הם עוד לא קיימים אצלך. ייבוא חוזר של אותו קובץ מדלג על רישומים שכבר קיימים.';

  @override
  String get chooseFile => 'בחירת קובץ';

  @override
  String get chooseSpreadsheet => 'בחירת גיליון או קובץ ‎.csv';

  @override
  String importedEntries(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'יובאו $count רישומים',
      one: 'יובא רישום אחד',
    );
    return '$_temp0';
  }

  @override
  String importedProjects(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'ו-$count פרויקטים חדשים',
      one: 'ופרויקט חדש אחד',
    );
    return '$_temp0';
  }

  @override
  String importedSkipped(int count) {
    return '$count שכבר קיימים דולגו';
  }

  @override
  String importedUnreadable(int count) {
    return 'ב-$count שורות לא היו זמנים קריאים';
  }

  @override
  String couldNotImportReason(String reason) {
    return 'לא ניתן היה לייבא את הקובץ: $reason';
  }

  @override
  String get couldNotImport => 'לא ניתן היה לייבא את הקובץ';

  @override
  String get errFileEmpty => 'הקובץ ריק';

  @override
  String get errNoStartDate => 'אין בקובץ הזה עמודת \"Start date\"';

  @override
  String get errFileDamaged => 'הקובץ פגום';

  @override
  String get errNotSpreadsheet =>
      'זה לא גיליון. אפשר להשתמש ב-‎.xlsx‏, ‎.ods או ‎.csv';

  @override
  String get errOldXls =>
      'אי אפשר לקרוא קובצי ‎.xls ישנים. קודם צריך לשמור אותו כ-‎.xlsx או ‎.csv';

  @override
  String get timerRunning => 'טיימר פועל';

  @override
  String get tapToOpen => 'אפשר להקיש כדי לפתוח את ZT Time';

  @override
  String get channelRunning => 'טיימר פעיל';

  @override
  String get channelRunningBody => 'מוצגת כשטיימר פועל';

  @override
  String get timerStillRunning => 'הטיימר עדיין פועל';

  @override
  String get timerStillRunningBody => 'הטיימר פועל כבר זמן מה. עדיין עובדים?';

  @override
  String get channelLong => 'טיימר ארוך';

  @override
  String get channelLongBody => 'תזכורת כשטיימר פועל במשך שעות';

  @override
  String get widgetStopTimer => 'עצירת הטיימר';

  @override
  String get widgetSignedOut => 'מנותק';

  @override
  String get widgetNotTracking => 'לא נמדד זמן';

  @override
  String get widgetOpenToStart => 'צריך לפתוח את ZT Time כדי להתחיל';

  @override
  String get widgetTapPlay => 'אפשר להקיש על הפעלה כדי להתחיל טיימר';

  @override
  String get widgetOpenApp => 'פתיחת ZT Time';

  @override
  String get widgetStartTimer => 'הפעלת טיימר';

  @override
  String widgetStartTimerFor(String project) {
    return 'הפעלת טיימר עבור $project';
  }
}
