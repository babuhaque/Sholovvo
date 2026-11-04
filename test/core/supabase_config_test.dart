import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sholovvo_app/core/config/supabase_config.dart';

/// A JWT-shaped string whose payload is [payload].
///
/// The signature is nonsense on purpose: the client only ever inspects the
/// payload to keep a privileged key out of the bundle, so a real signature would
/// add nothing to the test.
String _jwt(Map<String, Object?> payload) {
  final String body = base64Url
      .encode(utf8.encode(jsonEncode(payload)))
      .replaceAll('=', '');
  return 'eyJhbGciOiJub25lIn0.$body.c2lnbmF0dXJl';
}

void main() {
  group('SupabaseConfig.isConfigured', () {
    test('is false with no defines at all, which is the default build', () {
      const SupabaseConfig config = SupabaseConfig();

      expect(config.isConfigured, isFalse);
      expect(config.storageUrl, isNull);
      expect(config.rejection, isNull);
    });

    test('is true for an https project URL and a publishable key', () {
      const SupabaseConfig config = SupabaseConfig(
        url: 'https://abcdefgh.supabase.co',
        publishableKey: 'sb_publishable_abc123',
      );

      expect(config.isConfigured, isTrue);
      // `storage_client` appends `object/...`, so the base ends at `/storage/v1`.
      expect(
        config.storageUrl,
        'https://abcdefgh.supabase.co/storage/v1',
      );
    });

    test('accepts the legacy anon-role JWT as well', () {
      final SupabaseConfig config = SupabaseConfig(
        url: 'https://abcdefgh.supabase.co',
        publishableKey: _jwt(<String, Object?>{'role': 'anon', 'iss': 'supabase'}),
      );

      expect(config.isConfigured, isTrue);
    });

    test('tolerates a trailing slash in the URL', () {
      // Whitespace is trimmed where the define is read (`fromEnvironment`), so
      // only the slash matters here.
      const SupabaseConfig config = SupabaseConfig(
        url: 'https://abcdefgh.supabase.co/',
        publishableKey: 'sb_publishable_abc123',
      );

      expect(config.storageUrl, 'https://abcdefgh.supabase.co/storage/v1');
    });

    test('refuses plain http, because the bearer token would travel in clear '
        'text', () {
      const SupabaseConfig config = SupabaseConfig(
        url: 'http://abcdefgh.supabase.co',
        publishableKey: 'sb_publishable_abc123',
      );

      expect(config.isConfigured, isFalse);
      expect(config.storageUrl, isNull);
    });

    test('refuses a URL that is not a dotted host', () {
      for (final String url in <String>['not a url', 'https://localhost', '']) {
        final SupabaseConfig config = SupabaseConfig(
          url: url,
          publishableKey: 'sb_publishable_abc123',
        );

        expect(config.isConfigured, isFalse, reason: url);
      }
    });

    test('refuses a missing key even with a good URL', () {
      const SupabaseConfig config = SupabaseConfig(url: 'https://abc.supabase.co');

      expect(config.isConfigured, isFalse);
    });
  });

  group('SupabaseConfig.rejectPrivilegedKey', () {
    test('accepts empty, publishable and anon keys', () {
      expect(SupabaseConfig.rejectPrivilegedKey(''), isNull);
      expect(
        SupabaseConfig.rejectPrivilegedKey('sb_publishable_abc123'),
        isNull,
      );
      expect(
        SupabaseConfig.rejectPrivilegedKey(
          _jwt(<String, Object?>{'role': 'anon'}),
        ),
        isNull,
      );
    });

    test('rejects the sb_secret_ key, which bypasses every policy', () {
      expect(
        SupabaseConfig.rejectPrivilegedKey('sb_secret_abc123'),
        SupabaseKeyRejection.secretKey,
      );
    });

    test('rejects a JWT whose payload carries the service_role claim', () {
      expect(
        SupabaseConfig.rejectPrivilegedKey(
          _jwt(<String, Object?>{'role': 'service_role'}),
        ),
        SupabaseKeyRejection.serviceRoleToken,
      );
    });

    test('is whitespace tolerant, since the value comes from a command line', () {
      expect(
        SupabaseConfig.rejectPrivilegedKey('  sb_secret_abc123  '),
        SupabaseKeyRejection.secretKey,
      );
    });

    test('treats an undecodable key as "not recognised" rather than crashing', () {
      expect(SupabaseConfig.rejectPrivilegedKey('a.!!!.c'), isNull);
    });
  });

  group('SupabaseConfig with a rejected key', () {
    test('drops the key so no code path can send it', () {
      final SupabaseConfig config = SupabaseConfig(
        url: 'https://abcdefgh.supabase.co',
        publishableKey: '',
        rejection: SupabaseConfig.rejectPrivilegedKey('sb_secret_abc123'),
      );

      expect(config.isConfigured, isFalse);
      expect(config.publishableKey, isEmpty);
      expect(config.rejection, SupabaseKeyRejection.secretKey);
    });

    test('fromEnvironment reports no rejection when no define is present', () {
      // The test runner passes no `--dart-define`, which is also what a plain
      // `flutter build` does: unconfigured, and honest about it.
      final SupabaseConfig config = SupabaseConfig.fromEnvironment();

      expect(config.isConfigured, isFalse);
      expect(config.rejection, isNull);
    });
  });

  group('SupabaseConfig.toString', () {
    test('never prints the key, even when it is a rejected one', () {
      final SupabaseConfig config = SupabaseConfig(
        url: 'https://abcdefgh.supabase.co',
        publishableKey: 'sb_secret_do_not_log_me',
        rejection: SupabaseConfig.rejectPrivilegedKey('sb_secret_do_not_log_me'),
      );

      final String text = config.toString();

      expect(text, contains('https://abcdefgh.supabase.co'));
      expect(text, contains('secretKey'));
      expect(text, isNot(contains('do_not_log_me')));
    });
  });

  group('SupabaseConfig.postImagesBucket', () {
    test('defaults to the authoritative community-posts bucket', () {
      const SupabaseConfig config = SupabaseConfig();

      // The owner decision is that community-posts is authoritative and must not
      // be switched back to the earlier post-images name.
      expect(SupabaseConfig.defaultPostImagesBucket, 'community-posts');
      expect(config.postImagesBucket, 'community-posts');
    });

    test('honours an explicit bucket for a build that overrides it', () {
      const SupabaseConfig config = SupabaseConfig(
        postImagesBucket: 'some-other-bucket',
      );

      expect(config.postImagesBucket, 'some-other-bucket');
    });

    test('fromEnvironment falls back to the default when no define is present', () {
      // The test runner passes no `--dart-define`, so the bucket define is empty
      // and the authoritative default must hold rather than an empty string.
      final SupabaseConfig config = SupabaseConfig.fromEnvironment();

      expect(
        config.postImagesBucket,
        SupabaseConfig.defaultPostImagesBucket,
      );
    });
  });
}
