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

  /// No description provided for @sexIntact.
  ///
  /// In en, this message translates to:
  /// **'Not neutered'**
  String get sexIntact;

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

  /// No description provided for @vetActiveLabel.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get vetActiveLabel;

  /// No description provided for @vetsActiveSection.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get vetsActiveSection;

  /// No description provided for @vetsArchivedSection.
  ///
  /// In en, this message translates to:
  /// **'Archived'**
  String get vetsArchivedSection;

  /// No description provided for @actionShowArchived.
  ///
  /// In en, this message translates to:
  /// **'Show archived'**
  String get actionShowArchived;

  /// No description provided for @actionHideArchived.
  ///
  /// In en, this message translates to:
  /// **'Hide archived'**
  String get actionHideArchived;

  /// No description provided for @contactsListTitle.
  ///
  /// In en, this message translates to:
  /// **'Contacts'**
  String get contactsListTitle;

  /// No description provided for @contactsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No contacts yet'**
  String get contactsEmptyTitle;

  /// No description provided for @contactsEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'Dog sitters, trainers and other people your pet relies on.'**
  String get contactsEmptyMessage;

  /// No description provided for @contactsEmptyAction.
  ///
  /// In en, this message translates to:
  /// **'Add contact'**
  String get contactsEmptyAction;

  /// No description provided for @contactEditNewTitle.
  ///
  /// In en, this message translates to:
  /// **'New contact'**
  String get contactEditNewTitle;

  /// No description provided for @contactEditEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit contact'**
  String get contactEditEditTitle;

  /// No description provided for @contactFieldName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get contactFieldName;

  /// No description provided for @contactFieldRole.
  ///
  /// In en, this message translates to:
  /// **'Role'**
  String get contactFieldRole;

  /// No description provided for @contactFieldOrganization.
  ///
  /// In en, this message translates to:
  /// **'Organisation / company'**
  String get contactFieldOrganization;

  /// No description provided for @contactFieldAddress.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get contactFieldAddress;

  /// No description provided for @contactFieldPhone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get contactFieldPhone;

  /// No description provided for @contactFieldEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get contactFieldEmail;

  /// No description provided for @contactActiveLabel.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get contactActiveLabel;

  /// No description provided for @contactRoleSitter.
  ///
  /// In en, this message translates to:
  /// **'Sitter'**
  String get contactRoleSitter;

  /// No description provided for @contactRoleTrainer.
  ///
  /// In en, this message translates to:
  /// **'Trainer'**
  String get contactRoleTrainer;

  /// No description provided for @contactRoleGroomer.
  ///
  /// In en, this message translates to:
  /// **'Groomer'**
  String get contactRoleGroomer;

  /// No description provided for @contactRoleOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get contactRoleOther;

  /// No description provided for @moreContacts.
  ///
  /// In en, this message translates to:
  /// **'Contacts'**
  String get moreContacts;

  /// No description provided for @moreDocuments.
  ///
  /// In en, this message translates to:
  /// **'Documents'**
  String get moreDocuments;

  /// No description provided for @documentsListTitle.
  ///
  /// In en, this message translates to:
  /// **'Documents'**
  String get documentsListTitle;

  /// No description provided for @documentsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No documents yet'**
  String get documentsEmptyTitle;

  /// No description provided for @documentsEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'Findings, important letters and other PDFs or photos in one place.'**
  String get documentsEmptyMessage;

  /// No description provided for @documentsEmptyAction.
  ///
  /// In en, this message translates to:
  /// **'Add document'**
  String get documentsEmptyAction;

  /// No description provided for @documentsAddAction.
  ///
  /// In en, this message translates to:
  /// **'Pick file'**
  String get documentsAddAction;

  /// No description provided for @documentEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Title & note'**
  String get documentEditTitle;

  /// No description provided for @documentFieldTitle.
  ///
  /// In en, this message translates to:
  /// **'Title (optional)'**
  String get documentFieldTitle;

  /// No description provided for @documentFieldNotes.
  ///
  /// In en, this message translates to:
  /// **'Note (optional)'**
  String get documentFieldNotes;

  /// No description provided for @documentFieldOriginalFilename.
  ///
  /// In en, this message translates to:
  /// **'Original filename'**
  String get documentFieldOriginalFilename;

  /// No description provided for @attachmentRenameTitle.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get attachmentRenameTitle;

  /// No description provided for @attachmentRenameHint.
  ///
  /// In en, this message translates to:
  /// **'Title (leave empty to reset)'**
  String get attachmentRenameHint;

  /// No description provided for @actionRename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get actionRename;

  /// No description provided for @actionOpenInMaps.
  ///
  /// In en, this message translates to:
  /// **'Open in maps'**
  String get actionOpenInMaps;

  /// No description provided for @actionAddToCalendar.
  ///
  /// In en, this message translates to:
  /// **'Export to calendar'**
  String get actionAddToCalendar;

  /// No description provided for @actionAddToCalendarShareSubject.
  ///
  /// In en, this message translates to:
  /// **'Calendar entry'**
  String get actionAddToCalendarShareSubject;

  /// No description provided for @appointmentContactLabel.
  ///
  /// In en, this message translates to:
  /// **'Contact'**
  String get appointmentContactLabel;

  /// No description provided for @emptyShowArchivedAction.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Show 1 archived entry} other{Show {count} archived entries}}'**
  String emptyShowArchivedAction(int count);

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

  /// No description provided for @settingsSecurity.
  ///
  /// In en, this message translates to:
  /// **'Security'**
  String get settingsSecurity;

  /// No description provided for @settingsAppLock.
  ///
  /// In en, this message translates to:
  /// **'App lock'**
  String get settingsAppLock;

  /// No description provided for @settingsAppLockHelp.
  ///
  /// In en, this message translates to:
  /// **'Require biometric or device credential to open the app.'**
  String get settingsAppLockHelp;

  /// No description provided for @settingsAppLockUnavailable.
  ///
  /// In en, this message translates to:
  /// **'No biometric or device credential set up on this device.'**
  String get settingsAppLockUnavailable;

  /// No description provided for @appLockReason.
  ///
  /// In en, this message translates to:
  /// **'Unlock Pet Passport'**
  String get appLockReason;

  /// No description provided for @appLockSignInTitle.
  ///
  /// In en, this message translates to:
  /// **'Authentication required'**
  String get appLockSignInTitle;

  /// No description provided for @appLockLockedTitle.
  ///
  /// In en, this message translates to:
  /// **'Locked'**
  String get appLockLockedTitle;

  /// No description provided for @appLockLockedBody.
  ///
  /// In en, this message translates to:
  /// **'Authenticate to continue.'**
  String get appLockLockedBody;

  /// No description provided for @appLockUnlock.
  ///
  /// In en, this message translates to:
  /// **'Unlock'**
  String get appLockUnlock;

  /// No description provided for @settingsCloudSection.
  ///
  /// In en, this message translates to:
  /// **'Cloud & shared household'**
  String get settingsCloudSection;

  /// No description provided for @settingsSignIn.
  ///
  /// In en, this message translates to:
  /// **'Enable cloud (sign in)'**
  String get settingsSignIn;

  /// No description provided for @settingsSignedInAs.
  ///
  /// In en, this message translates to:
  /// **'Signed in as {email}'**
  String settingsSignedInAs(String email);

  /// No description provided for @settingsSignOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get settingsSignOut;

  /// No description provided for @signInTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signInTitle;

  /// No description provided for @signInHeadline.
  ///
  /// In en, this message translates to:
  /// **'Sign in with email'**
  String get signInHeadline;

  /// No description provided for @signInBody.
  ///
  /// In en, this message translates to:
  /// **'You\'ll get a magic link by mail. Tapping the link signs you in directly — no password needed.'**
  String get signInBody;

  /// No description provided for @signInEmailLabel.
  ///
  /// In en, this message translates to:
  /// **'Email address'**
  String get signInEmailLabel;

  /// No description provided for @signInEmailInvalid.
  ///
  /// In en, this message translates to:
  /// **'Invalid email'**
  String get signInEmailInvalid;

  /// No description provided for @signInSendAction.
  ///
  /// In en, this message translates to:
  /// **'Send magic link'**
  String get signInSendAction;

  /// No description provided for @signInSkipAction.
  ///
  /// In en, this message translates to:
  /// **'Back (skip cloud)'**
  String get signInSkipAction;

  /// No description provided for @signInWaitingHeadline.
  ///
  /// In en, this message translates to:
  /// **'Mail sent'**
  String get signInWaitingHeadline;

  /// No description provided for @signInWaitingBody.
  ///
  /// In en, this message translates to:
  /// **'We\'ve sent a link to {email}. Open the mail on this device and tap the link — the app will sign you in automatically.'**
  String signInWaitingBody(String email);

  /// No description provided for @signInWaitingBack.
  ///
  /// In en, this message translates to:
  /// **'Different email'**
  String get signInWaitingBack;

  /// No description provided for @displayNameTitle.
  ///
  /// In en, this message translates to:
  /// **'Display name'**
  String get displayNameTitle;

  /// No description provided for @displayNameHeadline.
  ///
  /// In en, this message translates to:
  /// **'How should you appear in the app?'**
  String get displayNameHeadline;

  /// No description provided for @displayNameBody.
  ///
  /// In en, this message translates to:
  /// **'Other household members will see this name, not your email. You can change it later.'**
  String get displayNameBody;

  /// No description provided for @displayNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Display name'**
  String get displayNameLabel;

  /// No description provided for @displayNameTooShort.
  ///
  /// In en, this message translates to:
  /// **'At least 2 characters'**
  String get displayNameTooShort;

  /// No description provided for @householdsSection.
  ///
  /// In en, this message translates to:
  /// **'My households'**
  String get householdsSection;

  /// No description provided for @householdsDefaultName.
  ///
  /// In en, this message translates to:
  /// **'My household'**
  String get householdsDefaultName;

  /// No description provided for @householdsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No households'**
  String get householdsEmpty;

  /// No description provided for @householdsMemberCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 member} other{{count} members}}'**
  String householdsMemberCount(int count);

  /// No description provided for @householdsRoleOwner.
  ///
  /// In en, this message translates to:
  /// **'Owner'**
  String get householdsRoleOwner;

  /// No description provided for @householdsRoleMember.
  ///
  /// In en, this message translates to:
  /// **'Member'**
  String get householdsRoleMember;

  /// No description provided for @householdsCreate.
  ///
  /// In en, this message translates to:
  /// **'Create household'**
  String get householdsCreate;

  /// No description provided for @householdsCreateHint.
  ///
  /// In en, this message translates to:
  /// **'Name (e.g. The Wilsons)'**
  String get householdsCreateHint;

  /// No description provided for @householdDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'Household'**
  String get householdDetailTitle;

  /// No description provided for @householdFieldName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get householdFieldName;

  /// No description provided for @householdDeleteAction.
  ///
  /// In en, this message translates to:
  /// **'Delete household'**
  String get householdDeleteAction;

  /// No description provided for @householdDeleteConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this household?'**
  String get householdDeleteConfirmTitle;

  /// No description provided for @householdDeleteConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'All data in this household (pets, appointments, photos, documents etc.) will be permanently deleted for every member.'**
  String get householdDeleteConfirmBody;

  /// No description provided for @householdInvitePerson.
  ///
  /// In en, this message translates to:
  /// **'Invite person'**
  String get householdInvitePerson;

  /// No description provided for @householdMembersHeader.
  ///
  /// In en, this message translates to:
  /// **'Members'**
  String get householdMembersHeader;

  /// No description provided for @householdMembersEmpty.
  ///
  /// In en, this message translates to:
  /// **'No members.'**
  String get householdMembersEmpty;

  /// No description provided for @householdMemberSelfSuffix.
  ///
  /// In en, this message translates to:
  /// **'{name} (you)'**
  String householdMemberSelfSuffix(String name);

  /// No description provided for @householdMemberRemoveAction.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get householdMemberRemoveAction;

  /// No description provided for @householdMemberRemoveConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove member?'**
  String get householdMemberRemoveConfirmTitle;

  /// No description provided for @householdMemberRemoveConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'{name} will be removed from the household and lose access to all its data immediately.'**
  String householdMemberRemoveConfirmBody(String name);

  /// No description provided for @householdLeaveAction.
  ///
  /// In en, this message translates to:
  /// **'Leave household'**
  String get householdLeaveAction;

  /// No description provided for @householdLeaveConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Leave this household?'**
  String get householdLeaveConfirmTitle;

  /// No description provided for @householdLeaveConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'You will lose access to all its data. Other members keep theirs.'**
  String get householdLeaveConfirmBody;

  /// No description provided for @householdLeaveSoloOwnerTitle.
  ///
  /// In en, this message translates to:
  /// **'Cannot leave'**
  String get householdLeaveSoloOwnerTitle;

  /// No description provided for @householdLeaveSoloOwnerBody.
  ///
  /// In en, this message translates to:
  /// **'You are the only owner. Invite someone and transfer the owner role, or delete the household entirely.'**
  String get householdLeaveSoloOwnerBody;

  /// No description provided for @inviteScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'Invite'**
  String get inviteScreenTitle;

  /// No description provided for @inviteHeadline.
  ///
  /// In en, this message translates to:
  /// **'Invite someone to this household'**
  String get inviteHeadline;

  /// No description provided for @inviteBody.
  ///
  /// In en, this message translates to:
  /// **'Scan the QR, share the link, or type the code manually. Expires after 24 hours and can be used once.'**
  String get inviteBody;

  /// No description provided for @inviteEmptyHeadline.
  ///
  /// In en, this message translates to:
  /// **'No code yet'**
  String get inviteEmptyHeadline;

  /// No description provided for @inviteEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Generate an invite code to add someone to this household.'**
  String get inviteEmptyBody;

  /// No description provided for @inviteGenerate.
  ///
  /// In en, this message translates to:
  /// **'Generate code'**
  String get inviteGenerate;

  /// No description provided for @inviteRegenerate.
  ///
  /// In en, this message translates to:
  /// **'Generate new code'**
  String get inviteRegenerate;

  /// No description provided for @inviteRevoke.
  ///
  /// In en, this message translates to:
  /// **'Revoke code'**
  String get inviteRevoke;

  /// No description provided for @inviteCopyLink.
  ///
  /// In en, this message translates to:
  /// **'Copy link'**
  String get inviteCopyLink;

  /// No description provided for @inviteShareLink.
  ///
  /// In en, this message translates to:
  /// **'Share link'**
  String get inviteShareLink;

  /// No description provided for @inviteShareSubject.
  ///
  /// In en, this message translates to:
  /// **'Household invitation'**
  String get inviteShareSubject;

  /// No description provided for @inviteShareBody.
  ///
  /// In en, this message translates to:
  /// **'Join my Pet Passport household: {link}'**
  String inviteShareBody(String link);

  /// No description provided for @inviteExpired.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get inviteExpired;

  /// No description provided for @inviteExpiresInHours.
  ///
  /// In en, this message translates to:
  /// **'Expires in {hours} h {minutes} min'**
  String inviteExpiresInHours(int hours, int minutes);

  /// No description provided for @inviteExpiresInMinutes.
  ///
  /// In en, this message translates to:
  /// **'Expires in {minutes} min {seconds} s'**
  String inviteExpiresInMinutes(int minutes, int seconds);

  /// No description provided for @inviteExpiresInSeconds.
  ///
  /// In en, this message translates to:
  /// **'Expires in {seconds} s'**
  String inviteExpiresInSeconds(int seconds);

  /// No description provided for @joinScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'Join household'**
  String get joinScreenTitle;

  /// No description provided for @joinHeadline.
  ///
  /// In en, this message translates to:
  /// **'Redeem invite code'**
  String get joinHeadline;

  /// No description provided for @joinBody.
  ///
  /// In en, this message translates to:
  /// **'Scan the QR or paste the code the owner generated for you.'**
  String get joinBody;

  /// No description provided for @joinCodeLabel.
  ///
  /// In en, this message translates to:
  /// **'Invite code'**
  String get joinCodeLabel;

  /// No description provided for @joinScanAction.
  ///
  /// In en, this message translates to:
  /// **'Scan QR'**
  String get joinScanAction;

  /// No description provided for @joinScanTitle.
  ///
  /// In en, this message translates to:
  /// **'Scan QR code'**
  String get joinScanTitle;

  /// No description provided for @joinAction.
  ///
  /// In en, this message translates to:
  /// **'Join'**
  String get joinAction;

  /// No description provided for @joinNeedSignInHeadline.
  ///
  /// In en, this message translates to:
  /// **'Sign in first'**
  String get joinNeedSignInHeadline;

  /// No description provided for @joinNeedSignInBody.
  ///
  /// In en, this message translates to:
  /// **'To join a household you need to sign in with email first. You can redeem the same code afterwards.'**
  String get joinNeedSignInBody;

  /// No description provided for @joinSuccessTitle.
  ///
  /// In en, this message translates to:
  /// **'Joined'**
  String get joinSuccessTitle;

  /// No description provided for @joinSuccessBody.
  ///
  /// In en, this message translates to:
  /// **'You are now a member of \"{name}\" with {count} members.'**
  String joinSuccessBody(String name, int count);

  /// No description provided for @joinErrorInvalid.
  ///
  /// In en, this message translates to:
  /// **'Code is invalid or no longer active.'**
  String get joinErrorInvalid;

  /// No description provided for @joinErrorExpired.
  ///
  /// In en, this message translates to:
  /// **'Code has expired. Ask the owner for a new one.'**
  String get joinErrorExpired;

  /// No description provided for @joinErrorUsed.
  ///
  /// In en, this message translates to:
  /// **'Code has already been used.'**
  String get joinErrorUsed;

  /// No description provided for @exportTitle.
  ///
  /// In en, this message translates to:
  /// **'Import / Export'**
  String get exportTitle;

  /// No description provided for @exportJsonTitle.
  ///
  /// In en, this message translates to:
  /// **'JSON backup'**
  String get exportJsonTitle;

  /// No description provided for @exportJsonHelp.
  ///
  /// In en, this message translates to:
  /// **'Creates a JSON file with all pets, vets, insurances and vaccinations. Share it via email, cloud or another app.'**
  String get exportJsonHelp;

  /// No description provided for @exportJsonAction.
  ///
  /// In en, this message translates to:
  /// **'Export & share'**
  String get exportJsonAction;

  /// No description provided for @exportMediaNote.
  ///
  /// In en, this message translates to:
  /// **'Attached documents and photos are referenced by path. To keep them, back up the app\'s storage folder separately.'**
  String get exportMediaNote;

  /// No description provided for @importJsonTitle.
  ///
  /// In en, this message translates to:
  /// **'JSON restore'**
  String get importJsonTitle;

  /// No description provided for @importJsonHelp.
  ///
  /// In en, this message translates to:
  /// **'Restore pets, vets, insurances and vaccinations from a JSON backup file. Entries with the same UUID are updated; new ones are added.'**
  String get importJsonHelp;

  /// No description provided for @importJsonAction.
  ///
  /// In en, this message translates to:
  /// **'Pick file & import'**
  String get importJsonAction;

  /// No description provided for @importConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Import backup?'**
  String get importConfirmTitle;

  /// No description provided for @importConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'Existing entries with matching UUIDs will be overwritten. Continue?'**
  String get importConfirmBody;

  /// No description provided for @importConfirm.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get importConfirm;

  /// No description provided for @importCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get importCancel;

  /// No description provided for @importResultTitle.
  ///
  /// In en, this message translates to:
  /// **'Import complete'**
  String get importResultTitle;

  /// No description provided for @importResultBody.
  ///
  /// In en, this message translates to:
  /// **'{added, plural, =0{No new entries} =1{1 new entry} other{{added} new entries}}, {updated, plural, =0{no updates} =1{1 updated} other{{updated} updated}}.'**
  String importResultBody(int added, int updated);

  /// No description provided for @importResultErrors.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 entry was skipped due to errors} other{{count} entries were skipped due to errors}}.'**
  String importResultErrors(int count);

  /// No description provided for @eventTypeWeight.
  ///
  /// In en, this message translates to:
  /// **'Weight'**
  String get eventTypeWeight;

  /// No description provided for @eventTypeFeeding.
  ///
  /// In en, this message translates to:
  /// **'Feeding'**
  String get eventTypeFeeding;

  /// No description provided for @eventTypeSymptom.
  ///
  /// In en, this message translates to:
  /// **'Symptom'**
  String get eventTypeSymptom;

  /// No description provided for @eventTypeActivity.
  ///
  /// In en, this message translates to:
  /// **'Activity'**
  String get eventTypeActivity;

  /// No description provided for @eventTypeGeneric.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get eventTypeGeneric;

  /// No description provided for @eventTypeAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get eventTypeAll;

  /// No description provided for @eventFeedingMealMorning.
  ///
  /// In en, this message translates to:
  /// **'Morning'**
  String get eventFeedingMealMorning;

  /// No description provided for @eventFeedingMealNoon.
  ///
  /// In en, this message translates to:
  /// **'Noon'**
  String get eventFeedingMealNoon;

  /// No description provided for @eventFeedingMealEvening.
  ///
  /// In en, this message translates to:
  /// **'Evening'**
  String get eventFeedingMealEvening;

  /// No description provided for @eventFeedingMealSnack.
  ///
  /// In en, this message translates to:
  /// **'Snack'**
  String get eventFeedingMealSnack;

  /// No description provided for @eventSymptomSeverityLow.
  ///
  /// In en, this message translates to:
  /// **'Mild'**
  String get eventSymptomSeverityLow;

  /// No description provided for @eventSymptomSeverityMedium.
  ///
  /// In en, this message translates to:
  /// **'Moderate'**
  String get eventSymptomSeverityMedium;

  /// No description provided for @eventSymptomSeverityHigh.
  ///
  /// In en, this message translates to:
  /// **'Severe'**
  String get eventSymptomSeverityHigh;

  /// No description provided for @eventActivityTypeWalk.
  ///
  /// In en, this message translates to:
  /// **'Walk'**
  String get eventActivityTypeWalk;

  /// No description provided for @eventActivityTypePlay.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get eventActivityTypePlay;

  /// No description provided for @eventActivityTypeTraining.
  ///
  /// In en, this message translates to:
  /// **'Training'**
  String get eventActivityTypeTraining;

  /// No description provided for @eventActivityTypeOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get eventActivityTypeOther;

  /// No description provided for @alltagFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get alltagFilterAll;

  /// No description provided for @alltagFilterTypeLabel.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get alltagFilterTypeLabel;

  /// No description provided for @alltagFilterRangeLabel.
  ///
  /// In en, this message translates to:
  /// **'Range: {days} days'**
  String alltagFilterRangeLabel(int days);

  /// No description provided for @alltagNoEventsForFilter.
  ///
  /// In en, this message translates to:
  /// **'No entries match the current filter.'**
  String get alltagNoEventsForFilter;

  /// No description provided for @alltagAddEventFabTooltip.
  ///
  /// In en, this message translates to:
  /// **'Add entry'**
  String get alltagAddEventFabTooltip;

  /// No description provided for @alltagSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search titles'**
  String get alltagSearchHint;

  /// No description provided for @eventEditNewTitle.
  ///
  /// In en, this message translates to:
  /// **'New entry'**
  String get eventEditNewTitle;

  /// No description provided for @eventEditEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit entry'**
  String get eventEditEditTitle;

  /// No description provided for @eventPickTypeTitle.
  ///
  /// In en, this message translates to:
  /// **'What did you observe?'**
  String get eventPickTypeTitle;

  /// No description provided for @eventFieldOccurredAt.
  ///
  /// In en, this message translates to:
  /// **'When'**
  String get eventFieldOccurredAt;

  /// No description provided for @eventFieldTitle.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get eventFieldTitle;

  /// No description provided for @eventFieldNote.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get eventFieldNote;

  /// No description provided for @eventFieldWeightKg.
  ///
  /// In en, this message translates to:
  /// **'Weight (kg)'**
  String get eventFieldWeightKg;

  /// No description provided for @eventFieldFoodName.
  ///
  /// In en, this message translates to:
  /// **'Food'**
  String get eventFieldFoodName;

  /// No description provided for @eventFieldAmountG.
  ///
  /// In en, this message translates to:
  /// **'Amount (g)'**
  String get eventFieldAmountG;

  /// No description provided for @eventFieldMeal.
  ///
  /// In en, this message translates to:
  /// **'Meal'**
  String get eventFieldMeal;

  /// No description provided for @eventFieldSymptomDescription.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get eventFieldSymptomDescription;

  /// No description provided for @eventFieldSymptomSeverity.
  ///
  /// In en, this message translates to:
  /// **'Severity'**
  String get eventFieldSymptomSeverity;

  /// No description provided for @eventFieldActivityType.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get eventFieldActivityType;

  /// No description provided for @eventFieldDistanceM.
  ///
  /// In en, this message translates to:
  /// **'Distance (m)'**
  String get eventFieldDistanceM;

  /// No description provided for @eventFieldDurationMin.
  ///
  /// In en, this message translates to:
  /// **'Duration (min)'**
  String get eventFieldDurationMin;

  /// No description provided for @eventTagsHeader.
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get eventTagsHeader;

  /// No description provided for @eventTagAddNew.
  ///
  /// In en, this message translates to:
  /// **'New tag'**
  String get eventTagAddNew;

  /// No description provided for @eventTagNewDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'New tag'**
  String get eventTagNewDialogTitle;

  /// No description provided for @eventTagNewDialogLabel.
  ///
  /// In en, this message translates to:
  /// **'Label'**
  String get eventTagNewDialogLabel;

  /// No description provided for @eventPhotosHeader.
  ///
  /// In en, this message translates to:
  /// **'Photos'**
  String get eventPhotosHeader;

  /// No description provided for @eventPhotoAdd.
  ///
  /// In en, this message translates to:
  /// **'Add photo'**
  String get eventPhotoAdd;

  /// No description provided for @eventValidationRequired.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get eventValidationRequired;

  /// No description provided for @eventValidationInvalidNumber.
  ///
  /// In en, this message translates to:
  /// **'Not a valid number'**
  String get eventValidationInvalidNumber;

  /// No description provided for @eventDeleteConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete entry?'**
  String get eventDeleteConfirmTitle;

  /// No description provided for @eventDeleteConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'This can\'t be undone.'**
  String get eventDeleteConfirmBody;

  /// No description provided for @overviewCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{None} =1{1 entry} other{{count} entries}}'**
  String overviewCount(int count);

  /// No description provided for @notesLabel.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get notesLabel;

  /// No description provided for @errorRequired.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get errorRequired;

  /// No description provided for @optionNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get optionNone;

  /// No description provided for @actionClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get actionClear;

  /// No description provided for @notFound.
  ///
  /// In en, this message translates to:
  /// **'Not found.'**
  String get notFound;

  /// No description provided for @appointmentsListTitle.
  ///
  /// In en, this message translates to:
  /// **'Appointments'**
  String get appointmentsListTitle;

  /// No description provided for @appointmentsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No appointments yet'**
  String get appointmentsEmptyTitle;

  /// No description provided for @appointmentsEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'Vet visits, grooming, and training show up here.'**
  String get appointmentsEmptyMessage;

  /// No description provided for @appointmentNewTitle.
  ///
  /// In en, this message translates to:
  /// **'New appointment'**
  String get appointmentNewTitle;

  /// No description provided for @appointmentEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit appointment'**
  String get appointmentEditTitle;

  /// No description provided for @appointmentDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'Appointment'**
  String get appointmentDetailTitle;

  /// No description provided for @appointmentTypeLabel.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get appointmentTypeLabel;

  /// No description provided for @appointmentTypeVet.
  ///
  /// In en, this message translates to:
  /// **'Vet'**
  String get appointmentTypeVet;

  /// No description provided for @appointmentTypeGrooming.
  ///
  /// In en, this message translates to:
  /// **'Grooming'**
  String get appointmentTypeGrooming;

  /// No description provided for @appointmentTypeTraining.
  ///
  /// In en, this message translates to:
  /// **'Training'**
  String get appointmentTypeTraining;

  /// No description provided for @appointmentTypeWalk.
  ///
  /// In en, this message translates to:
  /// **'Walk'**
  String get appointmentTypeWalk;

  /// No description provided for @appointmentTypeCheckup.
  ///
  /// In en, this message translates to:
  /// **'Checkup'**
  String get appointmentTypeCheckup;

  /// No description provided for @appointmentTypeOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get appointmentTypeOther;

  /// No description provided for @appointmentTitleLabel.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get appointmentTitleLabel;

  /// No description provided for @appointmentStartsAtLabel.
  ///
  /// In en, this message translates to:
  /// **'Starts at'**
  String get appointmentStartsAtLabel;

  /// No description provided for @appointmentDurationLabel.
  ///
  /// In en, this message translates to:
  /// **'Duration (min)'**
  String get appointmentDurationLabel;

  /// No description provided for @appointmentVetLabel.
  ///
  /// In en, this message translates to:
  /// **'Vet'**
  String get appointmentVetLabel;

  /// No description provided for @appointmentLocationLabel.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get appointmentLocationLabel;

  /// No description provided for @durationMinutesValue.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String durationMinutesValue(int minutes);

  /// No description provided for @upcomingOccurrencesTitle.
  ///
  /// In en, this message translates to:
  /// **'Next occurrences'**
  String get upcomingOccurrencesTitle;

  /// No description provided for @noUpcomingOccurrences.
  ///
  /// In en, this message translates to:
  /// **'No upcoming occurrences.'**
  String get noUpcomingOccurrences;

  /// No description provided for @recurrenceSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Recurrence'**
  String get recurrenceSectionTitle;

  /// No description provided for @remindersSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Reminders'**
  String get remindersSectionTitle;

  /// No description provided for @recurrenceFrequencyLabel.
  ///
  /// In en, this message translates to:
  /// **'Frequency'**
  String get recurrenceFrequencyLabel;

  /// No description provided for @recurrenceNone.
  ///
  /// In en, this message translates to:
  /// **'Once'**
  String get recurrenceNone;

  /// No description provided for @recurrenceDaily.
  ///
  /// In en, this message translates to:
  /// **'Daily'**
  String get recurrenceDaily;

  /// No description provided for @recurrenceWeekly.
  ///
  /// In en, this message translates to:
  /// **'Weekly'**
  String get recurrenceWeekly;

  /// No description provided for @recurrenceMonthly.
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get recurrenceMonthly;

  /// No description provided for @recurrenceIntervalLabel.
  ///
  /// In en, this message translates to:
  /// **'Every'**
  String get recurrenceIntervalLabel;

  /// No description provided for @recurrenceHintDaily.
  ///
  /// In en, this message translates to:
  /// **'{n, plural, =1{day} other{{n} days}}'**
  String recurrenceHintDaily(int n);

  /// No description provided for @recurrenceHintWeekly.
  ///
  /// In en, this message translates to:
  /// **'{n, plural, =1{week} other{{n} weeks}}'**
  String recurrenceHintWeekly(int n);

  /// No description provided for @recurrenceHintMonthly.
  ///
  /// In en, this message translates to:
  /// **'{n, plural, =1{month} other{{n} months}}'**
  String recurrenceHintMonthly(int n);

  /// No description provided for @recurrenceUntilNone.
  ///
  /// In en, this message translates to:
  /// **'No end date'**
  String get recurrenceUntilNone;

  /// No description provided for @recurrenceUntilLabel.
  ///
  /// In en, this message translates to:
  /// **'Until {date}'**
  String recurrenceUntilLabel(String date);

  /// No description provided for @recurrenceUntilPick.
  ///
  /// In en, this message translates to:
  /// **'Pick end date'**
  String get recurrenceUntilPick;

  /// No description provided for @weekdayShortMon.
  ///
  /// In en, this message translates to:
  /// **'Mon'**
  String get weekdayShortMon;

  /// No description provided for @weekdayShortTue.
  ///
  /// In en, this message translates to:
  /// **'Tue'**
  String get weekdayShortTue;

  /// No description provided for @weekdayShortWed.
  ///
  /// In en, this message translates to:
  /// **'Wed'**
  String get weekdayShortWed;

  /// No description provided for @weekdayShortThu.
  ///
  /// In en, this message translates to:
  /// **'Thu'**
  String get weekdayShortThu;

  /// No description provided for @weekdayShortFri.
  ///
  /// In en, this message translates to:
  /// **'Fri'**
  String get weekdayShortFri;

  /// No description provided for @weekdayShortSat.
  ///
  /// In en, this message translates to:
  /// **'Sat'**
  String get weekdayShortSat;

  /// No description provided for @weekdayShortSun.
  ///
  /// In en, this message translates to:
  /// **'Sun'**
  String get weekdayShortSun;

  /// No description provided for @reminderOffsetAtTime.
  ///
  /// In en, this message translates to:
  /// **'At time'**
  String get reminderOffsetAtTime;

  /// No description provided for @reminderOffsetMinutes.
  ///
  /// In en, this message translates to:
  /// **'{n} min before'**
  String reminderOffsetMinutes(int n);

  /// No description provided for @reminderOffsetHours.
  ///
  /// In en, this message translates to:
  /// **'{n, plural, =1{1 h before} other{{n} h before}}'**
  String reminderOffsetHours(int n);

  /// No description provided for @reminderOffsetDays.
  ///
  /// In en, this message translates to:
  /// **'{n, plural, =1{1 day before} other{{n} days before}}'**
  String reminderOffsetDays(int n);

  /// No description provided for @medicationsListTitle.
  ///
  /// In en, this message translates to:
  /// **'Medications'**
  String get medicationsListTitle;

  /// No description provided for @medicationsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No medications yet'**
  String get medicationsEmptyTitle;

  /// No description provided for @medicationsEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'Ongoing treatments and doses show up here.'**
  String get medicationsEmptyMessage;

  /// No description provided for @medicationNewTitle.
  ///
  /// In en, this message translates to:
  /// **'New medication'**
  String get medicationNewTitle;

  /// No description provided for @medicationEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit medication'**
  String get medicationEditTitle;

  /// No description provided for @medicationDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'Medication'**
  String get medicationDetailTitle;

  /// No description provided for @medicationNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get medicationNameLabel;

  /// No description provided for @medicationDosageAmountLabel.
  ///
  /// In en, this message translates to:
  /// **'Dosage'**
  String get medicationDosageAmountLabel;

  /// No description provided for @medicationDosageUnitLabel.
  ///
  /// In en, this message translates to:
  /// **'Unit'**
  String get medicationDosageUnitLabel;

  /// No description provided for @medicationFreqTypeLabel.
  ///
  /// In en, this message translates to:
  /// **'Frequency'**
  String get medicationFreqTypeLabel;

  /// No description provided for @medicationFreqDaily.
  ///
  /// In en, this message translates to:
  /// **'Daily'**
  String get medicationFreqDaily;

  /// No description provided for @medicationFreqWeekly.
  ///
  /// In en, this message translates to:
  /// **'Weekly'**
  String get medicationFreqWeekly;

  /// No description provided for @medicationFreqIntervalDays.
  ///
  /// In en, this message translates to:
  /// **'Every N days'**
  String get medicationFreqIntervalDays;

  /// No description provided for @medicationFreqIntervalLabel.
  ///
  /// In en, this message translates to:
  /// **'Interval'**
  String get medicationFreqIntervalLabel;

  /// No description provided for @medicationTimesOfDayLabel.
  ///
  /// In en, this message translates to:
  /// **'Times of day'**
  String get medicationTimesOfDayLabel;

  /// No description provided for @medicationAddTimeButton.
  ///
  /// In en, this message translates to:
  /// **'Add time'**
  String get medicationAddTimeButton;

  /// No description provided for @medicationStartsAtLabel.
  ///
  /// In en, this message translates to:
  /// **'Starts'**
  String get medicationStartsAtLabel;

  /// No description provided for @medicationEndsAtLabel.
  ///
  /// In en, this message translates to:
  /// **'Ends (optional)'**
  String get medicationEndsAtLabel;

  /// No description provided for @medicationActiveLabel.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get medicationActiveLabel;

  /// No description provided for @medicationPrescribedByLabel.
  ///
  /// In en, this message translates to:
  /// **'Prescribed by'**
  String get medicationPrescribedByLabel;

  /// No description provided for @medicationActiveSection.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get medicationActiveSection;

  /// No description provided for @medicationInactiveSection.
  ///
  /// In en, this message translates to:
  /// **'Inactive'**
  String get medicationInactiveSection;

  /// No description provided for @medicationAdherenceTitle.
  ///
  /// In en, this message translates to:
  /// **'Adherence — last 7 days'**
  String get medicationAdherenceTitle;

  /// No description provided for @medicationAdherenceCount.
  ///
  /// In en, this message translates to:
  /// **'{taken}/{expected} taken'**
  String medicationAdherenceCount(int taken, int expected);

  /// No description provided for @medicationLogIntakeButton.
  ///
  /// In en, this message translates to:
  /// **'Log intake'**
  String get medicationLogIntakeButton;

  /// No description provided for @medicationLogSkippedButton.
  ///
  /// In en, this message translates to:
  /// **'Log skipped'**
  String get medicationLogSkippedButton;

  /// No description provided for @medicationIntakeHistoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Intake history'**
  String get medicationIntakeHistoryTitle;

  /// No description provided for @medicationIntakeHistoryEmpty.
  ///
  /// In en, this message translates to:
  /// **'No entries yet.'**
  String get medicationIntakeHistoryEmpty;

  /// No description provided for @medicationIntakeSkippedChip.
  ///
  /// In en, this message translates to:
  /// **'Skipped'**
  String get medicationIntakeSkippedChip;

  /// No description provided for @medicationIntakeLoggedSnack.
  ///
  /// In en, this message translates to:
  /// **'Intake logged.'**
  String get medicationIntakeLoggedSnack;

  /// No description provided for @termineSectionAppointments.
  ///
  /// In en, this message translates to:
  /// **'Upcoming appointments'**
  String get termineSectionAppointments;

  /// No description provided for @termineSectionMedicationsToday.
  ///
  /// In en, this message translates to:
  /// **'Medications today'**
  String get termineSectionMedicationsToday;

  /// No description provided for @overviewNextAppointmentTitle.
  ///
  /// In en, this message translates to:
  /// **'Next appointment'**
  String get overviewNextAppointmentTitle;

  /// No description provided for @overviewNoAppointment.
  ///
  /// In en, this message translates to:
  /// **'No upcoming appointment.'**
  String get overviewNoAppointment;

  /// No description provided for @overviewActiveMedicationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Active medications'**
  String get overviewActiveMedicationsTitle;

  /// No description provided for @overviewNoActiveMedications.
  ///
  /// In en, this message translates to:
  /// **'No active medications.'**
  String get overviewNoActiveMedications;

  /// No description provided for @overviewActiveMedicationsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 medication} other{{count} medications}}'**
  String overviewActiveMedicationsCount(int count);

  /// No description provided for @moreAppointments.
  ///
  /// In en, this message translates to:
  /// **'Appointments'**
  String get moreAppointments;

  /// No description provided for @moreMedications.
  ///
  /// In en, this message translates to:
  /// **'Medications'**
  String get moreMedications;

  /// No description provided for @moreDiet.
  ///
  /// In en, this message translates to:
  /// **'Diet'**
  String get moreDiet;

  /// No description provided for @moreWeightChart.
  ///
  /// In en, this message translates to:
  /// **'Weight chart'**
  String get moreWeightChart;

  /// No description provided for @moreTimeline.
  ///
  /// In en, this message translates to:
  /// **'Timeline'**
  String get moreTimeline;

  /// No description provided for @timelineTitle.
  ///
  /// In en, this message translates to:
  /// **'Timeline'**
  String get timelineTitle;

  /// No description provided for @timelineEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Nothing in range'**
  String get timelineEmptyTitle;

  /// No description provided for @timelineEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'Events, vaccinations, medications and appointments show up here.'**
  String get timelineEmptyMessage;

  /// No description provided for @timelineFilterPet.
  ///
  /// In en, this message translates to:
  /// **'Pet'**
  String get timelineFilterPet;

  /// No description provided for @timelineFilterAllPets.
  ///
  /// In en, this message translates to:
  /// **'All pets'**
  String get timelineFilterAllPets;

  /// No description provided for @timelineKindEvent.
  ///
  /// In en, this message translates to:
  /// **'Events'**
  String get timelineKindEvent;

  /// No description provided for @timelineKindVaccination.
  ///
  /// In en, this message translates to:
  /// **'Vaccinations'**
  String get timelineKindVaccination;

  /// No description provided for @timelineKindMedication.
  ///
  /// In en, this message translates to:
  /// **'Medications'**
  String get timelineKindMedication;

  /// No description provided for @timelineKindAppointment.
  ///
  /// In en, this message translates to:
  /// **'Appointments'**
  String get timelineKindAppointment;

  /// No description provided for @morePdf.
  ///
  /// In en, this message translates to:
  /// **'PDF export'**
  String get morePdf;

  /// No description provided for @pdfMenuTitle.
  ///
  /// In en, this message translates to:
  /// **'PDF export'**
  String get pdfMenuTitle;

  /// No description provided for @pdfPassportTitle.
  ///
  /// In en, this message translates to:
  /// **'Vaccination passport'**
  String get pdfPassportTitle;

  /// No description provided for @pdfPassportSubtitle.
  ///
  /// In en, this message translates to:
  /// **'All vaccinations with date and batch number.'**
  String get pdfPassportSubtitle;

  /// No description provided for @pdfOverviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Profile sheet'**
  String get pdfOverviewTitle;

  /// No description provided for @pdfOverviewSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Full overview incl. vets and insurances.'**
  String get pdfOverviewSubtitle;

  /// No description provided for @pdfEmergencyTitle.
  ///
  /// In en, this message translates to:
  /// **'Emergency sheet'**
  String get pdfEmergencyTitle;

  /// No description provided for @pdfEmergencySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Contacts, chip and warnings for an emergency.'**
  String get pdfEmergencySubtitle;

  /// No description provided for @pdfVaccinationsSection.
  ///
  /// In en, this message translates to:
  /// **'Vaccinations'**
  String get pdfVaccinationsSection;

  /// No description provided for @pdfNoVaccinations.
  ///
  /// In en, this message translates to:
  /// **'No vaccinations recorded.'**
  String get pdfNoVaccinations;

  /// No description provided for @pdfColDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get pdfColDate;

  /// No description provided for @pdfColVaccine.
  ///
  /// In en, this message translates to:
  /// **'Vaccine'**
  String get pdfColVaccine;

  /// No description provided for @pdfColBatch.
  ///
  /// In en, this message translates to:
  /// **'Batch'**
  String get pdfColBatch;

  /// No description provided for @pdfColNextDue.
  ///
  /// In en, this message translates to:
  /// **'Next due'**
  String get pdfColNextDue;

  /// No description provided for @pdfColVet.
  ///
  /// In en, this message translates to:
  /// **'Vet'**
  String get pdfColVet;

  /// No description provided for @passportTitle.
  ///
  /// In en, this message translates to:
  /// **'Vaccination passport'**
  String get passportTitle;

  /// No description provided for @passportNumberLabel.
  ///
  /// In en, this message translates to:
  /// **'Passport number'**
  String get passportNumberLabel;

  /// No description provided for @passportNumberHelp.
  ///
  /// In en, this message translates to:
  /// **'Number on the physical passport booklet.'**
  String get passportNumberHelp;

  /// No description provided for @passportNumberSavedSnack.
  ///
  /// In en, this message translates to:
  /// **'Number saved.'**
  String get passportNumberSavedSnack;

  /// No description provided for @passportDocumentsSection.
  ///
  /// In en, this message translates to:
  /// **'Documents'**
  String get passportDocumentsSection;

  /// No description provided for @passportDocumentsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No documents attached yet.'**
  String get passportDocumentsEmpty;

  /// No description provided for @medicationWithFoodLabel.
  ///
  /// In en, this message translates to:
  /// **'Take with food'**
  String get medicationWithFoodLabel;

  /// No description provided for @medicationWithFoodHint.
  ///
  /// In en, this message translates to:
  /// **'Reminder body will include \"with food\".'**
  String get medicationWithFoodHint;

  /// No description provided for @medicationWithFoodChip.
  ///
  /// In en, this message translates to:
  /// **'With food'**
  String get medicationWithFoodChip;

  /// No description provided for @dietListTitle.
  ///
  /// In en, this message translates to:
  /// **'Diet'**
  String get dietListTitle;

  /// No description provided for @dietEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No food entries yet'**
  String get dietEmptyTitle;

  /// No description provided for @dietEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'Current diet and history show up here.'**
  String get dietEmptyMessage;

  /// No description provided for @dietActiveSection.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get dietActiveSection;

  /// No description provided for @dietInactiveSection.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get dietInactiveSection;

  /// No description provided for @dietNewTitle.
  ///
  /// In en, this message translates to:
  /// **'New food entry'**
  String get dietNewTitle;

  /// No description provided for @foodEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit food'**
  String get foodEditTitle;

  /// No description provided for @foodBrandLabel.
  ///
  /// In en, this message translates to:
  /// **'Brand'**
  String get foodBrandLabel;

  /// No description provided for @foodNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Product'**
  String get foodNameLabel;

  /// No description provided for @foodTypeLabel.
  ///
  /// In en, this message translates to:
  /// **'Food type'**
  String get foodTypeLabel;

  /// No description provided for @foodTypeDry.
  ///
  /// In en, this message translates to:
  /// **'Dry'**
  String get foodTypeDry;

  /// No description provided for @foodTypeWet.
  ///
  /// In en, this message translates to:
  /// **'Wet'**
  String get foodTypeWet;

  /// No description provided for @foodTypeRaw.
  ///
  /// In en, this message translates to:
  /// **'Raw'**
  String get foodTypeRaw;

  /// No description provided for @foodTypeBarf.
  ///
  /// In en, this message translates to:
  /// **'BARF'**
  String get foodTypeBarf;

  /// No description provided for @foodTypeTreat.
  ///
  /// In en, this message translates to:
  /// **'Treat'**
  String get foodTypeTreat;

  /// No description provided for @foodTypeOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get foodTypeOther;

  /// No description provided for @foodPortionGramsLabel.
  ///
  /// In en, this message translates to:
  /// **'Portion (g)'**
  String get foodPortionGramsLabel;

  /// No description provided for @foodFrequencyPerDayLabel.
  ///
  /// In en, this message translates to:
  /// **'Meals / day'**
  String get foodFrequencyPerDayLabel;

  /// No description provided for @foodTimesOfDayLabel.
  ///
  /// In en, this message translates to:
  /// **'Feeding times'**
  String get foodTimesOfDayLabel;

  /// No description provided for @foodStartsAtLabel.
  ///
  /// In en, this message translates to:
  /// **'Starts'**
  String get foodStartsAtLabel;

  /// No description provided for @foodEndsAtLabel.
  ///
  /// In en, this message translates to:
  /// **'Ends (optional)'**
  String get foodEndsAtLabel;

  /// No description provided for @foodActiveLabel.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get foodActiveLabel;

  /// No description provided for @foodRemindersEnabledLabel.
  ///
  /// In en, this message translates to:
  /// **'Feeding reminders'**
  String get foodRemindersEnabledLabel;

  /// No description provided for @foodRemindersEnabledHint.
  ///
  /// In en, this message translates to:
  /// **'Daily notifications at each feeding time.'**
  String get foodRemindersEnabledHint;

  /// No description provided for @foodRemindersOnChip.
  ///
  /// In en, this message translates to:
  /// **'Reminders on'**
  String get foodRemindersOnChip;

  /// No description provided for @petAllergyAddTitle.
  ///
  /// In en, this message translates to:
  /// **'Add allergy'**
  String get petAllergyAddTitle;

  /// No description provided for @petAllergyAddAction.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get petAllergyAddAction;

  /// No description provided for @petAllergyHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. chicken, pollen'**
  String get petAllergyHint;

  /// No description provided for @weightChartTitle.
  ///
  /// In en, this message translates to:
  /// **'Weight chart'**
  String get weightChartTitle;

  /// No description provided for @weightChartEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No curve yet'**
  String get weightChartEmptyTitle;

  /// No description provided for @weightChartEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'The chart shows up once at least two weight events exist.'**
  String get weightChartEmptyMessage;
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
