import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sholovvo_app/core/error/failure.dart';
import 'package:sholovvo_app/core/media/photo.dart';
import 'package:sholovvo_app/core/media/photo_picker.dart';
import 'package:sholovvo_app/core/result/result.dart';
import 'package:sholovvo_app/features/profile/application/profile_photo_providers.dart';
import 'package:sholovvo_app/features/profile/application/profile_providers.dart';
import 'package:sholovvo_app/features/profile/domain/user_profile.dart';

import '../../support/fake_photo_services.dart';
import '../../support/fake_profile_repository.dart';

/// The order the two backends were touched in, shared by the recording fakes.
///
/// The ordering *is* the design here — an upload with no published URL is an
/// orphan, a published URL with no upload is a broken card — so the tests assert
/// the sequence rather than only the end state.
final List<String> _events = <String>[];

class _RecordingRepository extends FakeProfileRepository {
  _RecordingRepository({super.profile});

  @override
  Future<Result<void>> setPhotoUrl(String? photoUrl) {
    _events.add(photoUrl == null ? 'clear' : 'publish');
    return super.setPhotoUrl(photoUrl);
  }

  @override
  Future<Result<void>> setCoverUrl(String? coverUrl) {
    _events.add(coverUrl == null ? 'clearCover' : 'publishCover');
    return super.setCoverUrl(coverUrl);
  }
}

class _RecordingStorage extends FakePhotoStorage {
  @override
  Future<Result<String>> uploadAvatar(ValidatedPhoto photo) {
    _events.add('upload');
    return super.uploadAvatar(photo);
  }

  @override
  Future<Result<bool>> removeAvatar(String publicUrl) {
    _events.add('delete');
    return super.removeAvatar(publicUrl);
  }

  @override
  Future<Result<String>> uploadCover(ValidatedPhoto photo) {
    _events.add('uploadCover');
    return super.uploadCover(photo);
  }

  @override
  Future<Result<bool>> removeCover(String publicUrl) {
    _events.add('deleteCover');
    return super.removeCover(publicUrl);
  }
}

void main() {
  late _RecordingRepository repo;
  late _RecordingStorage storage;
  late FakePhotoPicker picker;
  late ProviderContainer container;

  ProfilePhotoController controller() =>
      container.read(profilePhotoControllerProvider.notifier);

  /// Mounts the controller with all three seams stubbed out.
  void setUpController({UserProfile? profile, bool isConfigured = true}) {
    _events.clear();
    repo = _RecordingRepository(profile: profile);
    storage = _RecordingStorage()..isConfigured = isConfigured;
    picker = FakePhotoPicker(candidate: PhotoCandidate(bytes: jpegBytes()));
    container = ProviderContainer(
      overrides: [
        profileRepositoryProvider.overrideWithValue(repo),
        profilePhotoStorageProvider.overrideWithValue(storage),
        photoPickerProvider.overrideWithValue(picker),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(repo.dispose);
  }

  /// The profile of a donor who already has a photo at [url].
  UserProfile withPhoto(String url) => filledProfile.withPhoto(url);

  /// The profile of a donor who already has a cover at [url].
  UserProfile withCover(String url) => filledProfile.withCover(url);

  group('ProfilePhotoController.chooseAndUpload', () {
    test('uploads the object, then publishes the URL it came back with', () async {
      setUpController(profile: filledProfile);

      final Result<bool> result = await controller().chooseAndUpload(
        PhotoSource.gallery,
      );

      expect(result.valueOrNull, isTrue);
      expect(_events, <String>['upload', 'publish']);
      expect(picker.lastSource, PhotoSource.gallery);
      expect(storage.lastUpload?.format, PhotoFormat.jpeg);
      expect(repo.lastPhotoUrl, storage.uploadUrl);
      expect(repo.profile?.photoUrl, storage.uploadUrl);
      // Success leaves no lasting "saved" flag: the call's own result is what
      // the screen reports.
      expect(container.read(profilePhotoControllerProvider), isA<AsyncData<void>>());
    });

    test('a cancelled picker is not a failure and writes nothing', () async {
      setUpController(profile: filledProfile);
      picker.candidate = null;

      final Result<bool> result = await controller().chooseAndUpload(
        PhotoSource.camera,
      );

      expect(result.isSuccess, isTrue);
      expect(result.valueOrNull, isFalse, reason: 'nothing replaced the photo');
      expect(_events, isEmpty);
      expect(storage.uploadCalls, 0);
      expect(repo.photoUrlCalls, 0);
    });

    test('a refused picker is reported without touching either backend', () async {
      setUpController(profile: filledProfile);
      picker.failure = ValidationFailure(
        messageKey: PhotoIssue.accessDenied.name,
        debugMessage: 'the donor said no',
      );

      final Result<bool> result = await controller().chooseAndUpload(
        PhotoSource.gallery,
      );

      expect(PhotoValidator.issueOf(result.failureOrNull!), PhotoIssue.accessDenied);
      expect(_events, isEmpty);
      expect(repo.photoUrlCalls, 0);
      expect(
        container.read(profilePhotoControllerProvider),
        isA<AsyncError<void>>(),
      );
    });

    test('a file the validator refuses never reaches the network', () async {
      setUpController(profile: filledProfile);
      picker.candidate = PhotoCandidate(bytes: textBytes(), fileName: 'me.jpg');

      final Result<bool> result = await controller().chooseAndUpload(
        PhotoSource.gallery,
      );

      expect(
        PhotoValidator.issueOf(result.failureOrNull!),
        PhotoIssue.unsupportedType,
      );
      expect(_events, isEmpty);
      expect(storage.uploadCalls, 0);
    });

    test('an unconfigured build fails by name instead of uploading', () async {
      setUpController(profile: filledProfile, isConfigured: false);

      final Result<bool> result = await controller().chooseAndUpload(
        PhotoSource.gallery,
      );
      final Failure failure = result.failureOrNull!;

      expect(failure, isA<ConfigurationFailure>());
      expect((failure as ConfigurationFailure).setting, contains('SUPABASE'));
      // Nothing was sent, and the profile was not touched.
      expect(storage.uploadCalls, 0);
      expect(_events, isEmpty);
    });

    test('a failed upload leaves the published photo exactly as it was', () async {
      final String previous = FakePhotoStorage.defaultUploadUrl;
      setUpController(profile: withPhoto(previous));
      storage.uploadFailure = const NetworkFailure(debugMessage: 'offline');

      final Result<bool> result = await controller().chooseAndUpload(
        PhotoSource.gallery,
      );

      expect(result.failureOrNull, isA<NetworkFailure>());
      expect(_events, <String>['upload']);
      expect(repo.photoUrlCalls, 0);
      expect(repo.profile?.photoUrl, previous);
    });

    test('a failed profile write deletes the object it just uploaded', () async {
      final String previous = FakePhotoStorage.defaultUploadUrl;
      setUpController(profile: withPhoto(previous));
      repo.photoUrlFailure = const PermissionFailure(debugMessage: 'denied');

      final Result<bool> result = await controller().chooseAndUpload(
        PhotoSource.gallery,
      );

      expect(result.failureOrNull, isA<PermissionFailure>());
      // Uploaded, rejected, compensated: no object is left behind that nothing
      // points at, and the old photo is still published.
      expect(_events, <String>['upload', 'publish', 'delete']);
      expect(storage.removedUrls, <String>[storage.uploadUrl]);
      expect(repo.profile?.photoUrl, previous);
    });

    test('a second operation while one is running is refused, not raced', () async {
      setUpController(profile: filledProfile);
      storage.gate = Completer<void>();

      final Future<Result<bool>> first = controller().chooseAndUpload(
        PhotoSource.gallery,
      );
      // Let the first call reach the gated upload, the way it would sit on a slow
      // network. The screen's own spinner is covered by the widget tests; what
      // matters here is that a second call cannot start behind the first.
      await pumpEventQueue();

      final Result<bool> second = await controller().chooseAndUpload(
        PhotoSource.camera,
      );

      expect(second.failureOrNull, isA<ConflictFailure>());
      expect(storage.uploadCalls, 1);
      expect(_events, <String>['upload'], reason: 'the second call never started');

      storage.gate!.complete();
      expect((await first).valueOrNull, isTrue);
      expect(_events, <String>['upload', 'publish']);
    });
  });

  group('ProfilePhotoController.remove', () {
    test('clears the profile first, then deletes the object', () async {
      final String url = FakePhotoStorage.defaultUploadUrl;
      setUpController(profile: withPhoto(url));

      final Result<void> result = await controller().remove(url);

      expect(result.isSuccess, isTrue);
      expect(_events, <String>['clear', 'delete']);
      expect(repo.lastPhotoUrl, isNull);
      expect(repo.profile?.photoUrl, isNull);
      expect(repo.profile?.hasPhoto, isFalse);
      expect(storage.removedUrls, <String>[url]);
    });

    test('does nothing at all when there is no photo to remove', () async {
      setUpController(profile: filledProfile);

      expect((await controller().remove(null)).isSuccess, isTrue);
      expect((await controller().remove('   ')).isSuccess, isTrue);

      expect(_events, isEmpty);
      expect(repo.photoUrlCalls, 0);
      expect(storage.removedUrls, isEmpty);
    });

    test('a refused profile write leaves the object alone', () async {
      final String url = FakePhotoStorage.defaultUploadUrl;
      setUpController(profile: withPhoto(url));
      repo.photoUrlFailure = const NetworkFailure(debugMessage: 'offline');

      final Result<void> result = await controller().remove(url);

      expect(result.failureOrNull, isA<NetworkFailure>());
      // The photo is still published, so the object behind it must still exist.
      expect(_events, <String>['clear']);
      expect(storage.removedUrls, isEmpty);
      expect(repo.profile?.photoUrl, url);
    });

    test('a failed delete does not turn a finished removal into an error', () async {
      final String url = FakePhotoStorage.defaultUploadUrl;
      setUpController(profile: withPhoto(url));
      storage.removeFailure = const NetworkFailure(debugMessage: 'offline');

      final Result<void> result = await controller().remove(url);

      expect(result.isSuccess, isTrue, reason: 'the profile is what the donor sees');
      expect(_events, <String>['clear', 'delete']);
      expect(repo.profile?.photoUrl, isNull);
    });
  });

  group('ProfilePhotoController cover', () {
    test('chooses, uploads and publishes a cover without touching the photo', () async {
      setUpController(profile: filledProfile);

      final Result<bool> result = await controller().chooseAndUploadCover(
        PhotoSource.gallery,
      );

      expect(result.valueOrNull, isTrue);
      expect(_events, <String>['uploadCover', 'publishCover']);
      expect(storage.lastCoverUpload?.format, PhotoFormat.jpeg);
      expect(repo.lastCoverUrl, storage.coverUrl);
      expect(repo.profile?.coverUrl, storage.coverUrl);
      // The avatar is a separate field and a separate narrow write; a cover
      // change must not publish or clear it.
      expect(repo.photoUrlCalls, 0);
      expect(repo.profile?.photoUrl, filledProfile.photoUrl);
    });

    test('a failed cover write deletes the object it just uploaded', () async {
      setUpController(profile: filledProfile);
      repo.coverUrlFailure = const PermissionFailure(debugMessage: 'denied');

      final Result<bool> result = await controller().chooseAndUploadCover(
        PhotoSource.gallery,
      );

      expect(result.failureOrNull, isA<PermissionFailure>());
      expect(_events, <String>['uploadCover', 'publishCover', 'deleteCover']);
      expect(storage.coverRemovedUrls, <String>[storage.coverUrl]);
      expect(repo.profile?.coverUrl, isNull);
    });

    test('removing a cover clears the field first, then deletes the object', () async {
      final String url = FakePhotoStorage.defaultCoverUploadUrl;
      setUpController(profile: withCover(url));

      final Result<void> result = await controller().removeCover(url);

      expect(result.isSuccess, isTrue);
      expect(_events, <String>['clearCover', 'deleteCover']);
      expect(repo.lastCoverUrl, isNull);
      expect(repo.profile?.hasCover, isFalse);
      expect(storage.coverRemovedUrls, <String>[url]);
      // Removing the cover never touches the avatar's field or object.
      expect(repo.photoUrlCalls, 0);
      expect(storage.removedUrls, isEmpty);
    });

    test('an empty cover removal writes and deletes nothing', () async {
      setUpController(profile: filledProfile);

      expect((await controller().removeCover(null)).isSuccess, isTrue);

      expect(_events, isEmpty);
      expect(repo.coverUrlCalls, 0);
      expect(storage.coverRemovedUrls, isEmpty);
    });

    test('a cover upload cannot race an avatar upload on the same document', () async {
      setUpController(profile: filledProfile);
      storage.gate = Completer<void>();

      final Future<Result<bool>> first = controller().chooseAndUpload(
        PhotoSource.gallery,
      );
      await pumpEventQueue();

      // The second call targets the *other* image, but it is the same Firestore
      // document, so the one shared busy gate must refuse it.
      final Result<bool> second = await controller().chooseAndUploadCover(
        PhotoSource.gallery,
      );

      expect(second.failureOrNull, isA<ConflictFailure>());
      expect(storage.uploadCalls, 1);
      expect(storage.coverUploadCalls, 0);

      storage.gate!.complete();
      expect((await first).valueOrNull, isTrue);
    });
  });
}
