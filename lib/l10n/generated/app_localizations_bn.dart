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
  String get homeRequestsTitle => 'খোলা অনুরোধ';

  @override
  String get homeRequestsEmptyTitle => 'কোনো খোলা অনুরোধ নেই';

  @override
  String get homeRequestsEmptyBody =>
      'কারো রক্ত প্রয়োজন হলে তার অনুরোধ সবার আগে এখানে দেখা যাবে।';

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
  String get homeNeededByUnknown => 'তারিখ দেওয়া হয়নি';

  @override
  String get homeFeedTitle => 'কমিউনিটি থেকে';

  @override
  String get homeFeedEmptyTitle => 'এখনো কোনো পোস্ট নেই';

  @override
  String get homeFeedEmptyBody => 'ডোনারদের লেখা ও গল্প এখানে দেখা যাবে।';

  @override
  String get homeFeedOpenAction => 'কমিউনিটি দেখুন';

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
  String get profilePrivacyDiscoveryTitle => 'অন্য দাতারা যেন আমাকে খুঁজে পান';

  @override
  String get profilePrivacyDiscoveryBody =>
      'এটি চালু থাকলেই কেবল আপনার ডোনার কার্ড \"দাতা খুঁজুন\" তালিকায় দেখা যাবে। নিরীখে বন্ধ; আগে থেকে নিবন্ধিত দাতারা এটি চালু না করা পর্যন্ত তালিকায় থাকবেন না।';

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

  @override
  String get settingsTitle => 'সেটিংস';

  @override
  String get settingsAccountSection => 'অ্যাকাউন্ট';

  @override
  String get settingsPreferencesSection => 'পছন্দসমূহ';

  @override
  String get settingsAppearanceBody =>
      'থিম ও ভাষা। পরিবর্তন সঙ্গে সঙ্গে প্রযোজ্য হবে।';

  @override
  String get settingsAboutSection => 'অ্যাপ সম্পর্কে';

  @override
  String get settingsBuildLabel => 'বিল্ড';

  @override
  String get settingsBuildDevelopment => 'ডেভেলপমেন্ট';

  @override
  String get settingsBuildStaging => 'স্টেজিং';

  @override
  String get settingsBuildProduction => 'প্রোডাকশন';

  @override
  String get settingsSignOutBody =>
      'আবার সাইন ইন করতে ইমেইল ও পাসওয়ার্ড লাগবে।';

  @override
  String get navHome => 'হোম';

  @override
  String get feedTitle => 'কমিউনিটি';

  @override
  String get feedEmptyTitle => 'এখনো কোনো পোস্ট নেই';

  @override
  String get feedEmptyBody =>
      'কোনো রক্তদাতা কিছু শেয়ার করলে তা এখানে দেখা যাবে।';

  @override
  String get feedErrorTitle => 'ফিডটি লোড করা যায়নি';

  @override
  String get feedRetry => 'আবার চেষ্টা করুন';

  @override
  String get feedLoadMore => 'আরও দেখুন';

  @override
  String get feedEndOfFeed => 'সব পোস্ট দেখা হয়ে গেছে';

  @override
  String get feedReadMore => 'আরও পড়ুন';

  @override
  String get feedShowLess => 'কম দেখান';

  @override
  String get feedCopy => 'লেখাটি কপি করুন';

  @override
  String get feedShare => 'শেয়ার করুন';

  @override
  String get feedSave => 'সংরক্ষণ করুন';

  @override
  String get feedEditAction => 'সম্পাদনা';

  @override
  String get feedEditTitle => 'পোস্ট সম্পাদনা';

  @override
  String get feedEditHint => 'আপনার পোস্টের লেখা হালনাগাদ করুন।';

  @override
  String get feedEditSave => 'পরিবর্তন সংরক্ষণ';

  @override
  String get feedEditSaving => 'সংরক্ষণ হচ্ছে…';

  @override
  String get feedEditError => 'আপনার পরিবর্তন সংরক্ষণ করা যায়নি.';

  @override
  String get feedDeleteAction => 'পোস্ট মুছুন';

  @override
  String get feedDeleteConfirmTitle => 'এই পোস্টটি মুছবেন?';

  @override
  String get feedDeleteConfirmBody =>
      'এটি পূর্বাবস্থায় ফেরানো যাবে না। পোস্ট এবং এর মন্তব্যগুলো স্থায়ীভাবে সরানো হবে।';

  @override
  String get feedDeleteConfirm => 'মুছুন';

  @override
  String get feedDeleted => 'পোস্ট মুছে ফেলা হয়েছে।';

  @override
  String get feedDeleteError => 'পোস্টটি মুছে ফেলা যায়নি।';

  @override
  String get feedSavedFilterOn => 'সংরক্ষিত দেখানো হচ্ছে';

  @override
  String get feedSavedFilterOff => 'সব পোস্ট';

  @override
  String get feedSavedEmpty => 'এখনো কোনো সংরক্ষিত পোস্ট নেই।';

  @override
  String get requestsCreateTitle => 'নতুন রক্তের অনুরোধ';

  @override
  String get requestsCreateAction => 'অনুরোধ তৈরি করুন';

  @override
  String get requestsBloodGroup => 'রক্তের গ্রুপ';

  @override
  String get requestsBags => 'প্রয়োজনীয় ব্যাগ';

  @override
  String get requestsHospital => 'হাসপাতালের নাম';

  @override
  String get requestsDate => 'প্রয়োজনের তারিখ';

  @override
  String get requestsTime => 'প্রয়োজনের সময়';

  @override
  String get requestsNotes => 'অতিরিক্ত তথ্য (ঐচ্ছিক)';

  @override
  String get requestsNotesHint => 'আরেকোনো বিবরণ…';

  @override
  String get requestsCreateSubmit => 'অনুরোধ জমা দিন';

  @override
  String get requestsCreating => 'তৈরি হচ্ছে…';

  @override
  String get requestsCreateSuccess => 'অনুরোধ পোস্ট হয়েছে।';

  @override
  String get requestsCreateError => 'অনুরোধ তৈরি করা যায়নি।';

  @override
  String get requestsRequired => 'এই ফিল্ডটি আবশ্যক';

  @override
  String get requestsDetailTitle => 'অনুরোধের বিবরণ';

  @override
  String get requestsDetailNoActionNote =>
      'এই স্ক্রিনে যা প্রয়োজন এবং কোথায় প্রয়োজন তা দেখানো হয়। এই বিল্ডে অনুরোধকারীর সঙ্গে যোগাযোগ করা এখনো উপলব্ধ নয়।';

  @override
  String get requestsAcceptAction => 'অনুরোধ গ্রহণ করুন';

  @override
  String get requestsAcceptConfirmTitle => 'এই অনুরোধটি গ্রহণ করবেন?';

  @override
  String get requestsAcceptConfirmBody =>
      'আপনি এই রোগীর জন্য রক্তদান করতে যাচ্ছেন। অনুরোধকারী দেখতে পাবেন যে আপনি গ্রহণ করেছেন।';

  @override
  String get requestsAcceptConfirmYes => 'হ্যাঁ, আমি রক্তদান করব';

  @override
  String get requestsAcceptConfirmNo => 'এখন নয়';

  @override
  String get requestsAcceptError => 'অনুরোধ গ্রহণ করা যায়নি।';

  @override
  String get requestsCancelAction => 'অনুরোধ বাতিল করুন';

  @override
  String get requestsCancelConfirmTitle => 'এই অনুরোধটি বাতিল করবেন?';

  @override
  String get requestsCancelConfirmBody =>
      'এটি আপনার অনুরোধ খোলা তালিকা থেকে সরিয়ে দেবে। যারা এটি দেখেছিল তারা আর বিজ্ঞপ্তি পাবে না।';

  @override
  String get requestsCancelConfirmYes => 'হ্যাঁ, বাতিল করুন';

  @override
  String get requestsCancelConfirmNo => 'রেখে দিন';

  @override
  String get requestsCancelSuccess => 'অনুরোধ বাতিল হয়েছে।';

  @override
  String get requestsCancelError => 'অনুরোধ বাতিল করা যায়নি।';

  @override
  String get requestsEditAction => 'অনুরোধ সম্পাদনা করুন';

  @override
  String get requestsEditTitle => 'অনুরোধ সম্পাদনা';

  @override
  String get requestsEditSubmit => 'পরিবর্তন সংরক্ষণ করুন';

  @override
  String get requestsEditSaving => 'সংরক্ষণ হচ্ছে…';

  @override
  String get requestsEditSuccess => 'অনুরোধ হালনাগাদ হয়েছে।';

  @override
  String get requestsEditError => 'অনুরোধ হালনাগাদ করা যায়নি।';

  @override
  String get requestsContactAction => 'যোগাযোগের তথ্য';

  @override
  String get requestsContactTitle => 'অনুরোধকারীর যোগাযোগের তথ্য';

  @override
  String get requestsContactIntro =>
      'এই তথ্য এই অনুরোধের সঙ্গে গোপনভাবে সংরক্ষিত হয়। এই বিল্ডে ডোনারদের দেখানো হয় না।';

  @override
  String get requestsPatientName => 'রোগীর নাম';

  @override
  String get requestsPhoneNumber => 'ফোন নম্বর';

  @override
  String get requestsHospitalAddress => 'হাসপাতালের ঠিকানা';

  @override
  String get requestsContactSubmit => 'যোগাযোগের তথ্য সংরক্ষণ করুন';

  @override
  String get requestsContactSaving => 'সংরক্ষণ হচ্ছে…';

  @override
  String get requestsContactLoading => 'লোড হচ্ছে…';

  @override
  String get requestsContactSuccess => 'যোগাযোগের তথ্য সংরক্ষিত হয়েছে।';

  @override
  String get requestsContactError => 'যোগাযোগের তথ্য সংরক্ষণ করা যায়নি।';

  @override
  String get requestsContactLoadError =>
      'আপনার সংরক্ষিত যোগাযোগের তথ্য লোড করা যায়নি।';

  @override
  String get requestsContactRetry => 'আবার চেষ্টা করুন';

  @override
  String get requestsMyAction => 'আমার অনুরোধ';

  @override
  String get requestsMyTitle => 'আমার অনুরোধ';

  @override
  String get requestsMyEmptyTitle => 'আপনার কোনো খোলা অনুরোধ নেই';

  @override
  String get requestsMyEmptyBody =>
      'আপনি তৈরি করা অনুরোধগুলো পূরণ বা বাতিল হওয়া পর্যন্ত এখানে দেখাবে।';

  @override
  String get requestsFilterLabel => 'গ্রুপ অনুযায়ী ফিল্টার';

  @override
  String get requestsFilterEmpty =>
      'এই মুহূর্তে এই গ্রুপের কোনো খোলা অনুরোধ নেই।';

  @override
  String get feedCopied => 'পোস্টের লেখাটি কপি হয়েছে।';

  @override
  String get feedEdited => 'সম্পাদিত';

  @override
  String get feedJustNow => 'এইমাত্র';

  @override
  String feedMinutesAgo(num count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '$countString মিনিট আগে';
  }

  @override
  String feedHoursAgo(num count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '$countString ঘণ্টা আগে';
  }

  @override
  String feedDaysAgo(num count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '$countString দিন আগে';
  }

  @override
  String feedOnDate(String date) {
    return '$date তারিখে';
  }

  @override
  String feedLikeCount(num count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '$countString লাইক';
  }

  @override
  String feedCommentCount(num count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '$countString মন্তব্য';
  }

  @override
  String get commentsSheetTitle => 'মন্তব্য';

  @override
  String get commentsEmptyBody => 'এখনো কোনো মন্তব্য নেই। প্রথম হোন।';

  @override
  String get commentsLoading => 'মন্তব্য লোড হচ্ছে…';

  @override
  String get commentsHintText => 'একটি মন্তব্য লিখুন…';

  @override
  String get commentsSendTooltip => 'পাঠান';

  @override
  String get commentsErrorTitle => 'মন্তব্য লোড করা যায়নি';

  @override
  String commentsReplyPrefix(String name) {
    return '$name-কে উত্তর';
  }

  @override
  String commentsReplyingTo(String name) {
    return '$name-কে উত্তর দিচ্ছেন';
  }

  @override
  String get commentsReplyHint => 'উত্তর লিখুন…';

  @override
  String get commentsReplyAction => 'উত্তর';

  @override
  String get commentsDeleteAction => 'মুছুন';

  @override
  String get reportTooltip => 'রিপোর্ট';

  @override
  String get reportSheetTitle => 'এই পোস্ট রিপোর্ট করুন';

  @override
  String get reportCommentSheetTitle => 'এই মন্তব্য রিপোর্ট করুন';

  @override
  String get reportReasonLabel => 'কারণ';

  @override
  String get reportReasonSpam => 'স্প্যাম';

  @override
  String get reportReasonHarassment => 'হয়রানি';

  @override
  String get reportReasonHateSpeech => 'ঘৃণামূলক বক্তব্য';

  @override
  String get reportReasonMisinformation => 'ভুল তথ্য';

  @override
  String get reportReasonOther => 'অন্যান্য';

  @override
  String get reportNoteHint => 'অতিরিক্ত বিবরণ (ঐচ্ছিক)';

  @override
  String get reportSubmitButton => 'রিপোর্ট জমা দিন';

  @override
  String get reportSubmitting => 'জমা হচ্ছে…';

  @override
  String get reportSuccess => 'রিপোর্ট জমা হয়েছে। ধন্যবাদ।';

  @override
  String get reportError => 'রিপোর্ট জমা করা যায়নি।';

  @override
  String get feedUnreadableTitle => 'ফিড সম্পূর্ণভাবে পড়া যায়নি';

  @override
  String get feedUnreadableBody =>
      'এর পেছনে আরও পোস্ট আছে, তবে সেগুলো পড়া যায়নি।';

  @override
  String feedSkippedNotice(num count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '$countStringটি পোস্ট দেখানো যায়নি';
  }

  @override
  String feedPostPhotoLabel(String name) {
    return '$name-এর শেয়ার করা ছবি';
  }

  @override
  String get feedComposeAction => 'একটি আপডেট শেয়ার করুন';

  @override
  String get feedComposeTitle => 'নতুন পোস্ট';

  @override
  String get feedComposeTextLabel => 'আপনার আপডেট';

  @override
  String get feedComposeTextHint =>
      'খবর, অনুরোধ, বা রক্তদান শিবিরের একটি গল্প শেয়ার করুন।';

  @override
  String feedComposeLimit(num count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'সর্বোচ্চ $countString অক্ষর';
  }

  @override
  String get feedComposePhotosLabel => 'ছবি';

  @override
  String get feedComposeAddPhoto => 'ছবি যোগ করুন';

  @override
  String get feedComposeFromGallery => 'গ্যালারি থেকে বেছে নিন';

  @override
  String get feedComposeFromCamera => 'ছবি তুলুন';

  @override
  String get feedComposeRemovePhoto => 'ছবি সরান';

  @override
  String get feedComposeUploading => 'আপনার ছবি আপলোড হচ্ছে…';

  @override
  String get feedComposePublish => 'পোস্ট করুন';

  @override
  String get feedComposePublished => 'আপনার পোস্ট প্রকাশিত হয়েছে।';

  @override
  String get feedComposePhotosNotConfigured =>
      'এই বিল্ডে ছবি আপলোড এখনো চালু হয়নি।';

  @override
  String get feedComposeDiscardTitle => 'এই পোস্টটি বাতিল করবেন?';

  @override
  String get feedComposeDiscardBody => 'আপনার লেখা ও ছবি মুছে যাবে।';

  @override
  String get feedComposeDiscardConfirm => 'বাতিল করুন';

  @override
  String get feedComposeKeepEditing => 'লেখা চালিয়ে যান';

  @override
  String get requestsTitle => 'খোলা অনুরোধ';

  @override
  String get requestsEmptyTitle => 'এখন কোনো খোলা অনুরোধ নেই';

  @override
  String get requestsEmptyBody =>
      'এই মুহূর্তে কোনো অনুরোধ খোলা হিসেবে চিহ্নিত নেই। আবার দেখতে নিচের দিকে টানুন।';

  @override
  String get requestsErrorTitle => 'অনুরোধগুলো আনা যায়নি';

  @override
  String get requestsRetry => 'আবার চেষ্টা করুন';

  @override
  String get requestsUnreadableTitle => 'অনুরোধগুলো সম্পূর্ণভাবে পড়া যায়নি';

  @override
  String get requestsUnreadableBody =>
      'এর পেছনে খোলা অনুরোধ আছে, তবে সেগুলো পড়া যায়নি।';

  @override
  String requestsSkippedNotice(num count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '$countStringটি অনুরোধ দেখানো যায়নি';
  }

  @override
  String requestsTruncatedNotice(num count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'এখানে প্রথম $countStringটি খোলা অনুরোধ দেখানো হচ্ছে। এর পেছনে আরও আছে।';
  }

  @override
  String get requestsNoActionNote =>
      'এখানে দেখা যাচ্ছে কী এবং কোথায় দরকার। আপনি যোগ্য হলে অনুরোধটি খুলে গ্রহণ করতে পারেন।';

  @override
  String get donorSearchTitle => 'দাতা খুঁজুন';

  @override
  String get donorDetailsTitle => 'দাতার প্রোফাইল';

  @override
  String get donorUnnamed => 'রক্তদাতা';

  @override
  String get donorRetry => 'আবার চেষ্টা করুন';

  @override
  String get donorAvailable => 'উপলব্ধ';

  @override
  String get donorUnavailable => 'উপলব্ধ নন';

  @override
  String get donorGroupNotSet => 'রক্তের গ্রুপ নির্ধারণ করা হয়নি';

  @override
  String get donorAvailabilityHeading => 'উপলব্ধতা';

  @override
  String get donorAvailabilityFilter => 'শুধু উপলব্ধ দাতা';

  @override
  String get donorFilterAllGroups => 'সব গ্রুপ';

  @override
  String get donorAreaFieldLabel => 'এলাকা';

  @override
  String get donorAreaFieldHint => 'এলাকা বা মহল্লা';

  @override
  String get donorClearArea => 'এলাকা মুছে ফেলুন';

  @override
  String get donorSearchButton => 'খুঁজুন';

  @override
  String get donorErrorTitle => 'দাতাদের আনা যায়নি';

  @override
  String get donorUnreadableTitle => 'দাতাদের সম্পূর্ণভাবে পড়া যায়নি';

  @override
  String get donorUnreadableBody =>
      'এর পেছনে দাতা আছেন, তবে তাঁদের প্রোফাইল পড়া যায়নি।';

  @override
  String get donorEmptyFilteredTitle => 'আপনার ফিল্টারে কোনো দাতা নেই';

  @override
  String get donorEmptyFilteredBody =>
      'রক্তের গ্রুপ, উপলব্ধতা বা এলাকা কিছুটা বড় করে দেখুন।';

  @override
  String get donorEmptyAllTitle => 'এখনো কোনো দাতা তালিকাভুক্ত হননি';

  @override
  String get donorEmptyAllBody =>
      'যিনি নিজেকে খোঁজে উঠতে সম্মতি দেবেন, তাঁরা এখানে দেখা যাবেন।';

  @override
  String get donorContactNote =>
      'দাতাদের গোপনীয়তার জন্য যোগাযোগের তথ্য এখানে দেখানো হয় না। অনুরোধের মাধ্যমে যোগাযোগ করা হয়।';

  @override
  String get donorConsentNote =>
      'এই দাতা অনুসন্ধানে দেখা দেওয়ার সম্মতি দিয়েছেন। এলাকা কেবল তিনি প্রকাশ করলেই দেখা যায়।';

  @override
  String donorSkippedNotice(num count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '$countStringজন দাতা দেখানো যায়নি';
  }

  @override
  String donorTruncatedNotice(num count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'এখানে প্রথম $countStringজন দাতা দেখানো হচ্ছে। এর পেছনে আরও আছেন।';
  }

  @override
  String get errorPostTextRequired => 'পোস্ট করার আগে কিছু লিখুন';

  @override
  String errorPostTextTooLong(num count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'আপনার পোস্ট $countString অক্ষরের কম রাখুন';
  }

  @override
  String errorPostTooManyImages(num count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'সর্বোচ্চ $countStringটি ছবি যোগ করুন';
  }
}
