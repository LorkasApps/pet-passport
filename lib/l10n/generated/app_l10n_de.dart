// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_l10n.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppL10nDe extends AppL10n {
  AppL10nDe([String locale = 'de']) : super(locale);

  @override
  String get appTitle => 'Pet Passport';

  @override
  String get navDashboard => 'Übersicht';

  @override
  String get navPets => 'Tiere';

  @override
  String get navSettings => 'Einstellungen';

  @override
  String get navHome => 'Home';

  @override
  String get navTermine => 'Termine';

  @override
  String get navAlltag => 'Alltag';

  @override
  String get navMore => 'Mehr';

  @override
  String get termineEmptyTitle => 'Noch nichts geplant';

  @override
  String get termineEmptyMessage =>
      'Impfungen, Medikamente und Termine erscheinen hier.';

  @override
  String get alltagEmptyTitle => 'Noch keine Einträge';

  @override
  String get alltagEmptyMessage =>
      'Diät und Alltags-Ereignisse erscheinen hier.';

  @override
  String get switchPetTitle => 'Tier wechseln';

  @override
  String get moreManagePets => 'Tiere verwalten';

  @override
  String get actionSave => 'Speichern';

  @override
  String get actionCancel => 'Abbrechen';

  @override
  String get actionDelete => 'Löschen';

  @override
  String get actionEdit => 'Bearbeiten';

  @override
  String get actionAdd => 'Hinzufügen';

  @override
  String get actionConfirm => 'Bestätigen';

  @override
  String get actionSkip => 'Überspringen';

  @override
  String get actionNext => 'Weiter';

  @override
  String get actionBack => 'Zurück';

  @override
  String get actionFinish => 'Fertig';

  @override
  String get confirmDeleteTitle => 'Löschen?';

  @override
  String get confirmDeleteMessage =>
      'Diese Aktion kann nicht rückgängig gemacht werden.';

  @override
  String get onboardingWelcomeTitle => 'Willkommen bei Pet Passport';

  @override
  String get onboardingWelcomeBody =>
      'Gesundheit, Termine und Alltag deiner Tiere an einem Ort — nur lokal auf deinem Gerät gespeichert.';

  @override
  String get onboardingAddFirstPetTitle => 'Erstes Tier anlegen';

  @override
  String get onboardingAddFirstPetBody =>
      'Lege ein Profil für dein Tier an. Weitere kannst du später hinzufügen.';

  @override
  String get petsListTitle => 'Meine Tiere';

  @override
  String get petsListEmpty => 'Noch keine Tiere';

  @override
  String get petsListEmptyAction => 'Tier hinzufügen';

  @override
  String get petEditNewTitle => 'Neues Tier';

  @override
  String get petEditEditTitle => 'Tier bearbeiten';

  @override
  String get petFieldName => 'Name';

  @override
  String get petFieldSpecies => 'Tierart';

  @override
  String get petFieldBreed => 'Rasse';

  @override
  String get petFieldSex => 'Geschlecht';

  @override
  String get petFieldDateOfBirth => 'Geburtsdatum';

  @override
  String get petFieldColor => 'Farbe / Zeichnung';

  @override
  String get petFieldChipNumber => 'Chip-Nummer';

  @override
  String get petFieldTassoNumber => 'Tasso-Nummer';

  @override
  String get petFieldNotes => 'Notizen';

  @override
  String get petPickProfilePhoto => 'Profilfoto wählen';

  @override
  String get petReplaceProfilePhoto => 'Profilfoto ersetzen';

  @override
  String get petRemoveProfilePhoto => 'Foto entfernen';

  @override
  String get speciesDog => 'Hund';

  @override
  String get speciesCat => 'Katze';

  @override
  String get sexMale => 'Männlich';

  @override
  String get sexFemale => 'Weiblich';

  @override
  String get sexNeutered => 'Kastriert';

  @override
  String get sexIntact => 'Unkastriert';

  @override
  String get petFieldNeutered => 'Kastriert';

  @override
  String get petFieldNeuteredHelp => 'Unabhängig vom biologischen Geschlecht.';

  @override
  String get lifeStagePuppy => 'Welpe';

  @override
  String get lifeStageJunior => 'Junior';

  @override
  String get lifeStageAdult => 'Adult';

  @override
  String get lifeStageSenior => 'Senior';

  @override
  String ageYears(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Jahre',
      one: '1 Jahr',
    );
    return '$_temp0';
  }

  @override
  String ageMonths(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Monate',
      one: '1 Monat',
    );
    return '$_temp0';
  }

  @override
  String get ageUnknown => 'Alter unbekannt';

  @override
  String get petDetailOverview => 'Übersicht';

  @override
  String get settingsTitle => 'Einstellungen';

  @override
  String get settingsAppearance => 'Darstellung';

  @override
  String get settingsThemeMode => 'Design';

  @override
  String get settingsThemeSystem => 'System';

  @override
  String get settingsThemeLight => 'Hell';

  @override
  String get settingsThemeDark => 'Dunkel';

  @override
  String get settingsLanguage => 'Sprache';

  @override
  String get settingsLanguageSystem => 'System-Standard';

  @override
  String get settingsLanguageGerman => 'Deutsch';

  @override
  String get settingsLanguageEnglish => 'English';

  @override
  String get validationRequired => 'Pflichtfeld';

  @override
  String get validationTooLong => 'Zu lang';

  @override
  String get vetsListTitle => 'Tierärzte';

  @override
  String get vetsEmptyTitle => 'Noch keine Tierärzte';

  @override
  String get vetsEmptyMessage =>
      'Speichere die Kontakte deiner Tierärzte für Schnellzugriff.';

  @override
  String get vetsEmptyAction => 'Tierarzt hinzufügen';

  @override
  String get vetEditNewTitle => 'Neuer Tierarzt';

  @override
  String get vetEditEditTitle => 'Tierarzt bearbeiten';

  @override
  String get vetFieldName => 'Name';

  @override
  String get vetFieldPractice => 'Praxis / Klinik';

  @override
  String get vetFieldAddress => 'Adresse';

  @override
  String get vetFieldPhone => 'Telefon';

  @override
  String get vetFieldEmail => 'E-Mail';

  @override
  String get vetActiveLabel => 'Aktiv';

  @override
  String get vetsActiveSection => 'Aktiv';

  @override
  String get vetsArchivedSection => 'Archiv';

  @override
  String get actionShowArchived => 'Archivierte anzeigen';

  @override
  String get actionHideArchived => 'Archivierte ausblenden';

  @override
  String get contactsListTitle => 'Kontakte';

  @override
  String get contactsEmptyTitle => 'Noch keine Kontakte';

  @override
  String get contactsEmptyMessage =>
      'Hundesitter, Trainer und andere Bezugspersonen an einem Ort.';

  @override
  String get contactsEmptyAction => 'Kontakt hinzufügen';

  @override
  String get contactEditNewTitle => 'Neuer Kontakt';

  @override
  String get contactEditEditTitle => 'Kontakt bearbeiten';

  @override
  String get contactFieldName => 'Name';

  @override
  String get contactFieldRole => 'Rolle';

  @override
  String get contactFieldOrganization => 'Organisation / Firma';

  @override
  String get contactFieldAddress => 'Adresse';

  @override
  String get contactFieldPhone => 'Telefon';

  @override
  String get contactFieldEmail => 'E-Mail';

  @override
  String get contactActiveLabel => 'Aktiv';

  @override
  String get contactRoleSitter => 'Hundesitter';

  @override
  String get contactRoleTrainer => 'Trainer';

  @override
  String get contactRoleGroomer => 'Fellpflege';

  @override
  String get contactRoleOther => 'Sonstige';

  @override
  String get moreContacts => 'Kontakte';

  @override
  String get moreDocuments => 'Dokumente';

  @override
  String get documentsListTitle => 'Dokumente';

  @override
  String get documentsEmptyTitle => 'Noch keine Dokumente';

  @override
  String get documentsEmptyMessage =>
      'Befunde, wichtige Briefe und andere PDFs oder Fotos an einem Ort.';

  @override
  String get documentsEmptyAction => 'Dokument hinzufügen';

  @override
  String get documentsAddAction => 'Datei wählen';

  @override
  String get documentEditTitle => 'Titel & Notiz';

  @override
  String get documentFieldTitle => 'Titel (optional)';

  @override
  String get documentFieldNotes => 'Notiz (optional)';

  @override
  String get documentFieldOriginalFilename => 'Ursprünglicher Dateiname';

  @override
  String get actionOpenInMaps => 'In Karten öffnen';

  @override
  String get appointmentContactLabel => 'Kontakt';

  @override
  String emptyShowArchivedAction(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count archivierte Einträge anzeigen',
      one: '1 archivierten Eintrag anzeigen',
    );
    return '$_temp0';
  }

  @override
  String get insurancesListTitle => 'Versicherungen';

  @override
  String get insurancesEmptyTitle => 'Noch keine Versicherungen';

  @override
  String get insurancesEmptyMessage =>
      'Verwalte Verträge und hänge Dokumente an.';

  @override
  String get insurancesEmptyAction => 'Versicherung hinzufügen';

  @override
  String get insuranceEditNewTitle => 'Neue Versicherung';

  @override
  String get insuranceEditEditTitle => 'Versicherung bearbeiten';

  @override
  String get insuranceFieldProvider => 'Anbieter';

  @override
  String get insuranceFieldPolicy => 'Vertragsnummer';

  @override
  String get insuranceFieldContractStart => 'Vertragsbeginn';

  @override
  String get insuranceFieldContractEnd => 'Vertragsende';

  @override
  String get insuranceDocumentsSection => 'Dokumente';

  @override
  String get insuranceDocumentsEmpty => 'Noch keine Dokumente angehängt.';

  @override
  String get overviewVetsTile => 'Tierärzte';

  @override
  String get overviewInsurancesTile => 'Versicherungen';

  @override
  String get launchFailed => 'Keine App für diese Aktion verfügbar.';

  @override
  String get copiedToClipboard => 'In Zwischenablage kopiert';

  @override
  String get vaccinationsListTitle => 'Impfungen';

  @override
  String get vaccinationsEmptyTitle => 'Noch keine Impfungen erfasst';

  @override
  String get vaccinationsEmptyMessage =>
      'Erfasse Impfungen und ihre Fälligkeitstermine.';

  @override
  String get vaccinationsEmptyAction => 'Impfung hinzufügen';

  @override
  String get vaccinationEditNewTitle => 'Neue Impfung';

  @override
  String get vaccinationEditEditTitle => 'Impfung bearbeiten';

  @override
  String get vaccinationFieldName => 'Impfstoff';

  @override
  String get vaccinationFieldAdministered => 'Verabreicht am';

  @override
  String get vaccinationFieldNextDue => 'Nächste Fälligkeit';

  @override
  String get vaccinationFieldVet => 'Durchgeführt von';

  @override
  String get vaccinationFieldBatch => 'Chargen-Nr.';

  @override
  String get vaccinationVetNone => 'Nicht angegeben';

  @override
  String vaccinationAdministeredOn(String date) {
    return 'Verabreicht am $date';
  }

  @override
  String vaccinationNextDue(String date) {
    return 'Fällig am $date';
  }

  @override
  String get vaccinationOverdue => 'Überfällig';

  @override
  String get vaccinationOverdueMessage =>
      'Diese Impfung ist überfällig. Termin beim Tierarzt vereinbaren.';

  @override
  String vaccinationDueIn(int days, String date) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Fällig in $days Tagen · $date',
      one: 'Morgen fällig · $date',
      zero: 'Heute fällig · $date',
    );
    return '$_temp0';
  }

  @override
  String vaccinationOverdueBy(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Seit $days Tagen überfällig',
      one: 'Seit 1 Tag überfällig',
    );
    return '$_temp0';
  }

  @override
  String get termineUpcomingVaccinations => 'Anstehende Impfungen';

  @override
  String get overviewVaccinationsTitle => 'Impfungen';

  @override
  String get overviewVaccinationsEmpty =>
      'Keine anstehenden Impfungen erfasst.';

  @override
  String get emergencyTitle => 'Notfall-Info';

  @override
  String get emergencyVetsSection => 'Tierärzte';

  @override
  String get emergencyCallAction => 'Anrufen';

  @override
  String get emergencyWeightTitle => 'Aktuelles Gewicht';

  @override
  String emergencyWeightValue(String weight, String date) {
    return '$weight kg · gemessen am $date';
  }

  @override
  String get emergencyQrTitle => 'Notfall-QR';

  @override
  String get emergencyQrHelp =>
      'Scannen zeigt alle wichtigen Infos auf einen Blick. Tippe auf das Icon für die Vollbild-Version.';

  @override
  String get emergencyQrExpand => 'Vollbild';

  @override
  String get petFieldAllergies => 'Allergien';

  @override
  String get petFieldAllergiesHelp =>
      'Medikamente, Inhaltsstoffe oder Umweltreize, die zu vermeiden sind.';

  @override
  String get vaccinationDocumentsSection => 'Dokumente';

  @override
  String get vaccinationDocumentsEmpty => 'Noch keine Dokumente angehängt.';

  @override
  String get settingsReminders => 'Erinnerungen';

  @override
  String get settingsReminderLead => 'Vorlauf Impf-Erinnerung';

  @override
  String settingsReminderLeadValue(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days Tage vorher',
      one: '1 Tag vorher',
    );
    return '$_temp0';
  }

  @override
  String get settingsSecurity => 'Sicherheit';

  @override
  String get settingsAppLock => 'App-Sperre';

  @override
  String get settingsAppLockHelp =>
      'Fingerabdruck oder Gerätcode zum Öffnen der App erforderlich.';

  @override
  String get settingsAppLockUnavailable =>
      'Auf diesem Gerät ist keine biometrische oder PIN-Authentifizierung eingerichtet.';

  @override
  String get appLockReason => 'Pet Passport entsperren';

  @override
  String get appLockSignInTitle => 'Authentifizierung erforderlich';

  @override
  String get appLockLockedTitle => 'Gesperrt';

  @override
  String get appLockLockedBody => 'Authentifiziere dich, um fortzufahren.';

  @override
  String get appLockUnlock => 'Entsperren';

  @override
  String get exportTitle => 'Import / Export';

  @override
  String get exportJsonTitle => 'JSON-Backup';

  @override
  String get exportJsonHelp =>
      'Erstellt eine JSON-Datei mit allen Tieren, Tierärzten, Versicherungen und Impfungen. Über Mail, Cloud oder eine andere App teilen.';

  @override
  String get exportJsonAction => 'Exportieren & teilen';

  @override
  String get exportMediaNote =>
      'Angehängte Dokumente und Fotos werden nur per Pfad referenziert. Um sie mitzusichern, den App-Speicherordner separat sichern.';

  @override
  String get importJsonTitle => 'JSON wiederherstellen';

  @override
  String get importJsonHelp =>
      'Stellt Tiere, Tierärzte, Versicherungen und Impfungen aus einer JSON-Sicherung wieder her. Einträge mit gleicher UUID werden aktualisiert, neue hinzugefügt.';

  @override
  String get importJsonAction => 'Datei wählen & importieren';

  @override
  String get importConfirmTitle => 'Sicherung importieren?';

  @override
  String get importConfirmBody =>
      'Bestehende Einträge mit passender UUID werden überschrieben. Fortfahren?';

  @override
  String get importConfirm => 'Importieren';

  @override
  String get importCancel => 'Abbrechen';

  @override
  String get importResultTitle => 'Import abgeschlossen';

  @override
  String importResultBody(int added, int updated) {
    String _temp0 = intl.Intl.pluralLogic(
      added,
      locale: localeName,
      other: '$added neue Einträge',
      one: '1 neuer Eintrag',
      zero: 'Keine neuen Einträge',
    );
    String _temp1 = intl.Intl.pluralLogic(
      updated,
      locale: localeName,
      other: '$updated aktualisiert',
      one: '1 aktualisiert',
      zero: 'keine Aktualisierungen',
    );
    return '$_temp0, $_temp1.';
  }

  @override
  String importResultErrors(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Einträge wurden wegen Fehler übersprungen',
      one: '1 Eintrag wurde wegen Fehler übersprungen',
    );
    return '$_temp0.';
  }

  @override
  String get eventTypeWeight => 'Gewicht';

  @override
  String get eventTypeFeeding => 'Fütterung';

  @override
  String get eventTypeSymptom => 'Symptom';

  @override
  String get eventTypeActivity => 'Aktivität';

  @override
  String get eventTypeGeneric => 'Notiz';

  @override
  String get eventTypeAll => 'Alle';

  @override
  String get eventFeedingMealMorning => 'Morgens';

  @override
  String get eventFeedingMealNoon => 'Mittags';

  @override
  String get eventFeedingMealEvening => 'Abends';

  @override
  String get eventFeedingMealSnack => 'Snack';

  @override
  String get eventSymptomSeverityLow => 'Leicht';

  @override
  String get eventSymptomSeverityMedium => 'Mittel';

  @override
  String get eventSymptomSeverityHigh => 'Schwer';

  @override
  String get eventActivityTypeWalk => 'Spaziergang';

  @override
  String get eventActivityTypePlay => 'Spielen';

  @override
  String get eventActivityTypeTraining => 'Training';

  @override
  String get eventActivityTypeOther => 'Sonstiges';

  @override
  String get alltagFilterAll => 'Alle';

  @override
  String get alltagFilterTypeLabel => 'Typ';

  @override
  String alltagFilterRangeLabel(int days) {
    return 'Zeitraum: $days Tage';
  }

  @override
  String get alltagNoEventsForFilter => 'Keine Einträge im aktuellen Filter.';

  @override
  String get alltagAddEventFabTooltip => 'Eintrag hinzufügen';

  @override
  String get alltagSearchHint => 'Titel durchsuchen';

  @override
  String get eventEditNewTitle => 'Neuer Eintrag';

  @override
  String get eventEditEditTitle => 'Eintrag bearbeiten';

  @override
  String get eventPickTypeTitle => 'Was hast du beobachtet?';

  @override
  String get eventFieldOccurredAt => 'Wann';

  @override
  String get eventFieldTitle => 'Titel';

  @override
  String get eventFieldNote => 'Notiz';

  @override
  String get eventFieldWeightKg => 'Gewicht (kg)';

  @override
  String get eventFieldFoodName => 'Futter';

  @override
  String get eventFieldAmountG => 'Menge (g)';

  @override
  String get eventFieldMeal => 'Mahlzeit';

  @override
  String get eventFieldSymptomDescription => 'Beschreibung';

  @override
  String get eventFieldSymptomSeverity => 'Schweregrad';

  @override
  String get eventFieldActivityType => 'Art';

  @override
  String get eventFieldDistanceM => 'Distanz (m)';

  @override
  String get eventFieldDurationMin => 'Dauer (min)';

  @override
  String get eventTagsHeader => 'Tags';

  @override
  String get eventTagAddNew => 'Neuer Tag';

  @override
  String get eventTagNewDialogTitle => 'Neuer Tag';

  @override
  String get eventTagNewDialogLabel => 'Bezeichnung';

  @override
  String get eventPhotosHeader => 'Fotos';

  @override
  String get eventPhotoAdd => 'Foto hinzufügen';

  @override
  String get eventValidationRequired => 'Pflichtfeld';

  @override
  String get eventValidationInvalidNumber => 'Keine gültige Zahl';

  @override
  String get eventDeleteConfirmTitle => 'Eintrag löschen?';

  @override
  String get eventDeleteConfirmBody =>
      'Das kann nicht rückgängig gemacht werden.';

  @override
  String overviewCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Einträge',
      one: '1 Eintrag',
      zero: 'Keine',
    );
    return '$_temp0';
  }

  @override
  String get notesLabel => 'Notizen';

  @override
  String get errorRequired => 'Pflichtfeld';

  @override
  String get optionNone => 'Keine';

  @override
  String get actionClear => 'Löschen';

  @override
  String get notFound => 'Nicht gefunden.';

  @override
  String get appointmentsListTitle => 'Termine';

  @override
  String get appointmentsEmptyTitle => 'Noch keine Termine';

  @override
  String get appointmentsEmptyMessage =>
      'Tierarzt, Fellpflege und Training erscheinen hier.';

  @override
  String get appointmentNewTitle => 'Neuer Termin';

  @override
  String get appointmentEditTitle => 'Termin bearbeiten';

  @override
  String get appointmentDetailTitle => 'Termin';

  @override
  String get appointmentTypeLabel => 'Art';

  @override
  String get appointmentTypeVet => 'Tierarzt';

  @override
  String get appointmentTypeGrooming => 'Fellpflege';

  @override
  String get appointmentTypeTraining => 'Training';

  @override
  String get appointmentTypeWalk => 'Gassi';

  @override
  String get appointmentTypeCheckup => 'Vorsorge';

  @override
  String get appointmentTypeOther => 'Sonstiges';

  @override
  String get appointmentTitleLabel => 'Titel';

  @override
  String get appointmentStartsAtLabel => 'Beginn';

  @override
  String get appointmentDurationLabel => 'Dauer (min)';

  @override
  String get appointmentVetLabel => 'Tierarzt';

  @override
  String get appointmentLocationLabel => 'Ort';

  @override
  String durationMinutesValue(int minutes) {
    return '$minutes min';
  }

  @override
  String get upcomingOccurrencesTitle => 'Nächste Termine';

  @override
  String get noUpcomingOccurrences => 'Keine anstehenden Termine.';

  @override
  String get recurrenceSectionTitle => 'Wiederholung';

  @override
  String get remindersSectionTitle => 'Erinnerungen';

  @override
  String get recurrenceFrequencyLabel => 'Häufigkeit';

  @override
  String get recurrenceNone => 'Einmalig';

  @override
  String get recurrenceDaily => 'Täglich';

  @override
  String get recurrenceWeekly => 'Wöchentlich';

  @override
  String get recurrenceMonthly => 'Monatlich';

  @override
  String get recurrenceIntervalLabel => 'Alle';

  @override
  String recurrenceHintDaily(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n Tage',
      one: 'Tag',
    );
    return '$_temp0';
  }

  @override
  String recurrenceHintWeekly(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n Wochen',
      one: 'Woche',
    );
    return '$_temp0';
  }

  @override
  String recurrenceHintMonthly(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n Monate',
      one: 'Monat',
    );
    return '$_temp0';
  }

  @override
  String get recurrenceUntilNone => 'Ohne Enddatum';

  @override
  String recurrenceUntilLabel(String date) {
    return 'Bis $date';
  }

  @override
  String get recurrenceUntilPick => 'Enddatum wählen';

  @override
  String get weekdayShortMon => 'Mo';

  @override
  String get weekdayShortTue => 'Di';

  @override
  String get weekdayShortWed => 'Mi';

  @override
  String get weekdayShortThu => 'Do';

  @override
  String get weekdayShortFri => 'Fr';

  @override
  String get weekdayShortSat => 'Sa';

  @override
  String get weekdayShortSun => 'So';

  @override
  String get reminderOffsetAtTime => 'Zum Zeitpunkt';

  @override
  String reminderOffsetMinutes(int n) {
    return '$n min vorher';
  }

  @override
  String reminderOffsetHours(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n Std vorher',
      one: '1 Std vorher',
    );
    return '$_temp0';
  }

  @override
  String reminderOffsetDays(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n Tage vorher',
      one: '1 Tag vorher',
    );
    return '$_temp0';
  }

  @override
  String get medicationsListTitle => 'Medikamente';

  @override
  String get medicationsEmptyTitle => 'Noch keine Medikamente';

  @override
  String get medicationsEmptyMessage =>
      'Behandlungen und Dosierungen erscheinen hier.';

  @override
  String get medicationNewTitle => 'Neues Medikament';

  @override
  String get medicationEditTitle => 'Medikament bearbeiten';

  @override
  String get medicationDetailTitle => 'Medikament';

  @override
  String get medicationNameLabel => 'Name';

  @override
  String get medicationDosageAmountLabel => 'Dosis';

  @override
  String get medicationDosageUnitLabel => 'Einheit';

  @override
  String get medicationFreqTypeLabel => 'Häufigkeit';

  @override
  String get medicationFreqDaily => 'Täglich';

  @override
  String get medicationFreqWeekly => 'Wöchentlich';

  @override
  String get medicationFreqIntervalDays => 'Alle N Tage';

  @override
  String get medicationFreqIntervalLabel => 'Intervall';

  @override
  String get medicationTimesOfDayLabel => 'Uhrzeiten';

  @override
  String get medicationAddTimeButton => 'Uhrzeit hinzufügen';

  @override
  String get medicationStartsAtLabel => 'Beginn';

  @override
  String get medicationEndsAtLabel => 'Ende (optional)';

  @override
  String get medicationActiveLabel => 'Aktiv';

  @override
  String get medicationPrescribedByLabel => 'Verordnet von';

  @override
  String get medicationActiveSection => 'Aktiv';

  @override
  String get medicationInactiveSection => 'Inaktiv';

  @override
  String get medicationAdherenceTitle => 'Einnahme — letzte 7 Tage';

  @override
  String medicationAdherenceCount(int taken, int expected) {
    return '$taken/$expected genommen';
  }

  @override
  String get medicationLogIntakeButton => 'Einnahme protokollieren';

  @override
  String get medicationLogSkippedButton => 'Ausgelassen protokollieren';

  @override
  String get medicationIntakeHistoryTitle => 'Einnahmehistorie';

  @override
  String get medicationIntakeHistoryEmpty => 'Noch keine Einträge.';

  @override
  String get medicationIntakeSkippedChip => 'Ausgelassen';

  @override
  String get medicationIntakeLoggedSnack => 'Einnahme protokolliert.';

  @override
  String get termineSectionAppointments => 'Anstehende Termine';

  @override
  String get termineSectionMedicationsToday => 'Medikamente heute';

  @override
  String get overviewNextAppointmentTitle => 'Nächster Termin';

  @override
  String get overviewNoAppointment => 'Keine anstehenden Termine.';

  @override
  String get overviewActiveMedicationsTitle => 'Aktive Medikamente';

  @override
  String get overviewNoActiveMedications => 'Keine aktiven Medikamente.';

  @override
  String overviewActiveMedicationsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Medikamente',
      one: '1 Medikament',
    );
    return '$_temp0';
  }

  @override
  String get moreAppointments => 'Termine';

  @override
  String get moreMedications => 'Medikamente';

  @override
  String get moreDiet => 'Ernährung';

  @override
  String get moreWeightChart => 'Gewichtsverlauf';

  @override
  String get moreTimeline => 'Verlauf';

  @override
  String get timelineTitle => 'Verlauf';

  @override
  String get timelineEmptyTitle => 'Nichts im Zeitraum';

  @override
  String get timelineEmptyMessage =>
      'Ereignisse, Impfungen, Medikamente und Termine erscheinen hier.';

  @override
  String get timelineFilterPet => 'Tier';

  @override
  String get timelineFilterAllPets => 'Alle Tiere';

  @override
  String get timelineKindEvent => 'Ereignisse';

  @override
  String get timelineKindVaccination => 'Impfungen';

  @override
  String get timelineKindMedication => 'Medikamente';

  @override
  String get timelineKindAppointment => 'Termine';

  @override
  String get morePdf => 'PDF-Export';

  @override
  String get pdfMenuTitle => 'PDF-Export';

  @override
  String get pdfPassportTitle => 'Impfpass';

  @override
  String get pdfPassportSubtitle =>
      'Alle Impfungen mit Datum und Chargennummer.';

  @override
  String get pdfOverviewTitle => 'Steckbrief';

  @override
  String get pdfOverviewSubtitle =>
      'Vollständige Übersicht inkl. Tierärzten und Versicherungen.';

  @override
  String get pdfEmergencyTitle => 'Notfall-Blatt';

  @override
  String get pdfEmergencySubtitle =>
      'Kontakte, Chip und Warnhinweise für den Ernstfall.';

  @override
  String get pdfVaccinationsSection => 'Impfungen';

  @override
  String get pdfNoVaccinations => 'Keine Impfungen erfasst.';

  @override
  String get pdfColDate => 'Datum';

  @override
  String get pdfColVaccine => 'Impfung';

  @override
  String get pdfColBatch => 'Charge';

  @override
  String get pdfColNextDue => 'Nächste fällig';

  @override
  String get pdfColVet => 'Tierarzt';

  @override
  String get passportTitle => 'Impfpass';

  @override
  String get passportNumberLabel => 'Ausweis-Nummer';

  @override
  String get passportNumberHelp => 'Nummer auf dem Impfausweis-Booklet.';

  @override
  String get passportNumberSavedSnack => 'Nummer gespeichert.';

  @override
  String get passportDocumentsSection => 'Dokumente';

  @override
  String get passportDocumentsEmpty => 'Noch keine Dokumente angehängt.';

  @override
  String get medicationWithFoodLabel => 'Mit Futter einnehmen';

  @override
  String get medicationWithFoodHint =>
      'Erinnerung fügt „mit Futter“ am Ende hinzu.';

  @override
  String get medicationWithFoodChip => 'Mit Futter';

  @override
  String get dietListTitle => 'Ernährung';

  @override
  String get dietEmptyTitle => 'Noch keine Futter-Einträge';

  @override
  String get dietEmptyMessage => 'Aktuelle Diät und Historie erscheinen hier.';

  @override
  String get dietActiveSection => 'Aktiv';

  @override
  String get dietInactiveSection => 'Verlauf';

  @override
  String get dietNewTitle => 'Neuer Futter-Eintrag';

  @override
  String get foodEditTitle => 'Futter bearbeiten';

  @override
  String get foodBrandLabel => 'Marke';

  @override
  String get foodNameLabel => 'Bezeichnung';

  @override
  String get foodTypeLabel => 'Futterart';

  @override
  String get foodTypeDry => 'Trocken';

  @override
  String get foodTypeWet => 'Nass';

  @override
  String get foodTypeRaw => 'Roh';

  @override
  String get foodTypeBarf => 'BARF';

  @override
  String get foodTypeTreat => 'Leckerli';

  @override
  String get foodTypeOther => 'Andere';

  @override
  String get foodPortionGramsLabel => 'Portion (g)';

  @override
  String get foodFrequencyPerDayLabel => 'Mahlzeiten / Tag';

  @override
  String get foodTimesOfDayLabel => 'Fütterungszeiten';

  @override
  String get foodStartsAtLabel => 'Beginn';

  @override
  String get foodEndsAtLabel => 'Ende (optional)';

  @override
  String get foodActiveLabel => 'Aktiv';

  @override
  String get foodRemindersEnabledLabel => 'Fütterungs-Erinnerungen';

  @override
  String get foodRemindersEnabledHint =>
      'Tägliche Notifications zu den Fütterungszeiten.';

  @override
  String get foodRemindersOnChip => 'Erinnerung an';

  @override
  String get petAllergyAddTitle => 'Allergie hinzufügen';

  @override
  String get petAllergyAddAction => 'Hinzufügen';

  @override
  String get petAllergyHint => 'z. B. Hühnerfleisch, Pollen';

  @override
  String get weightChartTitle => 'Gewichtsverlauf';

  @override
  String get weightChartEmptyTitle => 'Noch keine Kurve';

  @override
  String get weightChartEmptyMessage =>
      'Ab dem zweiten Gewichts-Event wird eine Kurve angezeigt.';
}
