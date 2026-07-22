import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_l10n_de.dart';
import 'app_l10n_en.dart';

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
    Locale('de'),
    Locale('en'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Pet Passport'**
  String get appTitle;

  /// No description provided for @navDashboard.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get navDashboard;

  /// No description provided for @navPets.
  ///
  /// In en, this message translates to:
  /// **'Pets'**
  String get navPets;

  /// No description provided for @navSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navTermine.
  ///
  /// In en, this message translates to:
  /// **'Schedule'**
  String get navTermine;

  /// No description provided for @navAlltag.
  ///
  /// In en, this message translates to:
  /// **'Daily'**
  String get navAlltag;

  /// No description provided for @navMore.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get navMore;

  /// No description provided for @termineEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Nothing scheduled yet'**
  String get termineEmptyTitle;

  /// No description provided for @termineEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'Vaccinations, medications and appointments will appear here.'**
  String get termineEmptyMessage;

  /// No description provided for @alltagEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No entries yet'**
  String get alltagEmptyTitle;

  /// No description provided for @alltagEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'Diet and daily events will appear here.'**
  String get alltagEmptyMessage;

  /// No description provided for @switchPetTitle.
  ///
  /// In en, this message translates to:
  /// **'Switch pet'**
  String get switchPetTitle;

  /// No description provided for @moreManagePets.
  ///
  /// In en, this message translates to:
  /// **'Manage pets'**
  String get moreManagePets;

  /// No description provided for @actionSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get actionSave;

  /// No description provided for @actionCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get actionCancel;

  /// No description provided for @actionDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get actionDelete;

  /// No description provided for @actionEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get actionEdit;

  /// No description provided for @actionAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get actionAdd;

  /// No description provided for @actionConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get actionConfirm;

  /// No description provided for @actionSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get actionSkip;

  /// No description provided for @actionNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get actionNext;

  /// No description provided for @actionBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get actionBack;

  /// No description provided for @actionFinish.
  ///
  /// In en, this message translates to:
  /// **'Finish'**
  String get actionFinish;

  /// No description provided for @confirmDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete?'**
  String get confirmDeleteTitle;

  /// No description provided for @confirmDeleteMessage.
  ///
  /// In en, this message translates to:
  /// **'This action cannot be undone.'**
  String get confirmDeleteMessage;

  /// No description provided for @onboardingWelcomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome to Pet Passport'**
  String get onboardingWelcomeTitle;

  /// No description provided for @onboardingWelcomeBody.
  ///
  /// In en, this message translates to:
  /// **'Track your pets\' health, appointments, and daily life — all in one place, stored only on your device.'**
  String get onboardingWelcomeBody;

  /// No description provided for @onboardingAddFirstPetTitle.
  ///
  /// In en, this message translates to:
  /// **'Add your first pet'**
  String get onboardingAddFirstPetTitle;

  /// No description provided for @onboardingAddFirstPetBody.
  ///
  /// In en, this message translates to:
  /// **'Let\'s set up a profile for your pet. You can add more later.'**
  String get onboardingAddFirstPetBody;

  /// No description provided for @petsListTitle.
  ///
  /// In en, this message translates to:
  /// **'My pets'**
  String get petsListTitle;

  /// No description provided for @petsListEmpty.
  ///
  /// In en, this message translates to:
  /// **'No pets yet'**
  String get petsListEmpty;

  /// No description provided for @petsListEmptyAction.
  ///
  /// In en, this message translates to:
  /// **'Add a pet'**
  String get petsListEmptyAction;

  /// No description provided for @petEditNewTitle.
  ///
  /// In en, this message translates to:
  /// **'New pet'**
  String get petEditNewTitle;

  /// No description provided for @petEditEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit pet'**
  String get petEditEditTitle;

  /// No description provided for @petFieldName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get petFieldName;

  /// No description provided for @petFieldSpecies.
  ///
  /// In en, this message translates to:
  /// **'Species'**
  String get petFieldSpecies;

  /// No description provided for @petFieldBreed.
  ///
  /// In en, this message translates to:
  /// **'Breed'**
  String get petFieldBreed;

  /// No description provided for @petFieldSex.
  ///
  /// In en, this message translates to:
  /// **'Sex'**
  String get petFieldSex;

  /// No description provided for @petFieldDateOfBirth.
  ///
  /// In en, this message translates to:
  /// **'Date of birth'**
  String get petFieldDateOfBirth;

  /// No description provided for @petFieldColor.
  ///
  /// In en, this message translates to:
  /// **'Colour / markings'**
  String get petFieldColor;

  /// No description provided for @petFieldChipNumber.
  ///
  /// In en, this message translates to:
  /// **'Chip number'**
  String get petFieldChipNumber;

  /// No description provided for @petFieldTassoNumber.
  ///
  /// In en, this message translates to:
  /// **'Tasso number'**
  String get petFieldTassoNumber;

  /// No description provided for @petFieldNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get petFieldNotes;

  /// No description provided for @petPickProfilePhoto.
  ///
  /// In en, this message translates to:
  /// **'Choose profile photo'**
  String get petPickProfilePhoto;

  /// No description provided for @petReplaceProfilePhoto.
  ///
  /// In en, this message translates to:
  /// **'Replace profile photo'**
  String get petReplaceProfilePhoto;

  /// No description provided for @petRemoveProfilePhoto.
  ///
  /// In en, this message translates to:
  /// **'Remove photo'**
  String get petRemoveProfilePhoto;

  /// No description provided for @speciesDog.
  ///
  /// In en, this message translates to:
  /// **'Dog'**
  String get speciesDog;

  /// No description provided for @speciesCat.
  ///
  /// In en, this message translates to:
  /// **'Cat'**
  String get speciesCat;

  /// No description provided for @sexMale.
  ///
  /// In en, this message translates to:
  /// **'Male'**
  String get sexMale;

  /// No description provided for @sexFemale.
  ///
  /// In en, this message translates to:
  /// **'Female'**
  String get sexFemale;

  /// No description provided for @sexNeutered.
  ///
  /// In en, this message translates to:
  /// **'Neutered'**
  String get sexNeutered;

  /// No description provided for @petFieldNeutered.
  ///
  /// In en, this message translates to:
  /// **'Neutered / spayed'**
  String get petFieldNeutered;

  /// No description provided for @petFieldNeuteredHelp.
  ///
  /// In en, this message translates to:
  /// **'Independent of biological sex.'**
  String get petFieldNeuteredHelp;

  /// No description provided for @lifeStagePuppy.
  ///
  /// In en, this message translates to:
  /// **'Puppy'**
  String get lifeStagePuppy;

  /// No description provided for @lifeStageJunior.
  ///
  /// In en, this message translates to:
  /// **'Junior'**
  String get lifeStageJunior;

  /// No description provided for @lifeStageAdult.
  ///
  /// In en, this message translates to:
  /// **'Adult'**
  String get lifeStageAdult;

  /// No description provided for @lifeStageSenior.
  ///
  /// In en, this message translates to:
  /// **'Senior'**
  String get lifeStageSenior;

  /// No description provided for @ageYears.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 year} other{{count} years}}'**
  String ageYears(int count);

  /// No description provided for @ageMonths.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 month} other{{count} months}}'**
  String ageMonths(int count);

  /// No description provided for @ageUnknown.
  ///
  /// In en, this message translates to:
  /// **'Age unknown'**
  String get ageUnknown;

  /// No description provided for @petDetailOverview.
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get petDetailOverview;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsAppearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get settingsAppearance;

  /// No description provided for @settingsThemeMode.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get settingsThemeMode;

  /// No description provided for @settingsThemeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get settingsThemeSystem;

  /// No description provided for @settingsThemeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get settingsThemeLight;

  /// No description provided for @settingsThemeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get settingsThemeDark;

  /// No description provided for @settingsLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// No description provided for @settingsLanguageSystem.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get settingsLanguageSystem;

  /// No description provided for @settingsLanguageGerman.
  ///
  /// In en, this message translates to:
  /// **'Deutsch'**
  String get settingsLanguageGerman;

  /// No description provided for @settingsLanguageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get settingsLanguageEnglish;

  /// No description provided for @validationRequired.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get validationRequired;

  /// No description provided for @validationTooLong.
  ///
  /// In en, this message translates to:
  /// **'Too long'**
  String get validationTooLong;

  /// No description provided for @vetsListTitle.
  ///
  /// In en, this message translates to:
  /// **'Vets'**
  String get vetsListTitle;

  /// No description provided for @vetsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No vets yet'**
  String get vetsEmptyTitle;

  /// No description provided for @vetsEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'Save your pet\'s vet contacts for quick access.'**
  String get vetsEmptyMessage;

  /// No description provided for @vetsEmptyAction.
  ///
  /// In en, this message translates to:
  /// **'Add vet'**
  String get vetsEmptyAction;

  /// No description provided for @vetEditNewTitle.
  ///
  /// In en, this message translates to:
  /// **'New vet'**
  String get vetEditNewTitle;

  /// No description provided for @vetEditEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit vet'**
  String get vetEditEditTitle;

  /// No description provided for @vetFieldName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get vetFieldName;

  /// No description provided for @vetFieldPractice.
  ///
  /// In en, this message translates to:
  /// **'Practice / clinic'**
  String get vetFieldPractice;

  /// No description provided for @vetFieldAddress.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get vetFieldAddress;

  /// No description provided for @vetFieldPhone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get vetFieldPhone;

  /// No description provided for @vetFieldEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get vetFieldEmail;

  /// No description provided for @insurancesListTitle.
  ///
  /// In en, this message translates to:
  /// **'Insurances'**
  String get insurancesListTitle;

  /// No description provided for @insurancesEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No insurances yet'**
  String get insurancesEmptyTitle;

  /// No description provided for @insurancesEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'Track policies and attach the paperwork.'**
  String get insurancesEmptyMessage;

  /// No description provided for @insurancesEmptyAction.
  ///
  /// In en, this message translates to:
  /// **'Add insurance'**
  String get insurancesEmptyAction;

  /// No description provided for @insuranceEditNewTitle.
  ///
  /// In en, this message translates to:
  /// **'New insurance'**
  String get insuranceEditNewTitle;

  /// No description provided for @insuranceEditEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit insurance'**
  String get insuranceEditEditTitle;

  /// No description provided for @insuranceFieldProvider.
  ///
  /// In en, this message translates to:
  /// **'Provider'**
  String get insuranceFieldProvider;

  /// No description provided for @insuranceFieldPolicy.
  ///
  /// In en, this message translates to:
  /// **'Policy number'**
  String get insuranceFieldPolicy;

  /// No description provided for @insuranceFieldContractStart.
  ///
  /// In en, this message translates to:
  /// **'Contract start'**
  String get insuranceFieldContractStart;

  /// No description provided for @insuranceFieldContractEnd.
  ///
  /// In en, this message translates to:
  /// **'Contract end'**
  String get insuranceFieldContractEnd;

  /// No description provided for @insuranceDocumentsSection.
  ///
  /// In en, this message translates to:
  /// **'Documents'**
  String get insuranceDocumentsSection;

  /// No description provided for @insuranceDocumentsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No documents attached yet.'**
  String get insuranceDocumentsEmpty;

  /// No description provided for @overviewVetsTile.
  ///
  /// In en, this message translates to:
  /// **'Vets'**
  String get overviewVetsTile;

  /// No description provided for @overviewInsurancesTile.
  ///
  /// In en, this message translates to:
  /// **'Insurances'**
  String get overviewInsurancesTile;

  /// No description provided for @launchFailed.
  ///
  /// In en, this message translates to:
  /// **'No app available for this action.'**
  String get launchFailed;

  /// No description provided for @copiedToClipboard.
  ///
  /// In en, this message translates to:
  /// **'Copied to clipboard'**
  String get copiedToClipboard;

  /// No description provided for @vaccinationsListTitle.
  ///
  /// In en, this message translates to:
  /// **'Vaccinations'**
  String get vaccinationsListTitle;

  /// No description provided for @vaccinationsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No vaccinations recorded'**
  String get vaccinationsEmptyTitle;

  /// No description provided for @vaccinationsEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'Track shots and their next-due dates.'**
  String get vaccinationsEmptyMessage;

  /// No description provided for @vaccinationsEmptyAction.
  ///
  /// In en, this message translates to:
  /// **'Add vaccination'**
  String get vaccinationsEmptyAction;

  /// No description provided for @vaccinationEditNewTitle.
  ///
  /// In en, this message translates to:
  /// **'New vaccination'**
  String get vaccinationEditNewTitle;

  /// No description provided for @vaccinationEditEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit vaccination'**
  String get vaccinationEditEditTitle;

  /// No description provided for @vaccinationFieldName.
  ///
  /// In en, this message translates to:
  /// **'Vaccine'**
  String get vaccinationFieldName;

  /// No description provided for @vaccinationFieldAdministered.
  ///
  /// In en, this message translates to:
  /// **'Administered on'**
  String get vaccinationFieldAdministered;

  /// No description provided for @vaccinationFieldNextDue.
  ///
  /// In en, this message translates to:
  /// **'Next due'**
  String get vaccinationFieldNextDue;

  /// No description provided for @vaccinationFieldVet.
  ///
  /// In en, this message translates to:
  /// **'Given by'**
  String get vaccinationFieldVet;

  /// No description provided for @vaccinationFieldBatch.
  ///
  /// In en, this message translates to:
  /// **'Batch / lot'**
  String get vaccinationFieldBatch;

  /// No description provided for @vaccinationVetNone.
  ///
  /// In en, this message translates to:
  /// **'Not specified'**
  String get vaccinationVetNone;

  /// No description provided for @vaccinationAdministeredOn.
  ///
  /// In en, this message translates to:
  /// **'Administered {date}'**
  String vaccinationAdministeredOn(String date);

  /// No description provided for @vaccinationNextDue.
  ///
  /// In en, this message translates to:
  /// **'Next due {date}'**
  String vaccinationNextDue(String date);

  /// No description provided for @vaccinationOverdue.
  ///
  /// In en, this message translates to:
  /// **'Overdue'**
  String get vaccinationOverdue;

  /// No description provided for @vaccinationOverdueMessage.
  ///
  /// In en, this message translates to:
  /// **'This vaccination is overdue. Contact your vet to schedule a booster.'**
  String get vaccinationOverdueMessage;

  /// No description provided for @vaccinationDueIn.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =0{Due today · {date}} =1{Due tomorrow · {date}} other{Due in {days} days · {date}}}'**
  String vaccinationDueIn(int days, String date);

  /// No description provided for @vaccinationOverdueBy.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =1{Overdue by 1 day} other{Overdue by {days} days}}'**
  String vaccinationOverdueBy(int days);

  /// No description provided for @termineUpcomingVaccinations.
  ///
  /// In en, this message translates to:
  /// **'Upcoming vaccinations'**
  String get termineUpcomingVaccinations;

  /// No description provided for @overviewVaccinationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Vaccinations'**
  String get overviewVaccinationsTitle;

  /// No description provided for @overviewVaccinationsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No upcoming shots recorded.'**
  String get overviewVaccinationsEmpty;

  /// No description provided for @emergencyTitle.
  ///
  /// In en, this message translates to:
  /// **'Emergency info'**
  String get emergencyTitle;

  /// No description provided for @emergencyVetsSection.
  ///
  /// In en, this message translates to:
  /// **'Vets'**
  String get emergencyVetsSection;

  /// No description provided for @emergencyCallAction.
  ///
  /// In en, this message translates to:
  /// **'Call'**
  String get emergencyCallAction;

  /// No description provided for @emergencyWeightTitle.
  ///
  /// In en, this message translates to:
  /// **'Latest weight'**
  String get emergencyWeightTitle;

  /// No description provided for @emergencyWeightValue.
  ///
  /// In en, this message translates to:
  /// **'{weight} kg · measured {date}'**
  String emergencyWeightValue(String weight, String date);

  /// No description provided for @emergencyQrTitle.
  ///
  /// In en, this message translates to:
  /// **'Emergency QR'**
  String get emergencyQrTitle;

  /// No description provided for @emergencyQrHelp.
  ///
  /// In en, this message translates to:
  /// **'Scan to read all key info in one place. Tap the icon for a full-screen version.'**
  String get emergencyQrHelp;

  /// No description provided for @emergencyQrExpand.
  ///
  /// In en, this message translates to:
  /// **'Full screen'**
  String get emergencyQrExpand;

  /// No description provided for @petFieldAllergies.
  ///
  /// In en, this message translates to:
  /// **'Allergies'**
  String get petFieldAllergies;

  /// No description provided for @petFieldAllergiesHelp.
  ///
  /// In en, this message translates to:
  /// **'Medications, ingredients or environmental triggers to avoid.'**
  String get petFieldAllergiesHelp;

  /// No description provided for @vaccinationDocumentsSection.
  ///
  /// In en, this message translates to:
  /// **'Documents'**
  String get vaccinationDocumentsSection;

  /// No description provided for @vaccinationDocumentsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No documents attached yet.'**
  String get vaccinationDocumentsEmpty;

  /// No description provided for @settingsReminders.
  ///
  /// In en, this message translates to:
  /// **'Reminders'**
  String get settingsReminders;

  /// No description provided for @settingsReminderLead.
  ///
  /// In en, this message translates to:
  /// **'Vaccination reminder lead'**
  String get settingsReminderLead;

  /// No description provided for @settingsReminderLeadValue.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =1{1 day before} other{{days} days before}}'**
  String settingsReminderLeadValue(int days);

  /// No description provided for @overviewCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{None} =1{1 entry} other{{count} entries}}'**
  String overviewCount(int count);
}

class _AppL10nDelegate extends LocalizationsDelegate<AppL10n> {
  const _AppL10nDelegate();

  @override
  Future<AppL10n> load(Locale locale) {
    return SynchronousFuture<AppL10n>(lookupAppL10n(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['de', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppL10nDelegate old) => false;
}

AppL10n lookupAppL10n(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppL10nDe();
    case 'en':
      return AppL10nEn();
  }

  throw FlutterError(
    'AppL10n.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
