import 'package:test/test.dart';
import 'package:ulink_cli/config/constants.dart';

void main() {
  group('ULinkConstants', () {
    const legacy =
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoiYW5vbiJ9.c2lnbmF0dXJl';

    test('embedded key is a publishable key, not a legacy JWT', () {
      expect(ULinkConstants.supabaseAnonKey, startsWith('sb_publishable_'));
    });

    group('resolveSupabaseKey', () {
      test('replaces a stored legacy key for the production project', () {
        expect(
          ULinkConstants.resolveSupabaseKey(
            supabaseUrl: ULinkConstants.supabaseUrl,
            storedKey: legacy,
          ),
          ULinkConstants.supabaseAnonKey,
        );
      });

      test('ignores a trailing slash on the stored production URL', () {
        expect(
          ULinkConstants.resolveSupabaseKey(
            supabaseUrl: '${ULinkConstants.supabaseUrl}/',
            storedKey: legacy,
          ),
          ULinkConstants.supabaseAnonKey,
        );
      });

      test('keeps a stored publishable key', () {
        expect(
          ULinkConstants.resolveSupabaseKey(
            supabaseUrl: ULinkConstants.supabaseUrl,
            storedKey: 'sb_publishable_other',
          ),
          'sb_publishable_other',
        );
      });

      test('keeps any key for a non-production project', () {
        expect(
          ULinkConstants.resolveSupabaseKey(
            supabaseUrl: 'http://127.0.0.1:54321',
            storedKey: legacy,
          ),
          legacy,
        );
      });

      test('keeps the stored key when the URL is unknown', () {
        expect(
          ULinkConstants.resolveSupabaseKey(
              supabaseUrl: null, storedKey: legacy),
          legacy,
        );
      });
    });
  });
}
