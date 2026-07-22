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
  String get exportTitle => 'Export';

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
}
