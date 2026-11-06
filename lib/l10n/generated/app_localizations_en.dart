// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTagline => 'Save Lives • Connect Hearts';

  @override
  String get signIn => 'Sign in';

  @override
  String get signOut => 'Sign out';

  @override
  String get tryAgain => 'Try again';

  @override
  String get close => 'Close';

  @override
  String get emailLabel => 'Email';

  @override
  String get emailHint => 'you@example.com';

  @override
  String get passwordLabel => 'Password';

  @override
  String get showPassword => 'Show password';

  @override
  String get hidePassword => 'Hide password';

  @override
  String get welcomeHeadline => 'A Drop of Hope, Give Blood, Give Life';

  @override
  String get welcomeSubtitle =>
      'One donation can be the difference between a family waiting and a family reuniting. Join the community that answers when someone calls.';

  @override
  String get getStarted => 'Get Started';

  @override
  String get alreadyHaveAccount => 'Already have an account?';

  @override
  String get loginTitle => 'Welcome back';

  @override
  String get loginSubtitle =>
      'Sign in to reach your donor profile and the requests near you.';

  @override
  String get passwordHint => 'Your password';

  @override
  String get forgotPassword => 'Forgot password?';

  @override
  String get newToSolovvo => 'New to Solovvo?';

  @override
  String get createAnAccount => 'Create an account';

  @override
  String get registerTitle => 'Join Solovvo';

  @override
  String get registerSubtitle =>
      'Donors are matched by blood group and distance. Registration takes less than a minute.';

  @override
  String get fullNameLabel => 'Full name';

  @override
  String get fullNameHint => 'As it will appear to donors';

  @override
  String get newPasswordHint => 'At least 8 characters';

  @override
  String get passwordRule => 'Mix letters and numbers';

  @override
  String get confirmPasswordLabel => 'Confirm password';

  @override
  String get confirmPasswordHint => 'Repeat the password';

  @override
  String get createAccount => 'Create account';

  @override
  String get verificationEmailNote =>
      'We will email you a link to confirm the address before your account can answer a request.';

  @override
  String get alreadyRegistered => 'Already registered?';

  @override
  String get forgotTitle => 'Reset your password';

  @override
  String get forgotSubtitle =>
      'Enter the address on your account and we will send a link to choose a new password.';

  @override
  String get sendResetLink => 'Send reset link';

  @override
  String get backToSignIn => 'Back to sign in';

  @override
  String get resetSentTitle => 'Check your inbox';

  @override
  String resetSentBody(String email) {
    return 'If an account exists for $email, a password reset link is on its way from Firebase. The link expires after one hour.';
  }

  @override
  String get verifyTitle => 'Confirm your email';

  @override
  String get verifySubtitle =>
      'One tap in your inbox unlocks the rest of Solovvo.';

  @override
  String get sentToLabel => 'We sent a link to';

  @override
  String get verifyLockedBody =>
      'Your account is created, but donation features stay locked until the address is confirmed.';

  @override
  String get freshLinkSent => 'A fresh link is on its way.';

  @override
  String get notConfirmedYet =>
      'Not confirmed yet. Open the link in your inbox, then check again.';

  @override
  String get confirmedCta => 'I\'ve confirmed my email';

  @override
  String get resendEmail => 'Resend email';

  @override
  String resendIn(int seconds) {
    return 'Resend in ${seconds}s';
  }

  @override
  String get unknownEmail => 'your email address';

  @override
  String homeGreeting(String name) {
    return 'Welcome, $name';
  }

  @override
  String get homeDashboardSubtitle =>
      'Everything you need to give blood — and to ask for it.';

  @override
  String get verified => 'Verified';

  @override
  String get donorStatusTitle => 'Donor status';

  @override
  String get bloodGroupLabel => 'Blood group';

  @override
  String get lastDonationLabel => 'Last donation';

  @override
  String get availabilityLabel => 'Availability';

  @override
  String get notSetYet => 'Not set yet';

  @override
  String get availableNow => 'Available';

  @override
  String get notAvailableNow => 'Not available';

  @override
  String get neverDonated => 'No donations yet';

  @override
  String homeDonationsCount(num count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString donations',
      one: '$countString donation',
    );
    return '$_temp0';
  }

  @override
  String get homeRequestBlood => 'Request blood';

  @override
  String get homeFindDonors => 'Find donors';

  @override
  String get homeRequestsTitle => 'Open requests';

  @override
  String get homeRequestsEmptyTitle => 'No open requests';

  @override
  String get homeRequestsEmptyBody =>
      'When someone needs blood, their request appears here first.';

  @override
  String homeUnitsNeeded(num count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString units needed',
      one: '$countString unit needed',
    );
    return '$_temp0';
  }

  @override
  String homeNeededBy(String date) {
    return 'Needed by $date';
  }

  @override
  String get homeNeededByUnknown => 'No date given';

  @override
  String get homeFeedTitle => 'From the community';

  @override
  String get homeFeedEmptyTitle => 'No posts yet';

  @override
  String get homeFeedEmptyBody =>
      'Stories and updates from donors will appear here.';

  @override
  String get homeFeedOpenAction => 'Open the community';

  @override
  String get homeSeeAll => 'See all';

  @override
  String get homeComingSoon => 'Coming soon.';

  @override
  String get profileTitle => 'Profile';

  @override
  String get profileEditTitle => 'Edit profile';

  @override
  String get profileEditAction => 'Edit';

  @override
  String get profileSaveAction => 'Save changes';

  @override
  String get profileSaved => 'Profile saved.';

  @override
  String get profileSectionYou => 'Your donor card';

  @override
  String get profileSectionDetails => 'Personal details';

  @override
  String get profileSectionPrivacy => 'Privacy';

  @override
  String get profileSectionHistory => 'Donation history';

  @override
  String get profileCompletionTitle => 'Profile completion';

  @override
  String profileCompletionCount(num done, num total) {
    final intl.NumberFormat doneNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String doneString = doneNumberFormat.format(done);
    final intl.NumberFormat totalNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return '$doneString of $totalString filled in';
  }

  @override
  String get profileCompletionAllDone => 'Every field is filled in.';

  @override
  String get profileCompletionMissingTitle => 'Still missing';

  @override
  String get profileFieldPhoto => 'Profile photo';

  @override
  String get profilePhoneLabel => 'Phone';

  @override
  String get profileAreaLabel => 'Area';

  @override
  String get profileAddressLabel => 'Address';

  @override
  String get profileDobLabel => 'Date of birth';

  @override
  String get profileGenderLabel => 'Gender';

  @override
  String get profileGenderFemale => 'Female';

  @override
  String get profileGenderMale => 'Male';

  @override
  String get profileGenderOther => 'Other';

  @override
  String get profileGenderPreferNotToSay => 'Prefer not to say';

  @override
  String get profileAvailabilityTitle => 'Available to donate';

  @override
  String get profileAvailabilityOnBody =>
      'Your donor card shows you as available. You can switch this off at any time.';

  @override
  String get profileAvailabilityOffBody =>
      'Nobody looking for blood will be matched with you. Only you can switch this on.';

  @override
  String get profileAvailabilityNeedsGroup =>
      'Add your blood group before a request can be matched with you.';

  @override
  String get profilePrivacyDiscoveryTitle => 'Let other donors find me';

  @override
  String get profilePrivacyDiscoveryBody =>
      'Only when this is on does your donor card appear in the Find Donors list. Off by default; existing donors are not listed until they switch this on.';

  @override
  String get profilePrivacyAreaTitle => 'Show my area to other donors';

  @override
  String get profilePrivacyAreaBody =>
      'When this is on your area is published on your donor card. When it is off the area is removed from it.';

  @override
  String get profilePrivacyPrivateTitle => 'Always private';

  @override
  String get profilePrivacyPrivateBody =>
      'Phone, address and date of birth are stored where only you can read them.';

  @override
  String get profileHistoryEmptyTitle => 'No donations recorded yet';

  @override
  String get profileHistoryEmptyBody =>
      'A donation appears here once the recipient confirms it. Nothing is added by hand.';

  @override
  String get profileHistoryConfirmed => 'Confirmed';

  @override
  String get profileHistoryPending => 'Pending';

  @override
  String get profileHistoryErrorTitle => 'Could not load your donations';

  @override
  String get profileLoadErrorTitle => 'Could not load your profile';

  @override
  String profileHistoryCount(num count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString donations',
      one: '$countString donation',
    );
    return '$_temp0';
  }

  @override
  String profileHistoryLast(String date) {
    return 'Last donation $date';
  }

  @override
  String get profileContactPrivateBadge => 'Private';

  @override
  String get profileEmailManaged => 'Managed by your sign-in account';

  @override
  String get profileNotSetCtaTitle => 'Complete your profile';

  @override
  String get profileNotSetCtaBody =>
      'Add your blood group and area so a request near you can find you.';

  @override
  String get profileAddDetails => 'Add details';

  @override
  String get profilePhotoAdd => 'Add photo';

  @override
  String get profilePhotoChange => 'Change photo';

  @override
  String get profilePhotoSheetTitle => 'Profile photo';

  @override
  String get profilePhotoSheetBody =>
      'Your photo appears on your donor card. Only you can change it.';

  @override
  String get profilePhotoFromGallery => 'Choose from gallery';

  @override
  String get profilePhotoFromCamera => 'Take a photo';

  @override
  String get profilePhotoRemove => 'Remove photo';

  @override
  String get profilePhotoRemoveConfirmTitle => 'Remove your photo?';

  @override
  String get profilePhotoRemoveConfirmBody =>
      'Your initials will show on your donor card instead, and the stored image will be deleted.';

  @override
  String get profilePhotoUploading => 'Uploading your photo…';

  @override
  String get profilePhotoUpdated => 'Photo updated.';

  @override
  String get profilePhotoRemoved => 'Photo removed.';

  @override
  String get profilePhotoNotConfigured =>
      'Photo upload is not set up in this build yet.';

  @override
  String get profileCoverAdd => 'Add cover photo';

  @override
  String get profileCoverChange => 'Change cover photo';

  @override
  String get profileCoverEdit => 'Edit cover photo';

  @override
  String get profileCoverSheetTitle => 'Cover photo';

  @override
  String get profileCoverSheetBody =>
      'Your cover photo appears at the top of your profile. Only you can change it.';

  @override
  String get profileCoverRemove => 'Remove cover photo';

  @override
  String get profileCoverRemoveConfirmTitle => 'Remove your cover photo?';

  @override
  String get profileCoverRemoveConfirmBody =>
      'The stored image will be deleted and your profile will show its plain background instead.';

  @override
  String get profileCoverUpdated => 'Cover photo updated.';

  @override
  String get profileCoverRemoved => 'Cover photo removed.';

  @override
  String get actionCancel => 'Cancel';

  @override
  String get profilePickerDate => 'Choose a date';

  @override
  String get profilePickerClear => 'Clear';

  @override
  String get errorPhoneInvalid =>
      'Enter a valid mobile number, for example 01712345678';

  @override
  String errorAreaTooLong(num count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Keep the area under $countString characters';
  }

  @override
  String errorAddressTooLong(num count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Keep the address under $countString characters';
  }

  @override
  String get errorDobFuture => 'A date of birth cannot be in the future';

  @override
  String errorDobTooOld(num year) {
    final intl.NumberFormat yearNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String yearString = yearNumberFormat.format(year);

    return 'Enter a date after $yearString';
  }

  @override
  String get errorBloodGroupUnknown => 'Choose one of the eight blood groups';

  @override
  String get errorPhotoEmpty => 'That file was empty. Choose another photo';

  @override
  String errorPhotoTooLarge(num megabytes) {
    final intl.NumberFormat megabytesNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String megabytesString = megabytesNumberFormat.format(megabytes);

    return 'Choose a photo under $megabytesString MB';
  }

  @override
  String get errorPhotoUnsupported => 'Choose a JPEG, PNG or WebP image';

  @override
  String get errorPhotoAccessDenied =>
      'Solovvo needs access to your photos to set a profile photo';

  @override
  String get errorPhotoUnreadable =>
      'That photo could not be read. Try another one';

  @override
  String get firebaseUnavailableTitle => 'Firebase unavailable';

  @override
  String get firebaseUnavailableBody =>
      'Solovvo could not start its backend connection, so data screens are held back rather than shown empty.';

  @override
  String get reconnectHint => 'Reconnect and relaunch the app.';

  @override
  String get diagnosticReason => 'Reason';

  @override
  String get diagnosticDetail => 'Detail';

  @override
  String get diagnosticProject => 'Project';

  @override
  String get diagnosticFlavor => 'Flavor';

  @override
  String get sessionRestoreTitle => 'Could not restore your session';

  @override
  String get sessionRestoreBody =>
      'Solovvo could not reach Firebase Authentication, so it will not guess whether you are signed in.';

  @override
  String get errorEmailRequired => 'Enter your email address';

  @override
  String get errorEmailTooLong => 'That email address is too long';

  @override
  String get errorEmailInvalid => 'Enter a valid email address';

  @override
  String get errorPasswordRequired => 'Enter your password';

  @override
  String get errorPasswordChoose => 'Choose a password';

  @override
  String errorPasswordTooShort(int count) {
    return 'Use at least $count characters';
  }

  @override
  String get errorPasswordComposition => 'Mix letters and numbers';

  @override
  String get errorConfirmRequired => 'Repeat your password';

  @override
  String get errorConfirmMismatch => 'Passwords do not match';

  @override
  String get errorNameRequired => 'Enter your name';

  @override
  String get errorNameTooShort => 'That name is too short';

  @override
  String errorNameTooLong(int count) {
    return 'Keep it under $count characters';
  }

  @override
  String get failureInvalidCredentials =>
      'That email and password do not match. Check both and try again.';

  @override
  String get failureUserDisabled =>
      'This account has been disabled. Contact support to restore it.';

  @override
  String get failureEmailAlreadyInUse =>
      'An account already exists for this email. Sign in instead.';

  @override
  String get failureWeakPassword =>
      'That password is too easy to guess. Use at least 8 characters.';

  @override
  String get failureEmailNotVerified =>
      'Verify your email address before continuing.';

  @override
  String get failureRequiresRecentLogin =>
      'For your security, sign in again and retry.';

  @override
  String get failureOperationNotAllowed =>
      'Email sign-in is switched off for this app. Please contact support.';

  @override
  String get failureUnknownAuth =>
      'We could not complete that sign-in. Please try again.';

  @override
  String get failureNetwork =>
      'No connection. Check your network and try again.';

  @override
  String get failureRateLimited =>
      'Too many attempts. Wait a few minutes and try again.';

  @override
  String get failurePermission => 'You do not have permission to do that.';

  @override
  String get failureNotFound => 'We could not find that account.';

  @override
  String get failureConflict => 'That request is already in progress.';

  @override
  String get failureValidation => 'Please check the details you entered.';

  @override
  String get failureUnexpected =>
      'Something went wrong on our side. Please try again.';

  @override
  String get appearanceAndLanguage => 'Appearance & language';

  @override
  String get languageLabel => 'Language';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageBangla => 'বাংলা';

  @override
  String get themeLabel => 'Theme';

  @override
  String get themeSystem => 'System';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsAccountSection => 'Account';

  @override
  String get settingsPreferencesSection => 'Preferences';

  @override
  String get settingsAppearanceBody =>
      'Theme and language. Changes apply straight away.';

  @override
  String get settingsAboutSection => 'About';

  @override
  String get settingsBuildLabel => 'Build';

  @override
  String get settingsBuildDevelopment => 'Development';

  @override
  String get settingsBuildStaging => 'Staging';

  @override
  String get settingsBuildProduction => 'Production';

  @override
  String get settingsSignOutBody =>
      'You will need your email and password to sign in again.';

  @override
  String get navHome => 'Home';

  @override
  String get feedTitle => 'Community';

  @override
  String get feedEmptyTitle => 'No posts yet';

  @override
  String get feedEmptyBody => 'When a donor shares an update, it appears here.';

  @override
  String get userPostsEmptyTitle => 'No posts from this donor yet';

  @override
  String get userPostsEmptyBody =>
      'When they share an update, it will appear here.';

  @override
  String get feedErrorTitle => 'The feed could not be loaded';

  @override
  String get feedRetry => 'Try again';

  @override
  String get feedLoadMore => 'Load more';

  @override
  String get feedEndOfFeed => 'You have reached the end of the feed';

  @override
  String get feedReadMore => 'Read more';

  @override
  String get feedShowLess => 'Show less';

  @override
  String get feedCopy => 'Copy text';

  @override
  String get feedShare => 'Share';

  @override
  String get feedSave => 'Save';

  @override
  String get feedEditAction => 'Edit';

  @override
  String get feedEditTitle => 'Edit post';

  @override
  String get feedEditHint => 'Update the text of your post.';

  @override
  String get feedEditPhotosLabel => 'Photos';

  @override
  String get feedImageDownload => 'Download';

  @override
  String get feedImageDownloaded => 'Saved to your gallery.';

  @override
  String get feedImageDownloadFailed => 'Could not download this photo.';

  @override
  String get feedImageDownloadDenied =>
      'Solovvo needs permission to save to your gallery.';

  @override
  String get feedEditSave => 'Save changes';

  @override
  String get feedEditSaving => 'Saving…';

  @override
  String get feedEditError => 'Could not save your changes.';

  @override
  String get feedDeleteAction => 'Delete post';

  @override
  String get feedDeleteConfirmTitle => 'Delete this post?';

  @override
  String get feedDeleteConfirmBody =>
      'This cannot be undone. The post and its comments will be permanently removed.';

  @override
  String get feedDeleteConfirm => 'Delete';

  @override
  String get feedDeleted => 'Post deleted.';

  @override
  String get feedDeleteError => 'Could not delete the post.';

  @override
  String get feedSavedFilterOn => 'Showing saved';

  @override
  String get feedSavedFilterOff => 'All posts';

  @override
  String get feedSavedEmpty => 'No saved posts yet.';

  @override
  String get requestsCreateTitle => 'New blood request';

  @override
  String get requestsCreateAction => 'Create request';

  @override
  String get requestsBloodGroup => 'Blood group';

  @override
  String get requestsBags => 'Bags needed';

  @override
  String get requestsHospital => 'Hospital name';

  @override
  String get requestsDate => 'Date needed';

  @override
  String get requestsTime => 'Time needed';

  @override
  String get requestsNotes => 'Notes (optional)';

  @override
  String get requestsNotesHint => 'Any additional details…';

  @override
  String get requestsCreateSubmit => 'Submit request';

  @override
  String get requestsCreating => 'Creating…';

  @override
  String get requestsCreateSuccess => 'Request posted.';

  @override
  String get requestsCreateError => 'Could not create the request.';

  @override
  String get requestsRequired => 'This field is required';

  @override
  String get requestsDetailTitle => 'Request detail';

  @override
  String get requestsDetailNoActionNote =>
      'This screen shows what is needed and where. Contacting the requester is not available in this build yet.';

  @override
  String get requestsAcceptAction => 'Accept request';

  @override
  String get requestsAcceptConfirmTitle => 'Accept this request?';

  @override
  String get requestsAcceptConfirmBody =>
      'You are committing to donate for this patient. The requester will see that you have accepted.';

  @override
  String get requestsAcceptConfirmYes => 'Yes, I will donate';

  @override
  String get requestsAcceptConfirmNo => 'Not now';

  @override
  String get requestsAcceptError => 'Could not accept the request.';

  @override
  String get requestsCancelAction => 'Cancel request';

  @override
  String get requestsCancelConfirmTitle => 'Cancel this request?';

  @override
  String get requestsCancelConfirmBody =>
      'This withdraws your request from the open list. Donors who saw it will no longer be notified.';

  @override
  String get requestsCancelConfirmYes => 'Yes, cancel it';

  @override
  String get requestsCancelConfirmNo => 'Keep it';

  @override
  String get requestsCancelSuccess => 'Request cancelled.';

  @override
  String get requestsCancelError => 'Could not cancel the request.';

  @override
  String get requestsEditAction => 'Edit request';

  @override
  String get requestsEditTitle => 'Edit request';

  @override
  String get requestsEditSubmit => 'Save changes';

  @override
  String get requestsEditSaving => 'Saving…';

  @override
  String get requestsEditSuccess => 'Request updated.';

  @override
  String get requestsEditError => 'Could not update the request.';

  @override
  String get requestsContactAction => 'Contact details';

  @override
  String get requestsContactTitle => 'Requester contact details';

  @override
  String get requestsContactIntro =>
      'Stored privately with this request. Not shown to donors in this build.';

  @override
  String get requestsPatientName => 'Patient name';

  @override
  String get requestsPhoneNumber => 'Phone number';

  @override
  String get requestsHospitalAddress => 'Hospital address';

  @override
  String get requestsContactSubmit => 'Save contact details';

  @override
  String get requestsContactSaving => 'Saving…';

  @override
  String get requestsContactLoading => 'Loading…';

  @override
  String get requestsContactSuccess => 'Contact details saved.';

  @override
  String get requestsContactError => 'Could not save the contact details.';

  @override
  String get requestsContactLoadError =>
      'Could not load your saved contact details.';

  @override
  String get requestsContactRetry => 'Try again';

  @override
  String get requestsMyAction => 'My requests';

  @override
  String get requestsMyTitle => 'My requests';

  @override
  String get requestsMyEmptyTitle => 'You have no open requests';

  @override
  String get requestsMyEmptyBody =>
      'Requests you create appear here until they are filled or cancelled.';

  @override
  String get requestsFilterLabel => 'Filter by group';

  @override
  String get requestsFilterEmpty =>
      'No open requests need this group right now.';

  @override
  String get feedCopied => 'Post text copied.';

  @override
  String get feedEdited => 'Edited';

  @override
  String get feedJustNow => 'Just now';

  @override
  String feedMinutesAgo(num count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString minutes ago',
      one: '$countString minute ago',
    );
    return '$_temp0';
  }

  @override
  String feedHoursAgo(num count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString hours ago',
      one: '$countString hour ago',
    );
    return '$_temp0';
  }

  @override
  String feedDaysAgo(num count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString days ago',
      one: '$countString day ago',
    );
    return '$_temp0';
  }

  @override
  String feedOnDate(String date) {
    return 'On $date';
  }

  @override
  String feedLikeCount(num count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString likes',
      one: '$countString like',
    );
    return '$_temp0';
  }

  @override
  String feedCommentCount(num count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString comments',
      one: '$countString comment',
    );
    return '$_temp0';
  }

  @override
  String get commentsSheetTitle => 'Comments';

  @override
  String get commentsEmptyBody => 'No comments yet. Be the first.';

  @override
  String get commentsLoading => 'Loading comments…';

  @override
  String get commentsHintText => 'Write a comment…';

  @override
  String get commentsSendTooltip => 'Send';

  @override
  String get commentsErrorTitle => 'Could not load comments';

  @override
  String commentsReplyPrefix(String name) {
    return 'Reply to $name';
  }

  @override
  String commentsReplyingTo(String name) {
    return 'Replying to $name';
  }

  @override
  String get commentsReplyHint => 'Write a reply…';

  @override
  String get commentsReplyAction => 'Reply';

  @override
  String get commentsDeleteAction => 'Delete';

  @override
  String get reportTooltip => 'Report';

  @override
  String get reportSheetTitle => 'Report this post';

  @override
  String get reportCommentSheetTitle => 'Report this comment';

  @override
  String get reportReasonLabel => 'Reason';

  @override
  String get reportReasonSpam => 'Spam';

  @override
  String get reportReasonHarassment => 'Harassment';

  @override
  String get reportReasonHateSpeech => 'Hate speech';

  @override
  String get reportReasonMisinformation => 'Misinformation';

  @override
  String get reportReasonOther => 'Other';

  @override
  String get reportNoteHint => 'Additional details (optional)';

  @override
  String get reportSubmitButton => 'Submit report';

  @override
  String get reportSubmitting => 'Submitting…';

  @override
  String get reportSuccess => 'Report submitted. Thank you.';

  @override
  String get reportError => 'Could not submit report.';

  @override
  String get feedUnreadableTitle => 'The feed could not be fully read';

  @override
  String get feedUnreadableBody =>
      'There are more posts behind this, but they could not be read.';

  @override
  String feedSkippedNotice(num count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString posts could not be shown',
      one: '$countString post could not be shown',
    );
    return '$_temp0';
  }

  @override
  String feedPostPhotoLabel(String name) {
    return 'Photo shared by $name';
  }

  @override
  String get feedComposeAction => 'Share an update';

  @override
  String get feedComposeTitle => 'New post';

  @override
  String get feedComposeTextLabel => 'Your update';

  @override
  String get feedComposeTextHint =>
      'Share news, a request, or a story from a blood drive.';

  @override
  String feedComposeLimit(num count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Up to $countString characters';
  }

  @override
  String get feedComposePhotosLabel => 'Photos';

  @override
  String get feedComposeAddPhoto => 'Add photo';

  @override
  String get feedComposeFromGallery => 'Choose from gallery';

  @override
  String get feedComposeFromCamera => 'Take a photo';

  @override
  String get feedComposeRemovePhoto => 'Remove photo';

  @override
  String get feedComposeUploading => 'Uploading your photo…';

  @override
  String get feedComposePublish => 'Publish';

  @override
  String get feedComposePublished => 'Your post is live.';

  @override
  String get feedComposePhotosNotConfigured =>
      'Photo upload is not set up in this build yet.';

  @override
  String get feedComposeDiscardTitle => 'Discard this post?';

  @override
  String get feedComposeDiscardBody => 'Your text and photos will be deleted.';

  @override
  String get feedComposeDiscardConfirm => 'Discard';

  @override
  String get feedComposeKeepEditing => 'Keep editing';

  @override
  String get requestsTitle => 'Open requests';

  @override
  String get requestsEmptyTitle => 'No open requests right now';

  @override
  String get requestsEmptyBody =>
      'Nothing is marked open at the moment. Pull down to check again.';

  @override
  String get requestsErrorTitle => 'The requests could not be loaded';

  @override
  String get requestsRetry => 'Try again';

  @override
  String get requestsUnreadableTitle => 'The requests could not be fully read';

  @override
  String get requestsUnreadableBody =>
      'There are open requests behind this, but they could not be read.';

  @override
  String requestsSkippedNotice(num count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString requests could not be shown',
      one: '$countString request could not be shown',
    );
    return '$_temp0';
  }

  @override
  String requestsTruncatedNotice(num count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Only the first $countString open requests are shown here. More are still behind them.';
  }

  @override
  String get requestsNoActionNote =>
      'This list shows what is needed and where. Open a request to accept it if you are eligible.';

  @override
  String get donorSearchTitle => 'Find donors';

  @override
  String get donorDetailsTitle => 'Donor profile';

  @override
  String get donorUnnamed => 'Donor';

  @override
  String get donorRetry => 'Try again';

  @override
  String get donorAvailable => 'Available';

  @override
  String get donorUnavailable => 'Not available';

  @override
  String get donorGroupNotSet => 'Blood group not set';

  @override
  String get donorAvailabilityHeading => 'Availability';

  @override
  String get donorAvailabilityFilter => 'Available donors only';

  @override
  String get donorFilterAllGroups => 'All groups';

  @override
  String get donorAreaFieldLabel => 'Area';

  @override
  String get donorAreaFieldHint => 'Area or neighbourhood';

  @override
  String get donorClearArea => 'Clear area';

  @override
  String get donorSearchButton => 'Search';

  @override
  String get donorErrorTitle => 'The donors could not be loaded';

  @override
  String get donorUnreadableTitle => 'The donors could not be fully read';

  @override
  String get donorUnreadableBody =>
      'There are donors behind this, but their profiles could not be read.';

  @override
  String get donorEmptyFilteredTitle => 'No donors match your filters';

  @override
  String get donorEmptyFilteredBody =>
      'Try widening the blood group, availability, or area.';

  @override
  String get donorEmptyAllTitle => 'No donors are listed yet';

  @override
  String get donorEmptyAllBody =>
      'Donors who choose to make themselves discoverable will appear here.';

  @override
  String get donorContactNote =>
      'To protect donors, their contact details are not shown here. Reaching out happens through a blood request.';

  @override
  String get donorConsentNote =>
      'This donor chose to appear in search. Their area is shown only if they published it.';

  @override
  String donorSkippedNotice(num count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString donors could not be shown',
      one: '$countString donor could not be shown',
    );
    return '$_temp0';
  }

  @override
  String donorTruncatedNotice(num count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Only the first $countString donors are shown here. More are still behind them.';
  }

  @override
  String get errorPostTextRequired => 'Write something before publishing';

  @override
  String errorPostTextTooLong(num count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Keep your post under $countString characters';
  }

  @override
  String errorPostTooManyImages(num count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Attach up to $countString photos';
  }
}
