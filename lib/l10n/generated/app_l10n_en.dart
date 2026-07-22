// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_l10n.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppL10nEn extends AppL10n {
  AppL10nEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Pet Passport';

  @override
  String get navDashboard => 'Dashboard';

  @override
  String get navPets => 'Pets';

  @override
  String get navSettings => 'Settings';

  @override
  String get navHome => 'Home';

  @override
  String get navTermine => 'Schedule';

  @override
  String get navAlltag => 'Daily';

  @override
  String get navMore => 'More';

  @override
  String get termineEmptyTitle => 'Nothing scheduled yet';

  @override
  String get termineEmptyMessage =>
      'Vaccinations, medications and appointments will appear here.';

  @override
  String get alltagEmptyTitle => 'No entries yet';

  @override
  String get alltagEmptyMessage => 'Diet and daily events will appear here.';

  @override
  String get switchPetTitle => 'Switch pet';

  @override
  String get moreManagePets => 'Manage pets';

  @override
  String get actionSave => 'Save';

  @override
  String get actionCancel => 'Cancel';

  @override
  String get actionDelete => 'Delete';

  @override
  String get actionEdit => 'Edit';

  @override
  String get actionAdd => 'Add';

  @override
  String get actionConfirm => 'Confirm';

  @override
  String get actionSkip => 'Skip';

  @override
  String get actionNext => 'Next';

  @override
  String get actionBack => 'Back';

  @override
  String get actionFinish => 'Finish';

  @override
  String get confirmDeleteTitle => 'Delete?';

  @override
  String get confirmDeleteMessage => 'This action cannot be undone.';

  @override
  String get onboardingWelcomeTitle => 'Welcome to Pet Passport';

  @override
  String get onboardingWelcomeBody =>
      'Track your pets\' health, appointments, and daily life — all in one place, stored only on your device.';

  @override
  String get onboardingAddFirstPetTitle => 'Add your first pet';

  @override
  String get onboardingAddFirstPetBody =>
      'Let\'s set up a profile for your pet. You can add more later.';

  @override
  String get petsListTitle => 'My pets';

  @override
  String get petsListEmpty => 'No pets yet';

  @override
  String get petsListEmptyAction => 'Add a pet';

  @override
  String get petEditNewTitle => 'New pet';

  @override
  String get petEditEditTitle => 'Edit pet';

  @override
  String get petFieldName => 'Name';

  @override
  String get petFieldSpecies => 'Species';

  @override
  String get petFieldBreed => 'Breed';

  @override
  String get petFieldSex => 'Sex';

  @override
  String get petFieldDateOfBirth => 'Date of birth';

  @override
  String get petFieldColor => 'Colour / markings';

  @override
  String get petFieldChipNumber => 'Chip number';

  @override
  String get petFieldTassoNumber => 'Tasso number';

  @override
  String get petFieldNotes => 'Notes';

  @override
  String get petPickProfilePhoto => 'Choose profile photo';

  @override
  String get petReplaceProfilePhoto => 'Replace profile photo';

  @override
  String get petRemoveProfilePhoto => 'Remove photo';

  @override
  String get speciesDog => 'Dog';

  @override
  String get speciesCat => 'Cat';

  @override
  String get sexMale => 'Male';

  @override
  String get sexFemale => 'Female';

  @override
  String get sexNeutered => 'Neutered';

  @override
  String get petFieldNeutered => 'Neutered / spayed';

  @override
  String get petFieldNeuteredHelp => 'Independent of biological sex.';

  @override
  String get lifeStagePuppy => 'Puppy';

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
      other: '$count years',
      one: '1 year',
    );
    return '$_temp0';
  }

  @override
  String ageMonths(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count months',
      one: '1 month',
    );
    return '$_temp0';
  }

  @override
  String get ageUnknown => 'Age unknown';

  @override
  String get petDetailOverview => 'Overview';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsAppearance => 'Appearance';

  @override
  String get settingsThemeMode => 'Theme';

  @override
  String get settingsThemeSystem => 'System';

  @override
  String get settingsThemeLight => 'Light';

  @override
  String get settingsThemeDark => 'Dark';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsLanguageSystem => 'System default';

  @override
  String get settingsLanguageGerman => 'Deutsch';

  @override
  String get settingsLanguageEnglish => 'English';

  @override
  String get validationRequired => 'Required';

  @override
  String get validationTooLong => 'Too long';

  @override
  String get vetsListTitle => 'Vets';

  @override
  String get vetsEmptyTitle => 'No vets yet';

  @override
  String get vetsEmptyMessage =>
      'Save your pet\'s vet contacts for quick access.';

  @override
  String get vetsEmptyAction => 'Add vet';

  @override
  String get vetEditNewTitle => 'New vet';

  @override
  String get vetEditEditTitle => 'Edit vet';

  @override
  String get vetFieldName => 'Name';

  @override
  String get vetFieldPractice => 'Practice / clinic';

  @override
  String get vetFieldAddress => 'Address';

  @override
  String get vetFieldPhone => 'Phone';

  @override
  String get vetFieldEmail => 'Email';

  @override
  String get insurancesListTitle => 'Insurances';

  @override
  String get insurancesEmptyTitle => 'No insurances yet';

  @override
  String get insurancesEmptyMessage =>
      'Track policies and attach the paperwork.';

  @override
  String get insurancesEmptyAction => 'Add insurance';

  @override
  String get insuranceEditNewTitle => 'New insurance';

  @override
  String get insuranceEditEditTitle => 'Edit insurance';

  @override
  String get insuranceFieldProvider => 'Provider';

  @override
  String get insuranceFieldPolicy => 'Policy number';

  @override
  String get insuranceFieldContractStart => 'Contract start';

  @override
  String get insuranceFieldContractEnd => 'Contract end';

  @override
  String get insuranceDocumentsSection => 'Documents';

  @override
  String get insuranceDocumentsEmpty => 'No documents attached yet.';

  @override
  String get overviewVetsTile => 'Vets';

  @override
  String get overviewInsurancesTile => 'Insurances';

  @override
  String get launchFailed => 'No app available for this action.';

  @override
  String get copiedToClipboard => 'Copied to clipboard';

  @override
  String get vaccinationsListTitle => 'Vaccinations';

  @override
  String get vaccinationsEmptyTitle => 'No vaccinations recorded';

  @override
  String get vaccinationsEmptyMessage =>
      'Track shots and their next-due dates.';

  @override
  String get vaccinationsEmptyAction => 'Add vaccination';

  @override
  String get vaccinationEditNewTitle => 'New vaccination';

  @override
  String get vaccinationEditEditTitle => 'Edit vaccination';

  @override
  String get vaccinationFieldName => 'Vaccine';

  @override
  String get vaccinationFieldAdministered => 'Administered on';

  @override
  String get vaccinationFieldNextDue => 'Next due';

  @override
  String get vaccinationFieldVet => 'Given by';

  @override
  String get vaccinationFieldBatch => 'Batch / lot';

  @override
  String get vaccinationVetNone => 'Not specified';

  @override
  String vaccinationAdministeredOn(String date) {
    return 'Administered $date';
  }

  @override
  String vaccinationNextDue(String date) {
    return 'Next due $date';
  }

  @override
  String get vaccinationOverdue => 'Overdue';

  @override
  String get vaccinationOverdueMessage =>
      'This vaccination is overdue. Contact your vet to schedule a booster.';

  @override
  String vaccinationDueIn(int days, String date) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Due in $days days · $date',
      one: 'Due tomorrow · $date',
      zero: 'Due today · $date',
    );
    return '$_temp0';
  }

  @override
  String vaccinationOverdueBy(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Overdue by $days days',
      one: 'Overdue by 1 day',
    );
    return '$_temp0';
  }

  @override
  String get termineUpcomingVaccinations => 'Upcoming vaccinations';

  @override
  String get overviewVaccinationsTitle => 'Vaccinations';

  @override
  String get overviewVaccinationsEmpty => 'No upcoming shots recorded.';

  @override
  String get emergencyTitle => 'Emergency info';

  @override
  String get emergencyVetsSection => 'Vets';

  @override
  String get emergencyCallAction => 'Call';

  @override
  String get emergencyWeightTitle => 'Latest weight';

  @override
  String emergencyWeightValue(String weight, String date) {
    return '$weight kg · measured $date';
  }

  @override
  String get emergencyQrTitle => 'Emergency QR';

  @override
  String get emergencyQrHelp =>
      'Scan to read all key info in one place. Tap the icon for a full-screen version.';

  @override
  String get emergencyQrExpand => 'Full screen';

  @override
  String get petFieldAllergies => 'Allergies';

  @override
  String get petFieldAllergiesHelp =>
      'Medications, ingredients or environmental triggers to avoid.';

  @override
  String get vaccinationDocumentsSection => 'Documents';

  @override
  String get vaccinationDocumentsEmpty => 'No documents attached yet.';

  @override
  String get settingsReminders => 'Reminders';

  @override
  String get settingsReminderLead => 'Vaccination reminder lead';

  @override
  String settingsReminderLeadValue(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days before',
      one: '1 day before',
    );
    return '$_temp0';
  }

  @override
  String overviewCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count entries',
      one: '1 entry',
      zero: 'None',
    );
    return '$_temp0';
  }
}
