import 'package:flutter_test/flutter_test.dart';
import 'package:sholovvo_app/core/media/photo.dart';
import 'package:sholovvo_app/features/feed/data/supabase_post_image_storage.dart';

void main() {
  group('SupabasePostImageStorage.objectPath', () {
    test('namespaces the object under the caller\'s own uid', () {
      final String path = SupabasePostImageStorage.objectPath(
        uid: 'uid-verified',
        now: DateTime.fromMillisecondsSinceEpoch(1730000000000),
        format: PhotoFormat.jpeg,
      );

      expect(path, 'uid-verified/post-1730000000000-0.jpg');
      // The bucket policy compares this first segment to the token's `sub`, so
      // it must be the uid and nothing else.
      expect(path.split('/').first, 'uid-verified');
    });

    test('is exactly one folder deep, which is what the policy requires', () {
      final String path = SupabasePostImageStorage.objectPath(
        uid: 'uid-verified',
        now: DateTime.fromMillisecondsSinceEpoch(1730000000000),
        format: PhotoFormat.png,
      );

      // `array_length(storage.foldername(name), 1) = 1` — a nested path would be
      // refused by the server, so the client never builds one.
      expect(path.split('/'), hasLength(2));
    });

    test('uses the extension of the sniffed format, not a file name', () {
      final DateTime now = DateTime.fromMillisecondsSinceEpoch(1730000000000);

      expect(
        SupabasePostImageStorage.objectPath(
          uid: 'u1',
          now: now,
          format: PhotoFormat.png,
        ),
        endsWith('.png'),
      );
      expect(
        SupabasePostImageStorage.objectPath(
          uid: 'u1',
          now: now,
          format: PhotoFormat.webp,
        ),
        endsWith('.webp'),
      );
    });

    test('four photos picked in one millisecond never overwrite each other', () {
      final DateTime now = DateTime.fromMillisecondsSinceEpoch(1730000000000);
      final List<String> paths = <String>[
        for (int index = 0; index < 4; index++)
          SupabasePostImageStorage.objectPath(
            uid: 'u1',
            now: now,
            format: PhotoFormat.jpeg,
            index: index,
          ),
      ];

      // This is the whole reason the path carries a sequence number: two
      // uploads at the same millisecond would otherwise be one object, and the
      // second would silently replace the first.
      expect(paths.toSet(), hasLength(4));
      expect(paths[0], 'u1/post-1730000000000-0.jpg');
      expect(paths[3], 'u1/post-1730000000000-3.jpg');
    });

    test('a later millisecond never collides with an earlier one', () {
      expect(
        SupabasePostImageStorage.objectPath(
          uid: 'u1',
          now: DateTime.fromMillisecondsSinceEpoch(1730000000000),
          format: PhotoFormat.jpeg,
        ),
        isNot(
          SupabasePostImageStorage.objectPath(
            uid: 'u1',
            now: DateTime.fromMillisecondsSinceEpoch(1730000000001),
            format: PhotoFormat.jpeg,
          ),
        ),
      );
    });
  });

  group('SupabasePostImageStorage.ownPath', () {
    test('accepts an object in the caller\'s own folder', () {
      expect(
        SupabasePostImageStorage.ownPath(
          'uid-verified/post-1730000000000-0.jpg',
          uid: 'uid-verified',
        ),
        'uid-verified/post-1730000000000-0.jpg',
      );
    });

    test('trims the path it was given', () {
      expect(
        SupabasePostImageStorage.ownPath(
          '  uid-verified/post-1-0.jpg ',
          uid: 'uid-verified',
        ),
        'uid-verified/post-1-0.jpg',
      );
    });

    test('refuses another account\'s folder', () {
      expect(
        SupabasePostImageStorage.ownPath(
          'uid-other/post-1730000000000-0.jpg',
          uid: 'uid-verified',
        ),
        isNull,
      );
    });

    test('refuses a nested path', () {
      // The bucket policy refuses it too; refusing locally means a corrupt
      // `imagePaths` entry costs no round trip.
      expect(
        SupabasePostImageStorage.ownPath(
          'uid-verified/2026/post-1-0.jpg',
          uid: 'uid-verified',
        ),
        isNull,
      );
    });

    test('refuses a bare file name with no folder', () {
      expect(
        SupabasePostImageStorage.ownPath('post-1-0.jpg', uid: 'uid-verified'),
        isNull,
      );
    });

    test('refuses a folder with no name after it', () {
      expect(
        SupabasePostImageStorage.ownPath('uid-verified/', uid: 'uid-verified'),
        isNull,
      );
    });

    test('refuses a name that is a directory traversal', () {
      expect(
        SupabasePostImageStorage.ownPath('uid-verified/..', uid: 'uid-verified'),
        isNull,
      );
      expect(
        SupabasePostImageStorage.ownPath('uid-verified/.', uid: 'uid-verified'),
        isNull,
      );
    });

    test('refuses an empty path', () {
      expect(
        SupabasePostImageStorage.ownPath('   ', uid: 'uid-verified'),
        isNull,
      );
    });

    test('refuses everything without a signed-in uid', () {
      expect(
        SupabasePostImageStorage.ownPath(
          'uid-verified/post-1-0.jpg',
          uid: '',
        ),
        isNull,
      );
    });

    test('refuses a public URL, because a path and a URL are not the same', () {
      // The whole point of storing `imagePaths` beside `imageUrls`: the caller
      // passes a path, and anything that is not one is refused rather than
      // parsed hopefully.
      expect(
        SupabasePostImageStorage.ownPath(
          'https://demo.supabase.co/storage/v1/object/public/post-images/'
          'uid-verified/post-1-0.jpg',
          uid: 'uid-verified',
        ),
        isNull,
      );
    });
  });
}
