// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Bengali Bangla (`bn`).
class AppLocalizationsBn extends AppLocalizations {
  AppLocalizationsBn([String locale = 'bn']) : super(locale);

  @override
  String get appTagline => 'জীবন বাঁচান • হৃদয় জুড়ুন';

  @override
  String get signIn => 'সাইন ইন';

  @override
  String get signOut => 'সাইন আউট';

  @override
  String get tryAgain => 'আবার চেষ্টা করুন';

  @override
  String get close => 'বন্ধ করুন';

  @override
  String get emailLabel => 'ইমেইল';

  @override
  String get emailHint => 'you@example.com';

  @override
  String get passwordLabel => 'পাসওয়ার্ড';

  @override
  String get showPassword => 'পাসওয়ার্ড দেখুন';

  @override
  String get hidePassword => 'পাসওয়ার্ড লুকান';

  @override
  String get welcomeHeadline => 'এক ফোঁটা আশা, রক্ত দিন, জীবন দিন';

  @override
  String get welcomeSubtitle =>
      'একবার রক্তদান একটি পরিবারের অপেক্ষা আর মিলনের মাঝে পার্থক্য গড়ে দিতে পারে। যে সমাজ ডাকে সাড়া দেয়, তার সঙ্গে যুক্ত হোন।';

  @override
  String get getStarted => 'শুরু করুন';

  @override
  String get alreadyHaveAccount => 'আগেই অ্যাকাউন্ট আছে?';

  @override
  String get loginTitle => 'আবার স্বাগতম';

  @override
  String get loginSubtitle =>
      'আপনার ডোনার প্রোফাইল আর কাছের অনুরোধগুলো দেখতে সাইন ইন করুন।';

  @override
  String get passwordHint => 'আপনার পাসওয়ার্ড';

  @override
  String get forgotPassword => 'পাসওয়ার্ড ভুলে গেছেন?';

  @override
  String get newToSolovvo => 'Solovvo-তে নতুন?';

  @override
  String get createAnAccount => 'অ্যাকাউন্ট খোলেন';

  @override
  String get registerTitle => 'Solovvo-তে যুক্ত হোন';

  @override
  String get registerSubtitle =>
      'রক্তের গ্রুপ আর দূরত্ব অনুযায়ী ডোনারদের মিলানো হয়। নিবন্ধনে এক মিনিটও লাগবে না।';

  @override
  String get fullNameLabel => 'পুরো নাম';

  @override
  String get fullNameHint => 'যেভাবে ডোনাররা দেখবেন';

  @override
  String get newPasswordHint => 'অন্তত ৮ অক্ষর';

  @override
  String get passwordRule => 'অক্ষর ও সংখ্যা মিশিয়ে দিন';

  @override
  String get confirmPasswordLabel => 'পাসওয়ার্ড নিশ্চিত করুন';

  @override
  String get confirmPasswordHint => 'পাসওয়ার্ডটি আবার লিখুন';

  @override
  String get createAccount => 'অ্যাকাউন্ট তৈরি করুন';

  @override
  String get verificationEmailNote =>
      'অ্যাকাউন্ট দিয়ে কোনো অনুরোধে সাড়া দেওয়ার আগে আমরা ইমেইলে একটি লিংক পাঠিয়ে ঠিকানাটি নিশ্চিত করব।';

  @override
  String get alreadyRegistered => 'আগেই নিবন্ধিত?';

  @override
  String get forgotTitle => 'পাসওয়ার্ড রিসেট করুন';

  @override
  String get forgotSubtitle =>
      'আপনার অ্যাকাউন্টের ঠিকানাটি লিখুন, আমরা নতুন পাসওয়ার্ড বাছার একটি লিংক পাঠাব।';

  @override
  String get sendResetLink => 'রিসেট লিংক পাঠান';

  @override
  String get backToSignIn => 'সাইন ইনে ফিরুন';

  @override
  String get resetSentTitle => 'আপনার ইনবক্স দেখুন';

  @override
  String resetSentBody(String email) {
    return '$email দিয়ে কোনো অ্যাকাউন্ট থাকলে Firebase থেকে একটি পাসওয়ার্ড রিসেট লিংক পাঠানো হচ্ছে। লিংকটির মেয়াদ এক ঘণ্টা।';
  }

  @override
  String get verifyTitle => 'আপনার ইমেইল নিশ্চিত করুন';

  @override
  String get verifySubtitle =>
      'ইনবক্সে একবার ট্যাপ করলেই Solovvo-র বাকি অংশ খুলে যাবে।';

  @override
  String get sentToLabel => 'আমরা লিংক পাঠিয়েছি';

  @override
  String get verifyLockedBody =>
      'আপনার অ্যাকাউন্ট তৈরি হয়েছে, তবে ঠিকানাটি নিশ্চিত না হওয়া পর্যন্ত রক্তদানের সুবিধাগুলো বন্ধ থাকবে।';

  @override
  String get freshLinkSent => 'নতুন একটি লিংক পাঠানো হয়েছে।';

  @override
  String get notConfirmedYet =>
      'এখনো নিশ্চিত হয়নি। ইনবক্সের লিংকটি খুলুন, তারপর আবার দেখুন।';

  @override
  String get confirmedCta => 'আমি ইমেইল নিশ্চিত করেছি';

  @override
  String get resendEmail => 'ইমেইল আবার পাঠান';

  @override
  String resendIn(int seconds) {
    return '$seconds সেকেন্ড পরে আবার';
  }

  @override
  String get unknownEmail => 'আপনার ইমেইল ঠিকানা';

  @override
  String homeGreeting(String name) {
    return 'স্বাগতম, $name';
  }

  @override
  String get homeDashboardSubtitle =>
      'রক্ত দেওয়া আর রক্ত চাওয়ার সবকিছু এক জায়গায়।';

  @override
  String get verified => 'নিশ্চিত';

  @override
  String get donorStatusTitle => 'ডোনার স্ট্যাটাস';

  @override
  String get bloodGroupLabel => 'রক্তের গ্রুপ';

  @override
  String get lastDonationLabel => 'সর্বশেষ রক্তদান';

  @override
  String get availabilityLabel => 'উপলব্ধতা';

  @override
  String get notSetYet => 'এখনো দেওয়া হয়নি';

  @override
  String get availableNow => 'উপলব্ধ';

  @override
  String get notAvailableNow => 'উপলব্ধ নন';

  @override
  String get neverDonated => 'এখনো রক্তদান করেননি';

  @override
  String homeDonationsCount(num count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '$countString বার রক্তদান';
  }

  @override
  String get homeRequestBlood => 'রক্তের অনুরোধ';

  @override
  String get homeFindDonors => 'ডোনার খুঁজুন';

  @override
  String get homeNearbyTitle => 'আপনার কাছের অনুরোধ';

  @override
  String get homeNearbyEmptyTitle => 'কাছাকাছি কোনো অনুরোধ নেই';

  @override
  String get homeNearbyEmptyBody =>
      'আপনার কাছের কেউ রক্তের প্রয়োজন হলে তার অনুরোধ সবার আগে এখানে দেখা যাবে।';

  @override
  String homeUnitsNeeded(num count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '$countString ইউনিট দরকার';
  }

  @override
  String homeNeededBy(String date) {
    return 'শেষ তারিখ: $date';
  }

  @override
  String get homeFeedTitle => 'কমিউনিটি থেকে';

  @override
  String get homeFeedEmptyTitle => 'এখনো কোনো পোস্ট নেই';

  @override
  String get homeFeedEmptyBody => 'ডোনারদের লেখা ও গল্প এখানে দেখা যাবে।';

  @override
  String get homeSeeAll => 'সব দেখুন';

  @override
  String get homeComingSoon => 'শীঘ্রই আসছে।';

  @override
  String get profileTitle => 'প্রোফাইল';

  @override
  String get profileEditTitle => 'প্রোফাইল সম্পাদনা';

  @override
  String get profileEditAction => 'সম্পাদনা';

  @override
  String get profileSaveAction => 'পরিবর্তন সংরক্ষণ করুন';

  @override
  String get profileSaved => 'প্রোফাইল সংরক্ষণ করা হয়েছে।';

  @override
  String get profileSectionYou => 'আপনার ডোনার কার্ড';

  @override
  String get profileSectionDetails => 'ব্যক্তিগত তথ্য';

  @override
  String get profileSectionPrivacy => 'গোপনীয়তা';

  @override
  String get profileSectionHistory => 'রক্তদানের ইতিহাস';

  @override
  String get profileCompletionTitle => 'প্রোফাইল সম্পূর্ণতা';

  @override
  String profileCompletionCount(num done, num total) {
    final intl.NumberFormat doneNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String doneString = doneNumberFormat.format(done);
    final intl.NumberFormat totalNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return '$totalString টির মধ্যে $doneString টি পূরণ হয়েছে';
  }

  @override
  String get profileCompletionAllDone => 'সব তথ্য পূরণ হয়েছে।';

  @override
  String get profileCompletionMissingTitle => 'এখনও বাকি';

  @override
  String get profileFieldPhoto => 'প্রোফাইল ছবি';

  @override
  String get profilePhoneLabel => 'ফোন';

  @override
  String get profileAreaLabel => 'এলাকা';

  @override
  String get profileAddressLabel => 'ঠিকানা';

  @override
  String get profileDobLabel => 'জন্ম তারিখ';

  @override
  String get profileGenderLabel => 'লিঙ্গ';

  @override
  String get profileGenderFemale => 'মহিলা';

  @override
  String get profileGenderMale => 'পুরুষ';

  @override
  String get profileGenderOther => 'অন্যান্য';

  @override
  String get profileGenderPreferNotToSay => 'বলতে চাই না';

  @override
  String get profileAvailabilityTitle => 'রক্তদানে প্রস্তুত';

  @override
  String get profileAvailabilityOnBody =>
      'আপনার কার্ডে আপনি প্রস্তুত হিসেবে দেখানো হচ্ছে। যেকোনো সময় এটি বন্ধ করতে পারেন।';

  @override
  String get profileAvailabilityOffBody =>
      'রক্তের জন্য কেউ খুঁজলে আপনার সঙ্গে যোগাযোগ করা হবে না। কেবল আপনিই এটি চালু করতে পারেন।';

  @override
  String get profileAvailabilityNeedsGroup =>
      'কোনো অনুরোধের সঙ্গে মেলানোর আগে আপনার রক্তের গ্রুপ যোগ করুন।';

  @override
  String get profilePrivacyAreaTitle => 'অন্য ডোনারদের কাছে আমার এলাকা দেখান';

  @override
  String get profilePrivacyAreaBody =>
      'এটি চালু থাকলে আপনার এলাকা কার্ডে প্রকাশিত হয়। বন্ধ থাকলে এলাকাটি কার্ড থেকে সরিয়ে নেওয়া হয়।';

  @override
  String get profilePrivacyPrivateTitle => 'সবসময় গোপন';

  @override
  String get profilePrivacyPrivateBody =>
      'ফোন, ঠিকানা ও জন্ম তারিখ এমন জায়গায় রাখা হয় যা কেবল আপনি পড়তে পারেন।';

  @override
  String get profileHistoryEmptyTitle => 'এখনও কোনো রক্তদান নথিভুক্ত হয়নি';

  @override
  String get profileHistoryEmptyBody =>
      'রক্ত গ্রহীতা নিশ্চিত করার পরেই এখানে রক্তদান দেখা যাবে। হাতে কিছু যোগ করা হয় না।';

  @override
  String get profileHistoryConfirmed => 'নিশ্চিত';

  @override
  String get profileHistoryPending => 'অপেক্ষমাণ';

  @override
  String get profileHistoryErrorTitle => 'আপনার রক্তদানের তথ্য আনা যায়নি';

  @override
  String get profileLoadErrorTitle => 'আপনার প্রোফাইল আনা যায়নি';

  @override
  String profileHistoryCount(num count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString টি রক্তদান',
      one: '$countString টি রক্তদান',
    );
    return '$_temp0';
  }

  @override
  String profileHistoryLast(String date) {
    return 'সর্বশেষ রক্তদান $date';
  }

  @override
  String get profileContactPrivateBadge => 'গোপন';

  @override
  String get profileEmailManaged => 'আপনার সাইন-ইন অ্যাকাউন্ট দ্বারা পরিচালিত';

  @override
  String get profileNotSetCtaTitle => 'আপনার প্রোফাইল সম্পূর্ণ করুন';

  @override
  String get profileNotSetCtaBody =>
      'রক্তের গ্রুপ ও এলাকা যোগ করুন, যাতে কাছাকাছি কোনো অনুরোধ আপনাকে খুঁজে পায়।';

  @override
  String get profileAddDetails => 'তথ্য যোগ করুন';

  @override
  String get profilePhotoAdd => 'ছবি যোগ করুন';

  @override
  String get profilePhotoChange => 'ছবি বদলান';

  @override
  String get profilePhotoSheetTitle => 'প্রোফাইল ছবি';

  @override
  String get profilePhotoSheetBody =>
      'আপনার ছবি ডোনার কার্ডে দেখা যায়। কেবল আপনিই এটি বদলাতে পারেন।';

  @override
  String get profilePhotoFromGallery => 'গ্যালারি থেকে নিন';

  @override
  String get profilePhotoFromCamera => 'ক্যামেরায় ছবি তুলুন';

  @override
  String get profilePhotoRemove => 'ছবি সরান';

  @override
  String get profilePhotoRemoveConfirmTitle => 'ছবিটি সরিয়ে ফেলবেন?';

  @override
  String get profilePhotoRemoveConfirmBody =>
      'কার্ডে এর বদলে আপনার নামের আদ্যক্ষর দেখা যাবে এবং সংরক্ষিত ছবিটি মুছে ফেলা হবে।';

  @override
  String get profilePhotoUploading => 'ছবি আপলোড হচ্ছে…';

  @override
  String get profilePhotoUpdated => 'ছবি হালনাগাদ হয়েছে।';

  @override
  String get profilePhotoRemoved => 'ছবি সরানো হয়েছে।';

  @override
  String get profilePhotoNotConfigured =>
      'এই বিল্ডে ছবি আপলোড এখনো চালু হয়নি।';

  @override
  String get actionCancel => 'বাতিল';

  @override
  String get profilePickerDate => 'তারিখ বেছে নিন';

  @override
  String get profilePickerClear => 'মুছুন';

  @override
  String get errorPhoneInvalid => 'সঠিক মোবাইল নম্বর দিন, যেমন ০১৭১২৩৪৫৬৭৮';

  @override
  String errorAreaTooLong(num count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'এলাকার নাম $countString অক্ষরের মধ্যে রাখুন';
  }

  @override
  String errorAddressTooLong(num count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'ঠিকানা $countString অক্ষরের মধ্যে রাখুন';
  }

  @override
  String get errorDobFuture => 'জন্ম তারিখ ভবিষ্যতের হতে পারে না';

  @override
  String errorDobTooOld(num year) {
    final intl.NumberFormat yearNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String yearString = yearNumberFormat.format(year);

    return '$yearString সালের পরের একটি তারিখ দিন';
  }

  @override
  String get errorBloodGroupUnknown => 'আটটি রক্তের গ্রুপের একটি বেছে নিন';

  @override
  String get errorPhotoEmpty => 'ফাইলটি খালি ছিল। অন্য একটি ছবি বেছে নিন';

  @override
  String errorPhotoTooLarge(num megabytes) {
    final intl.NumberFormat megabytesNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String megabytesString = megabytesNumberFormat.format(megabytes);

    return '$megabytesString মেগাবাইটের ছোট একটি ছবি বেছে নিন';
  }

  @override
  String get errorPhotoUnsupported => 'JPEG, PNG বা WebP ছবি বেছে নিন';

  @override
  String get errorPhotoAccessDenied =>
      'প্রোফাইল ছবি দিতে ছবি ব্যবহারের অনুমতি দিতে হবে';

  @override
  String get errorPhotoUnreadable =>
      'ছবিটি পড়া যায়নি। অন্য একটি ছবি চেষ্টা করুন';

  @override
  String get firebaseUnavailableTitle => 'Firebase পাওয়া যাচ্ছে না';

  @override
  String get firebaseUnavailableBody =>
      'Solovvo তার ব্যাকএন্ড সংযোগ শুরু করতে পারেনি, তাই ডেটা স্ক্রিনগুলো খালি দেখানোর বদলে আটকে রাখা হয়েছে।';

  @override
  String get reconnectHint => 'সংযোগ ফিরিয়ে অ্যাপটি আবার চালু করুন।';

  @override
  String get diagnosticReason => 'কারণ';

  @override
  String get diagnosticDetail => 'বিস্তারিত';

  @override
  String get diagnosticProject => 'প্রজেক্ট';

  @override
  String get diagnosticFlavor => 'ফ্লেভার';

  @override
  String get sessionRestoreTitle => 'আপনার সেশন পুনরুদ্ধার করা যায়নি';

  @override
  String get sessionRestoreBody =>
      'Solovvo Firebase Authentication-এ পৌঁছাতে পারেনি, তাই আপনি সাইন ইন করা আছেন কি না তা অনুমান করবে না।';

  @override
  String get errorEmailRequired => 'আপনার ইমেইল ঠিকানা লিখুন';

  @override
  String get errorEmailTooLong => 'এই ইমেইল ঠিকানাটি বেশ বড়';

  @override
  String get errorEmailInvalid => 'সঠিক ইমেইল ঠিকানা লিখুন';

  @override
  String get errorPasswordRequired => 'আপনার পাসওয়ার্ড লিখুন';

  @override
  String get errorPasswordChoose => 'একটি পাসওয়ার্ড বেছে নিন';

  @override
  String errorPasswordTooShort(int count) {
    return 'অন্তত $count অক্ষর ব্যবহার করুন';
  }

  @override
  String get errorPasswordComposition => 'অক্ষর ও সংখ্যা মিশিয়ে দিন';

  @override
  String get errorConfirmRequired => 'আপনার পাসওয়ার্ডটি আবার লিখুন';

  @override
  String get errorConfirmMismatch => 'পাসওয়ার্ড দুটি মিলছে না';

  @override
  String get errorNameRequired => 'আপনার নাম লিখুন';

  @override
  String get errorNameTooShort => 'নামটি বেশ ছোট';

  @override
  String errorNameTooLong(int count) {
    return '$count অক্ষরের মধ্যে রাখুন';
  }

  @override
  String get failureInvalidCredentials =>
      'ইমেইল আর পাসওয়ার্ড মিলছে না। দুটোই দেখে আবার চেষ্টা করুন।';

  @override
  String get failureUserDisabled =>
      'এই অ্যাকাউন্টটি বন্ধ করে দেওয়া হয়েছে। চালু করতে সহায়তা কেন্দ্রে যোগাযোগ করুন।';

  @override
  String get failureEmailAlreadyInUse =>
      'এই ইমেইলে ইতিমধ্যে একটি অ্যাকাউন্ট আছে। বরং সাইন ইন করুন।';

  @override
  String get failureWeakPassword =>
      'পাসওয়ার্ডটি সহজেই অনুমান করা যায়। অন্তত ৮ অক্ষর ব্যবহার করুন।';

  @override
  String get failureEmailNotVerified =>
      'এগিয়ে যাওয়ার আগে আপনার ইমেইল নিশ্চিত করুন।';

  @override
  String get failureRequiresRecentLogin =>
      'নিরাপত্তার জন্য আবার সাইন ইন করে পুনরায় চেষ্টা করুন।';

  @override
  String get failureOperationNotAllowed =>
      'এই অ্যাপে ইমেইল সাইন ইন বন্ধ আছে। সহায়তা কেন্দ্রে যোগাযোগ করুন।';

  @override
  String get failureUnknownAuth =>
      'সাইন ইনটি সম্পন্ন করা যায়নি। আবার চেষ্টা করুন।';

  @override
  String get failureNetwork => 'সংযোগ নেই। নেটওয়ার্ক দেখে আবার চেষ্টা করুন।';

  @override
  String get failureRateLimited =>
      'অনেকবার চেষ্টা হয়েছে। কয়েক মিনিট অপেক্ষা করে আবার চেষ্টা করুন।';

  @override
  String get failurePermission => 'এই কাজটি করার অনুমতি আপনার নেই।';

  @override
  String get failureNotFound => 'অ্যাকাউন্টটি খুঁজে পাওয়া যায়নি।';

  @override
  String get failureConflict => 'অনুরোধটি আগেই চালু আছে।';

  @override
  String get failureValidation => 'আপনার দেওয়া তথ্যগুলো দেখে নিন।';

  @override
  String get failureUnexpected =>
      'আমাদের দিকেই কিছু একটা সমস্যা হয়েছে। আবার চেষ্টা করুন।';

  @override
  String get appearanceAndLanguage => 'রূপ ও ভাষা';

  @override
  String get languageLabel => 'ভাষা';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageBangla => 'বাংলা';

  @override
  String get themeLabel => 'থিম';

  @override
  String get themeSystem => 'সিস্টেম';

  @override
  String get themeLight => 'হালকা';

  @override
  String get themeDark => 'গাঢ়';
}
