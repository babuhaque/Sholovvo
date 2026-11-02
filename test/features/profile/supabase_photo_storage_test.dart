import 'package:flutter_test/flutter_test.dart';
import 'package:sholovvo_app/features/profile/data/supabase_photo_storage.dart';
import 'package:sholovvo_app/features/profile/domain/profile_photo.dart';

/// The storage base a configured project produces.
const String _storageUrl = 'https://demo.supabase.co/storage/v1';

/// The bucket those URLs point into.
const String _bucket = 'avatars';

/// A public URL of [path] inside [_bucket] on [_storageUrl]'s project.
String _publicUrl(String path) =>
    'https://demo.supabase.co/storage/v1/object/public/$_bucket/$path';

void main() {
  group('SupabasePhotoStorage.objectPath', () {
    test('namespaces the object under the caller\'s own uid', () {
      final String path = SupabasePhotoStorage.objectPath(
        uid: 'uid-verified',
        now: DateTime.fromMillisecondsSinceEpoch(1730000000000),
        format: PhotoFormat.jpeg,
      );

      expect(path, 'uid-verified/avatar-1730000000000.jpg');
      // The policies check this first segment against the JWT's `sub`, so it
      // must be the uid and nothing else.
      expect(path.split('/').first, 'uid-verified');
    });

    test('uses the extension of the sniffed format, not the file name', () {
      final DateTime now = DateTime.fromMillisecondsSinceEpoch(1730000000000);

      expect(
        SupabasePhotoStorage.objectPath(
          uid: 'u1',
          now: now,
          format: PhotoFormat.png,
        ),
        endsWith('.png'),
      );
      expect(
        SupabasePhotoStorage.objectPath(
          uid: 'u1',
          now: now,
          format: PhotoFormat.webp,
        ),
        endsWith('.webp'),
      );
    });

    test('a second upload at a later millisecond never overwrites the first', () {
      final String first = SupabasePhotoStorage.objectPath(
        uid: 'u1',
        now: DateTime.fromMillisecondsSinceEpoch(1730000000000),
        format: PhotoFormat.jpeg,
      );
      final String second = SupabasePhotoStorage.objectPath(
        uid: 'u1',
        now: DateTime.fromMillisecondsSinceEpoch(1730000000001),
        format: PhotoFormat.jpeg,
      );

      expect(first, isNot(second));
    });
  });

  group('SupabasePhotoStorage.objectPathOf', () {
    String? pathOf(String url, {String uid = 'uid-verified'}) {
      return SupabasePhotoStorage.objectPathOf(
        url,
        storageUrl: _storageUrl,
        bucket: _bucket,
        uid: uid,
      );
    }

    test('reads back the path of an object in the caller\'s own folder', () {
      expect(
        pathOf(_publicUrl('uid-verified/avatar-1730000000000.jpg')),
        'uid-verified/avatar-1730000000000.jpg',
      );
    });

    test('keeps a nested path together', () {
      expect(
        pathOf(_publicUrl('uid-verified/2026/avatar.jpg')),
        'uid-verified/2026/avatar.jpg',
      );
    });

    test('refuses another account\'s folder: ownership is not ours to cross', () {
      expect(pathOf(_publicUrl('uid-other/avatar-1730000000000.jpg')), isNull);
    });

    test('refuses another bucket', () {
      expect(
        pathOf(
          'https://demo.supabase.co/storage/v1/object/public/covers/uid-verified/a.jpg',
        ),
        isNull,
      );
    });

    test('refuses a different project origin, even with an identical path', () {
      expect(
        pathOf(
          'https://other.supabase.co/storage/v1/object/public/avatars/uid-verified/a.jpg',
        ),
        isNull,
      );
    });

    test('refuses an external image the donor once pasted in', () {
      expect(pathOf('https://example.com/me.jpg'), isNull);
    });

    test('refuses a URL that is not a URL', () {
      expect(pathOf('not a url'), isNull);
    });

    test('ignores a cache-busting query string when the path is still ours', () {
      expect(
        pathOf('${_publicUrl('uid-verified/avatar-1.jpg')}?v=2'),
        'uid-verified/avatar-1.jpg',
      );
    });

    test('refuses a URL that is only the prefix and a bucket', () {
      expect(pathOf('https://demo.supabase.co/storage/v1/object/public/avatars'), isNull);
    });

    test('refuses everything when the project is not configured', () {
      expect(
        SupabasePhotoStorage.objectPathOf(
          _publicUrl('uid-verified/avatar-1.jpg'),
          storageUrl: null,
          bucket: _bucket,
          uid: 'uid-verified',
        ),
        isNull,
      );
    });

    test('refuses everything without a signed-in uid', () {
      expect(pathOf(_publicUrl('uid-verified/avatar-1.jpg'), uid: ''), isNull);
    });
  });
}
