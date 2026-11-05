import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_bn.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
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
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

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
    Locale('bn'),
    Locale('en'),
  ];

  /// No description provided for @appTagline.
  ///
  /// In en, this message translates to:
  /// **'Save Lives • Connect Hearts'**
  String get appTagline;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signIn;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get signOut;

  /// No description provided for @tryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get tryAgain;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @emailLabel.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get emailLabel;

  /// No description provided for @emailHint.
  ///
  /// In en, this message translates to:
  /// **'you@example.com'**
  String get emailHint;

  /// No description provided for @passwordLabel.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get passwordLabel;

  /// No description provided for @showPassword.
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get showPassword;

  /// No description provided for @hidePassword.
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get hidePassword;

  /// No description provided for @welcomeHeadline.
  ///
  /// In en, this message translates to:
  /// **'A Drop of Hope, Give Blood, Give Life'**
  String get welcomeHeadline;

  /// No description provided for @welcomeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'One donation can be the difference between a family waiting and a family reuniting. Join the community that answers when someone calls.'**
  String get welcomeSubtitle;

  /// No description provided for @getStarted.
  ///
  /// In en, this message translates to:
  /// **'Get Started'**
  String get getStarted;

  /// No description provided for @alreadyHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account?'**
  String get alreadyHaveAccount;

  /// No description provided for @loginTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome back'**
  String get loginTitle;

  /// No description provided for @loginSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in to reach your donor profile and the requests near you.'**
  String get loginSubtitle;

  /// No description provided for @passwordHint.
  ///
  /// In en, this message translates to:
  /// **'Your password'**
  String get passwordHint;

  /// No description provided for @forgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get forgotPassword;

  /// No description provided for @newToSolovvo.
  ///
  /// In en, this message translates to:
  /// **'New to Solovvo?'**
  String get newToSolovvo;

  /// No description provided for @createAnAccount.
  ///
  /// In en, this message translates to:
  /// **'Create an account'**
  String get createAnAccount;

  /// No description provided for @registerTitle.
  ///
  /// In en, this message translates to:
  /// **'Join Solovvo'**
  String get registerTitle;

  /// No description provided for @registerSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Donors are matched by blood group and distance. Registration takes less than a minute.'**
  String get registerSubtitle;

  /// No description provided for @fullNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Full name'**
  String get fullNameLabel;

  /// No description provided for @fullNameHint.
  ///
  /// In en, this message translates to:
  /// **'As it will appear to donors'**
  String get fullNameHint;

  /// No description provided for @newPasswordHint.
  ///
  /// In en, this message translates to:
  /// **'At least 8 characters'**
  String get newPasswordHint;

  /// No description provided for @passwordRule.
  ///
  /// In en, this message translates to:
  /// **'Mix letters and numbers'**
  String get passwordRule;

  /// No description provided for @confirmPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Confirm password'**
  String get confirmPasswordLabel;

  /// No description provided for @confirmPasswordHint.
  ///
  /// In en, this message translates to:
  /// **'Repeat the password'**
  String get confirmPasswordHint;

  /// No description provided for @createAccount.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get createAccount;

  /// No description provided for @verificationEmailNote.
  ///
  /// In en, this message translates to:
  /// **'We will email you a link to confirm the address before your account can answer a request.'**
  String get verificationEmailNote;

  /// No description provided for @alreadyRegistered.
  ///
  /// In en, this message translates to:
  /// **'Already registered?'**
  String get alreadyRegistered;

  /// No description provided for @forgotTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset your password'**
  String get forgotTitle;

  /// No description provided for @forgotSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enter the address on your account and we will send a link to choose a new password.'**
  String get forgotSubtitle;

  /// No description provided for @sendResetLink.
  ///
  /// In en, this message translates to:
  /// **'Send reset link'**
  String get sendResetLink;

  /// No description provided for @backToSignIn.
  ///
  /// In en, this message translates to:
  /// **'Back to sign in'**
  String get backToSignIn;

  /// No description provided for @resetSentTitle.
  ///
  /// In en, this message translates to:
  /// **'Check your inbox'**
  String get resetSentTitle;

  /// No description provided for @resetSentBody.
  ///
  /// In en, this message translates to:
  /// **'If an account exists for {email}, a password reset link is on its way from Firebase. The link expires after one hour.'**
  String resetSentBody(String email);

  /// No description provided for @verifyTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm your email'**
  String get verifyTitle;

  /// No description provided for @verifySubtitle.
  ///
  /// In en, this message translates to:
  /// **'One tap in your inbox unlocks the rest of Solovvo.'**
  String get verifySubtitle;

  /// No description provided for @sentToLabel.
  ///
  /// In en, this message translates to:
  /// **'We sent a link to'**
  String get sentToLabel;

  /// No description provided for @verifyLockedBody.
  ///
  /// In en, this message translates to:
  /// **'Your account is created, but donation features stay locked until the address is confirmed.'**
  String get verifyLockedBody;

  /// No description provided for @freshLinkSent.
  ///
  /// In en, this message translates to:
  /// **'A fresh link is on its way.'**
  String get freshLinkSent;

  /// No description provided for @notConfirmedYet.
  ///
  /// In en, this message translates to:
  /// **'Not confirmed yet. Open the link in your inbox, then check again.'**
  String get notConfirmedYet;

  /// No description provided for @confirmedCta.
  ///
  /// In en, this message translates to:
  /// **'I\'ve confirmed my email'**
  String get confirmedCta;

  /// No description provided for @resendEmail.
  ///
  /// In en, this message translates to:
  /// **'Resend email'**
  String get resendEmail;

  /// No description provided for @resendIn.
  ///
  /// In en, this message translates to:
  /// **'Resend in {seconds}s'**
  String resendIn(int seconds);

  /// No description provided for @unknownEmail.
  ///
  /// In en, this message translates to:
  /// **'your email address'**
  String get unknownEmail;

  /// No description provided for @homeGreeting.
  ///
  /// In en, this message translates to:
  /// **'Welcome, {name}'**
  String homeGreeting(String name);

  /// No description provided for @homeDashboardSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Everything you need to give blood — and to ask for it.'**
  String get homeDashboardSubtitle;

  /// No description provided for @verified.
  ///
  /// In en, this message translates to:
  /// **'Verified'**
  String get verified;

  /// No description provided for @donorStatusTitle.
  ///
  /// In en, this message translates to:
  /// **'Donor status'**
  String get donorStatusTitle;

  /// No description provided for @bloodGroupLabel.
  ///
  /// In en, this message translates to:
  /// **'Blood group'**
  String get bloodGroupLabel;

  /// No description provided for @lastDonationLabel.
  ///
  /// In en, this message translates to:
  /// **'Last donation'**
  String get lastDonationLabel;

  /// No description provided for @availabilityLabel.
  ///
  /// In en, this message translates to:
  /// **'Availability'**
  String get availabilityLabel;

  /// No description provided for @notSetYet.
  ///
  /// In en, this message translates to:
  /// **'Not set yet'**
  String get notSetYet;

  /// No description provided for @availableNow.
  ///
  /// In en, this message translates to:
  /// **'Available'**
  String get availableNow;

  /// No description provided for @notAvailableNow.
  ///
  /// In en, this message translates to:
  /// **'Not available'**
  String get notAvailableNow;

  /// No description provided for @neverDonated.
  ///
  /// In en, this message translates to:
  /// **'No donations yet'**
  String get neverDonated;

  /// No description provided for @homeDonationsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} donation} other{{count} donations}}'**
  String homeDonationsCount(num count);

  /// No description provided for @homeRequestBlood.
  ///
  /// In en, this message translates to:
  /// **'Request blood'**
  String get homeRequestBlood;

  /// No description provided for @homeFindDonors.
  ///
  /// In en, this message translates to:
  /// **'Find donors'**
  String get homeFindDonors;

  /// No description provided for @homeRequestsTitle.
  ///
  /// In en, this message translates to:
  /// **'Open requests'**
  String get homeRequestsTitle;

  /// No description provided for @homeRequestsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No open requests'**
  String get homeRequestsEmptyTitle;

  /// No description provided for @homeRequestsEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'When someone needs blood, their request appears here first.'**
  String get homeRequestsEmptyBody;

  /// No description provided for @homeUnitsNeeded.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} unit needed} other{{count} units needed}}'**
  String homeUnitsNeeded(num count);

  /// No description provided for @homeNeededBy.
  ///
  /// In en, this message translates to:
  /// **'Needed by {date}'**
  String homeNeededBy(String date);

  /// No description provided for @homeNeededByUnknown.
  ///
  /// In en, this message translates to:
  /// **'No date given'**
  String get homeNeededByUnknown;

  /// No description provided for @homeFeedTitle.
  ///
  /// In en, this message translates to:
  /// **'From the community'**
  String get homeFeedTitle;

  /// No description provided for @homeFeedEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No posts yet'**
  String get homeFeedEmptyTitle;

  /// No description provided for @homeFeedEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Stories and updates from donors will appear here.'**
  String get homeFeedEmptyBody;

  /// No description provided for @homeFeedOpenAction.
  ///
  /// In en, this message translates to:
  /// **'Open the community'**
  String get homeFeedOpenAction;

  /// No description provided for @homeSeeAll.
  ///
  /// In en, this message translates to:
  /// **'See all'**
  String get homeSeeAll;

  /// No description provided for @homeComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Coming soon.'**
  String get homeComingSoon;

  /// No description provided for @profileTitle.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profileTitle;

  /// No description provided for @profileEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit profile'**
  String get profileEditTitle;

  /// No description provided for @profileEditAction.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get profileEditAction;

  /// No description provided for @profileSaveAction.
  ///
  /// In en, this message translates to:
  /// **'Save changes'**
  String get profileSaveAction;

  /// No description provided for @profileSaved.
  ///
  /// In en, this message translates to:
  /// **'Profile saved.'**
  String get profileSaved;

  /// No description provided for @profileSectionYou.
  ///
  /// In en, this message translates to:
  /// **'Your donor card'**
  String get profileSectionYou;

  /// No description provided for @profileSectionDetails.
  ///
  /// In en, this message translates to:
  /// **'Personal details'**
  String get profileSectionDetails;

  /// No description provided for @profileSectionPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get profileSectionPrivacy;

  /// No description provided for @profileSectionHistory.
  ///
  /// In en, this message translates to:
  /// **'Donation history'**
  String get profileSectionHistory;

  /// No description provided for @profileCompletionTitle.
  ///
  /// In en, this message translates to:
  /// **'Profile completion'**
  String get profileCompletionTitle;

  /// No description provided for @profileCompletionCount.
  ///
  /// In en, this message translates to:
  /// **'{done} of {total} filled in'**
  String profileCompletionCount(num done, num total);

  /// No description provided for @profileCompletionAllDone.
  ///
  /// In en, this message translates to:
  /// **'Every field is filled in.'**
  String get profileCompletionAllDone;

  /// No description provided for @profileCompletionMissingTitle.
  ///
  /// In en, this message translates to:
  /// **'Still missing'**
  String get profileCompletionMissingTitle;

  /// No description provided for @profileFieldPhoto.
  ///
  /// In en, this message translates to:
  /// **'Profile photo'**
  String get profileFieldPhoto;

  /// No description provided for @profilePhoneLabel.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get profilePhoneLabel;

  /// No description provided for @profileAreaLabel.
  ///
  /// In en, this message translates to:
  /// **'Area'**
  String get profileAreaLabel;

  /// No description provided for @profileAddressLabel.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get profileAddressLabel;

  /// No description provided for @profileDobLabel.
  ///
  /// In en, this message translates to:
  /// **'Date of birth'**
  String get profileDobLabel;

  /// No description provided for @profileGenderLabel.
  ///
  /// In en, this message translates to:
  /// **'Gender'**
  String get profileGenderLabel;

  /// No description provided for @profileGenderFemale.
  ///
  /// In en, this message translates to:
  /// **'Female'**
  String get profileGenderFemale;

  /// No description provided for @profileGenderMale.
  ///
  /// In en, this message translates to:
  /// **'Male'**
  String get profileGenderMale;

  /// No description provided for @profileGenderOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get profileGenderOther;

  /// No description provided for @profileGenderPreferNotToSay.
  ///
  /// In en, this message translates to:
  /// **'Prefer not to say'**
  String get profileGenderPreferNotToSay;

  /// No description provided for @profileAvailabilityTitle.
  ///
  /// In en, this message translates to:
  /// **'Available to donate'**
  String get profileAvailabilityTitle;

  /// No description provided for @profileAvailabilityOnBody.
  ///
  /// In en, this message translates to:
  /// **'Your donor card shows you as available. You can switch this off at any time.'**
  String get profileAvailabilityOnBody;

  /// No description provided for @profileAvailabilityOffBody.
  ///
  /// In en, this message translates to:
  /// **'Nobody looking for blood will be matched with you. Only you can switch this on.'**
  String get profileAvailabilityOffBody;

  /// No description provided for @profileAvailabilityNeedsGroup.
  ///
  /// In en, this message translates to:
  /// **'Add your blood group before a request can be matched with you.'**
  String get profileAvailabilityNeedsGroup;

  /// No description provided for @profilePrivacyDiscoveryTitle.
  ///
  /// In en, this message translates to:
  /// **'Let other donors find me'**
  String get profilePrivacyDiscoveryTitle;

  /// No description provided for @profilePrivacyDiscoveryBody.
  ///
  /// In en, this message translates to:
  /// **'Only when this is on does your donor card appear in the Find Donors list. Off by default; existing donors are not listed until they switch this on.'**
  String get profilePrivacyDiscoveryBody;

  /// No description provided for @profilePrivacyAreaTitle.
  ///
  /// In en, this message translates to:
  /// **'Show my area to other donors'**
  String get profilePrivacyAreaTitle;

  /// No description provided for @profilePrivacyAreaBody.
  ///
  /// In en, this message translates to:
  /// **'When this is on your area is published on your donor card. When it is off the area is removed from it.'**
  String get profilePrivacyAreaBody;

  /// No description provided for @profilePrivacyPrivateTitle.
  ///
  /// In en, this message translates to:
  /// **'Always private'**
  String get profilePrivacyPrivateTitle;

  /// No description provided for @profilePrivacyPrivateBody.
  ///
  /// In en, this message translates to:
  /// **'Phone, address and date of birth are stored where only you can read them.'**
  String get profilePrivacyPrivateBody;

  /// No description provided for @profileHistoryEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No donations recorded yet'**
  String get profileHistoryEmptyTitle;

  /// No description provided for @profileHistoryEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'A donation appears here once the recipient confirms it. Nothing is added by hand.'**
  String get profileHistoryEmptyBody;

  /// No description provided for @profileHistoryConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Confirmed'**
  String get profileHistoryConfirmed;

  /// No description provided for @profileHistoryPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get profileHistoryPending;

  /// No description provided for @profileHistoryErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Could not load your donations'**
  String get profileHistoryErrorTitle;

  /// No description provided for @profileLoadErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Could not load your profile'**
  String get profileLoadErrorTitle;

  /// No description provided for @profileHistoryCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} donation} other{{count} donations}}'**
  String profileHistoryCount(num count);

  /// No description provided for @profileHistoryLast.
  ///
  /// In en, this message translates to:
  /// **'Last donation {date}'**
  String profileHistoryLast(String date);

  /// No description provided for @profileContactPrivateBadge.
  ///
  /// In en, this message translates to:
  /// **'Private'**
  String get profileContactPrivateBadge;

  /// No description provided for @profileEmailManaged.
  ///
  /// In en, this message translates to:
  /// **'Managed by your sign-in account'**
  String get profileEmailManaged;

  /// No description provided for @profileNotSetCtaTitle.
  ///
  /// In en, this message translates to:
  /// **'Complete your profile'**
  String get profileNotSetCtaTitle;

  /// No description provided for @profileNotSetCtaBody.
  ///
  /// In en, this message translates to:
  /// **'Add your blood group and area so a request near you can find you.'**
  String get profileNotSetCtaBody;

  /// No description provided for @profileAddDetails.
  ///
  /// In en, this message translates to:
  /// **'Add details'**
  String get profileAddDetails;

  /// No description provided for @profilePhotoAdd.
  ///
  /// In en, this message translates to:
  /// **'Add photo'**
  String get profilePhotoAdd;

  /// No description provided for @profilePhotoChange.
  ///
  /// In en, this message translates to:
  /// **'Change photo'**
  String get profilePhotoChange;

  /// No description provided for @profilePhotoSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Profile photo'**
  String get profilePhotoSheetTitle;

  /// No description provided for @profilePhotoSheetBody.
  ///
  /// In en, this message translates to:
  /// **'Your photo appears on your donor card. Only you can change it.'**
  String get profilePhotoSheetBody;

  /// No description provided for @profilePhotoFromGallery.
  ///
  /// In en, this message translates to:
  /// **'Choose from gallery'**
  String get profilePhotoFromGallery;

  /// No description provided for @profilePhotoFromCamera.
  ///
  /// In en, this message translates to:
  /// **'Take a photo'**
  String get profilePhotoFromCamera;

  /// No description provided for @profilePhotoRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove photo'**
  String get profilePhotoRemove;

  /// No description provided for @profilePhotoRemoveConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove your photo?'**
  String get profilePhotoRemoveConfirmTitle;

  /// No description provided for @profilePhotoRemoveConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'Your initials will show on your donor card instead, and the stored image will be deleted.'**
  String get profilePhotoRemoveConfirmBody;

  /// No description provided for @profilePhotoUploading.
  ///
  /// In en, this message translates to:
  /// **'Uploading your photo…'**
  String get profilePhotoUploading;

  /// No description provided for @profilePhotoUpdated.
  ///
  /// In en, this message translates to:
  /// **'Photo updated.'**
  String get profilePhotoUpdated;

  /// No description provided for @profilePhotoRemoved.
  ///
  /// In en, this message translates to:
  /// **'Photo removed.'**
  String get profilePhotoRemoved;

  /// No description provided for @profilePhotoNotConfigured.
  ///
  /// In en, this message translates to:
  /// **'Photo upload is not set up in this build yet.'**
  String get profilePhotoNotConfigured;

  /// No description provided for @actionCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get actionCancel;

  /// No description provided for @profilePickerDate.
  ///
  /// In en, this message translates to:
  /// **'Choose a date'**
  String get profilePickerDate;

  /// No description provided for @profilePickerClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get profilePickerClear;

  /// No description provided for @errorPhoneInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid mobile number, for example 01712345678'**
  String get errorPhoneInvalid;

  /// No description provided for @errorAreaTooLong.
  ///
  /// In en, this message translates to:
  /// **'Keep the area under {count} characters'**
  String errorAreaTooLong(num count);

  /// No description provided for @errorAddressTooLong.
  ///
  /// In en, this message translates to:
  /// **'Keep the address under {count} characters'**
  String errorAddressTooLong(num count);

  /// No description provided for @errorDobFuture.
  ///
  /// In en, this message translates to:
  /// **'A date of birth cannot be in the future'**
  String get errorDobFuture;

  /// No description provided for @errorDobTooOld.
  ///
  /// In en, this message translates to:
  /// **'Enter a date after {year}'**
  String errorDobTooOld(num year);

  /// No description provided for @errorBloodGroupUnknown.
  ///
  /// In en, this message translates to:
  /// **'Choose one of the eight blood groups'**
  String get errorBloodGroupUnknown;

  /// No description provided for @errorPhotoEmpty.
  ///
  /// In en, this message translates to:
  /// **'That file was empty. Choose another photo'**
  String get errorPhotoEmpty;

  /// No description provided for @errorPhotoTooLarge.
  ///
  /// In en, this message translates to:
  /// **'Choose a photo under {megabytes} MB'**
  String errorPhotoTooLarge(num megabytes);

  /// No description provided for @errorPhotoUnsupported.
  ///
  /// In en, this message translates to:
  /// **'Choose a JPEG, PNG or WebP image'**
  String get errorPhotoUnsupported;

  /// No description provided for @errorPhotoAccessDenied.
  ///
  /// In en, this message translates to:
  /// **'Solovvo needs access to your photos to set a profile photo'**
  String get errorPhotoAccessDenied;

  /// No description provided for @errorPhotoUnreadable.
  ///
  /// In en, this message translates to:
  /// **'That photo could not be read. Try another one'**
  String get errorPhotoUnreadable;

  /// No description provided for @firebaseUnavailableTitle.
  ///
  /// In en, this message translates to:
  /// **'Firebase unavailable'**
  String get firebaseUnavailableTitle;

  /// No description provided for @firebaseUnavailableBody.
  ///
  /// In en, this message translates to:
  /// **'Solovvo could not start its backend connection, so data screens are held back rather than shown empty.'**
  String get firebaseUnavailableBody;

  /// No description provided for @reconnectHint.
  ///
  /// In en, this message translates to:
  /// **'Reconnect and relaunch the app.'**
  String get reconnectHint;

  /// No description provided for @diagnosticReason.
  ///
  /// In en, this message translates to:
  /// **'Reason'**
  String get diagnosticReason;

  /// No description provided for @diagnosticDetail.
  ///
  /// In en, this message translates to:
  /// **'Detail'**
  String get diagnosticDetail;

  /// No description provided for @diagnosticProject.
  ///
  /// In en, this message translates to:
  /// **'Project'**
  String get diagnosticProject;

  /// No description provided for @diagnosticFlavor.
  ///
  /// In en, this message translates to:
  /// **'Flavor'**
  String get diagnosticFlavor;

  /// No description provided for @sessionRestoreTitle.
  ///
  /// In en, this message translates to:
  /// **'Could not restore your session'**
  String get sessionRestoreTitle;

  /// No description provided for @sessionRestoreBody.
  ///
  /// In en, this message translates to:
  /// **'Solovvo could not reach Firebase Authentication, so it will not guess whether you are signed in.'**
  String get sessionRestoreBody;

  /// No description provided for @errorEmailRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter your email address'**
  String get errorEmailRequired;

  /// No description provided for @errorEmailTooLong.
  ///
  /// In en, this message translates to:
  /// **'That email address is too long'**
  String get errorEmailTooLong;

  /// No description provided for @errorEmailInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email address'**
  String get errorEmailInvalid;

  /// No description provided for @errorPasswordRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter your password'**
  String get errorPasswordRequired;

  /// No description provided for @errorPasswordChoose.
  ///
  /// In en, this message translates to:
  /// **'Choose a password'**
  String get errorPasswordChoose;

  /// No description provided for @errorPasswordTooShort.
  ///
  /// In en, this message translates to:
  /// **'Use at least {count} characters'**
  String errorPasswordTooShort(int count);

  /// No description provided for @errorPasswordComposition.
  ///
  /// In en, this message translates to:
  /// **'Mix letters and numbers'**
  String get errorPasswordComposition;

  /// No description provided for @errorConfirmRequired.
  ///
  /// In en, this message translates to:
  /// **'Repeat your password'**
  String get errorConfirmRequired;

  /// No description provided for @errorConfirmMismatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get errorConfirmMismatch;

  /// No description provided for @errorNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter your name'**
  String get errorNameRequired;

  /// No description provided for @errorNameTooShort.
  ///
  /// In en, this message translates to:
  /// **'That name is too short'**
  String get errorNameTooShort;

  /// No description provided for @errorNameTooLong.
  ///
  /// In en, this message translates to:
  /// **'Keep it under {count} characters'**
  String errorNameTooLong(int count);

  /// No description provided for @failureInvalidCredentials.
  ///
  /// In en, this message translates to:
  /// **'That email and password do not match. Check both and try again.'**
  String get failureInvalidCredentials;

  /// No description provided for @failureUserDisabled.
  ///
  /// In en, this message translates to:
  /// **'This account has been disabled. Contact support to restore it.'**
  String get failureUserDisabled;

  /// No description provided for @failureEmailAlreadyInUse.
  ///
  /// In en, this message translates to:
  /// **'An account already exists for this email. Sign in instead.'**
  String get failureEmailAlreadyInUse;

  /// No description provided for @failureWeakPassword.
  ///
  /// In en, this message translates to:
  /// **'That password is too easy to guess. Use at least 8 characters.'**
  String get failureWeakPassword;

  /// No description provided for @failureEmailNotVerified.
  ///
  /// In en, this message translates to:
  /// **'Verify your email address before continuing.'**
  String get failureEmailNotVerified;

  /// No description provided for @failureRequiresRecentLogin.
  ///
  /// In en, this message translates to:
  /// **'For your security, sign in again and retry.'**
  String get failureRequiresRecentLogin;

  /// No description provided for @failureOperationNotAllowed.
  ///
  /// In en, this message translates to:
  /// **'Email sign-in is switched off for this app. Please contact support.'**
  String get failureOperationNotAllowed;

  /// No description provided for @failureUnknownAuth.
  ///
  /// In en, this message translates to:
  /// **'We could not complete that sign-in. Please try again.'**
  String get failureUnknownAuth;

  /// No description provided for @failureNetwork.
  ///
  /// In en, this message translates to:
  /// **'No connection. Check your network and try again.'**
  String get failureNetwork;

  /// No description provided for @failureRateLimited.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Wait a few minutes and try again.'**
  String get failureRateLimited;

  /// No description provided for @failurePermission.
  ///
  /// In en, this message translates to:
  /// **'You do not have permission to do that.'**
  String get failurePermission;

  /// No description provided for @failureNotFound.
  ///
  /// In en, this message translates to:
  /// **'We could not find that account.'**
  String get failureNotFound;

  /// No description provided for @failureConflict.
  ///
  /// In en, this message translates to:
  /// **'That request is already in progress.'**
  String get failureConflict;

  /// No description provided for @failureValidation.
  ///
  /// In en, this message translates to:
  /// **'Please check the details you entered.'**
  String get failureValidation;

  /// No description provided for @failureUnexpected.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong on our side. Please try again.'**
  String get failureUnexpected;

  /// No description provided for @appearanceAndLanguage.
  ///
  /// In en, this message translates to:
  /// **'Appearance & language'**
  String get appearanceAndLanguage;

  /// No description provided for @languageLabel.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get languageLabel;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageBangla.
  ///
  /// In en, this message translates to:
  /// **'বাংলা'**
  String get languageBangla;

  /// No description provided for @themeLabel.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get themeLabel;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsAccountSection.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get settingsAccountSection;

  /// No description provided for @settingsPreferencesSection.
  ///
  /// In en, this message translates to:
  /// **'Preferences'**
  String get settingsPreferencesSection;

  /// No description provided for @settingsAppearanceBody.
  ///
  /// In en, this message translates to:
  /// **'Theme and language. Changes apply straight away.'**
  String get settingsAppearanceBody;

  /// No description provided for @settingsAboutSection.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsAboutSection;

  /// No description provided for @settingsBuildLabel.
  ///
  /// In en, this message translates to:
  /// **'Build'**
  String get settingsBuildLabel;

  /// No description provided for @settingsBuildDevelopment.
  ///
  /// In en, this message translates to:
  /// **'Development'**
  String get settingsBuildDevelopment;

  /// No description provided for @settingsBuildStaging.
  ///
  /// In en, this message translates to:
  /// **'Staging'**
  String get settingsBuildStaging;

  /// No description provided for @settingsBuildProduction.
  ///
  /// In en, this message translates to:
  /// **'Production'**
  String get settingsBuildProduction;

  /// No description provided for @settingsSignOutBody.
  ///
  /// In en, this message translates to:
  /// **'You will need your email and password to sign in again.'**
  String get settingsSignOutBody;

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @feedTitle.
  ///
  /// In en, this message translates to:
  /// **'Community'**
  String get feedTitle;

  /// No description provided for @feedEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No posts yet'**
  String get feedEmptyTitle;

  /// No description provided for @feedEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'When a donor shares an update, it appears here.'**
  String get feedEmptyBody;

  /// No description provided for @feedErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'The feed could not be loaded'**
  String get feedErrorTitle;

  /// No description provided for @feedRetry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get feedRetry;

  /// No description provided for @feedLoadMore.
  ///
  /// In en, this message translates to:
  /// **'Load more'**
  String get feedLoadMore;

  /// No description provided for @feedEndOfFeed.
  ///
  /// In en, this message translates to:
  /// **'You have reached the end of the feed'**
  String get feedEndOfFeed;

  /// No description provided for @feedReadMore.
  ///
  /// In en, this message translates to:
  /// **'Read more'**
  String get feedReadMore;

  /// No description provided for @feedShowLess.
  ///
  /// In en, this message translates to:
  /// **'Show less'**
  String get feedShowLess;

  /// No description provided for @feedCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy text'**
  String get feedCopy;

  /// No description provided for @feedShare.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get feedShare;

  /// No description provided for @feedSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get feedSave;

  /// No description provided for @feedEditAction.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get feedEditAction;

  /// No description provided for @feedEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit post'**
  String get feedEditTitle;

  /// No description provided for @feedEditHint.
  ///
  /// In en, this message translates to:
  /// **'Update the text of your post.'**
  String get feedEditHint;

  /// No description provided for @feedEditSave.
  ///
  /// In en, this message translates to:
  /// **'Save changes'**
  String get feedEditSave;

  /// No description provided for @feedEditSaving.
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get feedEditSaving;

  /// No description provided for @feedEditError.
  ///
  /// In en, this message translates to:
  /// **'Could not save your changes.'**
  String get feedEditError;

  /// No description provided for @feedDeleteAction.
  ///
  /// In en, this message translates to:
  /// **'Delete post'**
  String get feedDeleteAction;

  /// No description provided for @feedDeleteConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this post?'**
  String get feedDeleteConfirmTitle;

  /// No description provided for @feedDeleteConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'This cannot be undone. The post and its comments will be permanently removed.'**
  String get feedDeleteConfirmBody;

  /// No description provided for @feedDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get feedDeleteConfirm;

  /// No description provided for @feedDeleted.
  ///
  /// In en, this message translates to:
  /// **'Post deleted.'**
  String get feedDeleted;

  /// No description provided for @feedDeleteError.
  ///
  /// In en, this message translates to:
  /// **'Could not delete the post.'**
  String get feedDeleteError;

  /// No description provided for @feedSavedFilterOn.
  ///
  /// In en, this message translates to:
  /// **'Showing saved'**
  String get feedSavedFilterOn;

  /// No description provided for @feedSavedFilterOff.
  ///
  /// In en, this message translates to:
  /// **'All posts'**
  String get feedSavedFilterOff;

  /// No description provided for @feedSavedEmpty.
  ///
  /// In en, this message translates to:
  /// **'No saved posts yet.'**
  String get feedSavedEmpty;

  /// No description provided for @requestsCreateTitle.
  ///
  /// In en, this message translates to:
  /// **'New blood request'**
  String get requestsCreateTitle;

  /// No description provided for @requestsCreateAction.
  ///
  /// In en, this message translates to:
  /// **'Create request'**
  String get requestsCreateAction;

  /// No description provided for @requestsBloodGroup.
  ///
  /// In en, this message translates to:
  /// **'Blood group'**
  String get requestsBloodGroup;

  /// No description provided for @requestsBags.
  ///
  /// In en, this message translates to:
  /// **'Bags needed'**
  String get requestsBags;

  /// No description provided for @requestsHospital.
  ///
  /// In en, this message translates to:
  /// **'Hospital name'**
  String get requestsHospital;

  /// No description provided for @requestsDate.
  ///
  /// In en, this message translates to:
  /// **'Date needed'**
  String get requestsDate;

  /// No description provided for @requestsTime.
  ///
  /// In en, this message translates to:
  /// **'Time needed'**
  String get requestsTime;

  /// No description provided for @requestsNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes (optional)'**
  String get requestsNotes;

  /// No description provided for @requestsNotesHint.
  ///
  /// In en, this message translates to:
  /// **'Any additional details…'**
  String get requestsNotesHint;

  /// No description provided for @requestsCreateSubmit.
  ///
  /// In en, this message translates to:
  /// **'Submit request'**
  String get requestsCreateSubmit;

  /// No description provided for @requestsCreating.
  ///
  /// In en, this message translates to:
  /// **'Creating…'**
  String get requestsCreating;

  /// No description provided for @requestsCreateSuccess.
  ///
  /// In en, this message translates to:
  /// **'Request posted.'**
  String get requestsCreateSuccess;

  /// No description provided for @requestsCreateError.
  ///
  /// In en, this message translates to:
  /// **'Could not create the request.'**
  String get requestsCreateError;

  /// No description provided for @requestsRequired.
  ///
  /// In en, this message translates to:
  /// **'This field is required'**
  String get requestsRequired;

  /// No description provided for @requestsDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'Request detail'**
  String get requestsDetailTitle;

  /// No description provided for @requestsDetailNoActionNote.
  ///
  /// In en, this message translates to:
  /// **'This screen shows what is needed and where. Contacting the requester is not available in this build yet.'**
  String get requestsDetailNoActionNote;

  /// No description provided for @requestsAcceptAction.
  ///
  /// In en, this message translates to:
  /// **'Accept request'**
  String get requestsAcceptAction;

  /// No description provided for @requestsAcceptConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Accept this request?'**
  String get requestsAcceptConfirmTitle;

  /// No description provided for @requestsAcceptConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'You are committing to donate for this patient. The requester will see that you have accepted.'**
  String get requestsAcceptConfirmBody;

  /// No description provided for @requestsAcceptConfirmYes.
  ///
  /// In en, this message translates to:
  /// **'Yes, I will donate'**
  String get requestsAcceptConfirmYes;

  /// No description provided for @requestsAcceptConfirmNo.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get requestsAcceptConfirmNo;

  /// No description provided for @requestsAcceptError.
  ///
  /// In en, this message translates to:
  /// **'Could not accept the request.'**
  String get requestsAcceptError;

  /// No description provided for @requestsCancelAction.
  ///
  /// In en, this message translates to:
  /// **'Cancel request'**
  String get requestsCancelAction;

  /// No description provided for @requestsCancelConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Cancel this request?'**
  String get requestsCancelConfirmTitle;

  /// No description provided for @requestsCancelConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'This withdraws your request from the open list. Donors who saw it will no longer be notified.'**
  String get requestsCancelConfirmBody;

  /// No description provided for @requestsCancelConfirmYes.
  ///
  /// In en, this message translates to:
  /// **'Yes, cancel it'**
  String get requestsCancelConfirmYes;

  /// No description provided for @requestsCancelConfirmNo.
  ///
  /// In en, this message translates to:
  /// **'Keep it'**
  String get requestsCancelConfirmNo;

  /// No description provided for @requestsCancelSuccess.
  ///
  /// In en, this message translates to:
  /// **'Request cancelled.'**
  String get requestsCancelSuccess;

  /// No description provided for @requestsCancelError.
  ///
  /// In en, this message translates to:
  /// **'Could not cancel the request.'**
  String get requestsCancelError;

  /// No description provided for @requestsEditAction.
  ///
  /// In en, this message translates to:
  /// **'Edit request'**
  String get requestsEditAction;

  /// No description provided for @requestsEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit request'**
  String get requestsEditTitle;

  /// No description provided for @requestsEditSubmit.
  ///
  /// In en, this message translates to:
  /// **'Save changes'**
  String get requestsEditSubmit;

  /// No description provided for @requestsEditSaving.
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get requestsEditSaving;

  /// No description provided for @requestsEditSuccess.
  ///
  /// In en, this message translates to:
  /// **'Request updated.'**
  String get requestsEditSuccess;

  /// No description provided for @requestsEditError.
  ///
  /// In en, this message translates to:
  /// **'Could not update the request.'**
  String get requestsEditError;

  /// No description provided for @requestsContactAction.
  ///
  /// In en, this message translates to:
  /// **'Contact details'**
  String get requestsContactAction;

  /// No description provided for @requestsContactTitle.
  ///
  /// In en, this message translates to:
  /// **'Requester contact details'**
  String get requestsContactTitle;

  /// No description provided for @requestsContactIntro.
  ///
  /// In en, this message translates to:
  /// **'Stored privately with this request. Not shown to donors in this build.'**
  String get requestsContactIntro;

  /// No description provided for @requestsPatientName.
  ///
  /// In en, this message translates to:
  /// **'Patient name'**
  String get requestsPatientName;

  /// No description provided for @requestsPhoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Phone number'**
  String get requestsPhoneNumber;

  /// No description provided for @requestsHospitalAddress.
  ///
  /// In en, this message translates to:
  /// **'Hospital address'**
  String get requestsHospitalAddress;

  /// No description provided for @requestsContactSubmit.
  ///
  /// In en, this message translates to:
  /// **'Save contact details'**
  String get requestsContactSubmit;

  /// No description provided for @requestsContactSaving.
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get requestsContactSaving;

  /// No description provided for @requestsContactLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get requestsContactLoading;

  /// No description provided for @requestsContactSuccess.
  ///
  /// In en, this message translates to:
  /// **'Contact details saved.'**
  String get requestsContactSuccess;

  /// No description provided for @requestsContactError.
  ///
  /// In en, this message translates to:
  /// **'Could not save the contact details.'**
  String get requestsContactError;

  /// No description provided for @requestsContactLoadError.
  ///
  /// In en, this message translates to:
  /// **'Could not load your saved contact details.'**
  String get requestsContactLoadError;

  /// No description provided for @requestsContactRetry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get requestsContactRetry;

  /// No description provided for @requestsMyAction.
  ///
  /// In en, this message translates to:
  /// **'My requests'**
  String get requestsMyAction;

  /// No description provided for @requestsMyTitle.
  ///
  /// In en, this message translates to:
  /// **'My requests'**
  String get requestsMyTitle;

  /// No description provided for @requestsMyEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'You have no open requests'**
  String get requestsMyEmptyTitle;

  /// No description provided for @requestsMyEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Requests you create appear here until they are filled or cancelled.'**
  String get requestsMyEmptyBody;

  /// No description provided for @requestsFilterLabel.
  ///
  /// In en, this message translates to:
  /// **'Filter by group'**
  String get requestsFilterLabel;

  /// No description provided for @requestsFilterEmpty.
  ///
  /// In en, this message translates to:
  /// **'No open requests need this group right now.'**
  String get requestsFilterEmpty;

  /// No description provided for @feedCopied.
  ///
  /// In en, this message translates to:
  /// **'Post text copied.'**
  String get feedCopied;

  /// No description provided for @feedEdited.
  ///
  /// In en, this message translates to:
  /// **'Edited'**
  String get feedEdited;

  /// No description provided for @feedJustNow.
  ///
  /// In en, this message translates to:
  /// **'Just now'**
  String get feedJustNow;

  /// No description provided for @feedMinutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} minute ago} other{{count} minutes ago}}'**
  String feedMinutesAgo(num count);

  /// No description provided for @feedHoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} hour ago} other{{count} hours ago}}'**
  String feedHoursAgo(num count);

  /// No description provided for @feedDaysAgo.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} day ago} other{{count} days ago}}'**
  String feedDaysAgo(num count);

  /// No description provided for @feedOnDate.
  ///
  /// In en, this message translates to:
  /// **'On {date}'**
  String feedOnDate(String date);

  /// No description provided for @feedLikeCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} like} other{{count} likes}}'**
  String feedLikeCount(num count);

  /// No description provided for @feedCommentCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} comment} other{{count} comments}}'**
  String feedCommentCount(num count);

  /// No description provided for @commentsSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Comments'**
  String get commentsSheetTitle;

  /// No description provided for @commentsEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'No comments yet. Be the first.'**
  String get commentsEmptyBody;

  /// No description provided for @commentsLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading comments…'**
  String get commentsLoading;

  /// No description provided for @commentsHintText.
  ///
  /// In en, this message translates to:
  /// **'Write a comment…'**
  String get commentsHintText;

  /// No description provided for @commentsSendTooltip.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get commentsSendTooltip;

  /// No description provided for @commentsErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Could not load comments'**
  String get commentsErrorTitle;

  /// No description provided for @commentsReplyPrefix.
  ///
  /// In en, this message translates to:
  /// **'Reply to {name}'**
  String commentsReplyPrefix(String name);

  /// No description provided for @commentsReplyingTo.
  ///
  /// In en, this message translates to:
  /// **'Replying to {name}'**
  String commentsReplyingTo(String name);

  /// No description provided for @commentsReplyHint.
  ///
  /// In en, this message translates to:
  /// **'Write a reply…'**
  String get commentsReplyHint;

  /// No description provided for @commentsReplyAction.
  ///
  /// In en, this message translates to:
  /// **'Reply'**
  String get commentsReplyAction;

  /// No description provided for @commentsDeleteAction.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get commentsDeleteAction;

  /// No description provided for @reportTooltip.
  ///
  /// In en, this message translates to:
  /// **'Report'**
  String get reportTooltip;

  /// No description provided for @reportSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Report this post'**
  String get reportSheetTitle;

  /// No description provided for @reportCommentSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Report this comment'**
  String get reportCommentSheetTitle;

  /// No description provided for @reportReasonLabel.
  ///
  /// In en, this message translates to:
  /// **'Reason'**
  String get reportReasonLabel;

  /// No description provided for @reportReasonSpam.
  ///
  /// In en, this message translates to:
  /// **'Spam'**
  String get reportReasonSpam;

  /// No description provided for @reportReasonHarassment.
  ///
  /// In en, this message translates to:
  /// **'Harassment'**
  String get reportReasonHarassment;

  /// No description provided for @reportReasonHateSpeech.
  ///
  /// In en, this message translates to:
  /// **'Hate speech'**
  String get reportReasonHateSpeech;

  /// No description provided for @reportReasonMisinformation.
  ///
  /// In en, this message translates to:
  /// **'Misinformation'**
  String get reportReasonMisinformation;

  /// No description provided for @reportReasonOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get reportReasonOther;

  /// No description provided for @reportNoteHint.
  ///
  /// In en, this message translates to:
  /// **'Additional details (optional)'**
  String get reportNoteHint;

  /// No description provided for @reportSubmitButton.
  ///
  /// In en, this message translates to:
  /// **'Submit report'**
  String get reportSubmitButton;

  /// No description provided for @reportSubmitting.
  ///
  /// In en, this message translates to:
  /// **'Submitting…'**
  String get reportSubmitting;

  /// No description provided for @reportSuccess.
  ///
  /// In en, this message translates to:
  /// **'Report submitted. Thank you.'**
  String get reportSuccess;

  /// No description provided for @reportError.
  ///
  /// In en, this message translates to:
  /// **'Could not submit report.'**
  String get reportError;

  /// No description provided for @feedUnreadableTitle.
  ///
  /// In en, this message translates to:
  /// **'The feed could not be fully read'**
  String get feedUnreadableTitle;

  /// No description provided for @feedUnreadableBody.
  ///
  /// In en, this message translates to:
  /// **'There are more posts behind this, but they could not be read.'**
  String get feedUnreadableBody;

  /// No description provided for @feedSkippedNotice.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} post could not be shown} other{{count} posts could not be shown}}'**
  String feedSkippedNotice(num count);

  /// No description provided for @feedPostPhotoLabel.
  ///
  /// In en, this message translates to:
  /// **'Photo shared by {name}'**
  String feedPostPhotoLabel(String name);

  /// No description provided for @feedComposeAction.
  ///
  /// In en, this message translates to:
  /// **'Share an update'**
  String get feedComposeAction;

  /// No description provided for @feedComposeTitle.
  ///
  /// In en, this message translates to:
  /// **'New post'**
  String get feedComposeTitle;

  /// No description provided for @feedComposeTextLabel.
  ///
  /// In en, this message translates to:
  /// **'Your update'**
  String get feedComposeTextLabel;

  /// No description provided for @feedComposeTextHint.
  ///
  /// In en, this message translates to:
  /// **'Share news, a request, or a story from a blood drive.'**
  String get feedComposeTextHint;

  /// No description provided for @feedComposeLimit.
  ///
  /// In en, this message translates to:
  /// **'Up to {count} characters'**
  String feedComposeLimit(num count);

  /// No description provided for @feedComposePhotosLabel.
  ///
  /// In en, this message translates to:
  /// **'Photos'**
  String get feedComposePhotosLabel;

  /// No description provided for @feedComposeAddPhoto.
  ///
  /// In en, this message translates to:
  /// **'Add photo'**
  String get feedComposeAddPhoto;

  /// No description provided for @feedComposeFromGallery.
  ///
  /// In en, this message translates to:
  /// **'Choose from gallery'**
  String get feedComposeFromGallery;

  /// No description provided for @feedComposeFromCamera.
  ///
  /// In en, this message translates to:
  /// **'Take a photo'**
  String get feedComposeFromCamera;

  /// No description provided for @feedComposeRemovePhoto.
  ///
  /// In en, this message translates to:
  /// **'Remove photo'**
  String get feedComposeRemovePhoto;

  /// No description provided for @feedComposeUploading.
  ///
  /// In en, this message translates to:
  /// **'Uploading your photo…'**
  String get feedComposeUploading;

  /// No description provided for @feedComposePublish.
  ///
  /// In en, this message translates to:
  /// **'Publish'**
  String get feedComposePublish;

  /// No description provided for @feedComposePublished.
  ///
  /// In en, this message translates to:
  /// **'Your post is live.'**
  String get feedComposePublished;

  /// No description provided for @feedComposePhotosNotConfigured.
  ///
  /// In en, this message translates to:
  /// **'Photo upload is not set up in this build yet.'**
  String get feedComposePhotosNotConfigured;

  /// No description provided for @feedComposeDiscardTitle.
  ///
  /// In en, this message translates to:
  /// **'Discard this post?'**
  String get feedComposeDiscardTitle;

  /// No description provided for @feedComposeDiscardBody.
  ///
  /// In en, this message translates to:
  /// **'Your text and photos will be deleted.'**
  String get feedComposeDiscardBody;

  /// No description provided for @feedComposeDiscardConfirm.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get feedComposeDiscardConfirm;

  /// No description provided for @feedComposeKeepEditing.
  ///
  /// In en, this message translates to:
  /// **'Keep editing'**
  String get feedComposeKeepEditing;

  /// No description provided for @requestsTitle.
  ///
  /// In en, this message translates to:
  /// **'Open requests'**
  String get requestsTitle;

  /// No description provided for @requestsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No open requests right now'**
  String get requestsEmptyTitle;

  /// No description provided for @requestsEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Nothing is marked open at the moment. Pull down to check again.'**
  String get requestsEmptyBody;

  /// No description provided for @requestsErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'The requests could not be loaded'**
  String get requestsErrorTitle;

  /// No description provided for @requestsRetry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get requestsRetry;

  /// No description provided for @requestsUnreadableTitle.
  ///
  /// In en, this message translates to:
  /// **'The requests could not be fully read'**
  String get requestsUnreadableTitle;

  /// No description provided for @requestsUnreadableBody.
  ///
  /// In en, this message translates to:
  /// **'There are open requests behind this, but they could not be read.'**
  String get requestsUnreadableBody;

  /// No description provided for @requestsSkippedNotice.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} request could not be shown} other{{count} requests could not be shown}}'**
  String requestsSkippedNotice(num count);

  /// No description provided for @requestsTruncatedNotice.
  ///
  /// In en, this message translates to:
  /// **'Only the first {count} open requests are shown here. More are still behind them.'**
  String requestsTruncatedNotice(num count);

  /// No description provided for @requestsNoActionNote.
  ///
  /// In en, this message translates to:
  /// **'This list shows what is needed and where. Open a request to accept it if you are eligible.'**
  String get requestsNoActionNote;

  /// No description provided for @donorSearchTitle.
  ///
  /// In en, this message translates to:
  /// **'Find donors'**
  String get donorSearchTitle;

  /// No description provided for @donorDetailsTitle.
  ///
  /// In en, this message translates to:
  /// **'Donor profile'**
  String get donorDetailsTitle;

  /// No description provided for @donorUnnamed.
  ///
  /// In en, this message translates to:
  /// **'Donor'**
  String get donorUnnamed;

  /// No description provided for @donorRetry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get donorRetry;

  /// No description provided for @donorAvailable.
  ///
  /// In en, this message translates to:
  /// **'Available'**
  String get donorAvailable;

  /// No description provided for @donorUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Not available'**
  String get donorUnavailable;

  /// No description provided for @donorGroupNotSet.
  ///
  /// In en, this message translates to:
  /// **'Blood group not set'**
  String get donorGroupNotSet;

  /// No description provided for @donorAvailabilityHeading.
  ///
  /// In en, this message translates to:
  /// **'Availability'**
  String get donorAvailabilityHeading;

  /// No description provided for @donorAvailabilityFilter.
  ///
  /// In en, this message translates to:
  /// **'Available donors only'**
  String get donorAvailabilityFilter;

  /// No description provided for @donorFilterAllGroups.
  ///
  /// In en, this message translates to:
  /// **'All groups'**
  String get donorFilterAllGroups;

  /// No description provided for @donorAreaFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Area'**
  String get donorAreaFieldLabel;

  /// No description provided for @donorAreaFieldHint.
  ///
  /// In en, this message translates to:
  /// **'Area or neighbourhood'**
  String get donorAreaFieldHint;

  /// No description provided for @donorClearArea.
  ///
  /// In en, this message translates to:
  /// **'Clear area'**
  String get donorClearArea;

  /// No description provided for @donorSearchButton.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get donorSearchButton;

  /// No description provided for @donorErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'The donors could not be loaded'**
  String get donorErrorTitle;

  /// No description provided for @donorUnreadableTitle.
  ///
  /// In en, this message translates to:
  /// **'The donors could not be fully read'**
  String get donorUnreadableTitle;

  /// No description provided for @donorUnreadableBody.
  ///
  /// In en, this message translates to:
  /// **'There are donors behind this, but their profiles could not be read.'**
  String get donorUnreadableBody;

  /// No description provided for @donorEmptyFilteredTitle.
  ///
  /// In en, this message translates to:
  /// **'No donors match your filters'**
  String get donorEmptyFilteredTitle;

  /// No description provided for @donorEmptyFilteredBody.
  ///
  /// In en, this message translates to:
  /// **'Try widening the blood group, availability, or area.'**
  String get donorEmptyFilteredBody;

  /// No description provided for @donorEmptyAllTitle.
  ///
  /// In en, this message translates to:
  /// **'No donors are listed yet'**
  String get donorEmptyAllTitle;

  /// No description provided for @donorEmptyAllBody.
  ///
  /// In en, this message translates to:
  /// **'Donors who choose to make themselves discoverable will appear here.'**
  String get donorEmptyAllBody;

  /// No description provided for @donorContactNote.
  ///
  /// In en, this message translates to:
  /// **'To protect donors, their contact details are not shown here. Reaching out happens through a blood request.'**
  String get donorContactNote;

  /// No description provided for @donorConsentNote.
  ///
  /// In en, this message translates to:
  /// **'This donor chose to appear in search. Their area is shown only if they published it.'**
  String get donorConsentNote;

  /// No description provided for @donorSkippedNotice.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} donor could not be shown} other{{count} donors could not be shown}}'**
  String donorSkippedNotice(num count);

  /// No description provided for @donorTruncatedNotice.
  ///
  /// In en, this message translates to:
  /// **'Only the first {count} donors are shown here. More are still behind them.'**
  String donorTruncatedNotice(num count);

  /// No description provided for @errorPostTextRequired.
  ///
  /// In en, this message translates to:
  /// **'Write something before publishing'**
  String get errorPostTextRequired;

  /// No description provided for @errorPostTextTooLong.
  ///
  /// In en, this message translates to:
  /// **'Keep your post under {count} characters'**
  String errorPostTextTooLong(num count);

  /// No description provided for @errorPostTooManyImages.
  ///
  /// In en, this message translates to:
  /// **'Attach up to {count} photos'**
  String errorPostTooManyImages(num count);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['bn', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'bn':
      return AppLocalizationsBn();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
