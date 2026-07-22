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
  String get settingsSecurity => 'Security';

  @override
  String get settingsAppLock => 'App lock';

  @override
  String get settingsAppLockHelp =>
      'Require biometric or device credential to open the app.';

  @override
  String get settingsAppLockUnavailable =>
      'No biometric or device credential set up on this device.';

  @override
  String get appLockReason => 'Unlock Pet Passport';

  @override
  String get appLockSignInTitle => 'Authentication required';

  @override
  String get appLockLockedTitle => 'Locked';

  @override
  String get appLockLockedBody => 'Authenticate to continue.';

  @override
  String get appLockUnlock => 'Unlock';

  @override
  String get exportTitle => 'Export';

  @override
  String get exportJsonTitle => 'JSON backup';

  @override
  String get exportJsonHelp =>
      'Creates a JSON file with all pets, vets, insurances and vaccinations. Share it via email, cloud or another app.';

  @override
  String get exportJsonAction => 'Export & share';

  @override
  String get exportMediaNote =>
      'Attached documents and photos are referenced by path. To keep them, back up the app\'s storage folder separately.';

  @override
  String get importJsonTitle => 'JSON restore';

  @override
  String get importJsonHelp =>
      'Restore pets, vets, insurances and vaccinations from a JSON backup file. Entries with the same UUID are updated; new ones are added.';

  @override
  String get importJsonAction => 'Pick file & import';

  @override
  String get importConfirmTitle => 'Import backup?';

  @override
  String get importConfirmBody =>
      'Existing entries with matching UUIDs will be overwritten. Continue?';

  @override
  String get importConfirm => 'Import';

  @override
  String get importCancel => 'Cancel';

  @override
  String get importResultTitle => 'Import complete';

  @override
  String importResultBody(int added, int updated) {
    String _temp0 = intl.Intl.pluralLogic(
      added,
      locale: localeName,
      other: '$added new entries',
      one: '1 new entry',
      zero: 'No new entries',
    );
    String _temp1 = intl.Intl.pluralLogic(
      updated,
      locale: localeName,
      other: '$updated updated',
      one: '1 updated',
      zero: 'no updates',
    );
    return '$_temp0, $_temp1.';
  }

  @override
  String importResultErrors(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count entries were skipped due to errors',
      one: '1 entry was skipped due to errors',
    );
    return '$_temp0.';
  }

  @override
  String get eventTypeWeight => 'Weight';

  @override
  String get eventTypeFeeding => 'Feeding';

  @override
  String get eventTypeSymptom => 'Symptom';

  @override
  String get eventTypeActivity => 'Activity';

  @override
  String get eventTypeGeneric => 'Note';

  @override
  String get eventTypeAll => 'All';

  @override
  String get eventFeedingMealMorning => 'Morning';

  @override
  String get eventFeedingMealNoon => 'Noon';

  @override
  String get eventFeedingMealEvening => 'Evening';

  @override
  String get eventFeedingMealSnack => 'Snack';

  @override
  String get eventSymptomSeverityLow => 'Mild';

  @override
  String get eventSymptomSeverityMedium => 'Moderate';

  @override
  String get eventSymptomSeverityHigh => 'Severe';

  @override
  String get eventActivityTypeWalk => 'Walk';

  @override
  String get eventActivityTypePlay => 'Play';

  @override
  String get eventActivityTypeTraining => 'Training';

  @override
  String get eventActivityTypeOther => 'Other';

  @override
  String get alltagFilterAll => 'All';

  @override
  String get alltagFilterTypeLabel => 'Type';

  @override
  String alltagFilterRangeLabel(int days) {
    return 'Range: $days days';
  }

  @override
  String get alltagNoEventsForFilter => 'No entries match the current filter.';

  @override
  String get alltagAddEventFabTooltip => 'Add entry';

  @override
  String get eventEditNewTitle => 'New entry';

  @override
  String get eventEditEditTitle => 'Edit entry';

  @override
  String get eventPickTypeTitle => 'What did you observe?';

  @override
  String get eventFieldOccurredAt => 'When';

  @override
  String get eventFieldTitle => 'Title';

  @override
  String get eventFieldNote => 'Note';

  @override
  String get eventFieldWeightKg => 'Weight (kg)';

  @override
  String get eventFieldFoodName => 'Food';

  @override
  String get eventFieldAmountG => 'Amount (g)';

  @override
  String get eventFieldMeal => 'Meal';

  @override
  String get eventFieldSymptomDescription => 'Description';

  @override
  String get eventFieldSymptomSeverity => 'Severity';

  @override
  String get eventFieldActivityType => 'Type';

  @override
  String get eventFieldDistanceM => 'Distance (m)';

  @override
  String get eventFieldDurationMin => 'Duration (min)';

  @override
  String get eventTagsHeader => 'Tags';

  @override
  String get eventTagAddNew => 'New tag';

  @override
  String get eventTagNewDialogTitle => 'New tag';

  @override
  String get eventTagNewDialogLabel => 'Label';

  @override
  String get eventPhotosHeader => 'Photos';

  @override
  String get eventPhotoAdd => 'Add photo';

  @override
  String get eventValidationRequired => 'Required';

  @override
  String get eventValidationInvalidNumber => 'Not a valid number';

  @override
  String get eventDeleteConfirmTitle => 'Delete entry?';

  @override
  String get eventDeleteConfirmBody => 'This can\'t be undone.';

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

  @override
  String get notesLabel => 'Notes';

  @override
  String get errorRequired => 'Required';

  @override
  String get optionNone => 'None';

  @override
  String get actionClear => 'Clear';

  @override
  String get notFound => 'Not found.';

  @override
  String get appointmentsListTitle => 'Appointments';

  @override
  String get appointmentsEmptyTitle => 'No appointments yet';

  @override
  String get appointmentsEmptyMessage =>
      'Vet visits, grooming, and training show up here.';

  @override
  String get appointmentNewTitle => 'New appointment';

  @override
  String get appointmentEditTitle => 'Edit appointment';

  @override
  String get appointmentDetailTitle => 'Appointment';

  @override
  String get appointmentTypeLabel => 'Type';

  @override
  String get appointmentTypeVet => 'Vet';

  @override
  String get appointmentTypeGrooming => 'Grooming';

  @override
  String get appointmentTypeTraining => 'Training';

  @override
  String get appointmentTypeWalk => 'Walk';

  @override
  String get appointmentTypeCheckup => 'Checkup';

  @override
  String get appointmentTypeOther => 'Other';

  @override
  String get appointmentTitleLabel => 'Title';

  @override
  String get appointmentStartsAtLabel => 'Starts at';

  @override
  String get appointmentDurationLabel => 'Duration (min)';

  @override
  String get appointmentVetLabel => 'Vet';

  @override
  String get appointmentLocationLabel => 'Location';

  @override
  String durationMinutesValue(int minutes) {
    return '$minutes min';
  }

  @override
  String get upcomingOccurrencesTitle => 'Next occurrences';

  @override
  String get noUpcomingOccurrences => 'No upcoming occurrences.';

  @override
  String get recurrenceSectionTitle => 'Recurrence';

  @override
  String get remindersSectionTitle => 'Reminders';

  @override
  String get recurrenceFrequencyLabel => 'Frequency';

  @override
  String get recurrenceNone => 'Once';

  @override
  String get recurrenceDaily => 'Daily';

  @override
  String get recurrenceWeekly => 'Weekly';

  @override
  String get recurrenceMonthly => 'Monthly';

  @override
  String get recurrenceIntervalLabel => 'Every';

  @override
  String recurrenceHintDaily(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n days',
      one: 'day',
    );
    return '$_temp0';
  }

  @override
  String recurrenceHintWeekly(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n weeks',
      one: 'week',
    );
    return '$_temp0';
  }

  @override
  String recurrenceHintMonthly(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n months',
      one: 'month',
    );
    return '$_temp0';
  }

  @override
  String get recurrenceUntilNone => 'No end date';

  @override
  String recurrenceUntilLabel(String date) {
    return 'Until $date';
  }

  @override
  String get recurrenceUntilPick => 'Pick end date';

  @override
  String get weekdayShortMon => 'Mon';

  @override
  String get weekdayShortTue => 'Tue';

  @override
  String get weekdayShortWed => 'Wed';

  @override
  String get weekdayShortThu => 'Thu';

  @override
  String get weekdayShortFri => 'Fri';

  @override
  String get weekdayShortSat => 'Sat';

  @override
  String get weekdayShortSun => 'Sun';

  @override
  String get reminderOffsetAtTime => 'At time';

  @override
  String reminderOffsetMinutes(int n) {
    return '$n min before';
  }

  @override
  String reminderOffsetHours(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n h before',
      one: '1 h before',
    );
    return '$_temp0';
  }

  @override
  String reminderOffsetDays(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n days before',
      one: '1 day before',
    );
    return '$_temp0';
  }

  @override
  String get medicationsListTitle => 'Medications';

  @override
  String get medicationsEmptyTitle => 'No medications yet';

  @override
  String get medicationsEmptyMessage =>
      'Ongoing treatments and doses show up here.';

  @override
  String get medicationNewTitle => 'New medication';

  @override
  String get medicationEditTitle => 'Edit medication';

  @override
  String get medicationDetailTitle => 'Medication';

  @override
  String get medicationNameLabel => 'Name';

  @override
  String get medicationDosageAmountLabel => 'Dosage';

  @override
  String get medicationDosageUnitLabel => 'Unit';

  @override
  String get medicationFreqTypeLabel => 'Frequency';

  @override
  String get medicationFreqDaily => 'Daily';

  @override
  String get medicationFreqWeekly => 'Weekly';

  @override
  String get medicationFreqIntervalDays => 'Every N days';

  @override
  String get medicationFreqIntervalLabel => 'Interval';

  @override
  String get medicationTimesOfDayLabel => 'Times of day';

  @override
  String get medicationAddTimeButton => 'Add time';

  @override
  String get medicationStartsAtLabel => 'Starts';

  @override
  String get medicationEndsAtLabel => 'Ends (optional)';

  @override
  String get medicationActiveLabel => 'Active';

  @override
  String get medicationPrescribedByLabel => 'Prescribed by';

  @override
  String get medicationActiveSection => 'Active';

  @override
  String get medicationInactiveSection => 'Inactive';

  @override
  String get medicationAdherenceTitle => 'Adherence — last 7 days';

  @override
  String medicationAdherenceCount(int taken, int expected) {
    return '$taken/$expected taken';
  }

  @override
  String get medicationLogIntakeButton => 'Log intake';

  @override
  String get medicationLogSkippedButton => 'Log skipped';

  @override
  String get medicationIntakeHistoryTitle => 'Intake history';

  @override
  String get medicationIntakeHistoryEmpty => 'No entries yet.';

  @override
  String get medicationIntakeSkippedChip => 'Skipped';

  @override
  String get medicationIntakeLoggedSnack => 'Intake logged.';

  @override
  String get termineSectionAppointments => 'Upcoming appointments';

  @override
  String get termineSectionMedicationsToday => 'Medications today';

  @override
  String get overviewNextAppointmentTitle => 'Next appointment';

  @override
  String get overviewNoAppointment => 'No upcoming appointment.';

  @override
  String get overviewActiveMedicationsTitle => 'Active medications';

  @override
  String get overviewNoActiveMedications => 'No active medications.';

  @override
  String overviewActiveMedicationsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count medications',
      one: '1 medication',
    );
    return '$_temp0';
  }

  @override
  String get moreAppointments => 'Appointments';

  @override
  String get moreMedications => 'Medications';

  @override
  String get moreDiet => 'Diet';

  @override
  String get moreWeightChart => 'Weight chart';

  @override
  String get moreTimeline => 'Timeline';

  @override
  String get timelineTitle => 'Timeline';

  @override
  String get timelineEmptyTitle => 'Nothing in range';

  @override
  String get timelineEmptyMessage =>
      'Events, vaccinations, medications and appointments show up here.';

  @override
  String get timelineFilterPet => 'Pet';

  @override
  String get timelineFilterAllPets => 'All pets';

  @override
  String get timelineKindEvent => 'Events';

  @override
  String get timelineKindVaccination => 'Vaccinations';

  @override
  String get timelineKindMedication => 'Medications';

  @override
  String get timelineKindAppointment => 'Appointments';

  @override
  String get morePdf => 'PDF export';

  @override
  String get pdfMenuTitle => 'PDF export';

  @override
  String get pdfPassportTitle => 'Vaccination passport';

  @override
  String get pdfPassportSubtitle =>
      'All vaccinations with date and batch number.';

  @override
  String get pdfOverviewTitle => 'Profile sheet';

  @override
  String get pdfOverviewSubtitle => 'Full overview incl. vets and insurances.';

  @override
  String get pdfEmergencyTitle => 'Emergency sheet';

  @override
  String get pdfEmergencySubtitle =>
      'Contacts, chip and warnings for an emergency.';

  @override
  String get pdfVaccinationsSection => 'Vaccinations';

  @override
  String get pdfNoVaccinations => 'No vaccinations recorded.';

  @override
  String get pdfColDate => 'Date';

  @override
  String get pdfColVaccine => 'Vaccine';

  @override
  String get pdfColBatch => 'Batch';

  @override
  String get pdfColNextDue => 'Next due';

  @override
  String get pdfColVet => 'Vet';

  @override
  String get medicationWithFoodLabel => 'Take with food';

  @override
  String get medicationWithFoodHint =>
      'Reminder body will include \"with food\".';

  @override
  String get medicationWithFoodChip => 'With food';

  @override
  String get dietListTitle => 'Diet';

  @override
  String get dietEmptyTitle => 'No food entries yet';

  @override
  String get dietEmptyMessage => 'Current diet and history show up here.';

  @override
  String get dietActiveSection => 'Active';

  @override
  String get dietInactiveSection => 'History';

  @override
  String get dietNewTitle => 'New food entry';

  @override
  String get foodEditTitle => 'Edit food';

  @override
  String get foodBrandLabel => 'Brand';

  @override
  String get foodNameLabel => 'Product';

  @override
  String get foodTypeLabel => 'Food type';

  @override
  String get foodTypeDry => 'Dry';

  @override
  String get foodTypeWet => 'Wet';

  @override
  String get foodTypeRaw => 'Raw';

  @override
  String get foodTypeBarf => 'BARF';

  @override
  String get foodTypeTreat => 'Treat';

  @override
  String get foodTypeOther => 'Other';

  @override
  String get foodPortionGramsLabel => 'Portion (g)';

  @override
  String get foodFrequencyPerDayLabel => 'Meals / day';

  @override
  String get foodTimesOfDayLabel => 'Feeding times';

  @override
  String get foodStartsAtLabel => 'Starts';

  @override
  String get foodEndsAtLabel => 'Ends (optional)';

  @override
  String get foodActiveLabel => 'Active';

  @override
  String get foodRemindersEnabledLabel => 'Feeding reminders';

  @override
  String get foodRemindersEnabledHint =>
      'Daily notifications at each feeding time.';

  @override
  String get foodRemindersOnChip => 'Reminders on';

  @override
  String get petAllergyAddTitle => 'Add allergy';

  @override
  String get petAllergyAddAction => 'Add';

  @override
  String get petAllergyHint => 'e.g. chicken, pollen';

  @override
  String get weightChartTitle => 'Weight chart';

  @override
  String get weightChartEmptyTitle => 'No curve yet';

  @override
  String get weightChartEmptyMessage =>
      'The chart shows up once at least two weight events exist.';
}
